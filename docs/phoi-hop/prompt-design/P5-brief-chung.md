# Brief chung cho Claude Design: P5 (Bán hàng và Thu chi, Đào tạo, Chăm sóc KH, App Giáo viên)

Dán phần này vào đầu mỗi cuộc chat, rồi dán tiếp phần riêng (P5a, P5b, P5c, P5d). Đính kèm: gói P0 đến P2 và P4 hiện hành, `docs/design/ban-do-man-hinh.md`, `docs/design/luat-cho-thiet-ke.md`, `docs/spec/04-luat-nghiep-vu.md` (bản repo), `docs/spec/02`, `docs/spec/06`, và bốn file luật bổ sung 04d, 04e, 04f, 04g.

---

Chào Design. Anh Trường nhờ em vẽ tiếp bốn phân hệ: **Bán hàng và Thu chi**, **Đào tạo** (Ghi danh, Lớp, Buổi, Tái tục), **Chăm sóc KH** (Ticket), **App Giáo viên**. Mỗi phân hệ một canvas riêng, cùng làm theo brief này. Anh sẽ xem và sửa sau; các phân hệ nối vào nhau nên anh sửa một chỗ thì các màn liên quan phải sửa theo (xem mục 4).

## 1. Nguyên tắc (giống P4)
- **Vẽ đúng hệ thiết kế HMT và khuôn P0 hiện có** (K01 đến K14 trong bản đồ màn hình). Không tự chế kiểu dáng, hộp thoại, khuôn mới. Màn chỉ khác khuôn ở trường và chữ thì tự làm. Màn có cấu trúc hoặc cách tương tác mà không khuôn nào có: **dừng màn đó**, ghi rõ tên màn, mã màn, khuôn gần nhất, chỗ còn thiếu, rồi vẽ tiếp phần còn lại. Khuôn đã đề xuất thêm từ P4: bảng nhóm cột (hàng tiêu đề hai tầng).
- **Danh sách màn lấy từ `ban-do-man-hinh.md`, mã màn là tên khung.** Mức A: vẽ đủ trạng thái. Mức B: một trạng thái chính, thêm biến thể trống, đang tải, không có quyền nếu là danh sách hoặc bản ghi. Mức C: không vẽ, chỉ ghi trong ghi chú canvas là dựng từ khuôn nào. Không thêm, bớt màn.
- **Không thêm trường, nút, cột ngoài bản đồ và luật.** Trường lấy từ spec 02, 04, 06. Thiếu thì ghi câu hỏi, đừng tự bịa. Dữ liệu mẫu là dữ liệu giả.
- Chữ tiếng Việt. Số căn phải, thẳng hàng trong mọi bảng số. Tiền đồng có dấu chấm ngăn nghìn. Ngày dd/mm/yyyy.
- Nút Tạo chỉ ở nơi luật cho phép; Xuất chỉ hiện với vai trò có quyền (trên danh sách tài chính: Kế toán, Trưởng cơ sở, Admin theo bản đồ).
- Giai đoạn: màn của giai đoạn sau hiện **mờ** ở giai đoạn 1 theo cách P4 đã làm. Hộp thoại dùng khuôn K08 (Hoàn thành, Dời, Huỷ lịch hẹn tái dùng hộp P3).

