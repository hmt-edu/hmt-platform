-- D-26-07: app.get_parent_record (security definer) chỉ trả đơn hàng, phiếu thu (và số đếm của chúng) mà người gọi được xem.
-- Ai gọi: người có quyền Xem phụ huynh. Hai khối đơn hàng, phiếu thu xét thêm quyền của từng phân hệ.
-- Lọc bằng app.can_see_branch_wide (chỉ Toàn hệ thống hoặc Cơ sở mình, phạm vi hẹp không tính), cùng luật với chính sách sales_order_read, receipt_read
-- và list_orders, list_receipts (migration 422, 460, 461): không có quyền thì danh sách rỗng, số đếm 0.
-- Phần còn lại giữ nguyên migration 573; quyền gọi hàm giữ nguyên.

create or replace function app.get_parent_record(p_parent_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p app.parent;
begin
  -- Luật R-CRM-26 và chính sách parent_read (migration 422): chỉ phạm vi Toàn hệ thống, Cơ sở đọc được hồ sơ phụ huynh.
  if coalesce(app.permission_scope('PARENT', 'XEM'), '') not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  select * into p from app.parent where id = p_parent_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  return jsonb_build_object(
    'id', p.id, 'code', p.code, 'full_name', p.full_name, 'phone', p.phone, 'phone_2', p.phone_2, 'relative_name', p.relative_name,
    'address', p.address,
    'ward_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'WARD' and ci.code = p.ward_code),
    'province_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'PROVINCE' and ci.code = p.province_code),
    'branch_code', (select b.code from app.branch b where b.id = p.branch_id),
    'record_status', p.record_status, 'merged_into_id', p.merged_into_id,
    'created_at', p.created_at,
    'is_studying', exists (select from app.enrollment e where e.parent_id = p.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')),
    'studying_at', coalesce((select jsonb_agg(distinct eb.code order by eb.code) from app.enrollment e join app.branch eb on eb.id = e.branch_id
                              where e.parent_id = p.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb),
    'children', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'full_name', s.full_name, 'grade', s.grade, 'status', app.student_status(s.id)) order by s.full_name)
                            from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code, 'status_code', o.status_code, 'total_amount', o.total_amount, 'created_at', o.created_at) order by o.created_at desc)
                          from (select * from app.sales_order x
                                 where x.parent_id = p.id and app.can_see_branch_wide('SALES_ORDER', 'XEM', x.branch_id) -- quyền Xem đơn hàng
                                 order by x.created_at desc limit 50) o), '[]'::jsonb), -- allow-number: 50 dòng mới nhất mỗi loại trên bản ghi
    'receipts', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'status_code', r.status_code, 'amount', r.amount, 'paid_on', r.paid_on) order by r.created_at desc)
                            from (select * from app.receipt x
                                   where x.parent_id = p.id and app.can_see_branch_wide('RECEIPT', 'XEM', x.branch_id) -- quyền Xem phiếu thu
                                   order by x.created_at desc limit 50) r), '[]'::jsonb), -- allow-number: 50 dòng mới nhất mỗi loại trên bản ghi
    'counts', jsonb_build_object(
      'children', (select count(*) from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'),
      'opportunities', (select count(*) from app.opportunity o where o.parent_id = p.id and o.record_status = 'DANG_DUNG'),
      'tests', (select count(*) from app.student_test t join app.student s on s.id = t.student_id where s.parent_id = p.id),
      'enrollments', (select count(*) from app.enrollment e where e.parent_id = p.id),
      'orders', (select count(*) from app.sales_order o where o.parent_id = p.id and app.can_see_branch_wide('SALES_ORDER', 'XEM', o.branch_id)),
      'receipts', (select count(*) from app.receipt r where r.parent_id = p.id and app.can_see_branch_wide('RECEIPT', 'XEM', r.branch_id))));
end;
$$;
