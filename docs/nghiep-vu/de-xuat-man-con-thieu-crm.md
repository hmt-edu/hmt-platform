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

## Cập nhật 19/11 23:05 (anh Trường duyệt)

- TS-12: đổi trạng thái thành «Gộp vào CHUNG-14» (không làm riêng).
- QT-13: làm (Code F, PR riêng, rủi ro CAO).
- KH-08: **chưa làm vì thiếu luật.** Sáu câu hỏi gửi anh:
  1. Ai được chạy việc «Lên khối»: chỉ Admin, hay cả Trưởng cơ sở cho cơ sở của mình?
  2. Chạy khi nào: một lần cố định mỗi năm (ngày nào), hay anh bấm khi sang năm học mới (theo danh mục năm học)?
  3. Khối nào lên khối nào: mỗi em tăng một khối (ví dụ 6 lên 7)? Em lớp 12 thì chuyển «Đã tốt nghiệp» hay giữ nguyên?
  4. Em đang bảo lưu, đã dừng học hoặc nghỉ: có lên khối không, hay bỏ qua?
  5. Xem trước: có hiện danh sách từng em (khối cũ, khối mới) để bỏ tick loại trừ trước khi xác nhận không? Em học vượt cấp hoặc học lại thì sửa tay thế nào?
  6. Hoàn tác: sau khi xác nhận có cho hoàn tác cả đợt (trong bao lâu) không, hay chỉ sửa khối từng em? Ghi nhật ký theo từng em hay một dòng cho cả đợt?

## LOP-02 / LOP-03: câu hỏi quyết định DB (Code A, 20/11/2026, để Chat hỏi anh Trường)

Hiện trạng: nhóm lớp đã có (bảng `app.class_group`, cột `app.class.group_id`, luật R-LOP-14 đã CHỐT). LOP-02 đã hiện «Cùng nhóm» và «Lớp còn lại của nhóm» (migration 310). Canvas 9933 (`LOP03_tao`, `LOP03_sua`, `LOP02_*`) còn bốn chỗ chưa có trong code. Chi tiết đề xuất cũ: `docs/spec/de-xuat-hinh-thuc-hoc-to-chuc-lop.md`.

| # | Câu hỏi | Lựa chọn | Khuyến nghị | Hệ quả |
|---|---|---|---|---|
| 1 | Ô «Tổ chức lớp» (Học chung, Học riêng) trùng ý Phân loại «Lớp riêng»? | A. Bỏ ô, hiện chữ tự suy từ Phân loại (Lớp riêng = Học riêng, còn lại = Học chung). B. Giữ thành cột riêng, tự nhập. | **A** | A: không migration, không mâu thuẫn «Cơ bản + Học riêng». B: thêm cột, phải nêu quan hệ với Phân loại. |
| 2 | «Hình thức học» của LỚP (Offline, Online, OMO): thêm không? Ghi danh đã có OFF, ONL (R-TIEN-12). | A. Thêm danh mục lớp OFF, ONL, OMO + cột `delivery_mode_code` (lớp cũ mặc định OFF); xếp lớp chỉ CẢNH BÁO khi lệch. B. Như A nhưng CHẶN xếp lớp khi lệch (OMO nhận cả hai). C. Không thêm. | **A** (chặn sau khi anh thấy dữ liệu thật) | A, B: một migration mức CAO nhẹ + pgTAP, B đụng luật xếp lớp, cần Tester. C: bỏ ô, canvas vênh. |
| 3 | «Tạo lớp còn lại cho nhóm này»: lớp mới có sao chép giáo viên, lịch không? | A. Điền sẵn nhóm, cơ sở, năm, khối, phân loại; để TRỐNG môn, giáo viên, lịch (mỗi lớp độc lập, R-LOP-14). B. Sao chép cả lịch, giáo viên. | **A** | Không migration (dùng `create_class` có `group_id`). Làm được ngay khi anh chốt. |
| 4 | «Xem trước ngày kết thúc dự kiến» ở form Tạo/sửa lớp (số buổi theo khung, bỏ ngày nghỉ lễ, R-LOP-09, R-LOP-12). | A. Hàm đọc mới tính từ khung giờ đang nhập (chưa lưu). B. Chỉ hiện sau khi Lưu nháp (dùng ngày đã sinh). | **A** | A: một hàm đọc `security definer`, không đổi bảng, một migration nhẹ + pgTAP. B: không migration nhưng không «xem trước» đúng nghĩa. |

Ghi chú: «kiểm môn theo khối khi tạo lớp» (R-LOP-14, [CHỜ anh quyết]) vẫn chưa quyết, không gộp vào bốn câu trên.

## Kho #14: các mục «CẦN CHAT» còn lại của Thu chi và Bán hàng (Code C, 20/11/2026, để Chat hỏi anh Trường)

Đã làm xong: TC-04 cột «Sao kê» và nhóm lọc «Sao kê» (Đã khớp, Chưa khớp) lấy từ cờ TC-15 `bank_matched_at` (migration 439, PR C82). Cột «Mã giao dịch» đã có (migration 431). Phần dưới chưa làm vì thiếu luật hoặc thiếu dữ liệu; mỗi câu có khuyến nghị.

| # | Màn, chỗ thiếu | Câu hỏi | Lựa chọn | Khuyến nghị |
|---|---|---|---|---|
| 1 | TC-04 cột «Xử lý» (nút Duyệt, Từ chối ngay trên dòng) | Có cho duyệt, từ chối ngay trên dòng danh sách không, hay chỉ ở bản ghi? Từ chối cần lý do (hộp K08) | A. Giữ duyệt ở bản ghi TC-02, danh sách chỉ có nút mở. B. Thêm hai nút trên dòng, bấm Từ chối mở hộp K08 nhập lý do, Duyệt mở hộp xác nhận. | **A** (tiền, tránh bấm nhầm; R-HT-01, R-V2-44 không đổi). Nếu chọn B: cần Design vẽ khuôn nút trên dòng, không có trong K03 |
| 2 | TC-10, TC-11 «Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến» | Phiếu chi có ba trường này không? Hiện bảng phiếu chi chưa có cột tương ứng | A. Thêm cột `payment_method_code`, `payout_account`, `planned_on` (tuỳ chọn). B. Không thêm, bỏ khỏi canvas. | **A** nếu kế toán cần theo dõi chi; «Tài khoản nhận» tái dùng danh mục RECEIVING_ACCOUNT hay danh mục riêng cho tài khoản người nhận? (Chat hỏi anh) |
| 3 | TT-02 «Lịch sử liên hệ» và «Đã mua gần nhất» | Lịch sử liên hệ dùng ghi chú (note_target) loại UPSALE hay bảng riêng? «Đã mua gần nhất» lấy đơn đã thanh toán gần nhất của phụ huynh? | A. Dùng ghi chú loại UPSALE và đơn Đã duyệt gần nhất theo ngày. B. Bảng liên hệ riêng. | **A** (không bảng mới, một migration nhỏ thêm loại ghi chú) |
| 4 | TC-03, TC-17 «Lịch đóng tiền từng đợt», «Ưu đãi đóng sớm», «Dồn trước» | Lịch đóng từng đợt lấy từ đơn nào? Ưu đãi đóng sớm tính ở đâu? | Thuộc lane B (Bán hàng): chờ Chat giao thẻ và luật chiết khấu đóng sớm trong docs/spec/04 | Chat giao lane B |

Ngoài phạm vi Thu chi: GV-11 «Tiến độ khung chương trình» cần luật tính bài đã dạy (Chat giao lane E).
