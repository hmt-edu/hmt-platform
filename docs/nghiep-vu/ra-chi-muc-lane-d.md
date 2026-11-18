# Rà chỉ mục các bảng do lane D viết (thẻ D32)

19/11/2026. Quét `pg_constraint` và `pg_index` trên DB local sau `db:reset` cho bảy bảng: `refund_request`, `payment_voucher`, `enrollment_stop`, `enrollment_hold`, `class_transfer`, `customer_balance_entry`, `money_in`. Không có bảng mới nào trong migration 450 đến 499 do lane D viết (chỉ đổi hàm, chính sách, thêm cột `money_in.balance_entry_id` đã có chỉ mục duy nhất một phần `money_in_balance_entry_uq`).

| Nhóm khoá ngoại | Kết quả | Xử lý |
| --- | --- | --- |
| `branch_id`, `parent_id`, `student_id`, `enrollment_id`, `refund_request_id`, `receipt_id`, `order_id`, `reversal_of`, `extends_hold_id`, `from/to_class_id`, `from/to_branch_id`, `balance_entry_id` | Có chỉ mục | Không đổi |
| `money_in.opening_debt_student_id` | **Thiếu** | Migration 468: chỉ mục một phần `money_in_opening_student_idx` |
| `(reason_catalog, reason_code)` tới `catalog_item` ở `refund_request`, `enrollment_stop`, `enrollment_hold`, `class_transfer`, `money_in` | Không có chỉ mục | **Không thêm**: danh mục không xoá, không đổi mã (chỉ Ngừng), nên kiểm khoá ngược khi xoá không xảy ra; thêm chỉ mục chỉ làm chậm ghi |

Cột lọc, sắp xếp của danh sách (cơ sở, tình trạng, ngày lập; phụ huynh; ghi danh) đã có chỉ mục từ migration 217, 231, 232, 215, 210 (xem chú thích lý do trong từng migration). EXPLAIN trên seed lớn đã dán ở #101 (số dư, phiếu chi): đều dưới 150 ms.
