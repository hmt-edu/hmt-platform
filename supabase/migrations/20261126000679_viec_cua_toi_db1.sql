-- Migration 679 (E-26-04, anh Trường chốt 26/11/2026): «VIỆC CỦA TÔI», PR DB1: hàm gom app.list_my_work và các hàm con cho tín hiệu mức «Ngay».
-- Nguồn: HOP-THU VT1 mục 1, 3, 4. Không có bảng việc: đọc thẳng trạng thái, việc gốc xong thì dòng tự mất. «Để sau» và tín hiệu cần mốc mới làm ở PR sau.
-- Quyền: mỗi hàm con hỏi app.permission_scope MỘT lần, theo đúng phạm vi hàm danh sách cũ của phân hệ (Toàn hệ thống hoặc Cơ sở); không quyền thì trả rỗng.
-- «Của tôi» = người phụ trách (giáo viên, trợ giảng, CSKH lớp với buổi). «Cả đội» = bỏ lọc người, vẫn trong phạm vi Xem (anh chốt: không thêm quyền mới).
-- Chỉ mục: không thêm; các nguồn đi theo appointment_owner_idx, appointment_status_time_idx, student_test_owner_idx, student_test_status_time_idx,
--   class_session_open_idx, session_attendance (session_id), upsale_ticket_owner_idx, upsale_ticket_expected_end_idx (EXPLAIN trong mô tả PR).

select set_config('hmt.migration', 'on', false);
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description) values
  ('work_now_window_hours', 'Việc của tôi: còn dưới số giờ này thì vào nhóm Làm ngay', 'INT', 'giờ', 0, 72, '2', true, 'BAN_HANG', 'E-26-04',
   'Việc đã quá hạn hoặc còn ít hơn số giờ này tới hạn được xếp vào nhóm Làm ngay.'),
  ('work_soon_days', 'Việc của tôi: số ngày nhìn trước cho nhóm Sắp tới', 'INT', 'ngày', 0, 30, '3', true, 'BAN_HANG', 'E-26-04',
   'Lịch hẹn, phiếu kiểm tra trong số ngày này sau hôm nay được hiện ở nhóm Sắp tới.');
select set_config('hmt.migration', '', false);

create type app.work_item as (
  signal text, entity_type text, entity_id uuid, parent_id uuid, phone text, urgency text,
  title text, why text, due_at timestamptz, action text, owner_id uuid, branch_id uuid);

-- app.work_urgency: nhóm gấp theo hạn. Hàm trong. NOW = quá hạn hoặc còn trong cửa sổ; TODAY = hạn trong hôm nay (giờ Việt Nam); còn lại SOON.
create function app.work_urgency(p_due timestamptz, p_window_hours integer)
returns text
language sql
stable
set search_path = ''
as $$
  select case when p_due <= now() + make_interval(hours => p_window_hours) then 'NOW'
              when (p_due at time zone 'Asia/Ho_Chi_Minh')::date <= (now() at time zone 'Asia/Ho_Chi_Minh')::date then 'TODAY'
              else 'SOON' end;
$$;

-- app.work_appointments: lịch hẹn Chưa làm quá hạn, hôm nay, sắp tới (quyền Lịch hẹn · Xem). Hàm trong.
-- Lịch nhắc tự sinh của phiếu còn Nháp bị bỏ: một phiếu chỉ một dòng (tín hiệu phiếu kiểm tra).
create function app.work_appointments(p_mine boolean, p_branch uuid, p_until timestamptz, p_window integer)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  select 'APPOINTMENT', 'APPOINTMENT', a.id, coalesce(l.parent_id, o.parent_id, s.parent_id),
         case when coalesce(l.parent_id, o.parent_id, s.parent_id) is null then l.parent_phone end,
         app.work_urgency(a.scheduled_at, p_window), a.title,
         case when a.scheduled_at < now() then 'Lịch hẹn đã quá giờ' else 'Lịch hẹn sắp tới giờ' end,
         a.scheduled_at, 'COMPLETE_APPOINTMENT', a.owner_id, a.branch_id
    from app.appointment a
    left join app.lead l on l.id = a.lead_id
    left join app.opportunity o on o.id = a.opportunity_id
    left join app.student_test t on t.id = a.student_test_id
    left join app.student s on s.id = t.student_id
   where a.status = 'CHUA_LAM' and a.scheduled_at < p_until
     and (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my)
     and (p_branch is null or a.branch_id = p_branch)
     and (not p_mine or a.owner_id = v_me)
     and not (a.is_auto_reminder and t.status_code = 'DRAFT');
