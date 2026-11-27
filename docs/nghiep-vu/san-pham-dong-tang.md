# Dòng tặng và giá trị quà (migration 676, 677; rủi ro cao)

Anh Trường chốt 26/11. Dòng tặng = dòng sản phẩm thường gắn chính sách ưu đãi «Tặng» (`discount_policy.is_gift`: phần trăm, áp đúng mức 100).

## Luật
- Mức của chính sách Tặng không tính vào trần chiết khấu, không gây cảnh báo vượt trần. Giờ tặng (chính sách khác) trên cùng dòng vẫn tính.
- Không cộng thêm chiết khấu % khác trên dòng tặng (tổng quá 100 bị chặn).
- Tổng niêm yết và tổng chiết khấu không cộng dòng tặng; số phải trả không đổi.
- Dòng chụp `is_gift_line`, `list_unit_price` lúc tính giá (R-TIEN-14). `list_unit_price` chỉ để hiện «Giá trị quà»; dòng quà dịch vụ, tài liệu cũng có, đơn giá vẫn 0.
- Giờ (sửa R-TIEN-21 cho dòng tặng): không có giờ mua; toàn bộ giờ là giờ tặng, cấp khi đơn thu đủ phần có thu tiền; hoàn tác thu thì thu hồi bằng dòng sổ ngược. Ghi danh của dòng tặng: `purchased_hours` = 0.
- Đơn chỉ gồm dòng tặng (tổng 0 đồng): **chưa cấp giờ**, chờ anh quyết.
- Dòng tặng không có tiền chia về, nên giờ của ghi danh dòng tặng không có giá ghi nhận doanh thu; báo cáo doanh thu (R-BC-04) xếp các giờ này vào «giờ chưa có giá».
- Xem trước chia tiền của phiếu thu hiện giờ cấp 0 cho dòng tặng (giờ của dòng này cấp khi đơn thu đủ).

## Hàm đổi
`save_discount_policy`, `price_apply_discounts`, `price_line`, `save_quotation`, `send_quotation`, `order_write_priced_lines`, `order_add_priced_line`, `create_order_from_upsale_ticket`, `edit_order`, `tg_sales_line_snapshot`, `get_quotation`, `get_order`, `order_approve_core`, `enrollment_target_hours`, `create_enrollments_for_order`.
