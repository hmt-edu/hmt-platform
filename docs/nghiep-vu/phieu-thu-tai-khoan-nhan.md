# Phiếu thu: Tài khoản nhận (TC-17, TC-02; migration 582)

Anh Trường duyệt 20/11/2026 (Chat 20:38/20:44), theo canvas 9933 (`TC17_*`, `TC02_*`): khối «Nơi nhận tiền» hiện «Tài khoản nhận»; nhân viên lập phiếu **hoặc** Kế toán đều chọn được; **không bắt buộc**.

| Hàm | Làm gì | Ai gọi | Luật |
|---|---|---|---|
| `app.set_receipt_receiving_account(phiếu, mã)` | Ghi hoặc xoá tài khoản nhận (danh mục RECEIVING_ACCOUNT, mục còn dùng). Lỗi: `HMT_KHONG_TIM_THAY`, `HMT_KHONG_CO_QUYEN`, `HMT_PHIEU_THU_DA_KHOA`, `HMT_TAI_KHOAN_NHAN_KHONG_HOP_LE` | người lập khi phiếu **Nháp**; Kế toán, Admin (quyền Sửa phiếu thu toàn hệ thống) khi **Đã gửi** hoặc **Chờ kế toán** | R-HT-01 không đụng tới (không có Duyệt tiền) |
| `app.get_receipt(phiếu)` | Trả thêm `receiving_account_code`, `receiving_account` (tên) | người xem được phiếu theo phạm vi cơ sở | — |

Phiếu **Đã duyệt**: dùng màn Đối soát thu tiền TC-15 (`mark_receipts_bank_matched`, migration 478). Phiếu Huỷ không sửa.
Vì sao hàm riêng: không sửa `create_receipt`, `save_receipt`, `receipt_normalize` (lõi tiền vào); trường này không ảnh hưởng số tiền hay chia tiền. Giao diện bản ghi phiếu thu có ô chọn nhanh «Chọn tài khoản nhận» (lưu ngay khi chọn).
Canvas còn câu «Chỉ hiện tài khoản của cơ sở thu đã chọn»: danh mục RECEIVING_ACCOUNT chưa gắn cơ sở nên chưa lọc theo cơ sở; cần quyết định thêm cột cơ sở cho danh mục (xin Chat).
Bài pgTAP `582_c91_phieu_thu_tai_khoan_nhan.test.sql`: chọn, xoá, đọc lại, lỗi, Sale cơ sở khác bị chặn, người lập hết quyền sau khi gửi, Kế toán chọn được, phiếu Đã duyệt khoá.
