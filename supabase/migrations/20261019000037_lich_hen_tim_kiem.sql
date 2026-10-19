-- P3c-3 (DB): màn Lịch hẹn (TS-11) cần ô tìm "Tìm tên, SĐT, mã" và lọc theo người phụ trách (chế độ "Theo người").
-- Chỉ thêm hai bộ lọc vào app.list_appointments (q, owner_id); luật xem và phạm vi không đổi (docs/spec/04 R-CRM-04, R-CRM-07).
-- Lý do không thêm chỉ mục: q dò qua lead.search_text, opportunity.search_text (đã có chỉ mục trigram), còn khoá ngoại
-- lead_id, opportunity_id của lịch hẹn đã có chỉ mục (appointment_lead_idx, appointment_opportunity_idx).

create or replace function app.list_appointments(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  with f as not materialized (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_test is null or a.student_test_id = v_test)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       -- Tìm theo tên, SĐT, mã của hồ sơ gắn (lead hoặc cơ hội): dò hồ sơ bằng chỉ mục trigram trước, rồi nối về lịch hẹn.
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'activity_code', p.activity_code, 'scheduled_at', p.scheduled_at, 'title', p.title,
             'status', p.status, 'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'lead_id', p.lead_id, 'lead_code', l.code,
             'lead_label', l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_test_id', p.student_test_id, 'student_test_code', t.code, 'is_auto_reminder', p.is_auto_reminder,
             'record_code', coalesce(l.code, o.code, t.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif(o.student_name, ''), ''),
                                      ts.full_name || ' · Phiếu kiểm tra'),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = p.student_test_id
    left join app.student ts on ts.id = t.student_id;
  return v_result;
end;
$$;
