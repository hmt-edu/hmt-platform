-- P7 (Code 3, 13/11/2026): tự Done buổi không nuốt lỗi im lặng (phiếu dieu-phoi-kit#277; nguồn: báo cáo T2 #268).
-- Vấn đề: app.auto_complete_sessions() bắt lỗi từng buổi bằng `exception when others then null`; buổi Done lỗi (vd quỹ giờ âm) nằm im ở Đã chốt, không dấu vết.
-- Làm gì: (1) bảng app.session_auto_done_error: MỘT dòng cho mỗi buổi (mã lỗi HMT_* hoặc sqlstate, câu lỗi, số lần thử, lần đầu, lần cuối, lúc hết lỗi);
--          (2) thay thân hàm: vẫn bắt lỗi TỪNG buổi (một buổi lỗi không chặn buổi khác) nhưng ghi lại; lần chạy sau vẫn thử lại buổi đó; Done được thì đánh dấu đã hết lỗi.
-- KHÔNG đổi luật trừ giờ, điều kiện Done (app.session_pending_reason, app.mark_session_done). Luật: R-GIO-06 (tự Done), R-GD-18 (quỹ giờ không âm).
-- Không phình bảng: mỗi buổi tối đa một dòng (cập nhật số lần thử), nên chạy lại 15 phút một lần không ghi vô hạn.
select set_config('hmt.migration', 'on', false);

create table app.session_auto_done_error (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references app.class_session (id),
  class_id uuid not null references app.class (id),
  branch_id uuid not null references app.branch (id),
  -- Mã lỗi nghiệp vụ HMT_* nếu có, không thì sqlstate.
  error_code text not null,
  error_sqlstate text not null,
  error_message text not null,
  attempts integer not null default 1,
  first_error_at timestamptz not null default now(),
  last_error_at timestamptz not null default now(),
  -- Có giá trị khi lần chạy sau Done được (lỗi đã hết); lỗi lại thì đặt về null.
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.session_auto_done_error is 'Buổi tự Done bị lỗi (P7): một dòng mỗi buổi, kèm mã lỗi, số lần thử. Ghi chỉ qua app.auto_complete_sessions.';
-- Chỉ mục (lý do): khoá duy nhất session_id đã phủ việc tìm theo buổi; class_id cho khoá ngoại; branch_id cho RLS; lỗi chưa hết xem theo thời gian (màn theo dõi).
create index session_auto_done_error_class_idx on app.session_auto_done_error (class_id);
create index session_auto_done_error_branch_idx on app.session_auto_done_error (branch_id);
create index session_auto_done_error_open_idx on app.session_auto_done_error (last_error_at desc) where resolved_at is null;
select app.apply_standard('app.session_auto_done_error');

alter table app.session_auto_done_error enable row level security;
grant select on app.session_auto_done_error to authenticated;
-- Chỉ quản trị đọc (nhật ký kỹ thuật); không policy ghi: chỉ hàm tự Done (security definer) ghi.
create policy session_auto_done_error_read on app.session_auto_done_error for select to authenticated
  using ((select app.has_permission('ADMIN', 'XEM')));

-- app.auto_complete_sessions(): tự Done (R-GIO-06): các buổi Đã chốt đã đủ điều kiện thì Done; chưa đủ thì giữ Đã chốt (lý do xem app.session_pending_reason).
-- Mỗi buổi một lỗi không chặn buổi khác; lỗi được GHI vào app.session_auto_done_error (P7). Kết quả: số buổi đã Done.
create or replace function app.auto_complete_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_n integer := 0;
  v_ok boolean;
  v_state text;
  v_msg text;
  v_hint text;
begin
  for r in select s.id, s.class_id, s.branch_id from app.class_session s where s.status_code = 'DA_CHOT' order by s.session_date, s.start_time loop
    if app.session_pending_reason(r.id) is null then
      v_ok := false;
      begin
        perform app.mark_session_done(r.id);
        v_ok := true;
      exception when others then
        get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text, v_hint = pg_exception_hint;
        -- Luật P7: ghi lại, không nuốt. Chính việc ghi lỗi hỏng cũng không được chặn buổi khác (chỉ báo cảnh báo).
        begin
          insert into app.session_auto_done_error as t (session_id, class_id, branch_id, error_code, error_sqlstate, error_message)
          values (r.id, r.class_id, r.branch_id, case when v_hint like 'HMT\_%' then v_hint else v_state end, v_state, coalesce(v_msg, ''))
          on conflict (session_id) do update
            set error_code = excluded.error_code, error_sqlstate = excluded.error_sqlstate, error_message = excluded.error_message,
                attempts = t.attempts + 1, last_error_at = now(), resolved_at = null;
        exception when others then
          raise warning 'Không ghi được lỗi tự Done của buổi %: %', r.id, sqlerrm;
        end;
      end;
      if v_ok then
        v_n := v_n + 1;
        -- Buổi từng lỗi nay Done được: đánh dấu đã hết lỗi.
        update app.session_auto_done_error set resolved_at = now() where session_id = r.id and resolved_at is null;
      end if;
    end if;
  end loop;
  return v_n;
end;
$$;

select set_config('hmt.migration', '', false);
