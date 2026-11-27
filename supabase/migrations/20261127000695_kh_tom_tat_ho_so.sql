-- D-27-04 PR C (Chat duyệt 27/11/2026; migration 695; rủi ro VỪA, có tiền). Hồ sơ 360°: thẻ tóm tắt và cờ cảnh báo đầu hồ sơ phụ huynh, học sinh
-- (canvas a8d7: KH02_360, KH02_360_an_tien, KH05_360). Chỉ đọc. Tiền chỉ trả cho người xem được đơn hàng, phiếu thu (cùng luật migration 684).
select set_config('hmt.migration', 'on', false);

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('contact_stale_days', 'Số ngày chưa liên hệ thì cảnh báo', 'INT', 'ngày', 1, 365, '30', true, 'CSKH', 'R-CRM-43',
   'Hồ sơ phụ huynh, học sinh quá chừng này ngày chưa ghi nhận liên hệ thì hiện cờ «Lâu chưa liên hệ».'),
  ('absence_streak_sessions', 'Số buổi vắng liên tiếp thì cảnh báo', 'INT', 'buổi', 1, 20, '3', true, 'CSKH', null,
   'Học sinh vắng liên tiếp từ chừng này buổi gần nhất thì hồ sơ hiện cờ «Vắng liên tiếp».'),
  ('attendance_rate_window_days', 'Số ngày tính chuyên cần trên hồ sơ', 'INT', 'ngày', 1, 365, '30', true, 'CSKH', null,
   'Thẻ «Chuyên cần» và cờ «Thiếu nhận xét» trên hồ sơ xét các buổi trong chừng này ngày gần nhất.');

