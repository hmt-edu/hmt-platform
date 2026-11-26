-- Migration 687 (Code C, 27/11/2026, C-26-05, PR-DD2): Done tay (R-GIO-09) và Done hàng loạt (R-GIO-12).
-- Số buổi tối đa một lượt là tham số (DD1 mục 5), tránh giao dịch quá lớn.

select set_config('hmt.migration', 'on', false);
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('session_bulk_done_max', 'Số buổi tối đa một lượt Done hàng loạt', 'INT', 'buổi', 1, 200, '50', false, 'VAN_HANH_LOP', 'R-GIO-12',
        'Done hàng loạt chọn quá số này thì bị từ chối; chia thành nhiều lượt.')
on conflict (key) do nothing;
select set_config('hmt.migration', '', false);

-- app.finish_session: Done tay. Ai gọi: giáo viên, trợ giảng của buổi, người có quyền điểm danh phía vận hành, quản lý cơ sở, Admin
-- (quyền ATTENDANCE · Sửa theo phạm vi). Đủ điều kiện R-GIO-06 thì Done ngay; chưa đủ thì KHÔNG Done và trả danh sách còn thiếu.
-- Vào: buổi. Ra: {done: boolean, missing: [câu tiếng Việt]}. Lỗi trừ giờ (ví dụ quỹ âm) ném ra cho người bấm.
create or replace function app.finish_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_missing text[];
begin
  perform app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  select * into s from app.class_session where id = p_session_id for update;
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done.');
  end if;
  v_missing := app.session_missing(p_session_id);
  if cardinality(v_missing) > 0 then
    return jsonb_build_object('done', false, 'missing', to_jsonb(v_missing));
  end if;
  perform app.apply_session_done(p_session_id, 'TAY');
  update app.session_auto_done_error set resolved_at = now() where session_id = p_session_id and resolved_at is null;
  return jsonb_build_object('done', true, 'missing', '[]'::jsonb);
end;
$$;

-- app.bulk_finish_one: Done một buổi trong lượt hàng loạt (nội bộ, đã kiểm quyền và lý do).
-- Ra: null = đã Done; khác null = câu lý do buổi bị loại. Không bỏ qua điểm danh của giáo viên (R-GIO-12).
create or replace function app.bulk_finish_one(p_session_id uuid, p_reason text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_n integer;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.status_code <> 'DA_CHOT' then
    return case when s.status_code = 'DONE' then 'Buổi đã Done.' else 'Buổi chưa chốt danh sách.' end;
  end if;
  if app.session_ends_at(p_session_id) > now() then
    return 'Buổi chưa kết thúc.';
  end if;
  select count(*) into v_n from app.session_attendance where session_id = p_session_id and is_active and teacher_status_code is null;
  if v_n > 0 then
    return format('Giáo viên chưa điểm danh %s em.', v_n);
  end if;
  -- Cờ Thiếu nhận xét: còn thiếu nội dung, BTVN, nhận xét hoặc điểm (xét đủ cả bốn, không phụ thuộc tham số).
  perform app.apply_session_done(p_session_id, 'HANG_LOAT', p_reason, cardinality(app.session_teacher_missing(p_session_id, true)) > 0);
  update app.session_auto_done_error set resolved_at = now() where session_id = p_session_id and resolved_at is null;
  return null;
end;
$$;

-- app.bulk_finish_sessions: Done hàng loạt. Ai gọi: quản lý cơ sở, Admin (quyền ATTENDANCE · Duyệt ở cơ sở của TỪNG buổi;
-- một buổi ngoài quyền thì từ chối cả lượt). Lý do bắt buộc. Mỗi buổi một khối riêng: lỗi buổi này không chặn buổi khác.
-- Ra: {done: [session_id], skipped: [{session_id, class_code, session_no, reason}]}. Nhật ký từng buổi qua trigger của class_session.
create or replace function app.bulk_finish_sessions(p_session_ids uuid[], p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_max integer := app.get_setting_int('session_bulk_done_max', null)::integer;
  v_why text;
  v_msg text;
  v_done uuid[] := '{}';
  v_skipped jsonb := '[]'::jsonb;
begin
  perform app.assert_bulk_finish_input(p_session_ids, v_reason, v_max);
  for r in select s.id, s.branch_id, s.session_no, c.code as class_code
             from app.class_session s join app.class c on c.id = s.class_id
            where s.id = any (p_session_ids) order by s.id loop
    begin
      v_why := app.bulk_finish_one(r.id, v_reason);
    exception when others then
      get stacked diagnostics v_msg = message_text;
      v_why := v_msg;
    end;
    if v_why is null then
      v_done := v_done || r.id;
    else
      v_skipped := v_skipped || jsonb_build_object('session_id', r.id, 'class_code', r.class_code, 'session_no', r.session_no, 'reason', v_why);
    end if;
  end loop;
  return jsonb_build_object('done', to_jsonb(v_done), 'skipped', v_skipped);
end;
$$;

-- app.assert_bulk_finish_input: kiểm đầu vào của Done hàng loạt (nội bộ): quyền từng cơ sở, lý do, số buổi.
create or replace function app.assert_bulk_finish_input(p_session_ids uuid[], p_reason text, p_max integer)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r record;
  v_count integer := cardinality(coalesce(p_session_ids, '{}'));
begin
  if app.permission_scope('ATTENDANCE', 'DUYET') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản lý cơ sở, Admin được Done hàng loạt.');
  end if;
  if p_reason is null then
    perform app.raise_error('HMT_CAN_LY_DO', 'Done hàng loạt cần ghi lý do.');
  end if;
  if v_count = 0 then
    perform app.raise_error('HMT_CHUA_CHON_BUOI', 'Chưa chọn buổi nào.');
  end if;
  if v_count > p_max then
    perform app.raise_error('HMT_QUA_SO_BUOI', format('Mỗi lượt tối đa %s buổi.', p_max));
  end if;
  if (select count(*) from app.class_session where id = any (p_session_ids)) <> v_count then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Có buổi không tìm thấy hoặc chọn trùng.');
  end if;
  for r in select distinct branch_id from app.class_session where id = any (p_session_ids) loop
    perform app.assert_can('ATTENDANCE', 'DUYET', r.branch_id);
  end loop;
end;
$$;

revoke execute on function app.bulk_finish_one(uuid, text) from public, anon, authenticated;
revoke execute on function app.assert_bulk_finish_input(uuid[], text, integer) from public, anon, authenticated;