end;
$$;

-- app.work_tests: phiếu kiểm tra còn Nháp đã quá giờ hoặc sắp tới (quyền Phiếu kiểm tra · Xem). Hàm trong.
create function app.work_tests(p_mine boolean, p_branch uuid, p_until timestamptz, p_window integer)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  select 'TEST', 'STUDENT_TEST', t.id, s.parent_id, null::text, app.work_urgency(t.scheduled_at, p_window),
         'Kiểm tra đầu vào ' || t.code || ' · ' || s.full_name,
         case when t.scheduled_at < now() then 'Quá giờ kiểm tra, phiếu chưa bắt đầu' else 'Sắp tới giờ kiểm tra' end,
         t.scheduled_at, 'OPEN_TEST', t.owner_id, t.branch_id
    from app.student_test t
    join app.student s on s.id = t.student_id
   where t.status_code = 'DRAFT' and t.scheduled_at < p_until
     and (v_scope = 'TOAN_HE_THONG' or t.branch_id = v_my)
     and (p_branch is null or t.branch_id = p_branch)
     and (not p_mine or t.owner_id = v_me);
end;
$$;

-- app.work_approvals: việc chờ CHÍNH người gọi duyệt (dùng lại app.my_approval_items, đã lọc quyền). Hàm trong. Phụ huynh lấy theo chứng từ.
create function app.work_approvals(p_branch uuid)
returns setof app.work_item
language sql
stable
security definer
set search_path = ''
as $$
  select 'APPROVAL', i.kind, i.ref_id,
         case i.kind
           when 'DON_HANG' then (select x.parent_id from app.sales_order x where x.id = i.ref_id)
           when 'PHIEU_THU' then (select x.parent_id from app.receipt x where x.id = i.ref_id)
           when 'HOAN_PHI' then (select e.parent_id from app.refund_request x join app.enrollment e on e.id = x.enrollment_id where x.id = i.ref_id)
           when 'DUNG_HOC' then (select e.parent_id from app.enrollment_stop x join app.enrollment e on e.id = x.enrollment_id where x.id = i.ref_id)
           when 'BAO_LUU' then (select e.parent_id from app.enrollment_hold x join app.enrollment e on e.id = x.enrollment_id where x.id = i.ref_id)
           when 'CHUYEN_LOP' then (select e.parent_id from app.class_transfer x join app.enrollment e on e.id = x.enrollment_id where x.id = i.ref_id)
         end,
         null::text, 'TODAY',
         'Chờ duyệt ' || i.code || coalesce(' · ' || i.subject_name, ''),
         'Chờ bạn duyệt cấp ' || i.level_label, i.waiting_since, 'OPEN_APPROVAL', i.creator_id, i.branch_id
    from app.my_approval_items() i
   where p_branch is null or i.branch_id = p_branch;
$$;

