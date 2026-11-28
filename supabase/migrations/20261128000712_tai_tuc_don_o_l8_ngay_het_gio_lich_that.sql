-- C-27-18 (anh Trường chốt 28/11/2026 08:53; rủi ro CAO: tiền, dữ liệu). Số migration chờ Chat cấp.
-- (1) Luật R-GD-13, R-TIEN-02: tạo đơn từ phiếu tái tục (đơn thẳng và đơn từ báo giá của phiếu) CHỈ khi phiếu ở L8, không giới hạn số đơn. Tạo báo giá giữ ở mọi giai đoạn.
-- (2) Ngày dự kiến hết giờ theo LỊCH BUỔI THẬT của lớp (buổi từ hôm nay chưa Done, chưa huỷ, loại buổi trừ giờ), không còn ước theo giờ mỗi tuần của khung giờ.
--     Chưa có lớp thì để trống. Lịch đã sinh không đủ học hết số giờ còn thì cũng để trống (không đoán).
--     Dùng cho phiếu tái tục, đợt quét sinh phiếu, trang Ghi danh, tab Tái tục ở hồ sơ.
select set_config('hmt.migration', 'on', false);

-- app.class_schedule(các lớp): các buổi sắp tới sẽ trừ giờ của từng lớp, kèm số giờ cộng dồn. Một nguồn duy nhất cho ngày dự kiến hết giờ. Nội bộ.
create function app.class_schedule(p_class_ids uuid[])
returns table (class_id uuid, session_date date, hours_through numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select s.class_id, s.session_date,
         sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0) -- allow-number: 3600 giây một giờ
           over (partition by s.class_id order by s.session_date, s.start_time, s.id)
    from app.class_session s
   where s.class_id = any (p_class_ids) and s.status_code in ('NHAP', 'DA_CHOT')
     and s.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
     and app.session_type_deducts_hours(s.type_code);
$$;
revoke execute on function app.class_schedule(uuid[]) from public, anon, authenticated;

-- app.enrollment_expected_end(ghi danh): ngày buổi mà ghi danh này học hết giờ. Chỉ ghi danh Đã xếp lớp, Đang học còn giờ và đang ở lớp; chờ xếp lớp thì null.
-- Trừ giờ lần lượt theo ghi danh vào lớp sớm trước (R-GIO-04): cộng giờ còn của các ghi danh cùng em, cùng lớp đứng trước. Ghi danh học nhiều lớp thì
-- gộp lịch của các lớp đó. Nội bộ: hàm đọc gọi nó đã kiểm quyền.
create function app.enrollment_expected_end(p_enrollment_id uuid)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select e.id, e.student_id, e.created_at from app.enrollment e where e.id = p_enrollment_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
  ), cls as (
    select ec.class_id, ec.start_date from app.enrollment_class ec join me on me.id = ec.enrollment_id where ec.end_date is null
  ), mates as (
    select distinct e.id, e.created_at, ec.start_date
      from me
      join app.enrollment e on e.student_id = me.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null and ec.class_id in (select class_id from cls)
  ), bal as (
    select m.id, m.start_date, m.created_at,
           greatest(coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = m.id), 0), 0) as hours
      from (select id, min(start_date) as start_date, min(created_at) as created_at from mates group by id) m
  ), run as (
    select id, hours, sum(hours) over (order by start_date, created_at, id) as through from bal
  ), plan as (
    select session_date, sum(per_row) over (order by session_date, hours_through, class_id) as total
      from (select s.class_id, s.session_date, s.hours_through,
                   s.hours_through - coalesce(lag(s.hours_through) over (partition by s.class_id order by s.hours_through), 0) as per_row
              from app.class_schedule(array(select class_id from cls)) s) x
  )
  select min(p.session_date) from run r join plan p on p.total >= r.through
   where r.id = p_enrollment_id and r.hours > 0;
$$;
revoke execute on function app.enrollment_expected_end(uuid) from public, anon, authenticated;

