-- Migration 686 (Code C, 27/11/2026, C-26-05, PR-DD2): điều kiện Done mới và dấu Đúng hạn/Trễ hạn tách khỏi lúc Done.
-- Luật: R-GIO-06 (26/11: thêm điều kiện hai cột khớp, ghi mọi điều còn thiếu), R-GIO-07 (khoá sau Done), R-GV-05 (26/11: dấu đóng khi
-- phần việc giáo viên đủ), R-GV-04, R-V2-20, R-V2-35 (giữ). Sổ giờ app.deduct_session_hours KHÔNG đổi.
-- Khoá sau Done: app.set_attendance_ops và các hàm giáo viên đã từ chối buổi Done từ trước; migration này không mở thêm đường sửa.

select set_config('hmt.migration', 'on', false);

alter table app.class_session
  add column done_mode text check (done_mode in ('TU_DONG', 'TAY', 'HANG_LOAT')),
  add column done_by uuid,
  add column done_reason text,
  add column done_missing_review boolean not null default false;
comment on column app.class_session.done_mode is 'Cách buổi hoàn tất: TU_DONG, TAY (Done tay), HANG_LOAT. Null: buổi chưa Done hoặc Done trước 27/11/2026.';
comment on column app.class_session.done_by is 'Người đang thao tác lúc buổi Done (null khi lịch chạy tự Done).';
comment on column app.class_session.done_reason is 'Lý do bắt buộc của Done hàng loạt (R-GIO-12).';
comment on column app.class_session.done_missing_review is 'Cờ Thiếu nhận xét: Done hàng loạt khi còn thiếu nội dung, nhận xét, điểm hoặc BTVN (R-GIO-12).';
comment on column app.class_session.completion_stamped_at is 'Lúc hệ thống đóng dấu Đúng hạn/Trễ hạn (một lần, khi phần việc giáo viên đủ, R-GV-05).';
comment on column app.class_session.completion_late_hours is 'Số giờ trễ lúc đóng dấu (0 khi đúng hạn).';

-- Buổi Đã chốt giáo viên đã tích TRƯỚC khi có chép hai cột (685) mà ô vận hành trống: chép sang để không kẹt vì điều kiện khớp mới (R-DD-04).
update app.session_attendance a set ops_status_code = a.teacher_status_code, ops_source = 'GIAO_VIEN'
  from app.class_session s
 where s.id = a.session_id and s.status_code = 'DA_CHOT' and a.is_active
   and a.teacher_status_code is not null and a.ops_status_code is null;

select set_config('hmt.migration', '', false);

-- app.session_teacher_missing: các việc PHẦN GIÁO VIÊN còn thiếu của một buổi (nội bộ). p_require_review: có đòi BTVN buổi trước,
-- nhận xét hoặc điểm kiểm tra không. Kết quả: mảng câu tiếng Việt, rỗng = đủ.
create or replace function app.session_teacher_missing(p_session_id uuid, p_require_review boolean)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_out text[] := '{}';
  v_n integer;
begin
  select * into s from app.class_session where id = p_session_id;
  -- Luật R-GIO-06: mọi dòng (kể cả học thử) đã có điểm danh của giáo viên.
  select count(*) into v_n from app.session_attendance where session_id = p_session_id and is_active and teacher_status_code is null;
  if v_n > 0 then
    v_out := v_out || format('Giáo viên chưa điểm danh %s em.', v_n);
  end if;
  -- Luật Q-231, R-V2-35: buổi thường cần ít nhất một dòng nội dung; buổi kiểm tra không đòi (Q-252).
  if not app.session_is_exam(s) and not app.session_has_content(p_session_id) then
    v_out := v_out || 'Giáo viên chưa nhập nội dung buổi.'::text;
  end if;
  if p_require_review then
    v_out := v_out || app.session_review_missing(s);
  end if;
  return v_out;
end;
$$;

-- app.session_review_missing: phần BTVN buổi trước và nhận xét hoặc điểm còn thiếu (nội bộ).
create or replace function app.session_review_missing(p_session app.class_session)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_out text[] := '{}';
  v_hw jsonb;
  v_n integer;