-- app.work_sessions: buổi đã chốt cần hoàn tất (đã hết giờ), và buổi đang diễn ra chưa điểm danh (quyền Buổi học · Xem). Hàm trong.
-- Hạn hoàn tất như app.session_pending_list: giờ kết thúc + teacher_session_complete_hours. Chưa điểm danh theo công tắc DIEM_DANH_TRONG_NGAY.
create function app.work_sessions(p_mine boolean, p_branch uuid, p_window integer)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SESSION', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_time time := (now() at time zone 'Asia/Ho_Chi_Minh')::time;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  -- Tham số theo cơ sở đọc MỘT lần mỗi cơ sở (không gọi cho từng buổi).
  with th as materialized (
    select br.id, make_interval(hours => app.get_setting_int('teacher_session_complete_hours', br.id)::integer) as complete_within,
           app.feature_enabled('DIEM_DANH_TRONG_NGAY', br.id) as day_attendance
      from app.branch br
  ), f as (
    select s.id, s.branch_id, s.session_no, s.session_date, s.start_time, s.teacher_id, c.code as class_code,
           ((s.session_date + s.start_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') as starts_at,
           ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') as ends_at
      from app.class_session s join app.class c on c.id = s.class_id
     where s.status_code = 'DA_CHOT' and s.session_date <= v_today
       and (s.session_date < v_today or s.start_time <= v_time)
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my)
       and (p_branch is null or s.branch_id = p_branch)
       and (not p_mine or v_me in (s.teacher_id, s.assistant_id, c.cskh_id))
  )
  select 'SESSION_PENDING', 'SESSION', f.id, null::uuid, null::text, app.work_urgency(d.deadline, p_window),
         'Buổi ' || f.session_no || ' lớp ' || f.class_code, 'Buổi đã hết giờ, chưa hoàn tất', d.deadline,
         'COMPLETE_SESSION', f.teacher_id, f.branch_id
    from f
    join th on th.id = f.branch_id
    cross join lateral (select f.ends_at + th.complete_within as deadline) d
   where f.ends_at <= now()
  union all
  select 'SESSION_NO_ATTENDANCE', 'SESSION', f.id, null::uuid, null::text, 'NOW',
         'Buổi ' || f.session_no || ' lớp ' || f.class_code, 'Buổi đang diễn ra, chưa điểm danh', f.starts_at,
         'TAKE_ATTENDANCE', f.teacher_id, f.branch_id
    from f
    join th on th.id = f.branch_id
   where f.ends_at > now() and th.day_attendance
     and not exists (select from app.session_attendance a where a.session_id = f.id and a.is_active and a.teacher_status_code is not null);
end;
$$;

-- app.work_absent_today: học sinh vắng hôm nay chưa ghi lý do liên hệ (quyền Điểm danh · Sửa, như app.absent_today_list). Hàm trong.
create function app.work_absent_today(p_mine boolean, p_branch uuid)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ATTENDANCE', 'SUA');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  select 'ABSENT_TODAY', 'SESSION_ATTENDANCE', sa.id, st.parent_id, null::text, 'NOW',
         st.full_name || ' vắng · lớp ' || c.code, 'Vắng hôm nay, chưa ghi lý do liên hệ',
         ((s.session_date + s.start_time)::timestamp at time zone 'Asia/Ho_Chi_Minh'), 'CONTACT_ABSENT', c.cskh_id, s.branch_id
    from app.class_session s
    join app.session_attendance sa on sa.session_id = s.id and sa.is_active
    join app.class c on c.id = s.class_id
    join app.student st on st.id = sa.student_id
   where s.session_date = v_today and s.status_code = 'DA_CHOT'
     and coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
     and sa.contact_reason_code is null
     and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my)
     and (p_branch is null or s.branch_id = p_branch)
     and (not p_mine or c.cskh_id = v_me);
end;
$$;

