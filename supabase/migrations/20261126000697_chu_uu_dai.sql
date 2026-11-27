-- UD1 phần 3 (anh Trường duyệt 26/11): chữ máy chủ trả về đổi «chiết khấu» thành «ưu đãi». Tên bảng, cột, mã lỗi giữ nguyên.
-- Kèm sửa hai câu trái R-V2-11 (vượt trần chỉ cảnh báo, không có ô tích đồng ý, không cần duyệt thêm).
-- Không đổi công thức tiền, giờ, quyền. Dữ liệu và nhật ký đã ghi giữ chữ cũ (R-TIEN-14, nhật ký không sửa).
-- SQL động (pg_get_functiondef rồi thay đúng câu chữ): chỉ đổi chữ, không chép lại hàng trăm dòng hàm tính tiền, nên không đè mất
-- thay đổi của migration khác. Thiếu một câu cần thay thì migration dừng, không bỏ qua im lặng.
do $do$
declare
  v_item record;
  v_def text;
begin
  for v_item in
    select * from (values
      ('app.tg_quotation_child_lock', 'dòng và chiết khấu không sửa được', 'dòng và ưu đãi không sửa được'),
      ('app.price_apply_discounts', 'chính sách chiết khấu không có', 'chính sách ưu đãi không có'),
      ('app.price_apply_discounts', 'tổng chiết khấu phần trăm không quá 100', 'tổng ưu đãi phần trăm không quá 100'),
      ('app.save_quotation', 'chiết khấu (gồm giờ tặng) vượt trần %s%%. Đơn cần người duyệt tích đồng ý.',
        'ưu đãi (gồm giờ tặng) vượt trần %s%%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được.'),
      ('app.preview_quotation_lines', 'chiết khấu (gồm giờ tặng) vượt trần %s%%. Đơn cần người duyệt tích đồng ý.',
        'ưu đãi (gồm giờ tặng) vượt trần %s%%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được.'),
      ('app.order_line_diff_text', 'chiết khấu %s%% → %s%%', 'ưu đãi %s%% → %s%%'),
      ('app.edit_order', ', chiết khấu %s%%', ', ưu đãi %s%%'),
      ('app.list_policy_history', 'phải là chiết khấu hoặc quà tặng', 'phải là ưu đãi hoặc quà tặng')
    ) as t(function_name, old_text, new_text)
  loop
    v_def := pg_get_functiondef(v_item.function_name::regproc);
    if position(v_item.old_text in v_def) = 0 then
      raise exception 'Migration 697: hàm % không còn câu «%».', v_item.function_name, v_item.old_text;
    end if;
    execute replace(v_def, v_item.old_text, v_item.new_text);
  end loop;
end;
$do$;

update app.setting_def
   set name = 'Trần tổng ưu đãi',
       description = 'Tổng các ưu đãi cộng dồn trên một dòng vượt mức này thì cảnh báo; vẫn lưu và gửi được (R-V2-11).'
 where key = 'discount_total_cap_percent';

update app.setting_def
   set description = replace(description, 'trần tổng chiết khấu', 'trần tổng ưu đãi')
 where key = 'flexible_discount_max_percent';

update app.catalog_item
   set name = replace(name, 'chiết khấu', 'ưu đãi')
 where catalog_code = 'PERM_MODULE' and code = 'CONFIG_SALES';
