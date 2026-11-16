# TC-02 Thu nợ đầu kỳ, phần DB (migration 251)

Luật R-V2-15: phiếu thu **không cần đơn**; CSKH tạo, **Kế toán duyệt**, không qua quản lý trực tiếp; số tiền không vượt nợ đầu kỳ còn lại của **phụ huynh** (Chat 15:28 (b): khoá theo phụ huynh, học sinh chỉ là ghi chú tham chiếu); duyệt xong ghi khoản tiền vào và giảm nợ đầu kỳ. R-V2-32: nợ đầu kỳ ở sổ số dư khách hàng (`customer_balance_entry`, `DAU_KY_CONG_NO`, số âm). R-HT-01: Admin không duyệt tiền. R-TIEN-26: hoàn tác khoản thu cộng lại nợ.
**Cờ tắt mặc định:** tham số `opening_debt_receipt_enabled` (BOOL, ghi đè theo cơ sở, nhóm Bán hàng). Ngày 17/11 chỉ nạp giờ (Q-227); chỉ bật khi chủ dự án chốt nạp công nợ.

## Phương án đã chọn (an toàn nhất, Chat đổi được)
Cho `receipt.order_id` và `money_in.order_id` **rỗng**, kèm cột `is_opening_debt` và `opening_debt_student_id` (ghi chú tham chiếu tuỳ chọn); ràng buộc `receipt_kind_check` và `money_in_kind_check`: đúng MỘT trong hai (có đơn, hoặc `is_opening_debt`). Chat đã chốt phương án này ở thư 15:28 (a). **Không sửa** `create_receipt`, `submit_receipt`, `approve_receipt_accounting`: ràng buộc khiến các hàm cũ không thể tạo khoản tiền rỗng đơn. `cancel_receipt`, `reject_receipt` không đụng tới đơn nên dùng chung. Phương án thay thế (bảng phiếu riêng) bị bỏ vì nhân đôi luồng duyệt, mã PT và sổ KTV.

## Hàm
| Hàm | Ai | Việc |
| --- | --- | --- |
| `opening_debt_remaining(phụ huynh, trừ phiếu)` | nội bộ | Nợ còn lại của phụ huynh = nợ trong sổ số dư trừ các phiếu đang chờ (Nháp, Đã gửi, Chờ kế toán). |
| `create_opening_debt_receipt(phụ huynh, dữ liệu)` | Phiếu thu · Tạo (CSKH, Sale, Kế toán, Trưởng cơ sở) | Phiếu Nháp không đơn; `student_id` tuỳ chọn (phải là con của phụ huynh, `HMT_HOC_SINH_SAI`); chặn vượt nợ (`HMT_SO_TIEN_VUOT`), số tiền sai, thiếu hình thức. |
| `submit_opening_debt_receipt(phiếu)` | Phiếu thu · Tạo | Nháp → Chờ kế toán thẳng, không bước quản lý; kiểm lại nợ. |
| `approve_opening_debt_receipt(phiếu)` | Kế toán · Duyệt (Admin không) | Một giao dịch: khoản KTV không đơn, dòng `THU_NO_DAU_KY` (dương) vào sổ số dư, phiếu Đã duyệt. |
| `reverse_money_in` (sửa) | Kế toán | Khoản không đơn: cộng lại nợ (`DAO_THU_NO_DAU_KY`, âm), không tính giờ. |
| `list_money_in` (sửa) | như cũ | Nối trái đơn; khoản nợ đầu kỳ có `order_code` rỗng. |

Giao diện TC-08: cột «Đơn hàng» hiện nhãn «Nợ đầu kỳ» khi không có đơn.
## Kiểm kê chỗ giả định `order_id` không rỗng và cách sửa (migration 252)
Theo thư Chat 15:28 (a): kiểm kê MỌI hàm, view đang giả định phiếu thu hoặc khoản tiền vào luôn có đơn (bản mới nhất mỗi hàm). **5 chỗ** phải xử lý, mỗi chỗ đúng một nhánh, thân giữ nguyên bản cũ:
| Hàm (bản mới nhất) | Vấn đề nếu không sửa | Cách sửa ở 252 |
| --- | --- | --- |
| `save_receipt` (076) | chuẩn hoá theo đơn rỗng | phiếu nợ đầu kỳ chuyển sang `save_opening_debt_receipt` (hàm mới, cùng luật tạo) |
| `submit_receipt` (083) | đưa nhầm vào luồng quản lý | chuyển sang `submit_opening_debt_receipt`, trả `status = CHO_KE_TOAN` |
| `approve_receipt_accounting` (131) | ràng buộc chặn nhưng báo lỗi thô | chuyển sang `approve_opening_debt_receipt` |
| `list_receipts` (083) | nối trong đơn: phiếu biến mất khỏi danh sách | nối TRÁI, thêm cờ `is_opening_debt` |
| `get_receipt` (083) | màn bản ghi vỡ với đơn rỗng | `order = null`, `payment = {opening_debt_remaining}`, thêm `is_opening_debt`, `opening_student` |
Không ảnh hưởng (đã đọc thân hàm): `cancel_receipt`, `reject_receipt`, `approve_receipt_manager`, `receipt_search_text` (coalesce), `order_paid_amount`, `order_receivable`, `sync_enrollment_hours`, `enrollment_target_hours`, `create_enrollments_for_order`, `compute_refund`, báo cáo 211 (tổng `money_in` theo ngày: khoản nợ đầu kỳ tính là tiền thu), view 214 (theo allocation), `get_parent` (117). Giao diện: kiểu `ReceiptRecord`, `ReceiptRow` và các link «Đơn hàng» ở màn Phiếu thu còn giả định có đơn (làm ở PR giao diện); TC-08 đã sửa.
Vì các hàm cũ chuyển sang nhánh nợ đầu kỳ, giao diện dùng chung `save_receipt`, `submit_receipt`, `approve_receipt_accounting` cho cả hai loại phiếu.
**Chưa làm (PR giao diện sau):** 19 khung `TC02_no_dau_ky_*` ở phiếu thu (tạo, chờ kế toán, đã duyệt, lỗi vượt nợ…), nút «Thu nợ đầu kỳ» ở phụ huynh.