-- app.work_renewals: phiếu tái tục đang mở, học sinh sắp hết giờ (R-GD-13; ngưỡng upsale_*_threshold theo cơ sở; quyền Tái tục · Xem). Hàm trong.
create function app.work_renewals(p_mine boolean, p_branch uuid)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('UPSALE', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  with th as materialized (
    select br.id, app.get_setting_numeric('upsale_hours_left_threshold', br.id) as hours,
           app.get_setting_int('upsale_days_left_threshold', br.id)::integer as days
      from app.branch br
  )
  select 'RENEWAL', 'UPSALE_TICKET', u.id, u.parent_id, null::text,
         case when u.expected_end_date <= v_today or u.hours_left <= 0 then 'NOW' else 'SOON' end,
         'Tái tục ' || u.code || ' · ' || st.full_name,
         concat_ws(', ', 'Sắp hết giờ', 'còn ' || trim_scale(u.hours_left) || ' giờ', 'dự kiến hết ' || to_char(u.expected_end_date, 'DD/MM/YYYY')),
         (u.expected_end_date::timestamp at time zone 'Asia/Ho_Chi_Minh'), 'OPEN_RENEWAL', u.owner_id, u.branch_id
    from app.upsale_ticket u
    join app.student st on st.id = u.student_id
    join th on th.id = u.branch_id
   where u.closed_at is null and u.stage_code not in ('L5', 'L8')
     and (u.hours_left <= th.hours or u.expected_end_date <= v_today + th.days)
     and (v_scope = 'TOAN_HE_THONG' or u.branch_id = v_my)
     and (p_branch is null or u.branch_id = p_branch)
     and (not p_mine or u.owner_id = v_me);
end;
$$;

revoke execute on function app.work_urgency(timestamptz, integer), app.work_appointments(boolean, uuid, timestamptz, integer),
  app.work_tests(boolean, uuid, timestamptz, integer), app.work_approvals(uuid), app.work_sessions(boolean, uuid, integer),
  app.work_absent_today(boolean, uuid), app.work_renewals(boolean, uuid) from public, anon, authenticated;

-- app.list_my_work: «Việc của tôi», gom theo phụ huynh, phân trang theo THẺ.
-- Ai gọi: nhân viên đã sẵn sàng; mỗi tín hiệu tự kiểm quyền. Vào: p_filters {mine (mặc định true; false = cả đội), branch_id, owner_id (khi cả đội)},
--   p_limit, p_offset. Ra: {counts {now, today, soon} (đếm việc), total_cards, cards [{group_key, parent_id, parent_name, phone, urgency, items []}]}.
-- Thẻ: cùng phụ huynh; lead chưa có phụ huynh gom theo số điện thoại; việc không gắn phụ huynh đứng riêng. Sắp: nhóm gấp nhất, hạn sớm nhất, khoá thẻ.
create function app.list_my_work(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, true);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_my uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_window integer := app.get_setting_int('work_now_window_hours', v_my);
  v_until timestamptz := (((now() at time zone 'Asia/Ho_Chi_Minh')::date + app.get_setting_int('work_soon_days', v_my)::integer + 1)::timestamp
                          at time zone 'Asia/Ho_Chi_Minh');
  v_result jsonb;
begin
  if auth.uid() is null or not app.current_user_ready() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem việc của tôi.');
  end if;
  with i as materialized (
    select w.*, coalesce('P:' || w.parent_id, 'T:' || w.phone, w.signal || ':' || w.entity_id) as group_key,
           case w.urgency when 'NOW' then 1 when 'TODAY' then 2 else 3 end as rank -- allow-number: thứ tự ba nhóm gấp
      from (
        select * from app.work_appointments(v_mine, v_branch, v_until, v_window)
        union all select * from app.work_tests(v_mine, v_branch, v_until, v_window)
        union all select * from app.work_approvals(v_branch)
        union all select * from app.work_sessions(v_mine, v_branch, v_window)
        union all select * from app.work_absent_today(v_mine, v_branch)
        union all select * from app.work_renewals(v_mine, v_branch)
      ) w
     -- Lọc theo người chỉ ở chế độ cả đội; việc chờ duyệt là của người gọi nên không theo bộ lọc này.
     where v_mine or v_owner is null or (w.owner_id = v_owner and w.signal <> 'APPROVAL')
  ), cards as (
    select i.group_key, min(i.rank) as rank, min(i.due_at) as due_at,
           (array_agg(i.parent_id) filter (where i.parent_id is not null))[1] as parent_id, max(i.phone) as phone
      from i group by i.group_key
  ), page as (
    select * from cards order by rank, due_at nulls last, group_key limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'counts', (select jsonb_build_object('now', count(*) filter (where rank = 1), 'today', count(*) filter (where rank = 2), -- allow-number: thứ tự ba nhóm gấp
                                                'soon', count(*) filter (where rank = 3)) from i), -- allow-number: thứ tự ba nhóm gấp
           'total_cards', (select count(*) from cards),
           'cards', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'group_key', p.group_key, 'parent_id', p.parent_id, 'parent_name', par.full_name, 'phone', coalesce(par.phone, p.phone),
                      'urgency', case p.rank when 1 then 'NOW' when 2 then 'TODAY' else 'SOON' end, -- allow-number: thứ tự ba nhóm gấp
                      'items', (select jsonb_agg(jsonb_build_object(
                                         'signal', x.signal, 'entity_type', x.entity_type, 'entity_id', x.entity_id, 'urgency', x.urgency,
                                         'title', x.title, 'why', x.why, 'due_at', x.due_at, 'action', x.action,
                                         'owner_name', app.staff_display_name(x.owner_id), 'branch_code', b.code)
                                         order by x.rank, x.due_at nulls last, x.signal, x.entity_id)
                                  from i x left join app.branch b on b.id = x.branch_id where x.group_key = p.group_key))
                      order by p.rank, p.due_at nulls last, p.group_key)
               from page p left join app.parent par on par.id = p.parent_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;
revoke execute on function app.list_my_work(jsonb, integer, integer) from public, anon;
grant execute on function app.list_my_work(jsonb, integer, integer) to authenticated;