## 2. Luật mới chốt 17/10 phải thể hiện trong giao diện
- **Mỗi dòng đơn = một lớp = một ghi danh = một quỹ giờ riêng** (04e: R-GD-01, 02, 03, 14, 18). Sale tự nhập giờ, giá, chiết khấu cho từng dòng; **không có bước phân bổ giờ, không chia đều**. Toán khối 7+ học cả Đại và Hình thì **hai dòng đơn riêng**, hệ thống chỉ nhắc (không chặn) khi mới có một trong hai. Hết giờ ghi danh nào thì hết phí lớp đó; **học quá giờ bị chặn** (ngoại lệ duy nhất: "cho học trước, đóng tiền sau" R-GD-12, quỹ được âm trong hạn mức). Chuyển giờ giữa hai ghi danh: chỉ qua Đề nghị nhóm "Chuyển phí". Màn P4 HS-02 là mẫu cách thể hiện: mỗi lớp một dòng với Giờ đăng ký, Đã học, Còn lại.
- **Lớp Toán Đại + Hình xen kẽ và nhóm lớp** (04g: R-LOP-13, R-LOP-14, sửa R-LOP-08, 09, R-GD-15): mỗi khung giờ có **"Lặp mỗi N tuần"** (mặc định 1) và **"Buổi đầu tiên vào ngày"**, nên hai lớp Đại và Hình có thể cùng thứ, giờ, phòng mà luân phiên (cùng lặp mỗi 2 tuần, buổi đầu cách nhau 1 tuần); kiểm trùng giờ, trùng phòng ở cấp buổi thật. Hai lớp được gắn vào một **nhóm lớp**: nhóm **không có mã riêng**, mỗi lớp giữ mã theo spec 02; nhóm chỉ có **tên chung tuỳ chọn** (tham chiếu, ví dụ 9M1) hiện nhỏ dưới mã lớp. Học sinh có thể chỉ học Đại hoặc chỉ học Hình. Xếp lớp chọn được theo nhóm.
- **Mã cũ từ Google Sheet** (04g: R-LOP-15, R-CRM-33): màn chi tiết lớp (LOP-02) và hồ sơ học sinh (P4 KH-05) có ô **"Mã cũ (Sheet)"** cạnh mã mới, chỉ xem; ô tìm của danh sách lớp, học sinh gõ được mã cũ. **Phụ huynh không có mã cũ.** Theo spec 02 (mục Mã cũ), ở mọi màn bản ghi có mã cũ (đơn, phiếu thu, ...) mã cũ hiện nhỏ dưới mã mới; **riêng phụ huynh không có mã cũ**. Ô này khác "tên chung của nhóm lớp".
- **Cột Start Date, End Date (ngày hết phí)** cho từng lớp (End Date là dự kiến, chỉ để dự báo, không chặn gì).
- **Một ticket đề nghị chọn được nhiều ghi danh** (bảo lưu, dừng học, chuyển cơ sở cho học sinh có nhiều lớp).
- **Mô hình phụ huynh, học sinh dùng chung** (04f): PH, HS sinh tự động, không có nút Tạo; Cơ sở tiếp nhận cố định, Đang học tại tự tính. Chọn học sinh, phụ huynh trong đơn, ticket, ghi danh là chọn hồ sơ có sẵn.
- **Nhận xét buổi học** là đường dẫn tới nhận xét của giáo viên (từ App Giáo viên), các màn khác không lặp lại rubric, lời nhắn.
- Mục 3 của 04e (R-GD-07, 13, 16, R-GIO-03, 04) và mục 4 của 04g (chặn môn theo khối) là **đề xuất chờ anh duyệt**: vẽ theo đề xuất, ghi chú rõ chỗ nào đang chờ.

## 3. Cách làm và báo cáo
- Mỗi canvas bắt đầu bằng khung tổng quan: danh sách mã màn của phân hệ, ai dùng, nối tới màn nào (mục 4).
- Số mã màn lớn: làm theo thứ tự mức A trước, rồi B. Mỗi lần xong một cụm (ví dụ: Báo giá, Đơn hàng) báo anh một dòng.
- Cuối mỗi canvas, ghi chú: những chỗ lệch khuôn hoặc luật, câu hỏi còn treo (đánh số, kèm đề xuất để anh trả lời OK), và các màn đã dừng vì thiếu khuôn.
- Khi anh sửa một màn: **liệt kê các màn trong cùng nhóm liên quan (mục 4) có cần sửa theo, hỏi anh rồi mới sửa**; nếu anh đã dặn "áp dụng hết" thì sửa tất cả và báo lại danh sách đã sửa.
- Xong mỗi cụm màn: báo **link canvas và số phiên bản**, các khung đã vẽ hoặc sửa, câu hỏi còn treo, và câu "Anh gửi link này cho Claude Chat để đối chiếu luật".
- Xong gói thì xuất gói bàn giao cho Code, ghi số phiên bản.

## 4. Bản đồ các màn liên quan (giữ cập nhật khi anh sửa)

