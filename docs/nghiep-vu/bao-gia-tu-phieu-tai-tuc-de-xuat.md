# Báo giá từ phiếu tái tục (L7A): đề xuất làm (Code C, 18/11/2026, chờ Chat duyệt)

Căn cứ: Chat 13:55 («báo giá từ phiếu giống tạo đơn; nếu DB chưa có hàm tạo báo giá để gọi lại thì DỪNG, ghi lại»); R-GD-13 (tạo báo giá từ phiếu thì phiếu sang L7A); Đ187 (báo giá có đúng một gốc: cơ hội hoặc phiếu tái tục); canvas 9933 `TT02_l6` (nút «Tạo báo giá», «Tạo đơn»). Đơn từ phiếu đã làm ở #104 (migration 417, 418).

## Hiện trạng (đã kiểm DB)
- `app.quotation.opportunity_id` **not null**; `sales_order` đã có `renewal_ticket_id` và ràng buộc «đúng một gốc», báo giá thì chưa.
- `app.quotation_line` đã **chừa sẵn** `student_id` (cạnh `prospect_student_id`, ghi chú «cho báo giá từ phiếu tái tục», Đ84, Đ93).
- Không có hàm nào tạo báo giá mà không qua cơ hội: `save_quotation(p_id, p_opportunity_id, p_lines)` (migration 045) viết toàn bộ dòng theo em của cơ hội (`validate_line_student`), 42 chỗ trong migration 045 nhắc cơ hội hoặc em của cơ hội; còn `send_quotation`, `get_quotation`, `list_quotations`, `export_quotations`, `preview_quotation_lines`, `list_sellable_packages`, `assert_quotation_helper_access`, `create_order_from_quotation` (đọc cơ hội) và 22 tệp migration có nhắc `quotation`.

## Đề xuất: PR riêng «BH-02 gốc phiếu tái tục», mức CAO (tiền), dải migration 420 đến 429
1. **Bảng:** `quotation.opportunity_id` bỏ not null; thêm `renewal_ticket_id uuid`; ràng buộc `num_nonnulls(opportunity_id, renewal_ticket_id) = 1` (đúng như đơn hàng); chỉ mục `renewal_ticket_id`; `quotation_line` dòng gốc phiếu có `student_id`, không có `prospect_student_id` (ràng buộc có sẵn ở đơn: một trong hai).
2. **Hàm tạo mới, không sửa hàm cũ:** `app.create_quotation_from_upsale_ticket(phiếu, dòng)` giống `create_order_from_upsale_ticket` (417): kiểm hai quyền Báo giá · Tạo và Phiếu tái tục · Sửa, khoá phiếu, phiếu phải ở L6, học sinh và lớp từ phiếu, giá `price_line` ở máy chủ, một giao dịch, phiếu L6 → L7A. Tạo báo giá Nháp; **Gửi** dùng `send_quotation` hiện có sau khi sửa nhánh đọc cơ hội cho gốc phiếu.
3. **Sửa hàm đọc cho gốc phiếu (chỉ thêm nhánh, không đổi hành vi gốc cơ hội):** `send_quotation`, `get_quotation`, `list_quotations`, `export_quotations`, `create_order_from_quotation` (đơn từ báo giá của phiếu gắn `renewal_ticket_id` thay vì cơ hội; không đòi cơ hội ở L8, R-CRM-16 chỉ áp cho gốc cơ hội), `quotation_search_text`, RLS/chính sách xem nếu có đọc cơ hội.
4. **Móc giai đoạn:** báo giá Đã gửi thì phiếu ở L7A; tạo đơn từ báo giá thì L7B; báo giá Huỷ hoặc Từ chối thì phiếu về L6 (đối soát đêm `reconcile_upsale_orders` mở rộng; cộng nhật ký phiếu).
5. **Giao diện:** nút «Tạo báo giá» ở TT-02 (L6) mở hộp giống «Tạo đơn» (#104); màn BH-02 hiện gốc «Phiếu tái tục TTxxxxxx» thay cho cơ hội (khung BH02 vào từ tái tục ở canvas abea); tab «Báo giá và đơn» liệt kê báo giá.
6. **Kiểm thử:** pgTAP mỗi hàm sửa (gốc cơ hội vẫn y nguyên: chạy lại cả bộ bài báo giá, đơn), quyền từng bước, một giao dịch; Vitest hộp tạo; chạy lại toàn bộ pgTAP.

## Rủi ro và câu hỏi cho Chat
- Mức CAO, chạm 8 hàm báo giá đang chạy ổn. Để giảm rủi ro: mỗi hàm chỉ thêm nhánh `if renewal_ticket_id is not null`, bài pgTAP cũ giữ nguyên làm lưới an toàn.
- (a) Báo giá không bắt buộc (R-TIEN-01): có làm ngay không, hay để sau go-live? Đề xuất: sau; hiện đơn từ phiếu đã đủ cho nhu cầu tái tục nhanh.
- (b) Nếu làm: tách hai PR (DB và hàm, rồi giao diện) hay một? Đề xuất hai.
