-- C-27-12, C-27-12b (Chat cấp 708, 28/11/2026; rủi ro CAO theo C-27-15): số liệu trên phiếu tái tục.
-- (1) Giờ còn, Ngày hết giờ dự kiến, nhãn Campaign của danh sách, Kanban, bản ghi tính LÚC ĐỌC (R-GD-13), không dựa hai cột chỉ được đợt quét đêm ghi cho phiếu L1–L4.
--     Lọc và sắp xếp ở danh sách vẫn theo hai cột đã ghi (không tính cho hàng chục nghìn phiếu mỗi lần mở).
-- (2) «Đã mua gần nhất»: gộp theo ghi danh, chỉ lấy tổng dương (dòng âm do đảo khoản R-TIEN-26 không phải một lần mua).
-- (3) Bản ghi thêm: giờ tặng, buổi còn, lịch học, buổi tới, gói và đơn giá lần mua trước, lần liên hệ gần nhất, lịch hẹn đang chờ. Chỉ đọc.
select set_config('hmt.migration', 'on', false);

-- app.upsale_ticket_live(phiếu): giờ còn và ngày hết giờ dự kiến tính từ sổ giờ lúc đọc. Ai gọi: các hàm đọc phiếu; tự kiểm quyền Phiếu tái tục · Xem
-- (cùng điều kiện với RLS của phiếu). Giờ còn = tổng sổ giờ của ghi danh còn hiệu lực (Đã xếp lớp, Đang học) của em ở lớp, kể cả giờ tặng, không tính bảo
-- lưu hay đã dừng (R-GD-13); không có ghi danh nào thì null. Ngày hết giờ: cùng cách app.upsale_candidates (giờ mỗi tuần theo khung giờ của lớp).
-- security definer: người xem phiếu không nhất thiết có quyền đọc sổ giờ.
create function app.upsale_ticket_live(p_ticket_id uuid, out hours_left numeric, out expected_end_date date)
language sql
stable
security definer
set search_path = ''
as $$
  with t as (
    select u.student_id, u.class_id from app.upsale_ticket u
     where u.id = p_ticket_id
       and ((select app.permission_scope('UPSALE', 'XEM')) = 'TOAN_HE_THONG'
            or ((select app.permission_scope('UPSALE', 'XEM')) is not null and u.branch_id = (select app.current_branch_id())))
  ), h as (
    select sum(coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)) as left_hours
      from t
      join app.enrollment e on e.student_id = t.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
  ), w as (
    select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) as weekly -- allow-number: 3600 giây một giờ
      from t join app.class_slot s on s.class_id = t.class_id and s.is_active
  )
  select h.left_hours,
         case when h.left_hours > 0 and w.weekly > 0
              then (now() at time zone 'Asia/Ho_Chi_Minh')::date + ceil(h.left_hours / w.weekly * 7)::integer end -- allow-number: 7 ngày một tuần
    from h, w;
$$;
revoke execute on function app.upsale_ticket_live(uuid) from public, anon;
grant execute on function app.upsale_ticket_live(uuid) to authenticated;

-- Một dòng phiếu cho danh sách và thẻ Kanban: bản 414, chỉ đổi ba ô giờ còn, ngày hết giờ, campaign sang số tính lúc đọc.
create or replace function app.upsale_ticket_row(t app.upsale_ticket)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'code', t.code, 'branch_code', b.code,
    'student_id', t.student_id, 'student_name', s.full_name,
    'class_id', t.class_id, 'class_code', c.code,
    'enrollment_count', (select count(*)::int from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id
                          where e.student_id = t.student_id and ec.class_id = t.class_id and ec.end_date is null),
    'hours_left', v.hours_left, 'expected_end_date', v.expected_end_date,
    'campaign_label', case when v.expected_end_date is null then null else 'Tái tục ' || to_char(v.expected_end_date, 'MM/YYYY') end,
    'stage_code', t.stage_code, 'substage_code', t.substage_code,
    'owner_id', t.owner_id, 'owner_name', app.staff_display_name(t.owner_id),
    'risk_flag', t.risk_flag, 'origin_code', t.origin_code, 'created_at', t.created_at)
  from app.branch b, app.student s, app.class c, app.upsale_ticket_live(t.id) v
 where b.id = t.branch_id and s.id = t.student_id and c.id = t.class_id;
