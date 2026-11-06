-- ===========================================================================
-- Đơn hàng: vượt trần chiết khấu chỉ cảnh báo (R-V2-11, anh chốt 06/11, A4). order_approve_core (dùng chung cho approve_order và tự duyệt khi trình)
-- bỏ yêu cầu tích "đồng ý vượt trần / chính sách cần duyệt" (HMT_CAN_TICH_DONG_Y); tham số p_acknowledged giữ để tương thích, không còn tác dụng.
-- Nhật ký (sự kiện DUYET) ghi "Duyệt đơn vượt trần N%: dòng X Y%" khi có dòng vượt; cột acknowledged ghi đơn có cờ cảnh báo lúc duyệt.
-- Trần = tham số discount_total_cap_percent (mặc định 20), không viết cứng.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

create or replace function app.order_approve_core(p_id uuid, p_acknowledged boolean, p_on_behalf boolean, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  l app.sales_order_line;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_cap numeric := app.get_setting_numeric('discount_total_cap_percent', null);
  v_over text;
  v_note text := p_note;
begin
  -- Đọc LẠI đơn: order_refresh_totals ở submit_order có thể đã đổi needs_acknowledgement sau khi hàm gọi đọc đơn.
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  -- Luật R-V2-11 (anh chốt 06/11, A4): vượt trần chiết khấu chỉ CẢNH BÁO, không chặn và không cần tích đồng ý. Bước duyệt chính là lúc xem xét;
  -- nhật ký ghi người duyệt đơn vượt trần và tổng % cộng dồn từng dòng vượt lúc duyệt. Trần đọc từ tham số discount_total_cap_percent (không viết cứng).
  select string_agg(format('dòng %s %s%%', l2.line_no, to_char(l2.discount_percent + l2.gift_percent, 'FM999990.0')), '; ' order by l2.line_no)
    into v_over from app.sales_order_line l2 where l2.order_id = p_id and l2.over_cap;
  if v_over is not null then
    v_note := concat_ws(' · ', nullif(p_note, ''), format('Duyệt đơn vượt trần %s%%: %s', to_char(v_cap, 'FM999990.##'), v_over));
  end if;
  -- Luật R-TIEN-35: kiểm lại em đủ họ tên, năm sinh; R-GD-08: kiểm lại lớp.
  perform app.assert_order_students_complete(p_id);
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Trigger khoá dòng cho phép riêng việc gắn hồ sơ học sinh và chốt hạn đóng trong lúc duyệt (hmt.order_approve).
  perform set_config('hmt.order_approve', 'on', true);
  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh; trùng tên và năm sinh trong đơn thì chặn (KD6).
  perform app.order_link_students(p_id, v_o.parent_id, v_o.branch_id);
  -- Lịch đóng tiền đã tính lúc lưu và lúc trình (đơn khoá từ khi trình): chốt hạn đóng (ngày duyệt + số ngày của đợt).
  update app.sales_order_installment set due_date = v_today + due_days where order_id = p_id;
  perform set_config('hmt.order_approve', '', true);
  update app.sales_order set status_code = 'DA_DUYET', approved_at = now(), approved_by = auth.uid(),
         approved_on_behalf = coalesce(p_on_behalf, false), acknowledged = v_o.needs_acknowledgement where id = p_id;
  perform app.order_add_event(p_id, 'DUYET', 'DA_TRINH', 'DA_DUYET', null, null, v_note, coalesce(p_on_behalf, false));
end;
$$;

select set_config('hmt.migration', '', false);