-- Bản 710, đổi phần ngày dự kiến hết giờ sang lịch buổi thật.
create or replace function app.upsale_live(p_ticket_ids uuid[])
returns table (ticket_id uuid, hours_left numeric, expected_end_date date)
language plpgsql
stable
rows 20000 -- allow-number: ước lượng cho bộ lập kế hoạch (gọi cho cả danh sách), không phải số nghiệp vụ
security definer
set search_path = ''
-- Lập kế hoạch theo tham số thật: gọi cho một phiếu thì dùng chỉ mục, gọi cho cả danh sách thì quét một lượt.
set plan_cache_mode = force_custom_plan
as $$
#variable_conflict use_column
begin
  return query
  with t as (
    select u.id, u.student_id, u.class_id from app.upsale_ticket u
     where (p_ticket_ids is null or u.id = any (p_ticket_ids))
       and ((select app.permission_scope('UPSALE', 'XEM')) = 'TOAN_HE_THONG'
            or ((select app.permission_scope('UPSALE', 'XEM')) is not null and u.branch_id = (select app.current_branch_id())))
  ), h as (
    select t.id, sum(coalesce(l.hours, 0)) as left_hours
      from t
      join app.enrollment e on e.student_id = t.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
      left join lateral (select sum(x.hours) as hours from app.hour_ledger x where x.enrollment_id = e.id) l on true
     group by t.id
  ), plan as (
    select * from app.class_schedule(array(select distinct x.class_id from t x))
  ), done as (
    -- Buổi đầu tiên mà giờ cộng dồn của lịch đạt số giờ còn.
    select h.id, min(p.session_date) as end_date
      from h
      join t on t.id = h.id
      join plan p on p.class_id = t.class_id and p.hours_through >= h.left_hours
     where h.left_hours > 0
     group by h.id
  )
  select t.id, h.left_hours, done.end_date
    from t
    left join h on h.id = t.id
    left join done on done.id = t.id;
end;
$$;

-- Đợt quét sinh phiếu (bản 685): cùng cách tính ngày hết giờ.
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
  ), plan as (
    select * from app.class_schedule(array(select distinct g.class_id from grp g))
  ), calc as (
    select g.*, (select min(p.session_date) from plan p where p.class_id = g.class_id and p.hours_through >= g.hours_left) as end_date
      from grp g
  )
  select c.student_id, c.class_id, c.branch_id, c.parent_id, c.hours_left,
         case when c.hours_left > 0 then c.end_date end,
         (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
           where sa.student_id = c.student_id and s.class_id = c.class_id and sa.is_active
             and sa.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
             and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - app.get_setting_int('absence_risk_window_days', c.branch_id)::integer)
           >= app.get_setting_int('absence_risk_sessions', c.branch_id)
    from calc c;
$$;

-- Ghi danh trên phiếu (bản 710).
create or replace function app.upsale_enrollments(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code,
           'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0),
           'subject_code', coalesce(e.subject_code, c.subject_code), 'expected_end_date', app.enrollment_expected_end(e.id))
           order by e.code), '[]'::jsonb)
    from app.enrollment e
    join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
    join app.class c on c.id = ec.class_id
   where e.student_id = t.student_id;
$$;

