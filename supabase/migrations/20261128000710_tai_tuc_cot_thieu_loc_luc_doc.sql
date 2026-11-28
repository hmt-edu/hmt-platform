-- C-27-17 (Chat cấp 710, 28/11/2026; rủi ro CAO: dữ liệu): phiếu tái tục, phần «máy chủ chưa trả» và lọc theo số tính lúc đọc. Luật R-GD-13, R-GIO-04.
-- (1) Dòng danh sách, thẻ Kanban, bản ghi trả thêm Phụ huynh, Môn, Liên hệ gần nhất.
-- (2) Bản ghi: mỗi ghi danh thêm Môn, ngày dự kiến hết giờ; thêm nhận xét gần nhất của giáo viên. Đơn của phiếu thêm số đã thu.
-- (3) Lọc Campaign, sắp theo hết giờ, nhóm theo đợt tái tục dùng ngày tính LÚC ĐỌC (trước đây dùng cột đợt quét đêm ghi, phiếu tạo tay và L6–L8 để trống).
--     Màn Đối chiếu (TT-04) và đợt quét sinh phiếu KHÔNG đổi.
select set_config('hmt.migration', 'on', false);

-- app.upsale_live(các phiếu; null = mọi phiếu): giờ còn và ngày hết giờ dự kiến, tính một lượt. Một công thức duy nhất cho bản ghi, danh sách, bộ lọc, nhóm.
-- Chỉ trả phiếu người gọi xem được (Phiếu tái tục · Xem, cùng điều kiện với RLS). Giờ còn = tổng sổ giờ của ghi danh Đã xếp lớp, Đang học của em ở lớp,
-- kể cả giờ tặng; không có ghi danh nào thì null. Ngày hết giờ = hôm nay + số tuần đủ học hết, theo giờ mỗi tuần của khung giờ lớp (như app.upsale_candidates).
-- security definer: người xem phiếu không nhất thiết có quyền đọc sổ giờ.
create function app.upsale_live(p_ticket_ids uuid[])
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
  ), w as (
    select s.class_id, sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) as weekly -- allow-number: 3600 giây một giờ
      from app.class_slot s
     where s.is_active and s.class_id in (select class_id from t)
     group by s.class_id
  )
  select t.id, h.left_hours,
         case when h.left_hours > 0 and w.weekly > 0
              then (now() at time zone 'Asia/Ho_Chi_Minh')::date + ceil(h.left_hours / w.weekly * 7)::integer end -- allow-number: 7 ngày một tuần
    from t
    left join h on h.id = t.id
    left join w on w.class_id = t.class_id;
end;
$$;
revoke execute on function app.upsale_live(uuid[]) from public, anon;
grant execute on function app.upsale_live(uuid[]) to authenticated;

-- Bản một phiếu (migration 708) gọi lại công thức chung ở trên.
create or replace function app.upsale_ticket_live(p_ticket_id uuid, out hours_left numeric, out expected_end_date date)
language sql
stable
security definer
set search_path = ''
as $$
  select v.hours_left, v.expected_end_date
    from (select 1) one
    left join app.upsale_live(array[p_ticket_id]) v on true;
$$;

