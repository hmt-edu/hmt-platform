# Rà UI/UX nhóm Quản trị và Cấu hình so với canvas dc47 (thẻ D50, 19/11/2026)

Cách rà: so cột bảng, nhãn và bố cục trong code với khung canvas `design/hmt-canvas-dc47/` (chữ trích từ khung) và `docs/nghiep-vu/doi-chieu-canvas-quan-tri-v2.md`. Rà đợt 1 (19/11): QT-01/03, QT-07, QT-08, QT-09, CH-01, CH-03. Đợt 3 (19/11, cùng PR đợt 2): QT-18, CH-04, CH-09. QT-02, QT-04, QT-10: không có khung bảng để so (xem dòng cuối).

| Màn | Canvas | Code | Kết luận |
|---|---|---|---|
| QT-08 Cơ sở và phòng | Mã phòng, Phòng, Sức chứa, Trạng thái, thao tác | giống | Khớp |
| CH-01 Gói bán | Mã gói, Tên gói, Loại gói, Môn, Khối, Trạng thái | giống | Khớp |
| CH-03 Bảng giá | Loại gói, Môn · Khối, Giá offline, Giá online (nhóm) | Mã gói, Tên gói, Giá offline, Giá online, nhóm Loại, Môn, Khối | Khác có chủ đích (anh chốt 06/11: bảng giá theo gói); không sửa |
| QT-07 Danh mục | Cột trái: tên, nhãn Mở/Khoá/Chỉ xem, tóm tắt; bảng mục: Mã (không đổi), Tên hiển thị, Thứ tự, Trạng thái | giống | Khớp |
| QT-01/03 Người dùng (danh sách) | Tên đăng nhập, Tên hiển thị, Vai trò, Cơ sở, Trạng thái | Mã, Tên, Email đăng nhập (hiện mặc định), Vai trò, Cơ sở, Trạng thái; thiếu Tên đăng nhập | **Lệch, đã sửa ở PR này**: thêm cột Tên đăng nhập (migration 475 trả `username`), Tên → Tên hiển thị, Email đăng nhập ẩn mặc định (cột chọn được) |
| QT-09 Tham số | Tham số, Giá trị hiện tại, Đơn vị, Khoảng cho phép, Ghi đè theo cơ sở | Tham số, Giá trị chung (đơn vị gộp trong giá trị), Khoảng cho phép, Ghi đè theo cơ sở | **Lệch, đã sửa ở PR đợt 2**: tách cột Đơn vị, đổi nhãn «Giá trị hiện tại». Nhóm theo `module` thay vì 8 nhóm spec 06: vênh đã ghi (làm theo DB) |
| QT-18 Nhập dữ liệu | Thứ tự, Loại nạp, Mô tả, Cần có trước, Trạng thái, nút Nhập | giống (loại chưa có hàm nạp ghi «Sắp có») | Khớp |
| CH-09 Điều khoản | Đợt, Cách chia, Giá trị, Số ngày đến hạn | giống | Khớp |
| CH-04 Chiết khấu | Tên chính sách, Kiểu, **Giá trị**, Mức tối đa, Hiệu lực, Nhóm gói, Cơ sở, **Áp dụng cho** (Báo giá, Đơn, Phiếu thu), Cần duyệt, Trạng thái | Tên chính sách, Kiểu, Mức tối đa (gộp giá trị và «áp đúng mức»), Hiệu lực, Nhóm gói, Cơ sở, Cần duyệt, Trạng thái | **Lệch, chưa sửa, cần anh/Chat quyết**: (1) cột «Áp dụng cho» chưa có dữ liệu trong DB (cần migration thêm trường phạm vi áp dụng và thay đổi hàm lưu chính sách); (2) tách «Giá trị» và «Mức tối đa» cần chốt nghĩa hai cột khi chính sách «áp đúng mức» (`fixed_value`). Dừng mục này theo luật «thiếu dữ liệu thì báo», phần còn lại tiếp tục |
| QT-02 Hồ sơ người dùng, QT-04 Vai trò, QT-10 Công tắc | dc47 chỉ có khung hành động QT-02 (Đặt lại mật khẩu, đã làm #172); gói P2 chỉ có khung gộp «Cấu hình hệ thống» (Danh mục, Tham số, Công tắc); không có khung bảng Vai trò hay Công tắc (BAN-DO-VIEC ghi «Thiếu khung canvas») | Dựng từ khuôn K10 | Không rà được cột: **thiếu khung canvas**. Nếu Design vẽ thêm thì rà tiếp |
