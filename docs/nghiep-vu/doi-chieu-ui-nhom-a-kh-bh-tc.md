# Rà UI «nhóm A» (tiếp): Khách hàng, Bán hàng, Thu chi, Ghi danh, Tái tục (Code F, 19/11/2026; thẻ F68)

Cách làm như `doi-chieu-ui-nhom-a-tuyen-sinh-qt.md`: so chữ khung canvas với `src/`, bỏ chữ khung chung, tên người, dữ liệu mẫu. Chưa so ảnh bản dựng; Tester xem lại «Gần đúng».

| Màn | Chỗ canvas có mà code chưa thấy | Kết quả |
|---|---|---|
| KH-01 Phụ huynh (danh sách) | trạng thái trống «Chưa có phụ huynh nào», «Hồ sơ phụ huynh tự sinh khi có cơ hội mới ở phân hệ Tuyển sinh» | **gần đúng**: khác chữ trạng thái trống |
| KH-02 Phụ huynh (bản ghi) | «Người thu», «Đơn đăng ký và ghi danh», nhãn «tự tính từ lớp chính của các con» | **gần đúng** |
| KH-03 Tạo phụ huynh | «Bắt buộc nhập họ tên», «Bắt buộc nhập số điện thoại», «Số điện thoại đã có ở phụ huynh khác:» | **gần đúng**: câu báo lỗi và báo trùng khác chữ |
| KH-04 Học sinh (danh sách) | trạng thái trống «Hồ sơ học sinh tự sinh khi có phiếu kiểm tra đầu vào hoặc đơn được duyệt» | **gần đúng** |
| KH-05, KH-06, KH-07 Học sinh (bản ghi, sửa, chặn) | khối «Tài khoản app học sinh» (Cấp tài khoản, Đặt lại mật khẩu, Khoá tài khoản; canvas ghi «làm ở phân hệ sau»), «Ticket chăm sóc định kỳ» | **gần đúng**: khối tài khoản chờ QT-13 (chưa có màn) |
| BH-02 Báo giá (bản ghi) | chữ chính sách ưu đãi («Loại: % chiết khấu · cần duyệt») là dữ liệu mẫu; không thiếu nhãn rõ | **gần đúng** (cần xem ảnh) |
| BH-03 Bản in báo giá | «Khổ giấy», «Xem trạng thái» (khung chú thích của canvas) | **gần đúng** |
| BH-09 Cho học trước, đóng tiền sau | chỉ khác nhật ký mẫu | khớp |
| TC-03 Tạo phiếu thu từ đơn | chỉ khác nhật ký và tên ưu đãi mẫu | **gần đúng** |
| TC-07 Bản in phiếu thu | «Tiền về các dòng đơn», «Khổ giấy» | **gần đúng** |
| TC-10 Phiếu chi (danh sách) | không thiếu chữ | khớp |
| TC-11 Phiếu chi (bản ghi) | «Thông tin phiếu và bảng tính hoàn», «Số tiền hoàn (tự tính, khoá)», «Ngày chi dự kiến», «Còn lại sau khi trừ giờ đã học», «Trình kế toán duyệt.» | **gần đúng**: có «Số tiền hoàn», thiếu bốn nhãn còn lại |
| TC-17 Quản lý duyệt phiếu thu | như TC-02: «Dồn trước», «Thành tiền (đ)», «Admin không duyệt ở bước quản lý.», «Phiếu chờ bạn duyệt. Kiểm tra rồi bấm Duyệt…» | **gần đúng** |
| GD-05 Điều chỉnh giờ | «Trừ buổi», «Nhóm đề nghị» (như GD-02) | **gần đúng** |
| TT-02 Phiếu tái tục (bản ghi) | «Lần liên hệ gần nhất», «Đã mua gần nhất», «Chưa có lịch sử liên hệ.», «Chưa có báo giá hay đơn tái tục. Tạo từ các nút phía trên.» | **gần đúng**: thiếu hai nhãn và hai câu trạng thái trống |
| TT-03 Tạo phiếu tái tục | «Đối chiếu theo tháng», «Đổi tháng bằng bộ lọc Campaign. Cơ sở: tất cả.» | **gần đúng** |

Chưa rà: CH-05, CH-06 (khung gói 1aab không tách được chữ bằng cách này, cần xem ảnh). Nhóm B (không có khung canvas) rà ở thẻ sau.