-- Trang Ghi danh (bản 591): có ngày dự kiến hết giờ.
create or replace function app.enrollment_record(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  e app.enrollment;
begin
  select * into e from app.enrollment where id = p_id;
  if e.id is null or (v_scope = 'CO_SO' and e.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  return jsonb_build_object(
    'enrollment', (select jsonb_build_object(
        'id', e.id, 'code', e.code, 'legacy_ref', e.legacy_ref, 'status_code', e.status_code, 'status_name', sn.name,
        'student_id', st.id, 'student_code', st.code, 'student_name', st.full_name,
        'parent_id', pa.id, 'parent_code', pa.code, 'parent_name', pa.full_name,
        'package_code', pk.code, 'package_name', pk.name, 'delivery_mode_code', e.delivery_mode_code, 'delivery_mode_name', dm.name,
        'order_id', e.order_id, 'order_code', so.code, 'branch_code', br.code, 'branch_name', br.name,
        'enrolled_on', (e.created_at at time zone 'Asia/Ho_Chi_Minh')::date, 'start_date', e.start_date,
        'expected_end_date', app.enrollment_expected_end(e.id), 'package_deadline', null,
        -- GD-02 (canvas GD02_bao_luu, GD02_hoan_phi): ngày bảo lưu đang chạy và mã phiếu chi hoàn phí; chỉ đọc.
        'hold_start', (select h.start_date from app.enrollment_hold h where h.enrollment_id = e.id and h.status_code = 'DANG_BAO_LUU'
                        order by h.created_at desc limit 1),
        'hold_end', (select h.end_date from app.enrollment_hold h where h.enrollment_id = e.id and h.status_code = 'DANG_BAO_LUU'
                      order by h.created_at desc limit 1),
        'refund_voucher_code', (select pv.code from app.refund_request rr join app.payment_voucher pv on pv.refund_request_id = rr.id
                                 where rr.enrollment_id = e.id order by pv.created_at desc limit 1))
      from app.student st, app.parent pa, app.branch br
      left join app.sales_package pk on pk.id = e.package_id
      left join app.catalog_item dm on dm.catalog_code = 'STUDY_MODE' and dm.code = e.delivery_mode_code
      left join app.sales_order so on so.id = e.order_id
      left join app.catalog_item sn on sn.catalog_code = e.status_catalog and sn.code = e.status_code
      where st.id = e.student_id and pa.id = e.parent_id and br.id = e.branch_id),
    'hours', jsonb_build_object(
      'granted', (select coalesce(sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = e.id and l.entry_type in ('CAP_MUA', 'DAU_KY')),
      'gifted', (select coalesce(sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = e.id and l.entry_type = 'CAP_TANG'),
      'used', (select coalesce(-sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = e.id and l.entry_type = 'TRU_BUOI'),
      'remaining', app.enrollment_hours_balance(e.id),
      -- GD-02 (canvas GD02_hoc_truoc, R-GD-12): hạn mức âm của «cho học trước» = max_sessions_ahead buổi × giờ một buổi của lớp đang học; null khi ghi danh không học trước.
      'negative_limit_sessions', case when e.pay_later_enabled then app.get_setting_int('max_sessions_ahead', e.branch_id) end,
      'negative_limit_hours', case when e.pay_later_enabled then
         (select app.get_setting_int('max_sessions_ahead', e.branch_id)
                 * max(extract(epoch from (s.end_time - s.start_time)) / 3600.0) -- allow-number: 3600 giây một giờ
            from app.enrollment_class ec join app.class_slot s on s.class_id = ec.class_id and s.is_active
           where ec.enrollment_id = e.id and ec.end_date is null) end),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'class_id', ec.class_id, 'class_code', c.code, 'start_date', ec.start_date, 'end_date', ec.end_date, 'end_reason', ec.end_reason,
               'studied_hours', (select coalesce(-sum(l.hours), 0) from app.hour_ledger l join app.class_session s on s.id = l.session_id
                                  where l.enrollment_id = e.id and l.entry_type = 'TRU_BUOI' and s.class_id = ec.class_id))
             order by ec.start_date, ec.created_at)
        from app.enrollment_class ec join app.class c on c.id = ec.class_id where ec.enrollment_id = e.id), '[]'::jsonb),
    'tickets', 0);
end;
$$;

-- Tab Tái tục ở hồ sơ phụ huynh, học sinh (bản 696): giờ còn, ngày hết giờ tính lúc đọc.
create or replace function app.list_record_upsale(
  p_filters jsonb, p_sort text default 'open_first', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('UPSALE', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_parent uuid := (p_filters ->> 'parent_id')::uuid;
  v_student uuid := (p_filters ->> 'student_id')::uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu tái tục.');
  end if;
  with f as (
    select u.* from app.upsale_ticket u
     where (u.parent_id = v_parent or u.student_id = v_student)
       and (v_scope = 'TOAN_HE_THONG' or u.branch_id = v_my_branch)
  ), page as (
    select * from f order by (f.closed_at is not null), f.created_at desc, f.id limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'student_name', s.full_name,
             'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = c.subject_catalog and ci.code = c.subject_code),
             'class_code', c.code, 'hours_left', (select v.hours_left from app.upsale_ticket_live(p.id) v),
             'expected_end_date', (select v.expected_end_date from app.upsale_ticket_live(p.id) v),
             'stage_code', p.stage_code,
             'stage_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'UPSALE_STAGE' and ci.code = p.stage_code),
             'owner_name', app.staff_display_name(p.owner_id), 'risk', p.risk_flag,
             'absences', (select count(*) from app.session_attendance sa join app.class_session cs on cs.id = sa.session_id
                           where sa.student_id = p.student_id and cs.class_id = p.class_id and sa.is_active
                             and sa.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
                             and cs.session_date > v_today - app.get_setting_int('absence_risk_window_days', p.branch_id)::integer))
             order by (p.closed_at is not null), p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.student s on s.id = p.student_id
    join app.class c on c.id = p.class_id;
  return v_result;
end;
$$;

-- app.assert_upsale_stage_for_order(phiếu): chặn tạo đơn khi phiếu chưa ở L8 (R-GD-13, 28/11). Nội bộ.
create function app.assert_upsale_stage_for_order(p_stage text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_stage is distinct from 'L8' then
    perform app.raise_error('HMT_PHIEU_CHUA_O_L8', 'Phiếu tái tục cần ở L8 (đã thu tiền, hoàn thành tái tục) mới tạo được đơn hàng.');
  end if;
end;
$$;
revoke execute on function app.assert_upsale_stage_for_order(text) from public, anon, authenticated;

-- Bản ghi phiếu (bản 710): «Tạo đơn» chỉ ở L8.
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
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', p.email)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name, 'birth_year', s.birth_year)
                  from app.student s where s.id = t.student_id),
    'class', app.upsale_class_info(t),
    'enrollments', app.upsale_enrollments(t),
    'last_review', app.upsale_last_review(t),
    'hours', app.upsale_hours_info(t),
    'contact', app.upsale_contact_info(t),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end,
      -- Luật R-GD-13 (28/11): tạo báo giá ở mọi giai đoạn; tạo đơn chỉ ở L8 (thu tiền trước, chuyển L8 rồi mới tạo đơn).
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('QUOTATION', 'TAO', t.branch_id) then 'tao_bao_gia' end,
      case when t.stage_code = 'L8' and app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('SALES_ORDER', 'TAO', t.branch_id) then 'tao_don' end], null)));
