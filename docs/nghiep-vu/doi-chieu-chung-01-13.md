# Đối chiếu nhóm CHUNG-01..13 (màn có, không có khung canvas Đào tạo/Bán hàng) — 23/11/2026

Thẻ A-23-07 (Code A). Cách làm: màn đăng nhập và xác thực có khung trong gói P1 `design/hmt-p0-p2/artboards/DN01..DN10` (bản v4, 18/10) nên so chữ và luồng từng khung với code (grep chuỗi chữ); các màn còn lại so với `docs/design/ban-do-man-hinh.md`, spec 04 (R-HT-01..03) và khuôn chung. Chỉ đọc mã, chưa chụp màn hình.

| Mã | Màn | Khung / căn cứ | Kết quả | Ghi chú |
|---|---|---|---|---|
| CHUNG-01 | Đăng nhập nhân viên, giáo viên | DN01_pc/mb_ok, _err | Đúng | Đủ chữ: «Dành cho nhân viên, giáo viên và trợ giảng», lỗi «Email hoặc mật khẩu không đúng…», Quên mật khẩu?, «Học sinh? Đăng nhập bằng mã học sinh», dòng hỗ trợ ở khung chung |
| CHUNG-02 | Xác thực hai bước (nhập mã) | DN03_*_code, _code_err | Đúng | Không có mã dự phòng; «Mất điện thoại? Liên hệ quản trị viên…», «Bắt buộc với tài khoản Admin và Kế toán», liên kết đăng nhập tài khoản khác |
| CHUNG-03 | Thiết lập hai bước lần đầu | DN04_*_s1, _s2 | Đúng | 2 bước, nút cuối «Hoàn tất», có «Không quét được? Nhập khoá này…» |
| CHUNG-04 | Quên mật khẩu | DN05_*_form | Đúng | Chỉ hướng dẫn liên hệ quản trị viên, nút Quay lại đăng nhập |
| CHUNG-06 | Đăng nhập học sinh | DN02_*_ok, _err | Đúng | «Chào em», «Vào học», câu nhờ thầy cô/CSKH |
| CHUNG-09 | Hết phiên làm việc | DN09_*_end | Đúng | Có «Phiên làm việc đã hết», số phút theo vai trò, «Đăng nhập lại xong sẽ quay về đúng trang» |
| CHUNG-10 | Khung ứng dụng CRM | K1/K01 (P0), R-HT-01, R-HT-02 | Đúng (theo luật) | Menu từ ma trận quyền, ô «Cơ sở đang xem» có «Tất cả cơ sở» và các cơ sở dạy học, thu gọn menu, đường dẫn |
| CHUNG-11 | Tìm kiếm toàn hệ thống | S03-15 | Đúng (theo luật) | Gọi `app.search_records` bằng quyền người gọi; tìm tên, SĐT, mã mới, mã cũ; điện thoại thu thành biểu tượng |
| CHUNG-12 | Trung tâm thông báo | R-CS-08 và các luật liên quan | Đúng (theo luật) | Chuông có số chưa đọc, lọc Tất cả/Chưa đọc, Đánh dấu tất cả đã đọc, bấm mở bản ghi; chỉ thấy của mình (RLS) |
| CHUNG-13 | Hồ sơ cá nhân | S03-05, chốt 12/10 | Đúng (theo luật) | Đổi mật khẩu, thiết bị hai bước (thêm/gỡ, tối đa 2, vai trò bắt hai bước giữ ít nhất một thiết bị) |

**Lệch:** không có lệch cần sửa.

**Ghi nhận cho Chat (không sửa):** số «tối đa 2 thiết bị hai bước» đang là hằng `MAX_TOTP_DEVICES = 2` ở `src/lib/auth/mfa.ts`. Luật chốt 12/10 nên không trái; nếu muốn đưa thành tham số cài đặt thì mở thẻ riêng (cần migration).

**Chưa kiểm:** ảnh chụp cỡ điện thoại và e2e từng màn (do Tester/CI). CHUNG-05, 07, 08 không thuộc phạm vi thẻ.
