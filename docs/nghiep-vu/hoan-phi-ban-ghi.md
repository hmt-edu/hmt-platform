# Hoàn phí và phiếu chi (migration 231)

Code D, 16/11/2026. Luật: R-TIEN-28, R-TIEN-31, R-TIEN-34, R-TIEN-01, R-CS-02, R-CS-07, R-V2-24. Tính tiền: `compute_refund` (migration 212, `hoan-phi.md`). Chưa có giao diện (PR sau). Công tắc `HOAN_PHI` theo cơ sở, **mặc định TẮT**.

**Bảng:** `app.refund_request` (yêu cầu, số tiền chụp lúc tạo) và `app.payment_voucher` (phiếu chi PC). Trạng thái yêu cầu: `NHAP` → `CHO_QL` → `CHO_KE_TOAN` → `DA_DUYET` → `DA_CHI`; nhánh `TU_CHOI` (bắt buộc lý do), `HUY`. Mỗi ghi danh một yêu cầu chưa xong. Đọc theo quyền Xem phiếu thu/phiếu chi (`RECEIPT`) và phạm vi.

| Hàm                                                                      | Ai                                                            |
| ------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `create_refund_request(ghi danh, loại, giờ hoàn, lý do, ghi chú, ticket)` | Ghi danh · Sửa                                                |
| `submit_refund_request(id)`, `cancel_refund_request(id)`                 | Ghi danh · Sửa                                                |
| `approve_refund_manager(id)`                                             | Ghi danh · Duyệt (Trưởng cơ sở); người tạo không tự duyệt (trừ Admin) |
| `approve_refund_accountant(id)` → id phiếu chi                           | Đối soát kế toán · Duyệt (chỉ Kế toán; Trưởng cơ sở không có)  |
| `pay_payment_voucher(id, ghi chú)`                                       | Đối soát kế toán · Duyệt                                      |
| `reject_refund_request(id, lý do)`                                       | Bước quản lý: Ghi danh · Duyệt; bước kế toán: Đối soát kế toán · Duyệt |

Khi kế toán duyệt: kiểm lại số liệu (lệch so với lúc tạo thì chặn `HMT_HOAN_PHI_SO_LIEU_DOI`, tạo yêu cầu mới); ghi sổ giờ ngược dấu (`DIEU_CHINH`, lý do «Khác» kèm ghi chú mã phiếu chi); hoàn toàn bộ thì ghi danh sang **Hoàn phí**, đóng dòng xếp lớp, huỷ giờ tặng còn lại; lập phiếu chi `PC-CS-YYMM-STT` (chờ chi). `pay_payment_voucher` đánh dấu đã chi.

Chưa làm: giữ thành số dư khách hàng khi dừng học (R-GD-16, R-TIEN-33) và Dừng học, Chuyển phí; khoá ngoại ticket (chỉ lưu mã `ticket_ref`); giao diện.

## Cấn số dư khách hàng vào đơn (TC-16, migration 454)

- `apply_customer_balance_to_order(đơn, số tiền)`: Kế toán · Duyệt (Admin không, R-HT-01). Đơn Đã duyệt; số tiền ≤ số dư hiện tại và ≤ phần còn thu của đơn; khoá đơn và phụ huynh. Ghi dòng sổ `DUNG_CHO_DON` (âm), sinh khoản tiền vào không phiếu thu (`money_in.balance_entry_id`), chia về dòng đơn, tạo ghi danh và cấp giờ như duyệt phiếu thu.
- Cờ `customer_balance_apply_enabled` (mặc định TẮT, theo cơ sở). Lỗi: `HMT_TINH_NANG_TAT`, `HMT_SAI_TRANG_THAI`, `HMT_SO_TIEN_SAI`, `HMT_SO_DU_KHONG_DU`, `HMT_SO_TIEN_VUOT`.
- `reverse_money_in` trả lại số dư (dòng `DIEU_CHINH` dương) khi đảo khoản cấn; `order_has_receipt` tính khoản cấn chưa đảo nên không huỷ đơn đã cấn.

## Đọc phiếu chi cho TC-10, TC-11 (migration 452)

| Hàm                                                                  | Việc                                                                                                  | Luật                 |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------- |
| `list_payment_vouchers(bộ lọc, số dòng, bỏ qua)`                     | Danh sách phiếu chi phân trang; lọc `q`, `status`, `branch_id`, `created_from`, `created_to`          | R-TIEN-34            |
| `get_payment_voucher(id)`                                            | Bản ghi phiếu chi, bảng tính hoàn chụp lúc tạo, ghi danh; `can_pay` cho nút ghi nhận đã chi           | R-TIEN-28, R-TIEN-34 |

Quyền xem: RECEIPT · XEM theo phạm vi (cơ sở mình hoặc toàn hệ thống). Phiếu ngoài phạm vi báo `HMT_KHONG_TIM_THAY`.

## Đọc số dư khách hàng cho TC-14 (migration 453)

Hàm `list_customer_balances(bộ lọc, số dòng, bỏ qua)` (mỗi phụ huynh một dòng, số dư = tổng sổ; lọc `q`, `branch_id`, `only_positive`) và `get_customer_balance_history(phụ huynh)` (số dư và các dòng sổ, mới nhất trước). Quyền xem: RECEIPT · XEM theo phạm vi (R-TIEN-33); ngoài phạm vi báo `HMT_KHONG_TIM_THAY`. «Cấn vào đơn mới» (TC-16) làm sau cùng Code C.
