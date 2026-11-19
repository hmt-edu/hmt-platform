# Đề xuất 5 màn CRM còn thiếu và có luật, không cần khung canvas (Code F, 19/11/2026; thẻ F70)

Gửi Chat để anh Trường duyệt trước khi làm (CLAUDE.md: thay đổi lớn, anh OK mới code). Mọi màn dựng từ khuôn dùng chung (K03 danh sách, K06 bản ghi, K08 hộp thoại, K10 cấu hình), không có kiểu mới. Cả 5 chưa có bảng hay hàm trong DB (đã tìm trong `supabase/migrations`): mỗi màn cần migration và pgTAP đi kèm.

| Màn | Làm gì | Khuôn | Luật | Ai làm | Cỡ |
|---|---|---|---|---|---|
| **QT-13 Tài khoản học sinh** | Admin cấp tài khoản theo mã HS, in hoặc gửi mật khẩu tạm, đặt lại khi quên, khoá; cấp hàng loạt | K03 + hộp K08 | bản đồ màn hình QT-13 (chốt 12/10; bước 4, CS từ giai đoạn 4); không mang mật khẩu từ hệ thống cũ | Code F (cùng nhóm với QT-02 tạo người dùng, dùng Edge Function tạo tài khoản) | lớn: Edge Function (khoá service không vào giao diện), migration, pgTAP; mở khoá KH-05, KH-06 (khối «Tài khoản app học sinh») |
| **QT-15 Cấu hình người duyệt ticket theo nhóm con** | Ai duyệt từng nhóm con đề nghị, có ngày hiệu lực, xem lịch sử | K10 (như ma trận quyền) | R-CS-07, R-CS-11, R-V2-24 | Code B (giữ nghiệp vụ ticket) hoặc F | vừa: bảng cấu hình có hiệu lực + hàm đọc; cần thống nhất với bản ghi nghiệp vụ (việc duyệt nằm ở phiếu nghiệp vụ theo R-V2-24) nên **hỏi Chat: còn cần màn này không** |
| **QT-16 Giáo viên, trợ giảng (hồ sơ dạy)** | Mã GV/TG, môn dạy, khối, cơ sở thường dạy, tài khoản liên kết; Tạo, Sửa, Ngừng | K03 + K06 | R-LOP-08, R-LOP-10 (chọn giáo viên khi tạo lớp) | Code A (giữ Lớp) hoặc F | vừa: bảng hồ sơ dạy; hiện giáo viên chọn từ tài khoản người dùng có vai Giáo viên, chưa có môn, khối |
| **TS-12 Việc tuyển sinh hôm nay** | Bản đồ màn hình ghi rõ «gộp vào trang chủ theo vai trò K09b (CHUNG-14), không làm riêng» | không làm riêng | R-CRM-07 | không cần | đề xuất: đổi trạng thái thành «Gộp vào CHUNG-14» thay vì «Chưa có» |
| **KH-08 Lên khối đầu năm học** | Tăng khối cho học sinh đang học khi sang năm học mới; xem trước, loại trừ từng em, xác nhận | K08 (hộp xem trước) | không có luật chi tiết trong docs/spec (bản đồ màn hình để «—») | Code B (Khách hàng) | vừa; **thiếu luật**: em lớp 12 lên «tốt nghiệp» hay giữ khối; ghi nhật ký từng em; chạy một lần mỗi năm học. Cần anh chốt luật trước |

## Đề xuất thứ tự
1. TS-12: không làm, chỉ sửa trạng thái trong bảng (xong ở PR này nếu anh đồng ý).
2. QT-13 (mở khoá KH-05/06, cần cho go-live CS5 khi học sinh đăng nhập app).
3. QT-16, rồi QT-15 (sau khi Chat xác nhận còn cần), KH-08 (sau khi có luật).

## Nhầm lẫn đã sửa trong bảng màn hình (cùng PR)
Script không thấy mã ở đầu file nên báo «chưa có» hoặc «chỉ có DB»: CHUNG-07 (đổi mật khẩu bắt buộc: `PasswordPages.tsx`), CHUNG-18 (Xuất: nút «Xuất» ở các danh sách), CHUNG-19 (Favorites: `list/Favorites.tsx`), CHUNG-22 (Ghi chú và hoạt động: `ui/Chatter.tsx`), TS-14 (cảnh báo trùng: `ui/Dialogs.tsx`), GV-06 (`SessionContentPage.tsx`), GV-07 (`ReviewGradingPage.tsx`), LOP-04, LOP-07, LOP-10 (đã gộp vào LOP-03). Số mới: 197 màn, **157 có màn**, 10 chỉ có DB, 30 chưa có (HT 9, PH 5 để sau go-live; CRM 14, Giáo viên 2, trong đó 5 màn có đề xuất ở trên).
