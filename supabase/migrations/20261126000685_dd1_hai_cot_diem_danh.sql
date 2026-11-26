-- Migration 685 (Code C, 26/11/2026, C-26-05, PR-DD1): hai cột điểm danh theo DD1 (anh Trường duyệt 26/11).
-- DD-02: cờ vắng, báo cáo, giờ chỉ đọc cột giáo viên. DD-04 và C1: giáo viên lưu thì chép sang ô vận hành khi ô đó trống hoặc còn là ô
-- do chép (vận hành chưa tự tích). DD-03, DD-05: vận hành ghi riêng từng phần (trạng thái, lý do liên hệ, ghi chú).
-- Trạng thái, lý do liên hệ, ghi chú phía vận hành đã có cột từ migration 102; ở đây chỉ thêm nguồn ô, người và giờ ghi.
-- Màn gọi nhắc trong ngày (app.absent_today_list, app.absent_today_group_counts) vẫn đọc cả cột vận hành để gọi, không tính vào báo cáo.

select set_config('hmt.migration', 'on', false);

alter table app.session_attendance
  add column ops_source text check (ops_source in ('GIAO_VIEN', 'VAN_HANH')),
  add column ops_marked_by uuid,
  add column ops_marked_at timestamptz;
comment on column app.session_attendance.ops_source is
  'Nguồn ô vận hành: GIAO_VIEN = chép từ cột giáo viên (đi theo khi giáo viên đổi); VAN_HANH = vận hành tự tích (không bị đè); null = ô trống.';
comment on column app.session_attendance.ops_marked_by is 'Người vận hành tự tích ô vận hành. Null khi ô trống hoặc do chép.';

-- Ô đã ghi trước migration này đều do vận hành tích (trước đây không có chép). Không biết người, giờ ghi nên để trống.
update app.session_attendance set ops_source = 'VAN_HANH' where ops_status_code is not null;

select set_config('hmt.migration', '', false);

-- app.set_attendance_ops: vận hành ghi phía của mình khi buổi Đã chốt (quyền ATTENDANCE · Sửa).
-- Vào: p_entries [{student_id, status_code?, contact_reason_code?, note?}]; khoá vắng thì giữ giá trị đang có, khoá có giá trị trống thì xoá.
-- Trạng thái khác giá trị đang có = vận hành tự tích (nguồn VAN_HANH); gửi lại đúng giá trị đang có thì giữ nguyên nguồn.
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
  return v_n;
end;
$$;

