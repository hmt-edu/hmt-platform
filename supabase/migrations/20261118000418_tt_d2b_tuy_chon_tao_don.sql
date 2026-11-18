-- TT-D2b Tuỳ chọn cho hộp «Tạo đơn» của phiếu tái tục (Code C, 18/11/2026). Chỉ đọc.
-- app.list_upsale_order_options(phiếu): gói bán được cho lớp của phiếu (đúng môn, tính theo giờ, có giá hôm nay), hình thức học giữ như ghi danh cũ,
-- điều khoản thanh toán đang dùng, các buổi sắp tới của lớp (ngày vào lớp phải là một buổi sắp tới, R-GD-06). Giá chỉ để HIỂN THỊ, tiền tính khi tạo đơn (app.price_line).
-- Ai gọi: người vừa có quyền Đơn hàng · Tạo vừa có quyền Phiếu tái tục · Sửa ở cơ sở của phiếu (như app.create_order_from_upsale_ticket).
select set_config('hmt.migration', 'on', false);

create or replace function app.list_upsale_order_options(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_class app.class;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select * into t from app.upsale_ticket where id = p_ticket_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', t.branch_id);
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  select * into v_class from app.class where id = t.class_id;
  return jsonb_build_object(
    'delivery_mode_code', (select e.delivery_mode_code from app.enrollment e
                             join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                            where e.student_id = t.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') order by e.created_at desc limit 1),
    'packages', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'code', p.code, 'name', p.name,
                           'prices', jsonb_strip_nulls(jsonb_build_object('OFF', app.package_price_at(p.id, 'OFF', v_on), 'ONL', app.package_price_at(p.id, 'ONL', v_on))))
                           order by p.code)
                            from app.sales_package p
                           where p.is_active and app.package_unit(p.package_type_code) = 'GIO'
                             and app.package_matches_class_subject(p.subject_code, v_class.subject_code)
                             and (app.package_price_at(p.id, 'OFF', v_on) is not null or app.package_price_at(p.id, 'ONL', v_on) is not null)), '[]'::jsonb),
    'terms', coalesce((select jsonb_agg(jsonb_build_object('id', pt.id, 'name', pt.name) order by pt.name)
                         from app.payment_term pt where pt.is_active), '[]'::jsonb),
    'sessions', coalesce((select jsonb_agg(x.session_date order by x.session_date)
                            from (select distinct s.session_date from app.class_session s
                                   where s.class_id = t.class_id and s.status_code in ('NHAP', 'DA_CHOT') and s.session_date >= v_on
                                   order by s.session_date limit app.get_setting_int('list_page_size_default')) x), '[]'::jsonb));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.list_upsale_order_options(uuid) from public, anon;
grant execute on function app.list_upsale_order_options(uuid) to authenticated;