-- app.upsale_row_extra(phiếu): ba ô thêm của dòng danh sách, thẻ Kanban, bản ghi: phụ huynh, môn của lớp, lần liên hệ gần nhất (không kèm nội dung).
-- Ai gọi: app.upsale_ticket_row; tự kiểm Phiếu tái tục · Xem ở cơ sở của phiếu. Liên hệ chỉ trả khi người gọi xem được ghi chú của hồ sơ đó (R-CRM-30).
create function app.upsale_row_extra(p_ticket_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('parent_name', p.full_name, 'subject_code', c.subject_code,
           'last_contact', app.upsale_contact_info(t) -> 'last')
    from app.upsale_ticket t
    join app.parent p on p.id = t.parent_id
    join app.class c on c.id = t.class_id
   where t.id = p_ticket_id and app.can_see_branch('UPSALE', 'XEM', t.branch_id);
$$;
revoke execute on function app.upsale_row_extra(uuid) from public, anon;
grant execute on function app.upsale_row_extra(uuid) to authenticated;

-- app.upsale_enrollments(phiếu): ghi danh của em ở lớp. Ngày dự kiến hết giờ của từng ghi danh còn học: trừ giờ lần lượt theo ghi danh vào lớp sớm trước
-- (R-GIO-04), nên ghi danh sau hết giờ sau khi các ghi danh trước đã hết; không còn giờ, đã dừng, bảo lưu hay lớp chưa có khung giờ thì null. Nội bộ.
create function app.upsale_enrollments(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with en as (
    select e.id, e.code, e.status_code, e.created_at, ec.start_date,
           coalesce(e.subject_code, c.subject_code) as subject_code,
           coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0) as hours_left,
           e.status_code in ('DA_XEP_LOP', 'DANG_HOC') as is_studying
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
      join app.class c on c.id = ec.class_id
     where e.student_id = t.student_id
  ), run as (
    select en.*, sum(case when is_studying then greatest(hours_left, 0) else 0 end)
                   over (order by start_date, created_at, id) as hours_through
      from en
  ), w as (
    select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) as weekly -- allow-number: 3600 giây một giờ
      from app.class_slot s where s.class_id = t.class_id and s.is_active
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'status_code', r.status_code, 'hours_left', r.hours_left,
           'subject_code', r.subject_code,
           'expected_end_date', case when r.is_studying and r.hours_left > 0 and w.weekly > 0
              then (now() at time zone 'Asia/Ho_Chi_Minh')::date + ceil(r.hours_through / w.weekly * 7)::integer end) -- allow-number: 7 ngày một tuần
           order by r.code), '[]'::jsonb)
    from run r cross join w;
$$;
revoke execute on function app.upsale_enrollments(app.upsale_ticket) from public, anon, authenticated;

-- app.upsale_last_review(phiếu): nhận xét gần nhất của giáo viên cho em ở lớp này, ở buổi đã Done. Chỉ buổi người gọi được xem (app.session_visible,
-- cùng điều kiện với RLS của nhận xét). Không có thì null. Nội bộ.
create function app.upsale_last_review(t app.upsale_ticket)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('comment', r.teacher_comment, 'session_date', s.session_date)
    from app.session_student_review r
    join app.session_attendance a on a.id = r.attendance_id
    join app.class_session s on s.id = r.session_id
   where a.student_id = t.student_id and s.class_id = t.class_id and s.status_code = 'DONE'
     and nullif(btrim(r.teacher_comment), '') is not null
     and app.session_visible(s.id)
   order by s.session_date desc, s.start_time desc, r.attendance_id
   limit 1;
$$;
revoke execute on function app.upsale_last_review(app.upsale_ticket) from public, anon, authenticated;

-- Một dòng phiếu (bản 708) thêm ba ô của app.upsale_row_extra.
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
    || app.upsale_row_extra(t.id)
  from app.branch b, app.student s, app.class c, app.upsale_ticket_live(t.id) v
 where b.id = t.branch_id and s.id = t.student_id and c.id = t.class_id;
$$;

