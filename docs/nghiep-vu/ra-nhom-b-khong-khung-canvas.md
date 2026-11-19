# Rà «nhóm B» (có màn, KHÔNG có khung canvas): kiểm theo luật và khuôn chung (Code F, 19/11/2026; thẻ F69)

Nguồn: `HOP-THU/MAN-CHUA-KIEM.md` nhóm B (40 màn). Không có khung canvas để so, nên kiểm được ba điều bằng máy; **chưa phải so với thiết kế**, nên bảng màn hình KHÔNG đổi cột «Đúng canvas» cho nhóm này (vẫn «chưa kiểm»).

1. **Không dùng hộp thoại của trình duyệt** (`alert`, `confirm`, `prompt`): quét toàn `src/`, không thấy chỗ nào. Đạt.
2. **Dùng khuôn chung**: danh sách dùng `ListScreen` (K03), bản ghi dùng `RecordDetail` (K06), hộp thoại dùng `FormDialog` hoặc hộp xác nhận chung, trạng thái dùng `StateView`. Màn đăng nhập, xác thực, khung ứng dụng (CHUNG-01..04, 06, 09..13, 16, 17, 24, 25) không thuộc K03 hay K06 nên không áp dụng. Các màn Quản trị và Cấu hình danh sách (QT-04..06, 10..12, 14, CH-08, TC-14, CS-05, BC-01) đều là trang tuyến riêng dựng từ khuôn danh sách hoặc bảng chung (không tự chế kiểu).
3. **Có bài Playwright nhắc mã màn**: thiếu ở các màn sau (rủi ro hồi quy, nên bổ sung khi rảnh): CHUNG-11 (tìm toàn hệ thống; các bài khác dùng ô tìm này nhưng không có bài riêng), CHUNG-12 (thông báo), CHUNG-20 (xoá nhầm), CHUNG-25 (chọn cổng), CHUNG-26 (xác nhận chung), BH-10 (huỷ đơn), TC-06 (huỷ phiếu thu), CS-04 (tạo ticket từ ghi danh), CS-05 (hoàn tiền), CS-09 (bảo lưu), CS-11 (đổi lịch), BC-01 (tổng quan Ban giám đốc).

## Việc cho lane khác
- Tester: so các màn nhóm B bằng ảnh bản dựng với luật (`docs/spec/04`) và khuôn chung K03/K06; ghi vào bảng.
- Bài e2e còn thiếu cho 12 màn ở mục 3 (lane giữ màn).
