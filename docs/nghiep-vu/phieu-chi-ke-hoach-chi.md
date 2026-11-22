# Phiếu chi: Hình thức chi, Tài khoản nhận, Ngày chi dự kiến (migration 581)

Anh Trường duyệt 20/11/2026 (Chat 20:38/20:44), theo canvas TC10, TC11:
- **Tài khoản nhận = chữ tự do** (`payout_account_note`): tài khoản của người nhận hoàn tiền; không dùng danh mục RECEIVING_ACCOUNT (tài khoản của trung tâm ở phiếu thu).
- **Ngày chi dự kiến chỉ CẢNH BÁO, không chặn chi** (`planned_on`): giao diện nhắc trong hộp «Ghi nhận đã chi» khi chưa tới ngày; máy chủ không chặn.
- Hình thức chi: dùng cột `payment_method_code` đã có (migration 564, danh mục PAYMENT_METHOD chung với phiếu thu).

| Hàm | Làm gì | Ai gọi | Luật |
|---|---|---|---|
| `app.set_payment_voucher_plan(phiếu, hình thức, tài khoản nhận, ngày dự kiến)` | Ghi ba trường trên phiếu **Chờ chi**; trống = xoá. Lỗi: `HMT_PHIEU_CHI_DA_CHI`, `HMT_HINH_THUC_KHONG_HOP_LE`, `HMT_TAI_KHOAN_NHAN_DAI` (quá 200 ký tự) | Đối soát kế toán · Duyệt theo cơ sở của phiếu | R-TIEN-34 |
| `app.pay_payment_voucher(...)` | Như 564; lúc chi không chọn hình thức thì **giữ hình thức đã ghi trước** | như trên | R-TIEN-34 |
| `app.list_payment_vouchers`, `app.get_payment_voucher` | Trả thêm `planned_on`, `payout_account_note` | người xem được phiếu chi theo phạm vi cơ sở | — |

Giao diện: bản ghi TC-11 hiện «Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến»; nút «Kế hoạch chi» (Kế toán, phiếu Chờ chi) mở hộp lưu ba trường; danh sách TC-10 có hai cột ẩn mặc định. Phiếu đã chi là chứng từ chốt, không sửa.
Bài pgTAP `581_c90_phieu_chi_tai_khoan_ngay_du_kien.test.sql`: ghi và đọc lại, các lỗi, chi trước ngày dự kiến vẫn được, giữ hình thức đã ghi, phiếu đã chi không sửa, Sale và Trưởng cơ sở khác bị chặn.

## Tài khoản nhận riêng tư (migration 617, D-23-05, 23/11/2026)

- **Nhật ký:** bảng phiếu chi dùng trigger audit riêng `app.tg_audit_payment_voucher`; khi cột `payout_account_note` đổi, nhật ký chỉ ghi «đã đổi» thay cho nội dung (cả khi xoá). Số tài khoản không nằm trong `audit_log`.
- **Ai thấy:** `list_payment_vouchers` và `get_payment_voucher` chỉ trả `payout_account_note` cho người có Đối soát kế toán · Duyệt; vai khác nhận `null` (các cột còn lại, kể cả ngày chi dự kiến, vẫn hiện). Đọc thẳng bảng cũng bị chặn bằng quyền theo cột cho `authenticated`.
- Chỉ lưu văn bản, không nối ngân hàng.