$$;

-- app.upsale_last_purchase(phiếu): lần mua gần nhất của em ở lớp. Mỗi ghi danh (một dòng đơn, R-GD-01) là một lần mua: cộng mọi dòng CAP_MUA kể cả dòng âm
-- do đảo khoản, chỉ lấy ghi danh còn tổng dương. Đơn giá và học phí chỉ trả khi người gọi có Đơn hàng · Xem. Nội bộ: gọi từ app.get_upsale_ticket.
create function app.upsale_last_purchase(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with p as (
    select e.id, e.order_line_id, sum(h.hours) as hours,
           max(h.created_at) filter (where h.hours > 0) as at, max(h.seq) as seq
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
      join app.hour_ledger h on h.enrollment_id = e.id and h.entry_type = 'CAP_MUA'
     where e.student_id = t.student_id
     group by e.id, e.order_line_id
    having sum(h.hours) > 0
     order by max(h.created_at) filter (where h.hours > 0) desc, max(h.seq) desc
     limit 1
  )
  select jsonb_build_object('hours', p.hours, 'at', p.at, 'package_name', l.package_name, 'unit_code', l.unit_code,
           'unit_price', case when m.ok then l.unit_price end, 'amount', case when m.ok then l.line_total end)
    from p
    left join app.sales_order_line l on l.id = p.order_line_id
   cross join (select app.can_see_branch('SALES_ORDER', 'XEM', t.branch_id) as ok) m;
$$;
revoke execute on function app.upsale_last_purchase(app.upsale_ticket) from public, anon, authenticated;

-- app.upsale_hours_info(phiếu): khối «Giờ học» của bản ghi. Giờ đã mua (gồm giờ tặng, đầu kỳ), giờ tặng, đã học, vắng trong cửa sổ, buổi còn, lần mua gần nhất.
-- Buổi còn = số buổi trọn mà giờ còn đủ học, theo độ dài buổi trung bình của khung giờ lớp; lớp chưa có khung giờ thì null. Nội bộ.
create function app.upsale_hours_info(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with led as (
    select h.entry_type, h.hours
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
      join app.hour_ledger h on h.enrollment_id = e.id
     where e.student_id = t.student_id
  ), w as (
    select app.get_setting_int('absence_risk_window_days', t.branch_id)::integer as days,
           (select avg(extract(epoch from (s.end_time - s.start_time)) / 3600.0) -- allow-number: 3600 giây một giờ
              from app.class_slot s where s.class_id = t.class_id and s.is_active) as session_hours,
           (select v.hours_left from app.upsale_ticket_live(t.id) v) as left_hours
  )
  select jsonb_build_object(
    'bought', (select coalesce(sum(hours), 0) from led where entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')),
    'gifted', (select coalesce(sum(hours), 0) from led where entry_type = 'CAP_TANG'),
    'used', (select coalesce(-sum(hours), 0) from led where entry_type = 'TRU_BUOI'),
    'absences_window', (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
                         where sa.student_id = t.student_id and s.class_id = t.class_id and sa.is_active
                           and sa.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
                           and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - w.days),
    'window_days', w.days,
    'sessions_left', case when w.left_hours is null or w.session_hours is null then null
                          else greatest(floor(w.left_hours / w.session_hours), 0)::integer end,
    'last_purchase', app.upsale_last_purchase(t))
  from w;
$$;
revoke execute on function app.upsale_hours_info(app.upsale_ticket) from public, anon, authenticated;

-- app.upsale_contact_info(phiếu): lần liên hệ gần nhất (ghi chú có kênh, kết quả; R-CRM-30) trên hồ sơ phụ huynh hoặc học sinh của phiếu, và lịch hẹn đang
-- chờ sớm nhất của hai hồ sơ đó (R-CRM-42). Mỗi nguồn chỉ đọc khi người gọi xem được (ghi chú theo can_see_note_target, lịch hẹn theo Lịch hẹn · Xem);
-- không kèm nội dung ghi chú. Nội bộ.
create function app.upsale_contact_info(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with see as (
    select app.can_see_note_target('PARENT', t.parent_id) as parent_ok, app.can_see_note_target('STUDENT', t.student_id) as student_ok,
           app.can_see_branch('APPOINTMENT', 'XEM', t.branch_id) as appt_ok
  )
  select jsonb_build_object(
    'last', (select jsonb_build_object('at', n.created_at, 'channel_code', n.contact_channel_code,
                      'result_code', n.contact_result_code, 'by_name', app.staff_display_name(n.created_by))
               from app.note n
              where n.contact_channel_code is not null and not n.is_cancelled
                and ((see.parent_ok and n.entity_type = 'PARENT' and n.entity_id = t.parent_id)
                     or (see.student_ok and n.entity_type = 'STUDENT' and n.entity_id = t.student_id))
              order by n.created_at desc, n.id limit 1),
    'next_appointment_at', (select min(a.scheduled_at) from app.appointment a
                             where see.appt_ok and a.status = 'CHUA_LAM' and (a.parent_id = t.parent_id or a.student_id = t.student_id)))
  from see;
$$;
revoke execute on function app.upsale_contact_info(app.upsale_ticket) from public, anon, authenticated;

-- app.upsale_class_info(phiếu): lớp của phiếu, giáo viên, khung giờ trong tuần và buổi sắp tới gần nhất (chưa huỷ, chưa Done). Nội bộ.
create function app.upsale_class_info(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', t.class_id, 'code', (select code from app.class where id = t.class_id),
    'teacher_name', (select u.display_name from app.class_slot cs join app.user_account u on u.id = cs.teacher_id
                      where cs.class_id = t.class_id and cs.is_active order by cs.weekday, cs.start_time limit 1),
    'slots', coalesce((select jsonb_agg(jsonb_build_object('weekday', cs.weekday, 'start_time', cs.start_time, 'end_time', cs.end_time)
                                        order by cs.weekday, cs.start_time)
                         from app.class_slot cs where cs.class_id = t.class_id and cs.is_active), '[]'::jsonb),
    'next_session', (select jsonb_build_object('date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time)
                       from app.class_session s
                      where s.class_id = t.class_id and s.status_code in ('NHAP', 'DA_CHOT')
                        and (s.session_date + s.start_time) > (now() at time zone 'Asia/Ho_Chi_Minh')
                      order by s.session_date, s.start_time limit 1));
$$;
revoke execute on function app.upsale_class_info(app.upsale_ticket) from public, anon, authenticated;

-- app.get_upsale_ticket(phiếu): một lần gọi cho cả màn phiếu (TT-02). Ai gọi: Phiếu tái tục · Xem ở cơ sở của phiếu. Bản 707, các khối giờ, lớp, liên hệ
-- tách ra hàm con; việc làm được (actions) giữ nguyên luật R-GD-13.
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
begin
  select * into t from app.upsale_ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', t.branch_id);
  v_open := t.stage_code not in ('L5', 'L8');
  return jsonb_build_object(
    'ticket', app.upsale_ticket_row(t) || jsonb_build_object(
      'lost_reason_code', t.lost_reason_code, 'lost_note', t.lost_note, 'next_goal', t.next_goal, 'next_roadmap', t.next_roadmap,
      'closed_at', t.closed_at, 'created_by_name', app.staff_display_name(t.created_by),
      'branch_id', t.branch_id), -- cho form báo giá từ phiếu: hạn hiệu lực theo cơ sở của phiếu
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', null, 'zalo', null)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name, 'birth_year', s.birth_year)
                  from app.student s where s.id = t.student_id),
    'class', app.upsale_class_info(t),
    'enrollments', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code,
                       'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) order by e.code)
                  from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                 where e.student_id = t.student_id), '[]'::jsonb),
    'hours', app.upsale_hours_info(t),
    'contact', app.upsale_contact_info(t),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end,
      -- Luật R-GD-13 (27/11): tạo báo giá, tạo đơn ở mọi giai đoạn, theo quyền.
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('QUOTATION', 'TAO', t.branch_id) then 'tao_bao_gia' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('SALES_ORDER', 'TAO', t.branch_id) then 'tao_don' end], null)));
end;
$$;
