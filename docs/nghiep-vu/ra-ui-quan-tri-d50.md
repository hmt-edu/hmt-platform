# Rà UI/UX nhóm Quản trị và Cấu hình so với canvas dc47 (thẻ D50, 19/11/2026)

Cách rà: so cột bảng, nhãn và bố cục trong code với khung canvas `design/hmt-canvas-dc47/` (chữ trích từ khung) và `docs/nghiep-vu/doi-chieu-canvas-quan-tri-v2.md`. Rà đợt 1 (19/11): QT-01/03, QT-07, QT-08, QT-09, CH-01, CH-03. Còn lại (QT-02, QT-18, CH-04, CH-09, QT-10, Vai trò) rà ở đợt sau.

| Màn | Canvas | Code | Kết luận |
|---|---|---|---|
| QT-08 Cơ sở và phòng | Mã phòng, Phòng, Sức chứa, Trạng thái, thao tác | giống | Khớp |
| CH-01 Gói bán | Mã gói, Tên gói, Loại gói, Môn, Khối, Trạng thái | giống | Khớp |
| CH-03 Bảng giá | Loại gói, Môn · Khối, Giá offline, Giá online (nhóm) | Mã gói, Tên gói, Giá offline, Giá online, nhóm Loại, Môn, Khối | Khác có chủ đích (anh chốt 06/11: bảng giá theo gói); không sửa |
| QT-07 Danh mục | Cột trái: tên, nhãn Mở/Khoá/Chỉ xem, tóm tắt; bảng mục: Mã (không đổi), Tên hiển thị, Thứ tự, Trạng thái | giống | Khớp |
| QT-01/03 Người dùng (danh sách) | Tên đăng nhập, Tên hiển thị, Vai trò, Cơ sở, Trạng thái | Mã, Tên, Email đăng nhập (hiện mặc định), Vai trò, Cơ sở, Trạng thái; thiếu Tên đăng nhập | **Lệch, đã sửa ở PR này**: thêm cột Tên đăng nhập (migration 475 trả `username`), Tên → Tên hiển thị, Email đăng nhập ẩn mặc định (cột chọn được) |
| QT-09 Tham số | Tham số, Giá trị hiện tại, Đơn vị, Khoảng cho phép, Ghi đè theo cơ sở | Tham số, Giá trị chung (đơn vị gộp trong giá trị), Khoảng cho phép, Ghi đè theo cơ sở | **Lệch, đã sửa ở PR đợt 2**: tách cột Đơn vị, đổi nhãn «Giá trị hiện tại». Nhóm theo `module` thay vì 8 nhóm spec 06: vênh đã ghi (làm theo DB) |