-- Ghi một dòng phía vận hành (nội bộ, chỉ app.set_attendance_ops gọi sau khi đã kiểm quyền và khoá dòng).
create or replace function app.write_attendance_ops(p_row app.session_attendance, p_entry jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := case when p_entry ? 'status_code' then nullif(p_entry ->> 'status_code', '') else p_row.ops_status_code end;
  v_reason text := case when p_entry ? 'contact_reason_code' then nullif(p_entry ->> 'contact_reason_code', '') else p_row.contact_reason_code end;
  v_note text := case when p_entry ? 'note' then nullif(btrim(coalesce(p_entry ->> 'note', '')), '') else p_row.ops_note end;
  v_changed boolean := v_status is distinct from p_row.ops_status_code;
begin
  if v_changed and v_status is not null then
    perform app.assert_catalog_code_active('ATTENDANCE_STATUS', v_status);
  end if;
  if v_reason is not null then
    if v_reason is distinct from p_row.contact_reason_code then
      perform app.assert_catalog_code_active('ATTENDANCE_CONTACT_REASON', v_reason);
    end if;
    if v_reason = 'KHAC' and v_note is null then
      perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do liên hệ "Khác" cần ghi chú.');
    end if;
  end if;
  update app.session_attendance set
    ops_status_code = v_status, contact_reason_code = v_reason, ops_note = v_note,
    ops_source = case when not v_changed then ops_source when v_status is null then null else 'VAN_HANH' end,
    ops_marked_by = case when not v_changed then ops_marked_by when v_status is null then null else auth.uid() end,
    ops_marked_at = case when not v_changed then ops_marked_at when v_status is null then null else now() end
   where id = p_row.id;
end;
$$;
revoke execute on function app.write_attendance_ops(app.session_attendance, jsonb) from public, anon, authenticated;

-- Lấy từ 20261123000624_a2312_done_ngay_khi_hoan_tat.sql; chỉ đổi phần cột điểm danh (DD1).
create or replace function app.set_attendance_teacher(p_session_id uuid, p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_status text;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa điểm danh. Nhờ quản lý cơ sở sửa kèm lý do.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa điểm danh được.');
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) loop
    v_status := nullif(e ->> 'status_code', '');
    if v_status is not null then
      perform app.assert_catalog_code_active('ATTENDANCE_STATUS', v_status);
    end if;
    update app.session_attendance set teacher_status_code = v_status,
           teacher_marked_by = case when v_status is null then null else auth.uid() end,
           teacher_marked_at = case when v_status is null then null else now() end,
           -- DD-04, C1: ô vận hành trống hoặc còn là ô do chép thì đi theo ô giáo viên; vận hành đã tự tích thì không đè.
           ops_status_code = case when ops_status_code is null or ops_source = 'GIAO_VIEN' then v_status else ops_status_code end,
           ops_source = case when ops_status_code is null or ops_source = 'GIAO_VIEN'
                             then case when v_status is null then null else 'GIAO_VIEN' end else ops_source end
     where session_id = p_session_id and student_id = (e ->> 'student_id')::uuid and is_active;
    if not found then
      perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Có em không nằm trong danh sách buổi này.');
    end if;
    v_n := v_n + 1;
  end loop;
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_n;
end;
$$;

-- Lấy từ 20261118000415_tt_b_tu_sinh_phieu_tai_tuc.sql; chỉ đổi phần cột điểm danh (DD1).
create or replace function app.upsale_candidates()
returns table (student_id uuid, class_id uuid, branch_id uuid, parent_id uuid, hours_left numeric, expected_end_date date, risk_flag boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with grp as (
    select e.student_id, ec.class_id, min(e.branch_id::text)::uuid as branch_id, min(e.parent_id::text)::uuid as parent_id,
           sum(coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) as hours_left
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
     where e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
     group by e.student_id, ec.class_id
  ), calc as (
    select g.*,
           coalesce((select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) -- allow-number: 3600 giây một giờ
                       from app.class_slot s where s.class_id = g.class_id and s.is_active), 0) as weekly_hours
      from grp g
  )
  select c.student_id, c.class_id, c.branch_id, c.parent_id, c.hours_left,
         case when c.hours_left > 0 and c.weekly_hours > 0
              then ((now() at time zone 'Asia/Ho_Chi_Minh')::date + ceil(c.hours_left / c.weekly_hours * 7)::integer) end, -- allow-number: 7 ngày một tuần
         (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
           where sa.student_id = c.student_id and s.class_id = c.class_id and sa.is_active
             and sa.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
             and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - app.get_setting_int('absence_risk_window_days', c.branch_id)::integer)
           >= app.get_setting_int('absence_risk_sessions', c.branch_id)
    from calc c;
$$;

-- Lấy từ 20261123000623_tt02_da_mua_gan_nhat.sql; chỉ đổi phần cột điểm danh (DD1).
create or replace function app.get_upsale_ticket(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_open boolean;
  v_window integer;
begin
  select * into t from app.upsale_ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', t.branch_id);
  v_open := t.stage_code not in ('L5', 'L8');
  v_window := app.get_setting_int('absence_risk_window_days', t.branch_id)::integer;
  return jsonb_build_object(
    'ticket', app.upsale_ticket_row(t) || jsonb_build_object(
      'lost_reason_code', t.lost_reason_code, 'lost_note', t.lost_note, 'next_goal', t.next_goal, 'next_roadmap', t.next_roadmap,
      'closed_at', t.closed_at, 'created_by_name', app.staff_display_name(t.created_by)),
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', null, 'zalo', null)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name) from app.student s where s.id = t.student_id),
    'class', jsonb_build_object('id', t.class_id, 'code', (select code from app.class where id = t.class_id),
      'teacher_name', (select u.display_name from app.class_slot cs join app.user_account u on u.id = cs.teacher_id
                        where cs.class_id = t.class_id and cs.is_active order by cs.weekday, cs.start_time limit 1)),
    'enrollments', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code,
                       'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) order by e.code)
                  from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                 where e.student_id = t.student_id), '[]'::jsonb),
    'hours', jsonb_build_object(
      'bought', (select coalesce(sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                  join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                  where e.student_id = t.student_id and h.entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')),
      'used', (select coalesce(-sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                where e.student_id = t.student_id and h.entry_type = 'TRU_BUOI'),
      'absences_window', (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
                           where sa.student_id = t.student_id and s.class_id = t.class_id and sa.is_active
                             and sa.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
                             and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - v_window),
      'window_days', v_window,
      -- TT-02: lần cấp giờ mua (CAP_MUA) mới nhất của em ở lớp này.
      'last_purchase', (select jsonb_build_object('hours', h.hours, 'at', h.created_at)
                          from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                          join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                         where e.student_id = t.student_id and h.entry_type = 'CAP_MUA'
                         order by h.created_at desc, h.seq desc limit 1)),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when t.stage_code in ('L1', 'L2', 'L3', 'L4', 'L6') and app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end], null)));
end;
$$;

-- BC-06 (DD-02): chuyên cần chỉ tính cột giáo viên.
create or replace view report.class_attendance with (security_invoker = true) as
select c.id as class_id, c.branch_id, c.code as class_code, c.max_students,
       (select count(*) from app.enrollment_class ec where ec.class_id = c.id and ec.end_date is null) as active_students,
       count(a.id) filter (where a.teacher_status_code is not null) as marked,
       count(a.id) filter (where a.teacher_status_code in ('CO_MAT', 'DI_MUON')) as present,
       count(a.id) filter (where a.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')) as absent
  from app.class c
  left join app.class_session s on s.class_id = c.id and s.status_code = 'DONE'
  left join app.session_attendance a on a.session_id = s.id and a.is_active and not a.is_trial
 group by c.id, c.branch_id, c.code, c.max_students;