| Nhóm | Các màn nối nhau (mã trong bản đồ) | Điều phải khớp |
|---|---|---|
| A. Báo giá → đơn → phiếu thu → ghi danh | TS-13, BH-02, BH-05, BH-06, BH-07, BH-08, BH-09, TC-03, TC-02, TC-05, TC-04, TC-08, TC-13, GD-01, GD-02 | Dòng đơn (một lớp mỗi dòng): gói, lớp, ngày vào lớp, giờ, giá, chiết khấu, giờ tặng; trạng thái đơn và phiếu thu; tiền đã vào, còn lại |
| B. Quỹ giờ theo ghi danh (một ghi danh một lớp) | BH-05, BH-08, GD-02, GD-03, GD-04, GD-05, GD-07, LOP-09, TT-02, BUOI-02, BUOI-14, CS-05, CS-06, CS-07, CS-10, CS-14, P4 HS-02 | Giờ đăng ký, đã học, còn lại, Start Date, End Date; sổ giờ theo ghi danh; xếp lớp theo nhóm (GD-03) |
| C. Ticket thực hiện, tiền, giờ | CS-01 đến CS-14, TC-10, TC-11, TC-14, TC-16, BH-10, BH-05 | Ticket đã duyệt mới có nút Thực hiện; hoàn tiền sinh phiếu chi (CS-05 → TC-11); chuyển phí sinh đơn mới hoặc số dư (CS-10 → BH-05, TC-14, TC-16); dừng học (CS-14) |
| D. Lớp, nhóm lớp, thời khoá biểu, buổi, lịch giáo viên | LOP-01 đến LOP-10, BUOI-01, BUOI-02, BUOI-05, BUOI-13, GD-03, GV-02, GV-03, GV-10, GV-11 | Duyệt lớp tự sinh buổi theo cách lặp của khung giờ; đổi giáo viên, đổi lịch, dời buổi sinh lại buổi chưa diễn ra; trùng phòng, trùng giáo viên ở cấp buổi thật; lớp Đại và Hình độc lập, gắn nhóm lớp (không mã riêng, tên chung tuỳ chọn); ô Mã cũ (Sheet) ở LOP-02; LOP-03, LOP-04, LOP-08, GD-03 phải khớp |
| E. Buổi, điểm danh, chấm, nhận xét | BUOI-02, BUOI-03, BUOI-11, BUOI-12, BUOI-14, GV-04 đến GV-09, GV-18, CS-16, P4 HS-03, HS-04, HS-05 | Điểm danh hai cột (vận hành, giáo viên chính thức); bốn trạng thái điểm danh; thang 1–5; năm trạng thái BTVN; hoàn tất buổi đúng hạn, trễ hạn; nhận xét chờ gửi phụ huynh |
| F. Yêu cầu buổi | BUOI-07, BUOI-08, BUOI-09, BUOI-10, CS-11, GV-11 | Học bù, củng cố, bổ trợ: ai tạo, ai duyệt; học bù không trừ giờ; củng cố tính tiền |
| G. Tái tục | GD-07, TT-01, TT-02, TT-03, BH-02, BH-05, TS-13 | Phiếu tái tục tự sinh khi chạm ngưỡng, một phiếu cho mỗi ghi danh; sinh báo giá, đơn |
| H. Giáo viên tạo ticket, chấm phiếu test | GV-14, GV-15, CS-01, CS-04, TS-17 (P3) | Giáo viên chỉ tạo ticket, không duyệt, chỉ xem ticket lớp mình |
| I. Hồ sơ phụ huynh, học sinh (P4) | KH-02, KH-05, GD-02, BH-05, TC-14, CS-04 | Các nút liên kết có số đếm trỏ về các màn trên; KH-05 có ô Mã cũ (Sheet) |

Khi tạo canvas, vẽ bản đồ này thành một khung ghi chú ở đầu canvas.

## 5. Điều không làm
- Không dùng dữ liệu thật; không vẽ báo cáo Looker (nhóm BC); không vẽ màn app học sinh, phụ huynh (nhóm HT, PH ở giai đoạn 4) trong đợt này.
- Không đổi hệ thiết kế; khuôn mới cần thiết (ví dụ khuôn di động K12, K14 cho App Giáo viên) thì **nêu rõ là khuôn mới đề xuất** để anh duyệt trước khi dùng cho các màn khác.
