# Mã luật S02-*, S03-* dùng trong bản đồ màn hình

Bản đồ màn hình dùng hai nhóm mã này để trỏ về luật chưa có mã R-* trong spec 04.

- `S02-*`: các luật trong `docs/spec/02-chuan-ma-va-danh-muc.md`. `S02-TT-HS` là mục "Tình trạng" (học sinh); `S02-XL-1…9` là 9 điều của mục "Luật ghi danh và xếp lớp", đúng thứ tự.
- `S03-*`: các yêu cầu trong `docs/spec/03-dac-ta-giai-doan-0.md` (đăng nhập, phân quyền, nền dữ liệu, cấu hình) và các quyết định bảo mật của bước 3.

| Mã | Nội dung | Nguồn |
|---|---|---|
| S02-TT-HS | Tình trạng học sinh: Tiềm năng, Đang học, Bảo lưu, Dừng học | spec 02 |
| S02-XL-1 | Mỗi lần mua: một ghi danh, một quỹ giờ | spec 02 |
| S02-XL-2 | Ghi danh có dòng xếp lớp (lớp, ngày vào, ngày rời, tình trạng) | spec 02 |
| S02-XL-3 | Toán khối 7+ lớp chung: gợi ý một lớp DAI + một lớp HINH; một lớp thì cảnh báo | spec 02 |
| S02-XL-4 | Đổi lớp Hình: đóng dòng Hình, mở dòng mới; Đại giữ nguyên | spec 02 |
| S02-XL-5 | Bảo lưu, dừng, hết giờ, hoàn phí thao tác ở cấp ghi danh | spec 02 |
| S02-XL-6 | Buổi Done ở lớp nào cũng trừ cùng quỹ; giờ Đại/Hình xem trong báo cáo | spec 02 |
| S02-XL-7 | Dự báo ngày hết giờ cộng lịch mọi lớp đang xếp | spec 02 |
| S02-XL-8 | Hợp lệ khi xếp: đúng môn, loại lớp, cơ sở, không trùng giờ | spec 02 |
| S02-XL-9 | Lớp riêng khối 7+ giữ một lớp TOAN | spec 02 |
| S03-01 | Đăng nhập email + mật khẩu (NV, GV, TG) | spec 03 / bước 3 |
| S03-02 | Học sinh đăng nhập mã HS, đổi mật khẩu lần đầu | spec 03 / bước 3 |
| S03-03 | Khoá tài khoản thay vì xoá | spec 03 / bước 3 |
| S03-04 | Quên mật khẩu: NV tự đặt lại qua email; HS nhờ CSKH | spec 03 / bước 3 |
| S03-05 | Hai bước bắt buộc cho Admin, Kế toán | spec 03 / bước 3 |
| S03-06 | Menu theo quyền | spec 03 / bước 3 |
| S03-07 | Ma trận quyền sửa trên màn quản trị, có nhật ký | spec 03 / bước 3 |
| S03-08 | Danh mục: thêm, đổi tên, thứ tự, Ngừng | spec 03 / bước 3 |
| S03-09 | Tham số Cài đặt: kiểu, đơn vị, khoảng, giải thích, nhật ký, ghi đè theo cơ sở | spec 03 / bước 3 |
| S03-10 | Cấu hình có hiệu lực (bảng giá, gói, chiết khấu, khung, rubric, ma trận quyền) | spec 03 / bước 3 |
| S03-11 | Công tắc tính năng theo cơ sở | spec 03 / bước 3 |
| S03-12 | Nhật ký thao tác xem được | spec 03 / bước 3 |
| S03-13 | Ghi chú trao đổi dùng chung mọi bản ghi | spec 03 / bước 3 |
| S03-14 | Admin xoá bản ghi nhập nhầm, có nhật ký | spec 03 / bước 3 |
| S03-15 | Mã cũ tìm kiếm được | spec 03 / bước 3 |
| S03-16 | Mỗi bản ghi có link riêng; không quyền thì báo rõ | spec 03 / bước 3 |
| S03-17 | Thói quen cũ: thanh trạng thái, nút liên kết, ghi chú + lịch sử, lọc/nhóm/yêu thích/kanban/lịch | spec 03 / bước 3 |
| S03-18 | Tạm khoá sau nhiều lần sai, thông báo lỗi chung chung | spec 03 / bước 3 |
| S03-19 | Tự đăng xuất khi không dùng theo vai trò | spec 03 / bước 3 |
| S03-20 | Đổi vai trò/cơ sở thu hồi phiên; bảo vệ admin cuối cùng | spec 03 / bước 3 |
| S03-21 | Xuất file có nhật ký | spec 03 / bước 3 |
| S03-22 | Trưởng cơ sở không duyệt khoản tiền | spec 03 / bước 3 |
| S03-23 | NV thuộc một cơ sở; Admin/Kế toán chọn cơ sở xem | spec 03 / bước 3 |
| S03-24 | Hội sở CS3 không có phòng, lớp, học sinh | spec 03 / bước 3 |
