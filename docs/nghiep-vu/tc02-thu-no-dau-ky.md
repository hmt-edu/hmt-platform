# TC-02 Thu nợ đầu kỳ, phần DB (migration 251)

Luật R-V2-15: phiếu thu **không cần đơn**; CSKH tạo, **Kế toán duyệt**, không qua quản lý trực tiếp; số tiền không vượt nợ đầu kỳ còn lại của học sinh; duyệt xong ghi khoản tiền vào và giảm nợ đầu kỳ. R-V2-32: nợ đầu kỳ ở sổ số dư khách hàng (`customer_balance_entry`, `DAU_KY_CONG_NO`, số âm). R-HT-01: Admin không duyệt tiền. R-TIEN-26: hoàn tác khoản thu cộng lại nợ.
**Cờ tắt mặc định:** tham số `opening_debt_receipt_enabled` (BOOL, ghi đè theo cơ sở, nhóm Bán hàng). Ngày 17/11 chỉ nạp giờ (Q-227); chỉ bật khi chủ dự án chốt nạp công nợ.

## Phương án đã chọn (an toàn nhất, Chat đổi được)
Cho `receipt.order_id` và `money_in.order_id` **rỗng**, kèm `opening_debt_student_id`; ràng buộc `receipt_kind_check` và `money_in_kind_check`: đúng MỘT trong hai (đơn hoặc học sinh nợ đầu kỳ). **Không sửa** `create_receipt`, `submit_receipt`, `approve_receipt_accounting`: ràng buộc khiến các hàm cũ không thể tạo khoản tiền rỗng đơn. `cancel_receipt`, `reject_receipt` không đụng tới đơn nên dùng chung. Phương án thay thế (bảng phiếu riêng) bị bỏ vì nhân đôi luồng duyệt, mã PT và sổ KTV.

## Hàm
| Hàm | Ai | Việc |
| --- | --- | --- |
| `opening_debt_remaining(học sinh, trừ phiếu)` | nội bộ | Nợ còn lại = nợ trong sổ số dư trừ các phiếu đang chờ (Nháp, Đã gửi, Chờ kế toán). |
| `create_opening_debt_receipt(học sinh, dữ liệu)` | Phiếu thu · Tạo (CSKH, Sale, Kế toán, Trưởng cơ sở) | Phiếu Nháp không đơn; chặn vượt nợ (`HMT_SO_TIEN_VUOT`), số tiền sai, thiếu hình thức. |
| `submit_opening_debt_receipt(phiếu)` | Phiếu thu · Tạo | Nháp → Chờ kế toán thẳng, không bước quản lý; kiểm lại nợ. |
| `approve_opening_debt_receipt(phiếu)` | Kế toán · Duyệt (Admin không) | Một giao dịch: khoản KTV không đơn, dòng `THU_NO_DAU_KY` (dương) vào sổ số dư, phiếu Đã duyệt. |
| `reverse_money_in` (sửa) | Kế toán | Khoản không đơn: cộng lại nợ (`DAO_THU_NO_DAU_KY`, âm), không tính giờ. |
| `list_money_in` (sửa) | như cũ | Nối trái đơn; khoản nợ đầu kỳ có `order_code` rỗng. |

Giao diện TC-08: cột «Đơn hàng» hiện nhãn «Nợ đầu kỳ» khi không có đơn.
**Chưa làm (PR giao diện sau):** 19 khung `TC02_no_dau_ky_*` ở phiếu thu (tạo, chờ kế toán, đã duyệt, lỗi vượt nợ…), nút «Thu nợ đầu kỳ» ở học sinh. **Câu hỏi cho Chat:** khoá theo học sinh (đang làm) hay theo phụ huynh.