begin
  -- Luật Q-272, R-GV-11: chấm BTVN buổi trước (chỉ khi buổi trước có giao).
  v_hw := app.homework_progress(p_session.id);
  if (v_hw ->> 'state') = 'CAN_CHAM' and (v_hw ->> 'done')::integer < (v_hw ->> 'present')::integer then
    v_out := v_out || format('Giáo viên chưa chấm BTVN buổi trước cho %s em.', (v_hw ->> 'present')::integer - (v_hw ->> 'done')::integer);
  end if;
  if app.session_is_exam(p_session) then
    -- Luật R-V2-20: không còn em có mặt, đi muộn ở Chưa chấm.
    if not exists (select from app.session_exam where session_id = p_session.id) then
      return v_out || 'Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.'::text;
    end if;
    select count(*) into v_n from app.session_attendance sa
     where sa.session_id = p_session.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
       and not exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded);
    if v_n > 0 then
      v_out := v_out || format('Giáo viên chưa chấm điểm kiểm tra %s em.', v_n);
    end if;
    return v_out;
  end if;
  -- Luật R-V2-19, R-GV-04: mọi em có mặt, đi muộn không còn ô Chưa đánh giá ở tiêu chí đang bật.
  if not exists (select from app.session_review_criterion where session_id = p_session.id and enabled) then
    return v_out || 'Giáo viên chưa mở phần nhận xét của buổi.'::text;
  end if;
  select count(*) into v_n
    from app.session_attendance sa
    join app.session_review_criterion rc on rc.session_id = sa.session_id and rc.enabled
   where sa.session_id = p_session.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
     and not exists (select from app.session_review_score sc
                      where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA');
  if v_n > 0 then
    v_out := v_out || format('Còn %s ô nhận xét chưa đánh giá.', v_n);
  end if;
  return v_out;
end;
$$;

-- app.session_missing: MỌI điều còn thiếu để buổi được Done (tự Done và Done tay), rỗng = đủ (R-GIO-06, nội bộ).
create or replace function app.session_missing(p_session_id uuid)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_out text[];
  v_n integer;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.status_code <> 'DA_CHOT' then
    return array['Buổi chưa chốt danh sách.'];
  end if;
  if app.session_ends_at(p_session_id) > now() then
    return array['Buổi chưa kết thúc.'];
  end if;
  -- Luật Q-198: tham số tắt thì bỏ điều kiện BTVN, nhận xét, điểm.
  v_out := app.session_teacher_missing(p_session_id, app.get_setting_bool('session_done_requires_review', s.branch_id));
  -- Luật R-GIO-06 (26/11), R-DD-04: ô vận hành bằng ô giáo viên ở mọi dòng. Dòng giáo viên chưa tích đã báo ở trên.
  select count(*) into v_n from app.session_attendance
   where session_id = p_session_id and is_active and teacher_status_code is not null
     and ops_status_code is distinct from teacher_status_code;
  if v_n > 0 then
    v_out := v_out || format('Điểm danh giáo viên và vận hành chưa khớp ở %s em.', v_n);
  end if;
  return v_out;
end;
$$;

-- app.session_pending_reason: câu "vì sao chưa Done" (mọi điều còn thiếu, nối bằng dấu cách); null = đủ. Giữ chữ ký cũ cho các màn đang dùng.
create or replace function app.session_pending_reason(p_session_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(array_to_string(app.session_missing(p_session_id), ' '), '');
$$;

-- app.stamp_teacher_completion: đóng dấu MỘT lần Đúng hạn hoặc Trễ hạn khi phần việc giáo viên đủ (R-GV-05, nội bộ).
-- Không phụ thuộc điều kiện khớp hai cột và giờ kết thúc. p_force: đóng cả khi còn thiếu (lúc buổi Done).
create or replace function app.stamp_teacher_completion(p_session_id uuid, p_force boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_deadline timestamptz;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.completion_stamped_at is not null or s.status_code <> 'DA_CHOT' then
    return;
  end if;
  if not p_force and cardinality(app.session_teacher_missing(p_session_id,
       app.get_setting_bool('session_done_requires_review', s.branch_id))) > 0 then
    return;
  end if;
  -- Hạn: giờ kết thúc buổi cộng teacher_session_complete_hours.
  v_deadline := app.session_ends_at(p_session_id)
                + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer);
  update app.class_session
     set completion_stamped_at = now(),
         completion_late = now() > v_deadline,
         completion_late_hours = greatest(0, round((extract(epoch from (now() - v_deadline)) / 3600.0)::numeric, 2)) -- allow-number: 3600 giây một giờ (đổi giây ra giờ)
   where id = p_session_id;
end;
$$;

-- app.apply_session_done: chuyển một buổi Đã chốt thành Done (nội bộ; nơi gọi tự kiểm điều kiện và đã khoá buổi).
-- Trừ giờ (R-GIO-01), đóng dấu nếu chưa có, ghi cách hoàn tất, ghi danh Đã xếp lớp thành Đang học (R-GD-18).
create or replace function app.apply_session_done(p_session_id uuid, p_mode text, p_reason text default null, p_missing_review boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.deduct_session_hours(p_session_id);
  perform app.stamp_teacher_completion(p_session_id, true);
  update app.class_session
     set status_code = 'DONE', done_mode = p_mode, done_by = auth.uid(), done_reason = p_reason, done_missing_review = p_missing_review
   where id = p_session_id;
  update app.enrollment set status_code = 'DANG_HOC'
   where status_code = 'DA_XEP_LOP' and id in (select enrollment_id from app.session_attendance
                                               where session_id = p_session_id and is_active and enrollment_id is not null);
end;
$$;

-- app.mark_session_done: tự Done một buổi đã đủ điều kiện (lịch chạy và app.complete_session_if_ready gọi).
create or replace function app.mark_session_done(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
begin
  perform 1 from app.class_session where id = p_session_id for update;
  v_reason := app.session_pending_reason(p_session_id);
  if v_reason is not null then
    perform app.raise_error('HMT_BUOI_CHUA_DONE_DUOC', v_reason);
  end if;
  perform app.apply_session_done(p_session_id, 'TU_DONG');
end;
$$;

-- Lấy từ 20261123000624_a2312_done_ngay_khi_hoan_tat.sql; chỉ thêm bước đóng dấu phần giáo viên (R-GV-05).
create or replace function app.complete_session_if_ready(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_state text;
  v_msg text;
  v_hint text;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.id is null or s.status_code <> 'DA_CHOT' then
    return false;
  end if;
  perform app.stamp_teacher_completion(p_session_id);
  if app.session_pending_reason(p_session_id) is not null then
    return false;
  end if;
  begin
    perform app.mark_session_done(p_session_id);
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text, v_hint = pg_exception_hint;
    -- Luật quyết định 23/11: lưu vẫn thành công; buổi giữ Đã chốt; ghi lỗi để vận hành xử lý (P7).
    insert into app.session_auto_done_error as t (session_id, class_id, branch_id, error_code, error_sqlstate, error_message)
    values (s.id, s.class_id, s.branch_id, case when v_hint like 'HMT\_%' then v_hint else v_state end, v_state, coalesce(v_msg, ''))
    on conflict (session_id) do update
      set error_code = excluded.error_code, error_sqlstate = excluded.error_sqlstate, error_message = excluded.error_message,
          attempts = t.attempts + 1, last_error_at = now(), resolved_at = null;
    return false;
  end;
  update app.session_auto_done_error set resolved_at = now() where session_id = s.id and resolved_at is null;
  return true;
end;
$$;

-- Lấy từ 20261126000685_dd1_hai_cot_diem_danh.sql; thêm gọi tự Done: vận hành sửa cho khớp thì Done ngay (R-GIO-06, ca 4).
create or replace function app.set_attendance_ops(p_session_id uuid, p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_row app.session_attendance;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA', true);
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Chỉ ghi điểm danh phía vận hành khi buổi Đã chốt, chưa Done.');
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) loop
    select * into v_row from app.session_attendance
     where session_id = p_session_id and student_id = (e ->> 'student_id')::uuid and is_active for update;
    if v_row.id is null then
      perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Có em không nằm trong danh sách buổi này.');
    end if;
    perform app.write_attendance_ops(v_row, e);
    v_n := v_n + 1;
  end loop;
  perform app.complete_session_if_ready(p_session_id);
  return v_n;
end;
$$;

revoke execute on function app.session_teacher_missing(uuid, boolean) from public, anon, authenticated;
revoke execute on function app.session_review_missing(app.class_session) from public, anon, authenticated;
revoke execute on function app.session_missing(uuid) from public, anon, authenticated;
revoke execute on function app.stamp_teacher_completion(uuid, boolean) from public, anon, authenticated;
revoke execute on function app.apply_session_done(uuid, text, text, boolean) from public, anon, authenticated;