end;
$$;

-- Đơn thẳng từ phiếu (bản 707).
create or replace function app.create_order_from_upsale_ticket(p_ticket_id uuid, p_lines jsonb, p_payment_term_id uuid default null, p_enrol_start_date date default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_start date;
  v_mode text;
  e jsonb;
  d jsonb;
  r jsonb;
  v_n integer := 0;
  v_kind text;
  v_class uuid;
  v_line_id uuid;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
  end if;
  select * into t from app.upsale_ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  -- Hai quyền, kiểm riêng từng bước (Chat 13:20).
  perform app.assert_can('SALES_ORDER', 'TAO', t.branch_id);
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  -- Luật R-GD-13 (28/11): chỉ khi phiếu ở L8; không giới hạn số đơn; giai đoạn chỉ đổi bằng tay.
  perform app.assert_upsale_stage_for_order(t.stage_code);
  select c.delivery_mode_code, c.start_date into v_mode, v_start from app.upsale_order_context(t, p_enrol_start_date) c;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, priced_on)
  values (v_code, t.branch_id, t.id, t.parent_id, v_on)
  returning id into v_id;
  -- Dòng đơn: học sinh, lớp lấy từ phiếu; giá tính như đơn thường (R-TIEN-13, 14).
  for e in select * from jsonb_array_elements(p_lines) loop
    v_n := v_n + 1;
    v_kind := coalesce(nullif(e ->> 'kind', ''), 'ENROL');
    v_class := case when v_kind = 'ENROL' then t.class_id end;
    r := app.price_line(v_n, v_kind, nullif(e ->> 'package_id', '')::uuid, coalesce(nullif(e ->> 'delivery_mode_code', ''), v_mode),
                        nullif(e ->> 'quantity', '')::numeric, e -> 'discounts', nullif(e ->> 'gift_policy_id', '')::uuid, t.branch_id, v_on);
    perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, t.branch_id);
    insert into app.sales_order_line (
      order_id, branch_id, line_no, line_kind, student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code, is_gift_line, list_unit_price)
    values (
      v_id, t.branch_id, v_n, v_kind, t.student_id,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, case when v_class is not null then v_start end, e ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.sales_order_line_discount (line_id, branch_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, t.branch_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
  end loop;
  -- Điều khoản thanh toán áp ngay trong cùng giao dịch (Đ260, R-CRM-19); sai thì cả giao dịch lùi.
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, 'Tạo từ phiếu tái tục ' || t.code);
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- Đơn từ báo giá (bản 707).
create or replace function app.create_order_from_quotation(p_quotation_id uuid, p_line_nos integer[] default null, p_payment_term_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_opp app.opportunity;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_n integer := 0;
  l app.quotation_line;
  v_new_line uuid;
  v_picked integer := 0;
  v_constraint text;
  t app.upsale_ticket;
  v_mode text;
  v_start date;
  v_class uuid;
begin
  select * into v_q from app.quotation where id = p_quotation_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  -- Báo giá của phiếu tái tục: cần thêm Phiếu tái tục · Sửa; không áp luật giai đoạn của cơ hội.
  if v_q.upsale_ticket_id is not null then
    t := app.assert_upsale_sales_access(v_q.upsale_ticket_id);
    -- Luật R-GD-13 (28/11): đơn từ báo giá của phiếu cũng chỉ khi phiếu ở L8.
    perform app.assert_upsale_stage_for_order(t.stage_code);
  end if;
  select * into v_opp from app.opportunity where id = v_q.opportunity_id;
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo đơn được.');
  end if;
  -- Luật R-TIEN-14: chỉ báo giá Đã gửi chuyển được đơn.
  if v_q.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_BAO_GIA_CHUA_GUI', 'Chỉ báo giá Đã gửi mới chuyển được thành đơn.');
  end if;
  -- Luật R-CRM-16: chưa ở L8 thì không tạo được đơn từ cơ hội.
  if t.id is null and v_opp.stage_code <> 'L8' then
    perform app.raise_error('HMT_CHUA_O_L8', 'Cơ hội cần ở L8 (phụ huynh đã thanh toán) mới tạo được đơn hàng.');
  end if;
  if p_line_nos is not null and exists (
       select from unnest(p_line_nos) n where not exists (select from app.quotation_line x where x.quotation_id = v_q.id and x.line_no = n)) then
    perform app.raise_error('HMT_DONG_KHONG_CO', 'Có dòng không thuộc báo giá này.');
  end if;
  select code into v_branch_code from app.branch where id = v_q.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  if t.id is not null then
    select c.start_date into v_start from app.upsale_order_context(t, null) c;
  end if;
  insert into app.sales_order (code, branch_id, opportunity_id, renewal_ticket_id, parent_id, quotation_id, priced_on)
  values (v_code, v_q.branch_id, v_q.opportunity_id, v_q.upsale_ticket_id, v_q.parent_id, v_q.id, v_q.priced_on)
  returning id into v_id;
  for l in select * from app.quotation_line x
            where x.quotation_id = v_q.id and (p_line_nos is null or x.line_no = any (p_line_nos)) order by x.line_no loop
    -- Luật R-TIEN-02: dòng đã nằm trong đơn đang sống thì chặn (lệnh chọn tay) hoặc bỏ qua (chọn mọi dòng).
    if exists (select from app.sales_order_line o where o.quotation_line_id = l.id and o.is_live) then
      if p_line_nos is not null then
        perform app.raise_error('HMT_DONG_DA_CO_DON', format('Dòng %s của báo giá đã nằm trong một đơn đang xử lý.', l.line_no));
      end if;
      continue;
    end if;
    v_n := v_n + 1;
    -- Đơn tái tục: dòng ghi danh vào đúng lớp của phiếu (R-GD-13).
    v_class := case when l.line_kind = 'ENROL' then t.class_id end;
    if v_class is not null then
      perform app.check_order_line_class(v_n, v_class, l.package_id, v_q.branch_id);
    end if;
    insert into app.sales_order_line (
      order_id, line_no, line_kind, quotation_line_id, prospect_student_id, student_id, package_id, package_code, package_name,
      package_type_code, delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent,
      gift_percent, discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date)
    values (
      v_id, v_n, l.line_kind, l.id, l.prospect_student_id, l.student_id, l.package_id, l.package_code, l.package_name,
      l.package_type_code, l.delivery_mode_code, l.unit_code, l.quantity, l.gifted_quantity, l.unit_price, l.gross_amount,
      l.discount_percent, l.gift_percent, l.discount_amount, l.line_total, l.over_cap, l.needs_acknowledgement, l.gift_policy_id,
      v_class, case when v_class is not null then v_start end)
    returning id into v_new_line;
    insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
    select v_new_line, d.policy_id, d.policy_code, d.policy_name, d.kind, d.applied_value, d.requires_approval
      from app.quotation_line_discount d where d.line_id = l.id;
    v_picked := v_picked + 1;
  end loop;
  if v_picked = 0 then
    perform app.raise_error('HMT_KHONG_CO_DONG_DE_CHUYEN', 'Không còn dòng nào của báo giá để chuyển thành đơn.');
  end if;
  -- Luật Đ260, R-CRM-19: điều khoản thanh toán áp ngay trong cùng giao dịch tạo đơn; điều khoản sai thì cả giao dịch lùi (không có đơn Nháp rác, mã không nhảy số).
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  -- Nhật ký (Q-145): dòng ưu đãi linh hoạt được nhập ở báo giá, kèm mã báo giá.
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, app.order_flexible_note(v_id, true));
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
exception
  when unique_violation then
    -- Chỉ lỗi trùng đúng chỉ mục "một dòng báo giá không nằm trong hai đơn sống" mới đổi thành lỗi có mã; lỗi trùng khác ném lại.
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'sales_order_line_quotation_live_uidx' then
      perform app.raise_error('HMT_DONG_DA_CO_DON', 'Có dòng của báo giá đã nằm trong một đơn đang xử lý.');
    end if;
    raise;
end;
$$;

select set_config('hmt.migration', '', false);
