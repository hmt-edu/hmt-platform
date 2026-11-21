# Group By «Người lập», «Sale», «Hình thức» (migration 604)

Thư Chat 05:18 (21/11/2026), theo canvas 9933 (`BH01`, `BH06`, `TC10` có nhóm này). Rà lại `docs/nghiep-vu/doi-chieu-group-by.md`: **TC-08 «Ngày» và TC-13 «Sale», «Tình trạng» đã có từ migration 435** (bảng rà ngày 21/11 02:36 ghi nhầm vì chỉ đọc nhãn đầu của cấu hình); chỉ ba màn dưới đây thiếu.

| Màn | Trường nhóm mới | Hàm đếm | Bộ lọc mở nhóm | Nhãn |
|---|---|---|---|---|
| BH-01 Báo giá | `creator` (người lập) | `app.quotation_group_counts` | `creator_id` (`list_quotations`) | tên người lập (`staff_display_name`) |
| BH-06 Đơn hàng | `sale` (người lập đơn) | `app.order_group_counts` | `creator_id` (`list_orders`) | tên người lập |
| TC-10 Phiếu chi | `method` (hình thức chi, cột có từ migration 564) | `app.voucher_group_counts` | `payment_method` mảng (`list_payment_vouchers`) | tên hình thức (PAYMENT_METHOD) |

Ba hàm đếm cũng nhận các bộ lọc mới để số đếm khớp danh sách. Giữ nguyên quyền, phạm vi cơ sở, hai cấp tối đa (Đ35). Chỉ đọc, không đổi bảng, không thêm chỉ mục.
Bài pgTAP `604_c95_group_by_nguoi_lap_sale_hinh_thuc.test.sql`: đếm từng nhóm, nhãn, mở nhóm bằng bộ lọc, số đếm khớp danh sách, chặn trường của màn khác, giáo viên bị chặn. Hai bài cũ 432 (đơn hàng) và 436 (phiếu chi) từng dùng `sale` và `method` làm ví dụ trường bị chặn nên đổi sang `creator`.
