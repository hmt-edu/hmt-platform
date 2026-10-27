-- ===========================================================================
-- P5a-DB1c-4 (migration 056): get_quotation trả thêm, cho từng dòng, mã đơn đang sống sinh từ dòng đó (`order_id`, `order_code`,
-- `order_status_code`) và `live_order_count` (số đơn đang sống của báo giá), để BH-02 hiện "đã lên đơn nào". Chỉ thêm khoá vào kết quả;
-- mọi thứ khác giữ nguyên. Đọc `sales_order_line` qua chỉ mục duy nhất từng phần `sales_order_line_quotation_live_uidx` (quotation_line_id, is_live).
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

create or replace function app.get_quotation(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  q app.quotation;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_display text;
begin
  select * into q from app.quotation where id = p_id;
  if q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'XEM', q.branch_id);
  v_display := case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end;
  return (to_jsonb(q) - 'search_text') || jsonb_build_object(
    'display_status_code', v_display,
    'display_status', (select c.name from app.catalog_item c where c.catalog_code = 'QUOTATION_STATUS' and c.code = v_display),
    'overdue_days', case when q.status_code = 'DA_GUI' and q.valid_until < v_today then v_today - q.valid_until end,
    'branch_code', (select b.code from app.branch b where b.id = q.branch_id),
    'opportunity_code', (select o.code from app.opportunity o where o.id = q.opportunity_id),
    'parent_code', (select p.code from app.parent p where p.id = q.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = q.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = q.parent_id),
    'created_by_name', app.staff_display_name(q.created_by),
    'sent_by_name', app.staff_display_name(q.sent_by),
    'reject_reason', (select c.name from app.catalog_item c where c.catalog_code = 'REJECT_REASON' and c.code = q.reject_reason_code),
    'has_incomplete_students', exists (
      select from app.quotation_line l join app.prospect_student_v v on v.id = l.prospect_student_id
       where l.quotation_id = q.id and (v.full_name is null or v.birth_year is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'quotation_id' || jsonb_build_object(
               'student_name', v.full_name, 'student_birth_year', v.birth_year, 'student_code', v.student_code,
               'student_complete', (v.full_name is not null and v.birth_year is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               -- Đơn đang sống của dòng (Đ106: tối đa một); chưa lên đơn hoặc đơn đã huỷ thì rỗng.
               'order_id', ol.order_id, 'order_code', ol.order_code, 'order_status_code', ol.order_status_code,
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.quotation_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.quotation_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join lateral (select o.id as order_id, o.code as order_code, o.status_code as order_status_code
                             from app.sales_order_line sl join app.sales_order o on o.id = sl.order_id
                            where sl.quotation_line_id = l.id and sl.is_live) ol on true
       where l.quotation_id = q.id), '[]'::jsonb),
    -- Số đơn đang sống sinh từ báo giá này (cho nút "Đơn hàng" của BH-02).
    'live_order_count', (select count(distinct sl.order_id)::integer
                           from app.quotation_line l2 join app.sales_order_line sl on sl.quotation_line_id = l2.id and sl.is_live
                          where l2.quotation_id = q.id));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.get_quotation(uuid) from public, anon;
grant execute on function app.get_quotation(uuid) to authenticated;