-- Luật lọc chung (bản 437): ngày hết giờ để lọc Campaign và sắp xếp lấy từ app.upsale_live.
create or replace function app.upsale_filtered(p_filters jsonb)
returns table (id uuid, stage_code text, expected_end_date date, created_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select t.id, t.stage_code, v.expected_end_date, t.created_at
    -- Tính một lượt cho mọi phiếu người gọi xem được (trả đúng tập phiếu RLS cho thấy), rồi tra phiếu theo khoá chính.
    from app.upsale_live(null) v
    join app.upsale_ticket t on t.id = v.ticket_id
   where (p_filters ->> 'stage_code' is null or t.stage_code = p_filters ->> 'stage_code')
     and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
     and (nullif(p_filters ->> 'owner', '') is null
          or (p_filters ->> 'owner' = 'mine' and t.owner_id = auth.uid())
          or (p_filters ->> 'owner' = 'unassigned' and t.owner_id is null))
     and (nullif(p_filters ->> 'campaign_month', '') is null or to_char(v.expected_end_date, 'YYYY-MM') = p_filters ->> 'campaign_month')
     and (coalesce((p_filters ->> 'risk')::boolean, false) = false or t.risk_flag)
     -- C69 (Group By): mở nhóm theo người phụ trách cụ thể và nhóm con.
     and (nullif(p_filters ->> 'owner_id', '') is null or t.owner_id = (p_filters ->> 'owner_id')::uuid)
     and (nullif(p_filters ->> 'substage_code', '') is null or t.substage_code = p_filters ->> 'substage_code')
     -- Tìm chữ: chỉ khi có chữ mới tra tên học sinh, mã lớp (không nối hai bảng cho từng dòng khi không tìm).
     and (nullif(btrim(coalesce(p_filters ->> 'q', '')), '') is null
          or t.code ilike '%' || btrim(p_filters ->> 'q') || '%'
          or exists (select from app.student s where s.id = t.student_id and s.full_name ilike '%' || btrim(p_filters ->> 'q') || '%')
          or exists (select from app.class c where c.id = t.class_id and c.code ilike '%' || btrim(p_filters ->> 'q') || '%'));
$$;

-- Đếm nhóm (bản 437): đợt tái tục theo ngày tính lúc đọc.
create or replace function app.upsale_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('stage', 'substage', 'campaign', 'owner', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (giai đoạn, nhóm con, đợt tái tục, phụ trách, cơ sở).');
  end if;
  with f as (select u.*, x.expected_end_date as live_end_date from app.upsale_filtered(p_filters) x join app.upsale_ticket u on u.id = x.id),
  keyed as (
    select case v_f1 when 'stage' then f.stage_code when 'substage' then f.substage_code when 'campaign' then to_char(f.live_end_date, 'YYYY-MM')
                     when 'owner' then f.owner_id::text when 'branch' then f.branch_id::text end as k1,
           case v_f2 when 'stage' then f.stage_code when 'substage' then f.substage_code when 'campaign' then to_char(f.live_end_date, 'YYYY-MM')
                     when 'owner' then f.owner_id::text when 'branch' then f.branch_id::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.upsale_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.upsale_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

-- Bản ghi (bản 709): ghi danh và nhận xét tách ra hàm con; việc làm được giữ nguyên.
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
      -- Luật R-GD-13 (27/11): tạo báo giá, tạo đơn ở mọi giai đoạn, theo quyền.
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('QUOTATION', 'TAO', t.branch_id) then 'tao_bao_gia' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('SALES_ORDER', 'TAO', t.branch_id) then 'tao_don' end], null)));
end;
$$;

-- Đơn của phiếu (bản 417): thêm số đã thu; vẫn chỉ trả khi người gọi có Đơn hàng · Xem.
create or replace function app.list_upsale_orders(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from app.upsale_ticket where id = p_ticket_id;
  if v_branch is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', v_branch);
  -- Người xem đơn cần quyền Đơn hàng · Xem; không có thì danh sách trống (không lộ tiền).
  if not app.can_see_branch('SALES_ORDER', 'XEM', v_branch) then
    return '[]'::jsonb;
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code, 'status_code', o.status_code, 'total_amount', o.total_amount, 'paid_amount', app.order_paid_amount(o.id),
                                                       'created_at', o.created_at) order by o.created_at, o.id)
                     from app.sales_order o where o.renewal_ticket_id = p_ticket_id), '[]'::jsonb);
end;
$$;

select set_config('hmt.migration', '', false);