-- app.record_last_contact: lần liên hệ gần nhất trong các hồ sơ đưa vào (chỉ hồ sơ người gọi đọc được ghi chú). Hàm trong.
create or replace function app.record_last_contact(p_entity_type text, p_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('at', n.created_at,
           'channel', (select c.name from app.catalog_item c where c.catalog_code = n.contact_channel_catalog and c.code = n.contact_channel_code),
           'days', (now() at time zone 'Asia/Ho_Chi_Minh')::date - (n.created_at at time zone 'Asia/Ho_Chi_Minh')::date)
    from app.note n
   where n.entity_type = p_entity_type and n.entity_id = any (p_ids) and n.contact_channel_code is not null and not n.is_cancelled
     and app.can_see_note_target(n.entity_type, n.entity_id)
   order by n.created_at desc limit 1;
$$;

-- app.record_ticket_counts: số ticket mở và quá hạn xử lý của một phụ huynh hoặc học sinh, chỉ ticket người gọi xem được. Hàm trong.
create or replace function app.record_ticket_counts(p_parent_id uuid, p_student_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  -- Cùng điều kiện với chính sách ticket_read; ticket «mở» là chưa Đã xử lý, Đã đóng, Đã huỷ; quá hạn không tính lúc đang tạm dừng.
  select case when app.permission_scope('TICKET', 'XEM') is not null then
           jsonb_build_object('open', count(*),
                              'overdue', count(*) filter (where t.resolve_due_at < now() and t.paused_at is null)) end
    from app.ticket t
   where (t.parent_id = p_parent_id or t.student_id = p_student_id)
     and t.status_code not in ('DA_XU_LY', 'DA_DONG', 'DA_HUY')
     and (app.permission_scope('TICKET', 'XEM') = 'TOAN_HE_THONG'
          or (app.permission_scope('TICKET', 'XEM') = 'CO_SO' and t.branch_id = app.current_branch_id())
          or (app.permission_scope('TICKET', 'XEM') = 'DUOC_PHAN_CONG' and (t.created_by = auth.uid() or t.assignee_id = auth.uid())));
$$;

-- app.record_expiring: các (học sinh, lớp) đã hết hoặc sắp hết giờ. Dùng đúng định nghĩa R-GD-07 (app.expiring_enrollment_rows). Hàm trong.
create or replace function app.record_expiring(p_student_ids uuid[])
returns table (student_id uuid, class_id uuid, hours_left numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select x.student_id, x.class_id, x.hours_left
    from (select distinct ec.class_id from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
           where e.student_id = any (p_student_ids)) k
    cross join lateral app.expiring_enrollment_rows(k.class_id, 'TOAN_HE_THONG') x
   where x.student_id = any (p_student_ids) and x.status_code in ('HET_GIO', 'SAP_HET_GIO');
$$;

-- app.record_upsale: phiếu tái tục đang mở của các em (nút «Báo giá tái tục»), chỉ phiếu người gọi xem được (cùng chính sách upsale_ticket_read). Hàm trong.
create or replace function app.record_upsale(p_student_ids uuid[])
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id from app.upsale_ticket u
   where u.student_id = any (p_student_ids) and u.closed_at is null
     and (app.permission_scope('UPSALE', 'XEM') = 'TOAN_HE_THONG'
          or (app.permission_scope('UPSALE', 'XEM') is not null and u.branch_id = app.current_branch_id()))
   order by u.created_at desc limit 1;
$$;

-- app.record_missing_review: số buổi gần đây em có mặt mà buổi bị Done khi còn thiếu nhận xét (cờ R-GIO-12). Hàm trong.
create or replace function app.record_missing_review(p_student_ids uuid[], p_branch_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(distinct s.id)::integer
    from app.session_attendance sa join app.class_session s on s.id = sa.session_id
   where sa.student_id = any (p_student_ids) and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
     and s.status_code = 'DONE' and s.done_missing_review
     and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - app.get_setting_int('attendance_rate_window_days', p_branch_id)::integer;
$$;

-- app.parent_money_summary: Tổng đã đóng, Còn nợ (kèm số ngày quá hạn), Số dư của phụ huynh. Hàm trong.
-- Quyền từng ô như migration 684: không xem được thì ô trả null.
-- Số dư và nợ đầu kỳ chỉ cộng dòng sổ số dư ở cơ sở người xem được (lọc từng dòng theo cơ sở của dòng).
-- Số ngày quá hạn (dựng cờ) chỉ tính từ đơn người xem được: không lộ nợ ngoài quyền.
create or replace function app.parent_money_summary(p_parent app.parent)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with ord as (
    select o.id, o.total_amount, app.order_paid_amount(o.id) as paid,
           app.can_see_branch_wide('SALES_ORDER', 'XEM', o.branch_id) as seen
      from app.sales_order o where o.parent_id = p_parent.id and o.status_code = 'DA_DUYET'
  ), inst as (
    -- Cùng cách chia tiền đã vào theo thứ tự đợt như list_receivables.
    select i.due_date, i.amount,
           o.paid - coalesce(sum(i.amount) over (partition by i.order_id order by i.seq rows between unbounded preceding and 1 preceding), 0) as paid_left
      from ord o join app.sales_order_installment i on i.order_id = o.id
     where o.seen
  )
  select jsonb_build_object(
    'paid_total', case when app.can_see_branch_wide('RECEIPT', 'XEM', p_parent.branch_id) then
        coalesce((select sum(m.amount) from app.money_in m where m.parent_id = p_parent.id and app.can_see_branch_wide('RECEIPT', 'XEM', m.branch_id)), 0)
        + coalesce((select sum(b.amount) from app.customer_balance_entry b where b.parent_id = p_parent.id and b.entry_type in ('THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY')
                   and app.can_see_branch_wide('RECEIPT', 'XEM', b.branch_id)), 0) end,
    'debt', case when app.can_see_branch_wide('SALES_ORDER', 'XEM', p_parent.branch_id) then
        coalesce((select sum(greatest(o.total_amount - o.paid, 0)) from ord o where o.seen), 0)
        + greatest(-coalesce((select sum(b.amount) from app.customer_balance_entry b
                               where b.parent_id = p_parent.id and b.entry_type in ('DAU_KY_CONG_NO', 'THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY')
                                 and app.can_see_branch_wide('SALES_ORDER', 'XEM', b.branch_id)), 0), 0) end,
    'balance', case when app.can_see_branch_wide('RECEIPT', 'XEM', p_parent.branch_id) then
        coalesce((select sum(b.amount) from app.customer_balance_entry b
                   where b.parent_id = p_parent.id and app.can_see_branch_wide('RECEIPT', 'XEM', b.branch_id)), 0) end,
    'overdue_days', (select (now() at time zone 'Asia/Ho_Chi_Minh')::date - min(i.due_date) from inst i
                      where i.due_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date and i.amount > greatest(i.paid_left, 0)));
$$;

-- app.get_parent_summary: thẻ tóm tắt và dữ liệu cờ đầu hồ sơ phụ huynh. Ai gọi: người xem được phụ huynh (R-CRM-26). Chỉ đọc.
create or replace function app.get_parent_summary(p_parent_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p app.parent;
  v_kids uuid[];
  v_contact jsonb;
begin
  if coalesce(app.permission_scope('PARENT', 'XEM'), '') not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  select * into p from app.parent where id = p_parent_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  v_kids := array(select s.id from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG');
  -- Lần liên hệ cuối tính cả liên hệ ghi trên hồ sơ các con.
  select x into v_contact
    from (values (app.record_last_contact('PARENT', array[p.id])), (app.record_last_contact('STUDENT', v_kids))) as t (x)
   where x is not null order by (x ->> 'at')::timestamptz desc limit 1;
  return jsonb_build_object(
    'branch_id', p.branch_id,
    'upsale_id', app.record_upsale(v_kids),
    'children_total', cardinality(v_kids),
    'studying_names', coalesce((select jsonb_agg(s.full_name order by s.full_name) from app.student s
                                 where s.id = any (v_kids) and exists (select from app.enrollment e
                                       where e.student_id = s.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC'))), '[]'::jsonb),
    'money', app.parent_money_summary(p),
    'tickets', app.record_ticket_counts(p.id, null),
    'last_contact', v_contact,
    'expiring_names', coalesce((select jsonb_agg(distinct s.full_name) from app.record_expiring(v_kids) x join app.student s on s.id = x.student_id), '[]'::jsonb),
    'missing_review', app.record_missing_review(v_kids, p.branch_id),
    'days_since_created', (now() at time zone 'Asia/Ho_Chi_Minh')::date - (p.created_at at time zone 'Asia/Ho_Chi_Minh')::date,
    'contact_visible', app.can_see_note_target('PARENT', p.id),
    'stale_days', app.get_setting_int('contact_stale_days', p.branch_id));
end;
$$;

-- app.student_attendance_summary: chuyên cần trong cửa sổ ngày và số buổi vắng liên tiếp gần nhất. Hàm trong.
create or replace function app.student_attendance_summary(p_student_id uuid, p_branch_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with a as (
    select sa.teacher_status_code in ('CO_MAT', 'DI_MUON') as present, s.session_date,
           row_number() over (order by s.session_date desc, s.start_time desc) as rn
      from app.session_attendance sa join app.class_session s on s.id = sa.session_id
     where sa.student_id = p_student_id and sa.is_active and sa.teacher_status_code is not null
  ), w as (
    select * from a where session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - app.get_setting_int('attendance_rate_window_days', p_branch_id)::integer
  )
  select jsonb_build_object(
    'rate', (select round(100.0 * count(*) filter (where present) / nullif(count(*), 0))::integer from w), -- allow-number: phần trăm
    'window_days', app.get_setting_int('attendance_rate_window_days', p_branch_id),
    'absent_streak', coalesce((select min(rn) - 1 from a where present), (select count(*) from a))::integer);
$$;

-- app.get_student_summary: thẻ tóm tắt và dữ liệu cờ đầu hồ sơ học sinh. Ai gọi: người xem được học sinh (cùng phạm vi get_student_record). Chỉ đọc.
-- Người chỉ có phạm vi «được phân công» (giáo viên) không nhận phần chăm sóc (liên hệ, CSKH, ticket), R-GV-13.
create or replace function app.get_student_summary(p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT', 'XEM');
  s app.student;
  v_class app.class;
  v_care boolean;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select * into s from app.student where id = p_student_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy học sinh.');
  end if;
  if v_scope is null
     or (v_scope = 'DUOC_PHAN_CONG' and not app.student_assigned_to_me(s.id))
     or (v_scope not in ('TOAN_HE_THONG', 'DUOC_PHAN_CONG') and s.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh này.');
  end if;
  v_care := v_scope <> 'DUOC_PHAN_CONG';
  -- Lớp đang học: lớp của ghi danh còn hiệu lực, vào gần nhất.
  select c.* into v_class
    from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null join app.class c on c.id = ec.class_id
   where e.student_id = s.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
   order by ec.start_date desc, c.code limit 1;
  return jsonb_build_object(
    'branch_id', s.branch_id,
    'upsale_id', app.record_upsale(array[s.id]),
    'class', case when v_class.id is not null then jsonb_build_object('id', v_class.id, 'code', v_class.code,
               'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = v_class.subject_catalog and ci.code = v_class.subject_code)) end,
    'next_session', (select jsonb_build_object('session_date', cs.session_date, 'start_time', cs.start_time, 'branch_code', b.code)
                       from app.class_session cs join app.class c on c.id = cs.class_id join app.branch b on b.id = c.branch_id
                      where cs.class_id = v_class.id and cs.session_date >= v_today and cs.status_code = 'NHAP'
                      order by cs.session_date, cs.start_time limit 1),
    'hours_left', (select sum(app.enrollment_hours_balance(e.id)) from app.enrollment e
                    where e.student_id = s.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')),
    'expiring', exists (select from app.record_expiring(array[s.id])),
    'attendance', app.student_attendance_summary(s.id, s.branch_id),
    'last_score', (select jsonb_build_object('score', es.total_score, 'max_score', se.max_score, 'session_date', cs.session_date)
                     from app.exam_score es join app.session_attendance sa on sa.id = es.attendance_id
                     join app.class_session cs on cs.id = es.session_id left join app.session_exam se on se.session_id = es.session_id
                    where sa.student_id = s.id and es.graded order by cs.session_date desc, cs.start_time desc limit 1),
    'care_staff', case when v_care and v_class.cskh_id is not null then
        jsonb_build_object('name', app.staff_display_name(v_class.cskh_id), 'branch_code', (select b.code from app.branch b where b.id = v_class.branch_id)) end,
    'tickets', case when v_care then app.record_ticket_counts(null, s.id) end,
    'last_contact', app.record_last_contact('STUDENT', array[s.id]),
    'missing_review', app.record_missing_review(array[s.id], s.branch_id),
    'days_since_created', v_today - (s.created_at at time zone 'Asia/Ho_Chi_Minh')::date,
    'contact_visible', v_care and app.can_see_note_target('STUDENT', s.id),
    'stale_days', app.get_setting_int('contact_stale_days', s.branch_id),
    'absence_limit', app.get_setting_int('absence_streak_sessions', s.branch_id));
end;
$$;

revoke execute on function app.record_last_contact(text, uuid[]), app.record_ticket_counts(uuid, uuid), app.record_expiring(uuid[]),
  app.record_upsale(uuid[]),
  app.record_missing_review(uuid[], uuid), app.parent_money_summary(app.parent), app.student_attendance_summary(uuid, uuid),
  app.get_parent_summary(uuid), app.get_student_summary(uuid) from public, anon, authenticated;
grant execute on function app.get_parent_summary(uuid), app.get_student_summary(uuid) to authenticated;

select set_config('hmt.migration', '', false);
