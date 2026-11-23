> **Ghi chú của anh Trường (16/10/2026), đọc trước:** chỉ các quyết định về **giao diện, màu, thương hiệu, khuôn** trong file này còn hiệu lực. **Mục 1 (quy trình wireframe, bốn cổng duyệt) đã cũ**: quy trình hiện hành theo `docs/quy-trinh-phoi-hop.md` và `docs/lo-trinh-phan-he.md`.

# Quyết định thiết kế 13/10/2026 (anh Trường chốt)

File này ghi các quyết định mới về cách làm thiết kế kiểu Odoo. Khi vênh với `00-quy-trinh-phoi-hop.md` (mục 4 và 5) hoặc `ban-do-man-hinh.md` thì làm theo file này. Chưa là luật nghiệp vụ; luật chỉ vào `docs/spec/` khi anh nói "OK ĐƯA VÀO LUẬT".

## 1. Quy trình mới: từng phân hệ, bốn cổng duyệt
Làm theo từng phân hệ (giai đoạn 0 đến 5). Mỗi phân hệ đi qua 4 cổng, chưa qua cổng nào thì không sang bước sau:
1. **Wireframe**: Claude Chat vẽ trong artifact "Wireframe HMT kiểu Odoo". Anh duyệt.
2. **Thiết kế**: Claude Design làm đẹp trên nền wireframe đã duyệt. Mỗi lần giao tối đa 5 màn. Không đổi bố cục, không bỏ tính năng, chỉ làm đẹp. Anh duyệt.
3. **Code**: Claude Code dựng. Mỗi PR có bản xem trước và mục "Anh kiểm". Anh bình luận "OK" trên PR.
4. **Staging**: anh thử, rồi cập nhật bản chạy thật qua `hmt-deploy`.

Quy tắc kèm theo:
- Khoá khuôn trước: K1–K5 duyệt thiết kế một lần ở giai đoạn 0. Các phân hệ sau chỉ thêm màn đặc trưng và danh sách cột, trường; không vẽ lại khuôn.
- 151 màn chỉ là cấu hình của khuôn không vẽ, không wireframe. Claude Code dựng từ danh sách cột, trường theo luật; anh kiểm trên staging.
- Chạy gối đầu: lúc anh duyệt wireframe phân hệ N+1, Claude Code có thể đang code phân hệ N.
- Bộ thiết kế cũ `design/hmt-platform/` (P5) sẽ bị thay bằng bản Odoo. Claude Code không dựng giao diện mới khi chưa có "thiết kế đã duyệt".
- Claude Design chạy ở cùng tài khoản đang dùng; bỏ qua tài khoản có bộ "Hoà Ma Toán" cũ.
- **(13/10 chiều)** Trước khi giao màn cho Claude Design làm đẹp, làm bộ nhận diện trước: việc 1 chốt mã màu từ logo, việc 2 tạo bộ nhận diện và hệ thiết kế. Prompt ở `HMT/prompt/claude-design-thuong-hieu.md`.

## 2. Con số và tiến độ wireframe
Cần thiết kế 26: 11 khuôn (K1–K11) + 15 màn đặc trưng (Đ1–Đ15). 169 màn cũ không vẽ: 151 cấu hình + 11 bộ lọc lưu sẵn + 7 báo cáo Looker Studio. 28 màn cũ được thay bằng 26 thiết kế này.
Anh chọn vẽ wireframe đủ cả 26 (không bỏ K6, K7, K8).

| Giai đoạn | Wireframe | Tình trạng |
|---|---|---|
| 0 Chung, Quản trị | K1, K2, K3 | Đã duyệt |
| 0 Chung, Quản trị | K4, K5, K6, Đ1, Đ11 | **Đã duyệt 13/10** |
| 0 Chung, Quản trị | K7 | Claude Code đã code trang đăng nhập, anh thấy đẹp, không vẽ lại (chỉ để đối chiếu) |
| 0 Chung, Quản trị | Đ9 | **Bản tạm, ưu tiên sau.** Trang chỉ tập trung nhắc việc; làm lại cùng các màn nhắc việc và báo cáo sau khi xong các chức năng chính |
| 1 Tuyển sinh, Bán hàng, Thu chi | Đ2, Đ3, K8 | Chưa vẽ |
| 2 Đào tạo | Đ4, Đ5, Đ6, Đ7, Đ8 | Chưa vẽ |
| 3 Giáo viên | K9, K10, K11, Đ12, Đ13 | Chưa vẽ |
| 4 Học tập, Phụ huynh | Đ14, Đ15 | Chưa vẽ |
| 5 Báo cáo | Đ10 | Chưa vẽ |

## 3. Cổng CRM: 9 menu (đã duyệt)
Tổng quan · Tuyển sinh · Khách hàng · Bán hàng & thu chi · Đào tạo · Chăm sóc KH · Báo cáo · Cấu hình · Quản trị.
- Giáo viên, trợ giảng nằm ở Đào tạo.
- Công nợ, Số dư khách hàng, Nhận xét chờ gửi phụ huynh không có mục menu riêng, chỉ là bộ lọc lưu sẵn.
- Danh mục, Tham số, Công tắc tính năng nằm ở Cấu hình. Quản trị giữ người dùng, vai trò và quyền, cơ sở và phòng, tài khoản học sinh và phụ huynh, nhật ký.
- Báo cáo trong app chỉ có 4 màn; 7 báo cáo còn lại mở sang Looker Studio.
- Bản đầy đủ từng mục nằm ở artifact "HMT - Danh sách màn hình kiểu Odoo", tab "Bản đồ theo phân hệ".

## 4. Khuôn Tổng quan và Chi tiết (đã duyệt wireframe)
- Sidebar: đầu sidebar nền trắng ghi tên cổng (CRM, LMS, App Giáo viên); thân tối; menu 2 tầng; nút mở rộng/thu gọn tất cả; cuộn dọc; nút « thu gọn còn icon.
- Chi tiết: **có nút Sửa** (đổi quy tắc 12/10 "sửa trực tiếp, không nút Sửa"); bấm Sửa thì các ô thành ô nhập, nút đổi thành Lưu / Huỷ.
- **Bấm Tạo mở thẳng khuôn Chi tiết ở trạng thái trống cho mọi đối tượng**, bỏ kiểu "biểu mẫu tạo" riêng. Giai đoạn, smart button, ghi chú mờ cho đến khi lưu.
- Thanh giai đoạn chỉ ở bản ghi có giai đoạn. Giai đoạn đã qua bị khoá.
- 4 kiểu chuyển giai đoạn: Đổi ngay (thông báo + Hoàn tác) · Hỏi thêm (hộp chọn sub-stage + ghi chú) · Cần đủ điều kiện (hộp chặn liệt kê chỗ thiếu + nút đi tới ô cần điền) · Hệ thống tự đổi (ổ khoá + lý do).
- Anh đồng ý đề xuất của Claude cho 4 câu còn mở: bộ lọc thông minh, sao ưu tiên và nút Theo dõi, màu topbar (nền trắng như wireframe), và phạm vi các câu còn lại trong tab "Khuôn và thiết kế cần vẽ" của artifact danh sách màn hình.

## 5. Thuật ngữ
Giữ tiếng Anh cho khung Odoo: Sidebar, Topbar, Header, Toolbar, Stage, Sub-stage, Smart button, Filters, Group By, Favorites, Source, Sub-source, **Calendar** (anh chốt 13/10, thay cho "Lịch"). Từ nghiệp vụ HMT dùng tiếng Việt. Nút hành động dùng tiếng Việt. Cột phải ghi tên **"Ghi chú & hoạt động"** (không dùng Lognote & Activity). (26/10) Sub-source đổi tên thành Medium, thêm tầng Source type: Source type, Source, Medium (Đ184).
Nhãn vùng như GIAI ĐOẠN, NÚT NGHIỆP VỤ, THÔNG TIN trên wireframe chỉ để anh đọc, không đưa lên hệ thống.
Wireframe còn một số chỗ ghi "Lịch" (menu, tiêu đề màn): cần đổi thành "Calendar" khi làm đẹp.

## 6. Màu (đã chốt 13/10 chiều, sau việc Brand Color Discovery)
- Màu cam chính thức của HMT: **#EF6926** (đọc từ file SVG logo; wireframe tạm dùng #EF6925). Logo không đổi, giữ cả dòng "18+ năm kinh nghiệm luyện thi".
- **Nút chính:** nền #CB4D0E (brand-600), chữ trắng. Cam logo #EF6926 dùng cho logo, Stage đang chọn, icon, điểm nhấn (chữ trắng trên cam logo chỉ đạt 3,13:1).
- Chữ cam và link dùng #AB420F (thay #B5440F của wireframe). Nút Huỷ, Từ chối, Xoá dạng viền, không dùng nền đỏ đặc cạnh nút cam. Viền ô nhập #8A8076, đường kẻ bảng và khối #E3DDD5. Icon cảnh báo vàng #7A5C00.
- Bảng màu đầy đủ (thang cam 50 đến 900, 4 màu trạng thái, trung tính ấm) nằm trong hệ thiết kế "HMT Platform" của Claude Design: `claude.ai/artifact/FJx7TsZfJ3jaNwfjm5TTeu`.
- Chỉ làm giao diện sáng. Font Inter cho giao diện và số, Be Vietnam Pro cho tiêu đề. Icon Lucide nét 1,5px.

## 7. Việc Claude Code (sau khi anh gửi)
Dừng bắt đầu PR giao diện mới; PR đang mở làm cho xong và chờ OK; phần không phụ thuộc giao diện (cơ sở dữ liệu, quyền, kiểm thử, logic đăng nhập) làm tiếp; cập nhật `docs/TIEN-DO.md`.

## 8. Báo cáo và trang chủ (13/10 chiều)
- **Tách trang chủ và báo cáo.** Đ9 Trang chủ CRM chỉ nhắc việc (thẻ số việc HÔM NAY / QUÁ HẠN, bộ lọc thời gian chỉ áp dụng cho thẻ số việc, hai danh sách chi tiết theo vai). KPI, tỷ lệ chuyển đổi, biểu đồ làm ở wireframe Báo cáo sau. Anh sẽ làm kỹ phần báo cáo.
- **Khái niệm đã chốt cho báo cáo:** "Doanh thu thu được" = tiền đã thu và kế toán duyệt, tính theo **ngày kế toán duyệt**. Học sinh mới = tính khi ghi danh sinh, học sinh chưa từng học. Tỷ lệ chuyển đổi tính **luỹ kế** theo giai đoạn hiện tại của cơ hội (cơ hội chỉ đi tới), kỳ lọc theo ngày tạo cơ hội; "đã đạt Lk" nghĩa là đang ở giai đoạn từ Lk trở lên (công thức cần anh xác nhận lại, xem ghi chú dưới).
- **Chưa chốt (hỏi lại khi vẽ báo cáo):** công thức luỹ kế (anh viết (L1..L4)/(L1..L8), em đề xuất (L4..L8)/(L1..L8)); ASP bán mới chia cho số học sinh mới hay số đơn bán mới; dashboard theo vai (Tuyển sinh, Trưởng cơ sở, CSKH) làm trong app hay Looker (em đề xuất trong app vì cần giới hạn dữ liệu theo cơ sở, nhân sự).
- Bản dashboard KPI dựng thử (Tuyển sinh, Trưởng cơ sở có lọc nhân sự, CSKH) đã lưu riêng để dùng làm nền cho wireframe Báo cáo.

## 9. Quyết định thiết kế 23/10 (anh Trường chốt)
- **QĐ-Đ10:** BUOI-14, lý do sửa điểm danh là **ô ghi tự do, bắt buộc** (R-GIO-07); chưa làm danh mục lý do.
- **QĐ-Đ11:** LOP-09 mở cho CS, BM, AD. Cột "Đại/Hình" chỉ hiện với lớp thuộc nhóm, nghĩa là học sinh có học cả lớp còn lại của nhóm hay không (R-GD-14, R-LOP-14); lớp không thuộc nhóm thì ẩn cột.
- **QĐ-Đ12:** K12 là **biểu mẫu**, bỏ thanh Filters / Group By / Favorites.
- **QĐ-Đ13:** ảnh so sánh bản điện thoại **không bắt buộc** trước khi gộp PR giao diện; bổ sung ở PR kế tiếp.
- **QĐ-Đ14:** tách canvas. Canvas "HMT Platform" giữ làm nguồn khuôn P0. Canvas "HMT Đào tạo & Giáo viên" chứa trạng thái LOP-08, BUOI-03 và cổng Giáo viên. Mỗi canvas một thư mục trong `design/nguon-canvas/`. Khi Design lưu canvas thứ hai, mục lục ghi mã màn nào ở canvas nào được sửa ở PR tài liệu sau đó.
- **QĐ-Đ15:** GV-05 giữ "Còn lại: Có mặt", không tự lưu, vẫn bấm Lưu. QĐ-Đ8 chỉ áp cho điểm danh vận hành.
- **QĐ-Đ16:** Design vẽ **bộ khuôn điện thoại cổng Giáo viên** trước; anh duyệt rồi mới dựng GV-01 đến GV-18.
- **QĐ-Đ17:** K12 (BUOI-03) bỏ nút "Làm mới", nút "Cột" và ô tìm kiếm; chỉ còn nút Lưu, vì K12 là biểu mẫu một buổi chứ không phải danh sách (cùng QĐ-Đ12).
- **QĐ-Đ18:** mọi màn giáo viên ở giai đoạn 1 đều **bấm Lưu, không tự lưu**. Điện thoại: "Lưu và em tiếp theo" lưu từng em. Laptop: nút Lưu lưu cả bảng; rời màn khi chưa lưu thì hiện hộp thoại nhắc của ứng dụng (không dùng `confirm` của trình duyệt). Bản đồ màn hình: dòng khuôn K12, K14 đổi "lưu tự động" thành "bấm Lưu".
- **QĐ-Đ19:** tab "Việc cần làm" của cổng Giáo viên đổi thành **"Cần làm"** (GV-01). Tiêu đề trang GV-12 giữ "Việc cần làm / quá hạn".
- **QĐ-Đ20:** khuôn cổng Giáo viên dùng **ví dụ giả** cho rubric; nội dung rubric thật nhập khi có màn CH-07.
- **QĐ-Đ21:** dấu Đúng hạn / Trễ hạn đóng **tự động, một lần**, vào lúc giáo viên lưu mục cuối cùng làm cả bốn bước đủ (điểm danh, nội dung buổi và BTVN, chấm nhận xét, chấm BTVN buổi trước; bỏ bước cuối nếu buổi trước không giao BTVN), cùng điều kiện tự Done của R-GIO-06. Nút "Hoàn tất buổi" ở GV-04 đổi thành "Kiểm còn thiếu" (mở GV-09 liệt kê chỗ thiếu); khi đã đủ chỉ hiện dấu đã đóng lúc nào. Không có nút giáo viên bấm để đóng dấu. Luật: R-GV-05 (đã vào spec 24/10).
- **QĐ-Đ22 (04/11: phần BTVN thay bởi Đ292, R-V2-35):** GV-06 giữ ô "Buổi này không giao BTVN". Buổi đánh dấu "không giao" thì buổi sau không phải chấm BTVN buổi trước và không chặn Done (R-GIO-06). Là trường dữ liệu mới của buổi. Luật: R-GV-11 (đã vào spec 24/10).
- **QĐ-Đ23:** nội dung buổi (GV-06) phải có **ít nhất một dòng**.
- **QĐ-Đ24:** GV-16 (Giờ dạy của tôi): trên điện thoại dùng khuôn **mới** "báo cáo tháng" (chọn tháng, thẻ số, danh sách thẻ theo loại buổi) do Design vẽ và anh duyệt; laptop dùng K09.
- **QĐ-Đ25:** nút "Trả về sale" ở GV-15 = giáo viên **nộp kết quả đã chấm cho sale**, phiếu chuyển Hoàn thành, không cần lý do. Nút "Lưu" chỉ lưu nháp. Giai đoạn 1 chưa có "tải bài làm" (R-CRM-10).
- **QĐ-Đ26:** **kịch bản trước, vẽ sau**: Chat viết kịch bản cho phân hệ, anh duyệt, rồi Design vẽ và tự thử theo kịch bản.
- **QĐ-Đ27 (24/10):** duyệt khuôn K09 (báo cáo tháng) và GV-15 "đã nộp, chỉ xem".
- **QĐ-Đ28:** không giao Design vẽ phân hệ chưa có kịch bản được duyệt.
- **QĐ-Đ29:** anh duyệt kịch bản cổng Giáo viên (D-01 đến D-14). Luật đã vào `docs/spec/04` ngày 24/10: R-GV-04, 05, 07, 09, 11, 13, 14, R-GIO-08, R-CS-10.
- **QĐ-Đ30:** sửa CI bước cài thư viện hệ thống của trình duyệt (kho gói Ubuntu của Azure có lúc chậm, làm job treo): apt chờ 20 giây và thử lại 3 lần, lưu cache gói đã tải theo phiên bản Playwright (trong 10 GB gói Free); ảnh Docker chính thức của Playwright chỉ đo, chưa đổi. PR riêng (#76 đã gộp; #78).
- **QĐ-Đ32 (D-01):** giáo viên **không thấy danh sách điểm danh tạm** trước khi buổi Đã chốt; vẫn nhập được nội dung buổi. Luật: R-GIO-08.
- **D-12:** giai đoạn 1 **chưa gửi nhắc hạn ra ngoài** (không thư, tin nhắn); nhắc chỉ hiện trong cổng.
- **QĐ-Đ33 (24/10):** giao việc cho lịch hẹn (màn Lịch hẹn, chọn hàng loạt): chỉ giao được lịch hẹn **Chưa làm** (R-CRM-38; Hoàn thành, Huỷ là lịch sử). Lô chọn lẫn: giao phần hợp lệ, trả cho giao diện số giao được, số bị bỏ và lý do từng nhóm bị bỏ; không im lặng bỏ dòng.
- **QĐ-Đ34 (24/10, đã sửa bởi Đ38):** lịch "Theo người", chế độ Ngày: chỉ hiện người có lịch hẹn trong ngày, xếp theo tên, cuộn ngang. Trưởng cơ sở thấy người trong cơ sở mình, Admin thấy mọi cơ sở. ~~Sale, CSKH chỉ thấy lịch của mình (một cột).~~ Câu gạch bị Đ38 thay.
- **QĐ-Đ35 (24/10):** Group By của màn Lịch hẹn: trường nhóm gồm trạng thái, loại hoạt động, người phụ trách, cơ sở, loại hồ sơ gắn (lead, cơ hội, phiếu); một đến hai cấp.
- **QĐ-Đ36 (24/10):** lịch nhắc tự sinh của phiếu kiểm tra **không giao tay hàng loạt** (đi theo người phụ trách phiếu); bị bỏ khỏi lô giao việc với lý do riêng.
- **QĐ-Đ37 (24/10):** chặn đổi người phụ trách của lịch nhắc tự sinh của phiếu cả ở hàm **Dời lịch hẹn** (R-CRM-38), trong cơ sở dữ liệu, kể cả người có quyền Giao việc. Dùng mã lỗi `HMT_LICH_NHAC_THEO_PHIEU`. Chỉ chặn việc đổi người phụ trách; dời giờ, ghi chú vẫn như cũ. Luật: R-CRM-38 (đã vào spec 24/10).
- **QĐ-Đ38 (24/10, sửa Đ34):** lịch "Theo người" hiện những người có lịch hẹn trong ngày, **trong phạm vi lịch mà người xem được quyền xem theo ma trận quyền hiện có**. **Không** thu hẹp quyền xem của Sale, CSKH; không sửa ma trận quyền (Tuyển sinh, CSKH vẫn xem mọi lịch hẹn của cơ sở mình).
- **QĐ-Đ39 (24/10):** hai người cùng sửa một ô ở GV-05, GV-07, GV-08: khi người lưu sau bấm Lưu và có ô vênh (ô cả hai đã sửa và hai số khác nhau) thì hiện hộp thoại "Có ô vừa được [tên] sửa" liệt kê các ô vênh, hai nút "Giữ của tôi" và "Lấy của [tên]". Không cảnh báo lúc nhập. Dựng bằng khuôn "Chưa lưu thay đổi", không thêm khuôn.
- **QĐ-Đ40 (24/10):** thêm bản laptop cho khung mới của GV-04 (ba bước khi buổi trước không giao BTVN, buổi đầu của lớp, thiếu BTVN giao mới), GV-07 (chưa điểm danh), GV-08 (em vắng buổi giao bài, em vắng buổi chấm).
- **QĐ-Đ44 (24/10):** Quản trị người dùng (QT-01, QT-02, QT-03): PR 1 DB (migration 042: `list_users`, `get_user`, `export_users`; bài pgTAP đúng và bị chặn; EXPLAIN trên dữ liệu giả lớn), rồi PR 2 giao diện. PR 2 làm QT-01 và các phần QT-02, QT-03 không cần hộp mật khẩu tạm K4g (máy tính), K4e4 (điện thoại); **dừng đúng hai chỗ Đặt lại mật khẩu và Tạo người dùng**, ghi vào mô tả PR (mã màn QT-02, QT-03; khuôn K4g, K4e4; chờ #69); không tự chế khuôn.
- **QĐ-Đ45 (24/10):** Xuất danh sách người dùng chỉ Admin; cột gồm mã NV/GV/TG, tên, email đăng nhập, vai trò, cơ sở, trạng thái; không mật khẩu, không dữ liệu hai bước; ghi nhật ký xuất.
- **QĐ-Đ46 (24/10):** bật mục menu "Người dùng" khi QT-01 xong.
- **QĐ-Đ49 (24/10):** "Đặt lại hai bước" và "Thu hồi phiên" của QT-02 làm bằng **hàm DB** `app.admin_reset_mfa`, `app.admin_revoke_sessions` trong PR 1 (đổi so với B16: không qua Edge Function). Điều kiện: (1) hàm ghi thẳng bảng Auth nên phải chạy thử được trên hmt-staging; staging từ chối quyền ghi thì dừng, báo anh, quay về Edge Function; (2) luồng đăng nhập phải buộc người vừa được đặt lại hai bước thiết lập lại ở lần đăng nhập sau (Admin, Kế toán).
- **QĐ-Đ50 (24/10):** hai thao tác trên chặn thao tác lên **chính mình** (`HMT_THAO_TAC_CHINH_MINH`).
- **QĐ-Đ53 (24/10):** đặc tả P5a (Bán hàng và Thu chi) đưa vào repo tại `docs/design/dac-ta/P5a-ban-hang-thu-chi.md` sau khi anh duyệt kế hoạch P5a-DB1.
- **QĐ-Đ55 (24/10):** P5a-DB1 chỉ làm cơ sở dữ liệu (bảng, hàm, danh mục). Không dựng giao diện BH, TC khi anh chưa duyệt màn P5a (P5a v6 đang đóng băng chờ anh; chỉ khuôn K13 đã duyệt).
- **QĐ-Đ56 (24/10):** duyệt màn P5a: gom thành một lượt sau khi xong vòng Cổng giáo viên; trước đó Chat rà P5a v6 với luật mới.
- **QĐ-Đ57 (24/10):** chữ R-GV-09 về hai người cùng sửa đổi theo Đ39 và Đ58.
- **QĐ-Đ58 (24/10):** nút "Lấy của [tên]" ở hộp thoại hai người cùng sửa (Đ39, R-GV-09) lưu luôn, không thêm bước xem lại.
- **QĐ-Đ59 (24/10):** em vắng buổi chấm luôn vào Việc cần làm như "Nộp sau"; không có nút đánh dấu "có bài". Giai đoạn 4 (LMS) mới có "em đã nộp" thật.
- **QĐ-Đ60 (24/10):** câu cuối R-GV-11 (em vắng buổi chấm) sửa theo Đ59: bài luôn vào Việc cần làm như Nộp sau, không có nút đánh dấu "có bài", giáo viên chấm khi em nộp bài.
- **QĐ-P3f-1:** P3f chỉ gộp Lead và Cơ hội. Gộp Phụ huynh, Học sinh (KH-07) và điều kiện "học sinh học hai lớp trùng giờ" (R-CRM-25 phần [CHỜ]) để phân hệ Khách hàng, Ghi danh.
- **QĐ-P3f-2:** KD6 (hai học sinh trùng tên và năm sinh của một phụ huynh, ví dụ sinh đôi): giữ nguyên hành vi hiện tại, chưa thêm cảnh báo mềm, bàn lại khi gặp thật. Ghi ở "Việc để sau" của TIEN-DO, vẫn [CHỐT chờ].
- **QĐ-Đ62 (24/10):** tài liệu chấm bài tự luận bằng AI lưu ở `docs/nghien-cuu/cham-tu-luan-ai.md` làm tài liệu tham khảo (không phải luật, không phải đặc tả).
- **QĐ-Đ63 (24/10):** AI chấm bài thuộc giai đoạn 4b/4c (sau 4a). Chưa vẽ GV-17, GV-18, HT; chưa thêm bảng hay cột AI vào cơ sở dữ liệu. Khi tới lượt: viết kịch bản LMS trước, anh duyệt, rồi mới vẽ và code.
- **QĐ-Đ64 (24/10):** trước khi thử bài thật của học sinh với AI: ảnh bỏ hẳn tên và mã học sinh; dữ liệu thật chỉ đi qua gói trả phí hoặc khi phụ huynh đã đồng ý; chưa có thì thử bằng bài mẫu do giáo viên làm.
- **QĐ-Đ75 (24/10):** lead và cơ hội có **danh sách em**. Các em test hoặc đóng tiền cùng lúc thì một cơ hội; mỗi em một thời điểm thì mỗi em một cơ hội.
- **QĐ-Đ76 (24/10):** cơ hội có nhiều phiếu kiểm tra thì phiếu đầu tiên Hoàn thành là đủ để cơ hội lên L6 (R-CRM-13); các phiếu sau không đổi giai đoạn.
- **QĐ-Đ77 (24/10):** từ L5 trở lên cần ít nhất một em đủ tên và năm sinh. Khối nhập khi tạo phiếu kiểm tra và trên dòng báo giá, dòng đơn, không nằm ở danh sách em. Số em tối đa là tham số cấu hình `prospect_max_students` (mặc định 5).
- **QĐ-Đ78 (24/10):** phần học sinh trên dòng báo giá và dòng đơn trong P5a-DB1 chờ luật mới về danh sách em; chưa viết.
- **QĐ-Đ79 (24/10):** ô Nhu cầu dùng chung cả nhà, không theo từng em.
- **QĐ-Đ80 (24/10):** cơ hội có nhiều em thì giao diện hiển thị bằng thẻ chọn.
- **QĐ-Đ81 (24/10):** lead cũng có danh sách em. Nhập nhanh và nhập file vẫn một em. Tạo cơ hội từ lead cho chọn em đưa vào. Gộp thì hợp danh sách; em trùng tên chuẩn hoá và năm sinh gộp thành một dòng.
- **QĐ-Đ83 (24/10):** báo giá và đơn không tạo em mới. Dòng chọn em trong danh sách của cơ hội; không có nút "Thêm em" trên dòng, chỉ gợi ý "Chưa thấy em? Thêm em ở cơ hội". Thêm em chỉ có ở Lead và Cơ hội.
- **QĐ-Đ84 (24/10):** báo giá và đơn từ phiếu tái tục chỉ gồm em của ghi danh; em khác thì tạo cơ hội mới.
- **QĐ-Đ85 (24/10):** tạo phiếu kiểm tra không tạo em mới và không có "Thêm em"; chỉ chọn em trong danh sách của cơ hội.
- **QĐ-Đ86 (24/10):** dòng danh sách đã gắn hồ sơ học sinh đọc thẳng từ hồ sơ (không giữ bản sao). Em đã có ghi danh thì tên, năm sinh chỉ sửa ở KH-06. Sửa thành trùng em khác của cùng phụ huynh thì chặn, nêu mã hồ sơ trùng.
- **QĐ-Đ87 (24/10):** trường, học lực, mục tiêu, tên, ngày sinh, năm sinh theo từng em; Nhu cầu chung cả nhà.
- **QĐ-Đ88 (24/10):** số em tối đa áp cho cả lead và cơ hội; tham số `prospect_max_students`, khoảng 1 đến 20, mặc định 5.
- **QĐ-Đ89 (24/10):** gộp mà vượt số em tối đa thì chặn. Gộp cơ hội bỏ chặn "khác học sinh" của R-CRM-37(a), thay bằng hợp danh sách. Hai dòng trùng tên chuẩn hoá và năm sinh mà gắn hai hồ sơ học sinh khác nhau thì chặn, gộp học sinh trước.
- **QĐ-Đ90 (24/10):** hộp "Thêm em" chỉ mở từ Lead và Cơ hội. Phiếu kiểm tra, báo giá, đơn không có nút hay hộp thêm em, chỉ chọn trong danh sách (Đ83, Đ85).
- **QĐ-Đ91 (24/10):** trùng tên chuẩn hoá và năm sinh cùng phụ huynh thì chặn, nêu mã hồ sơ trùng. KD6 (sinh đôi trùng tên) vẫn [CHỜ] theo QĐ-P3f-2, không đổi.
- **QĐ-Đ92 (24/10):** tạo cơ hội từ lead: mặc định tick hết em, cho phép 0 em. Danh sách hiện em đầu và "+N em"; xuất file nối các em bằng dấu chấm phẩy.
- **QĐ-Đ93 (24/10):** báo giá Nháp được lập cho em chưa đủ tên và năm sinh; đơn bắt buộc đủ. Đường tái tục: chỉ chừa cột `student_id`, luồng làm sau.
- **QĐ-Đ98 (24/10):** ở Cơ hội, hộp "Thêm em" có hai chế độ: em mới (chỉ ghi nhận, không tạo hồ sơ học sinh) và chọn con có sẵn của phụ huynh (gắn `student_id`). Ở Lead chỉ có chế độ em mới.
- **QĐ-Đ100 (24/10):** P5a tách PR DB0 (cấu hình: gói, bảng giá, chiết khấu, quà tặng, điều khoản thanh toán), gộp trước P5a-DB1.
- **QĐ-Đ101 (24/10):** gói DV, TL dùng cột `quantity`, đơn vị theo loại gói (DV theo tháng, TL theo bộ, còn lại theo giờ); dòng báo giá, dòng đơn chụp lại cả đơn vị.
- **QĐ-Đ102 (24/10):** một ô tích chung cho "vượt trần" và "chính sách cần duyệt"; người tích là người duyệt đã chốt lúc trình (Trưởng cơ sở tự duyệt thì chính họ tích; Admin duyệt thay thì Admin tích, ghi "duyệt thay").
- **QĐ-Đ103 (24/10):** lý do từ chối: mục dùng chung để `applies_to` trống; "Sai số tiền", "Sai chứng từ" chỉ gán phiếu thu; "Không đúng chính sách" chỉ gán báo giá và đơn.
- **QĐ-Đ104 (24/10):** "Lý do huỷ đơn" khai trong migration, sáu lý do: Khách đổi ý, không đăng ký nữa · Chọn nhầm gói hoặc lớp · Nhập sai thông tin · Thay bằng đơn khác · Không liên lạc được · Khác (bắt buộc ghi chú). Chữ trong spec 06 chờ "OK ĐƯA VÀO LUẬT" riêng.
- **QĐ-Đ105 (24/10):** Xuất báo giá, đơn, phiếu thu chỉ Trưởng cơ sở (cơ sở mình), Kế toán, Admin. Sale và CSKH bỏ Xuất, vẫn in báo giá của mình. Sửa ma trận bằng phiên bản mới (cấu hình có hiệu lực), làm trong PR cấu hình trước P5a-DB1; ghi chỗ vênh với ma trận cũ vào PR.
- **QĐ-Đ106 (24/10):** giấy tờ chặn gộp cơ hội tính mọi bản ghi còn hiệu lực, trừ đơn Huỷ và báo giá Từ chối; chỉ chặn khi bản bị gộp đã có giấy tờ (R-CRM-22).
- **QĐ-Đ107 (24/10):** tham số `debt_due_soon_days` khoảng 1 đến 30, không ghi đè theo cơ sở; anh duyệt khi tới P5a-DB2.
- **QĐ-Đ108 (24/10):** hộp "Thêm em" chỉ bắt buộc họ tên; năm sinh không bắt buộc (nhập thì 4 chữ số). Năm sinh bắt buộc từ L5, khi tạo phiếu kiểm tra và khi duyệt đơn.
- **QĐ-Đ94 (24/10):** màn tạo phiếu kiểm tra (TS-15) không có "Thêm em"; chỉ chọn em trong danh sách của cơ hội.
- **QĐ-Đ95 (24/10):** báo giá và đơn không có nút "Thêm em"; gợi ý "Chưa thấy em? Thêm em ở cơ hội".
- **QĐ-Đ97 (24/10):** danh sách em làm theo kế hoạch đã duyệt (Chat soạn, anh Trường duyệt) rồi mới viết mã.
- **QĐ-Đ109 (24/10):** em đã ghi danh (đã học) thì khoá cả ngày sinh cùng tên và năm sinh ở cơ hội; sửa ở KH-06.
- **QĐ-Đ111 (24/10):** thêm ba khuôn dùng chung vào khuôn P0: K06b (thẻ chọn đối tượng), K08b (danh sách tick chọn nhiều dòng), K08c (hộp "Thêm em").
- **QĐ-Đ113 (24/10):** dựng sáu màn theo kịch bản đã duyệt: TS-08, TS-02, TS-06, TS-15, BH-02, BH-05. TT-02 (tái tục) chưa vẽ.
- **QĐ-Đ114 (24/10):** K06b bỏ dấu * ở chỗ không bắt buộc.
- **QĐ-Đ115 (24/10):** duyệt bản canvas "HMT Platform" bản 34 (khuôn K06b, K08b, K08c).
- Đ96, Đ110, Đ112: đã được anh OK, chưa ghi lại được chữ.
- **QĐ-Đ82 (24/10):** tám mã luật về danh sách em được duyệt đưa vào spec 04: R-CRM-23, R-CRM-03, R-CRM-05, R-CRM-13, R-CRM-27, R-CRM-37, R-TIEN-35, R-TIEN-02 (chữ trong PR sửa luật riêng, không migration).
- **QĐ-Đ116 (26/10):** P5a-DB0 (cấu hình bán hàng) lập kế hoạch cho anh duyệt trước khi viết migration.
- **QĐ-Đ117 (26/10):** kế hoạch DB0 được duyệt với các quyết định: (a) gói không có số giờ, không có loại lớp (R-TIEN-36); (b) kèm sáu hàm ghi của Admin; (c) điều khoản thanh toán cho đợt 1 (cọc) là số tiền cố định, các đợt sau chia % của phần còn lại (tổng 100%); (d) chiết khấu có `fixed_value`: bật = áp đúng `max_value`, tắt = nhân viên điền từ 0 đến `max_value`, tặng giờ luôn là loại điền; (e) `applies_to` dùng BAO_GIA, DON, PHIEU_THU (các loại sau LOP, TICKET, YEU_CAU_BUOI mở rộng sau); (f) Kế toán thêm Xem báo giá toàn hệ thống (chỉ đọc) để Xuất được; (g) `effective_from` được ở quá khứ, báo giá mới luôn tính giá theo ngày tạo.
- **QĐ-Đ156 (26/10):** phiếu tái tục tính theo (học sinh, lớp). Giờ còn = tổng giờ còn của mọi ghi danh còn hiệu lực của em ở lớp đó. Sinh khi giờ còn ≤ 10 hoặc ngày hết giờ dự kiến ≤ 30 ngày; tối đa một phiếu đang mở. Sau L5 Không tái tục không tự sinh lại. Tái tục thành công (L8) sinh ghi danh mới cùng lớp. Bảo lưu: dừng sinh; dừng học: đóng phiếu; chuyển lớp: phiếu chuyển theo lớp mới.
- Đ99: chưa ghi lại được chữ.
- **QĐ-Đ118 (26/10):** tham số `debt_due_soon_days`, mặc định 3 ngày (khoảng 1 đến 30).
- **QĐ-Đ119 (26/10):** P5a-DB0 là một PR, migration 044, gộp sau #88.
- **QĐ-Đ120 (26/10):** số Đ nào không còn chữ thì ghi "chưa ghi lại được chữ" (không ghi "bỏ trống").
- **QĐ-Đ122 (26/10):** gộp các file nhãn nhóm `Man_*` và `Nhom_*` trên canvas để lấy chỗ đăng; chỉ gộp nhãn tiêu đề, không xoá hay đổi nội dung màn; vị trí và kích thước khung màn không đổi.
- **QĐ-Đ123 (26/10):** được xoá khung cũ `TS08_K3` vì khung mới thay hẳn; `TS08b_K3` chưa xoá cho tới khi anh quyết.
- **QĐ-Đ124 (26/10):** nút ở TS-06 giữ chữ "Vẫn tạo mới".
- **QĐ-Đ125 (26/10):** đang sửa dở một ô mà chuyển thẻ em hoặc bấm "Thêm em" thì hiện "Lưu hoặc Huỷ thay đổi trước khi…"; chỉ khi ô có thay đổi chưa lưu. Code làm theo.
- **QĐ-Đ126 (26/10):** TS-08 dùng đúng hộp tạo phiếu của TS-15; bỏ hộp "Tạo lịch Test" riêng ở TS-08.
- **QĐ-Đ127 (26/10):** nhãn gộp bên trái canvas giữ như hiện tại.
- **QĐ-Đ132 (26/10):** nhãn ô chọn khối trong hộp TS-15 là "Khối"; lựa chọn giữ Lớp 2 đến Lớp 12 (dữ liệu danh mục). Code ở PR giao diện đổi nhãn "Lớp" thành "Khối".
- **QĐ-Đ133 (26/10):** ngày giờ test không ở tương lai thì khoá nút "Tạo phiếu" và hiện dòng đỏ "Giờ test phải ở tương lai." (đúng chữ code đang dùng).
- **QĐ-Đ134 (26/10):** nhãn "Khối" áp cho cả `TS15_chon_em` và `TS15_hai_phieu`.
- **QĐ-Đ135 (26/10):** anh OK sáu màn canvas bản 37 (TS-08, TS-02, TS-06, TS-15, BH-02, BH-05 phần danh sách em); không có nghĩa là lưu canvas vào repo.
- **QĐ-Đ143 (26/10, anh OK):** khung BH05_tao_trang giữ nguyên, kể cả hai chỗ "Lệch". Đây là hạn chế của bản vẽ: ô chọn em đã hiện ở ba khung BH-05 khác nên không vẽ thêm dòng giả. Không đổi khung nào.
- **QĐ-Đ144 (26/10, anh OK):** chốt TS08_nhieu_phieu. Xoá hẳn khung TS08b_K3 và vùng "CŨ – CHỜ XOÁ" khỏi canvas. Kiểm tiêu đề khung có khớp TS08_em1 không, chỉ sửa nếu lệch.
- **QĐ-Đ145 (26/10, anh OK):** sửa nhãn nhóm "Cơ hội" và "Phiếu kiểm tra" cho đúng số khung thật.
- **QĐ-Đ157 (26/10):** phiếu tái tục tính theo (học sinh, lớp) trên TT-01, TT-02, TT-04, GD-07, GD-02; ngưỡng giờ còn ≤ 10 hoặc ≤ 30 ngày; có nhóm con L1B; L8A "Đã đóng đủ, đã cấp quỹ giờ mới".
- **QĐ-Đ158 (26/10):** BH-07 mỗi dòng ghi "dùng HS…" hoặc "sẽ tạo hồ sơ mới".
- **QĐ-Đ159 (26/10):** bộ số liệu mẫu chuẩn cho lớp `CS1-2627-DAI-K09-CB-A-001`, các ghi danh và mã HS.
- **QĐ-Đ160 (26/10):** nhãn "Cấp" đổi thành "Khối" ở LOP-01, LOP-02, LOP-03; LOP-01 chỉ hiện lớp cơ sở mình cho Trưởng cơ sở, CSKH, Sale; Admin xem toàn hệ thống.
- **QĐ-Đ161 (26/10):** thêm khung cảnh báo trùng giáo viên (không chặn) vào LOP-03.
- **QĐ-Đ162 (26/10):** luật Lớp theo thay đổi 26/10 (R-LOP-01, R-LOP-02, R-LOP-03, R-LOP-10, R-LOP-11).
- **QĐ-Đ163 (26/10):** tình trạng vận hành của lớp tính tự động, chỉ có giá trị từ lớp Đã duyệt trở đi (R-LOP-05).
- **QĐ-Đ164 (26/10):** vẽ CH-03, CH-04 (kèm tab "Chính sách quà tặng"), CH-09; quà tặng chưa có mã màn trong bản đồ.
- **QĐ-Đ165 (26/10):** KH-06: ngày sinh không bắt buộc, năm sinh bắt buộc; chữ báo trùng "họ tên hoặc năm sinh".
- **QĐ-Đ166 (26/10):** Design cập nhật mục lục, số khung, ghi chú cuối canvas.
- **QĐ-Đ167 (26/10):** buổi củng cố chỉ cần quản lý cơ sở duyệt; bỏ yêu cầu phụ huynh đồng ý (R-BUOI-10 bản 26/10).
- **QĐ-Đ168 (26/10):** R-LOP-01 chỉ giữ một dòng "Đường đi", bản 26/10.
- **QĐ-Đ121 (26/10):** anh đã đọc và OK Đ94 đến Đ115.
- **QĐ-Đ182 (26/10):** R-CRM-40 (lead tạo cơ hội khi ở nhóm con C4C; C4D tạo thêm qua R-CRM-01) đã vào docs/spec/04, [CHỐT]. Cài đặt ở PR #97 (migration 048).
- **QĐ-Đ183 (26/10):** lead đổi giai đoạn sang giai đoạn có nhóm con chọn tay (C2, C3, C4) thì bắt buộc chọn nhóm con, cùng hộp như cơ hội, áp cả Kanban; lỗi DB `HMT_THIEU_NHOM_CON`. Đã vào docs/spec/04 (R-CRM-41), 26/10.
- **QĐ-Đ184 (26/10):** bảng Source type / Source / Medium (Marketing gồm Facebook Ads, Google Ads, Website, Hotline, Walk-in, Zalo, Referral [By Customer, By HMT], Upsale [Cross-Sale]; Telemarketing: Cold Call; Event: Event; Ban Giám Đốc: Ban Giám Đốc); bỏ Medium Renew Lost, New Opp; Medium bắt buộc khi Source có Medium con. Đã vào docs/spec/06 mục 1.1.
- **QĐ-Đ185 (26/10):** R-CRM-41 (lead đổi giai đoạn có nhóm con chọn tay thì bắt buộc chọn nhóm con) đã vào docs/spec/04.
- **QĐ-Đ186 (26/10):** R-CRM-01 viết lại (ba lựa chọn khi lead đã có cơ hội; cơ hội tạo trực tiếp không cần lead; lead chỉ tạo cơ hội ở C4C) đã vào docs/spec/04.
- **QĐ-Đ187 (26/10):** tái tục lên đơn. (a) Nút Tạo báo giá, Tạo đơn trên phiếu tái tục (TT-02) khi phiếu ở L6 hoặc L7; CSKH phụ trách phiếu tạo; báo giá và đơn gắn đúng một gốc, cơ hội hoặc phiếu tái tục; học sinh và lớp lấy từ phiếu; mã BG, DH cấp theo cơ sở của lớp; duyệt đơn theo R-HT-06. (b) R-CRM-16 không áp dụng cho đơn tái tục; thay bằng điều kiện phiếu ở L6 hoặc L7, chặn trong hàm; tạo báo giá thì phiếu sang L7A, tạo đơn sang L7B, đơn đóng đủ thì L8A. (c) Ghi danh mới dùng chung on_receipt_approved_enrolment khi đủ cọc, gắn đúng lớp của phiếu, không vào hàng chờ xếp lớp, giữ hình thức học. Đã vào docs/spec/04 (R-CRM-16, R-TIEN-02, R-GD-13), ngày 26/10.
- **QĐ-Đ188 (26/10):** chữ luật tái tục lên đơn (TAI-TUC-DON) đã vào docs/spec/04.
- **QĐ-Đ189 (26/10):** dòng "Source, Sub-source" của quyết định 13/10 giữ nguyên chữ gốc, thêm ghi chú: Sub-source đổi tên thành Medium, thêm tầng Source type (Đ184).
- **QĐ-Đ169 (26/10):** báo giá Nháp tính giá theo bảng giá hiệu lực lúc Lưu; bấm Gửi thì đóng băng đơn giá, chiết khấu, số giờ (R-TIEN-14). Sau Gửi, đổi bảng giá không ảnh hưởng.
- **QĐ-Đ170 (26/10):** Gửi báo giá bị chặn khi còn em thiếu họ tên hoặc năm sinh; báo đúng dòng, đúng ô thiếu, mã lỗi `HMT_EM_THIEU_THONG_TIN` kèm câu tiếng Việt.
- **QĐ-Đ171 (26/10):** báo giá có trạng thái Huỷ (R-CRM-19), không xoá cứng.
- **QĐ-Đ172 (26/10):** tiền chiết khấu làm tròn xuống đồng (bigint). Đã vào docs/spec/04 (R-TIEN-37), 26/10.
- **QĐ-Đ173 (26/10, bản chốt, anh OK):** công tắc của báo giá và đơn là phân hệ `BAN_HANG` bật theo cơ sở (danh mục MODULE đã có; bảng `app.feature_flag` và hàm `app.require_feature` đã có từ migration 006, không dựng mới). Kiểm trong các hàm ghi của báo giá (lưu, gửi, từ chối, huỷ), lỗi `HMT_TINH_NANG_TAT`; giao diện kiểm cùng công tắc. Hàm đọc không chặn theo công tắc (Đ181).
- **QĐ-Đ174 (26/10):** một dòng báo giá/đơn dùng tối đa MỘT chính sách tặng giờ. Giờ tặng tính vào trần chiết khấu (R-TIEN-29, R-TIEN-36).
- **QĐ-Đ175 (26/10, anh OK):** bấm Gửi thì `send_quotation` TÍNH LẠI mọi dòng bằng `price_line` theo giá và chính sách hiệu lực của NGÀY GỬI, dùng đầu vào đã lưu (gói, hình thức, số lượng, chính sách), rồi mới đóng băng. Gói ngừng bán, hình thức không còn giá, chính sách hết hiệu lực hoặc không áp dụng thì chặn Gửi, báo đúng dòng bằng mã lỗi của `price_line`. Tổng sau tính lại khác lúc Lưu thì trả cảnh báo `HMT_TONG_TIEN_DOI` (kèm tổng cũ, tổng mới) để giao diện hiện.
- **QĐ-Đ176 (26/10, anh OK):** thành tiền dòng làm tròn đến đồng (nửa đồng lên); tiền chiết khấu làm tròn xuống đồng (Đ172); thành tiền sau chiết khấu = thành tiền − tiền chiết khấu. Đã vào docs/spec/04 (R-TIEN-37), 26/10.
- **QĐ-Đ181 (26/10, anh OK):** KHÔNG chặn các hàm đọc của báo giá (danh sách, bản ghi, xuất) khi phân hệ `BAN_HANG` tắt ở cơ sở; chỉ các hàm ghi bị chặn (Đ173). Giao diện ẩn mục báo giá khi phân hệ tắt.
Ghi chú (26/10): Đ190 và Đ191 là lời OK trong chat, không có luật riêng và không có chữ gốc để ghi lại. Nội dung TT-02 nằm ở QĐ-Đ192 và R-GD-13 (docs/spec/04).

- **QĐ-Đ192 (26/10, anh OK):** TT-02 thêm Email phụ huynh, hai ô tự do Mục tiêu/nhu cầu tiếp theo và Lộ trình tiếp theo (sửa có nhật ký), tab "Tình hình học tập" mờ đến giai đoạn Giáo viên. Đã vào docs/spec/04 (R-GD-13), 26/10.
- **QĐ-Đ195 (26/10, anh OK):** không ghi Đ190, Đ191 thành quyết định riêng; xem ghi chú ở trên.
- **QĐ-Đ201 (26/10, anh OK):** dòng đơn lấy từ báo giá sao nguyên giá đã đóng băng lúc Gửi, kể cả khi báo giá quá hạn; chỉ báo giá Đã gửi chuyển đơn; đơn thẳng từ cơ hội tính theo giá ngày tạo đơn. Đã vào docs/spec/04 (R-TIEN-14), 26/10.
- **QĐ-Đ202 (26/10, anh OK):** người lập huỷ đơn Nháp; đơn Đã trình, Đã duyệt do người duyệt đã chốt lúc trình huỷ (Admin thay khi vắng); chỉ huỷ khi chưa có phiếu thu; lý do từ danh mục. Đã vào docs/spec/04 (R-TIEN-38), 26/10.
- **QĐ-Đ203 (26/10, anh OK):** em đủ họ tên và năm sinh kiểm khi trình và khi duyệt; lớp còn chỗ kiểm khi lưu, trình, duyệt; không giữ chỗ trước. Đã vào docs/spec/04 (R-TIEN-35, R-GD-08), 26/10.
- **QĐ-Đ204 (26/10, anh OK):** ma trận quyền v6: Sale và CSKH có quyền Huỷ đơn hàng; cancel_order chỉ cho họ huỷ đơn Nháp do chính mình lập. Đơn Đã trình, Đã duyệt chỉ người duyệt đã chốt lúc trình hoặc Admin thay khi vắng huỷ (Đ202).
- **QĐ-Đ205 (26/10, anh OK):** submit_order bị chặn, báo lỗi có mã và câu tiếng Việt, khi quản lý trực tiếp đã chốt không có quyền Duyệt đơn; lúc duyệt vẫn cần cả hai điều kiện: có quyền Duyệt và đúng người đã chốt (hoặc Admin thay).
- **QĐ-Đ206 (27/10, anh Trường quyết):** Actions hết phút gói Free trong tháng 10 (2.000 phút); chờ đến khoảng 1/11 để có phút lại. Không nâng gói Pro, không đặt ngân sách chi tiêu, không tốn tiền.
- **QĐ-Đ207 (27/10, anh Trường quyết):** PR #105 (ma trận quyền phiên bản 6) được gộp dù job "Bản xem trước (Cloudflare Pages)" trượt vì hết phút Actions (hai nhóm checks và DB + Playwright đã xanh ở commit cd10030). Kiểm thử cuối cùng của #105 là bản chạy trên máy theo Đ208, vì commit sau đó không chạy được CI do hết phút. Gộp khi có OK của TÀI KHOẢN GỘP sau commit cuối, như thường lệ.
- **QĐ-Đ208 (27/10, anh Trường quyết) — NGOẠI LỆ TẠM đến khi CI chạy lại, không phải luật mới:** trong lúc CI chưa chạy được, kết quả chạy đủ bộ kiểm tra trên máy được dùng thay CI, theo đủ các điều kiện sau:
  a) Chạy đủ trên máy: `npm run db:reset`, `npm run db:test`, `npm run lint`, `npm run typecheck`, `npm run test`, `npm run check:hardcode`, `npm run format:check`, `npm run e2e`. Thiếu bước nào thì PR đó không dùng Đ208 và phải chờ CI thật.
  b) Dán kết quả từng bước (đạt hoặc trượt, số bài kiểm tra) và mã commit đã chạy vào MÔ TẢ PR. Sửa mô tả không tạo commit nên không làm mất OK.
  c) Chat đọc diff trước khi anh OK.
  d) Chỉ gộp khi có comment "OK" từ TÀI KHOẢN GỘP đăng SAU commit cuối. OK trong chat không tính.
  e) Sau 1/11, khi Actions chạy lại, chạy CI trên main và báo kết quả; nếu trượt thì sửa ngay bằng PR riêng.
  f) PR có migration vẫn tách: PR DB nhỏ gộp trước.
- **QĐ-Đ209 (27/10, anh Trường quyết):** thêm bước "kiểm độc lập" cho PR có tiền, quyền hoặc RLS: sau khi tự viết và tự chạy đủ bộ kiểm tra (Đ208), một agent phụ chạy riêng, không mang bối cảnh của người làm, chỉ nhận chữ nguyên văn các luật liên quan trong docs/spec, file migration và file pgTAP; viết thêm bài pgTAP cố phá từng luật, liệt kê luật chưa có bài kiểm, báo chỗ code lệch chữ luật; chỉ ghi vào file kiểm thử riêng, không sửa migration. **Thử một PR trước, chưa áp rộng:** lần đầu CHỈ áp cho P5a-DB1b-1, đo mức dùng, rồi Chat báo anh quyết có áp cho PR khác hay không. Chưa áp cho PR nào khác.
- **QĐ-Đ210 (27/10, anh Trường quyết):** cắt phút CI làm bốn việc: #1 (Deploy staging không chạy lại job "checks" đã chạy ở PR; vẫn giữ bước kiểm migration trên hmt-staging), #3 (bản xem trước Cloudflare chỉ chạy khi PR đổi file giao diện), #4 (Keepalive 3 ngày một lần thay vì mỗi ngày, sau khi xác nhận ngưỡng tự dừng của Supabase Free từ tài liệu Supabase), #6 (lệnh gom `npm run check:all` chạy ở máy trước khi đẩy, ghi cách dùng vào docs/quy-trinh-phoi-hop.md). CHƯA làm #2 (gộp job checks vào job DB + Playwright) và #5 (cache ảnh Docker của Supabase). KHÔNG làm #7 (Deploy staging chỉ chạy khi bấm tay hoặc theo lịch): staging cập nhật chậm làm anh thử tay không kịp, và #1 đã cắt phần lớn. Việc sửa workflow làm SAU 1/11, khi Actions có phút lại (thử workflow mới cũng tốn phút); không bỏ kiểm tra bắt buộc nào, không thêm dịch vụ tốn tiền.
- **QĐ-Đ211 (27/10, anh Trường quyết, phương án A):** mục tiêu đến 31/10 là Bán hàng chạy trọn vòng; làm hai luồng song song: luồng DB và luồng giao diện.
- **QĐ-Đ212 (27/10, anh Trường quyết, phương án A):** từ nay đến 1/11 (chưa có CI) giảm mức kiểm trên máy và tiết kiệm token. Đ208 giữ nguyên là ngoại lệ tạm; Đ212 chỉ nới cách áp dụng điều kiện a của Đ208, không đổi các điều kiện b đến f. (1) PR dữ liệu (migration, hàm DB): chạy đủ `db:reset`, `db:test` (toàn bộ pgTAP), `lint`, `typecheck`, `test`, `check:hardcode`, `format:check`; bỏ e2e nếu PR CHỈ thêm đối tượng mới (bảng, hàm, chỉ mục mới) và không đổi hàm, bảng, chính sách RLS đã có, ghi câu "PR chỉ thêm đối tượng mới, không đổi đối tượng cũ" kèm danh sách trong mô tả PR; có đổi đối tượng cũ thì chạy e2e liên quan. PR giao diện: chạy `lint`, `typecheck`, `test`, `check:hardcode`, `format:check` và e2e chỉ các bài của màn đã đổi (máy tính và iPhone), nêu tên bài trong mô tả PR. Bước bỏ thì ghi "bỏ theo Đ212, vì …", không im lặng bỏ. (2) Chạy đủ toàn bộ e2e một lần ngày 31/10 trên `main`, báo Chat; ngày 1/11 khi Actions có phút thì chạy CI thật trên `main` (Đ208 mục e). (3) Đ209 (kiểm độc lập) giữ nguyên chỉ cho DB1b-1 và chạy song song với lúc Chat kiểm diff, bổ sung mục "Kiểm độc lập" vào mô tả PR khi xong. (4) Tiết kiệm token: chỉ đọc tóm tắt kết quả kiểm (đạt, trượt, số bài), mở nhật ký chi tiết khi có bài trượt; bài trượt thì chạy lại đúng bài đó trước; không đọc cả file hay thư mục lớn khi chỉ cần một đoạn; báo cáo cho Chat ngắn; mô tả PR gọn (bảng kết quả, thay đổi chính, rủi ro, không dán nhật ký).
- **QĐ-Đ213 (27/10, anh Trường quyết, phương án A):** đơn thẳng từ cơ hội tính theo bảng giá và chính sách hiệu lực NGÀY TẠO ĐƠN; lưu lại đơn Nháp vẫn dùng ngày đó (`priced_on` không đổi), không tính lại theo ngày lưu (R-TIEN-14).
- **QĐ-Đ214 (27/10, anh Trường quyết):** tuần này đơn chưa chọn lớp (em vào hàng chờ xếp lớp); giao diện đơn chưa có bước chọn lớp. Kiểm lớp R-GD-08 và màn BH-08 chờ P5b (bảng lớp); hàm `check_order_line_class` giữ chỗ, lớp có giá trị thì báo `HMT_LOP_CHUA_CO_BANG`.
- **QĐ-Đ215 (27/10, anh Trường quyết, phương án A):** `save_order` và `submit_order` giữ như hiện tại: ai có quyền Sửa ở cơ sở của đơn đều sửa, trình được đơn Nháp của đồng nghiệp. Người duyệt vẫn chốt theo NGƯỜI LẬP (R-HT-06). Lịch sử ghi người trình (`submitted_by`). Không thêm luật cấm.
- **QĐ-Đ216 (27/10, anh Trường quyết):** áp bước kiểm độc lập (Đ209) cho mọi PR DB GHI TIỀN hoặc ĐỔI QUYỀN (DB2 phiếu thu, công nợ, ma trận quyền…); KHÔNG áp cho PR chỉ có hàm đọc (như DB1b-2). Số đo từ DB1b-1: 160.137 token, 6 phút 24 giây, tìm ra 5 chỗ lệch luật thật.
- **QĐ-Đ226 (27/10, anh OK):** chiết khấu ở báo giá và đơn theo luật (R-TIEN-29, Đ174): chọn từ danh sách chính sách chiết khấu hiệu lực do DB trả, cộng dồn, trần `discount_total_cap_percent` (mặc định 20%), giờ tặng tính vào trần, một dòng tối đa MỘT chính sách tặng giờ. Vượt trần: `save_quotation` trả cảnh báo, không chặn (D3). Canvas BH-02 phần chiết khấu % cố định bị thay bằng chọn chính sách.
- **QĐ-Đ227 (27/10, anh OK):** Design vẽ khuôn lưới dòng chỉnh sửa và hộp chọn gói trước GV-08. Code làm trước phần chỉ đọc của BH-02.
- **QĐ-Đ228 (27/10, anh OK):** mục "Hay dùng" của hộp chọn gói = N gói người dùng chọn nhiều nhất trên báo giá của mình trong M ngày gần nhất; N và M là tham số cài đặt (`quotation_popular_packages_count`, `quotation_popular_window_days`).
- **QĐ-Đ229 (27/10, anh OK; bản nháp tiêu chí, chưa vào luật):** ba tiêu chí tự xếp mức của BTVN, giáo viên nhập số liệu, hệ thống xếp mức. Mức độ hoàn thành: giáo viên nhập "làm X / tổng Y", hệ thống tính % và xếp theo ngưỡng 20/40/70/90. Độ chính xác: giáo viên nhập điểm thang 10. Thời gian nộp: giáo viên chọn Trước hạn (Mức 5), Đúng hạn (Mức 4), Muộn có gia hạn (Mức 3), Muộn không gia hạn (Mức 2), Chưa nộp (Mức 1); gia hạn do giáo viên ghi riêng.
- **QĐ-Đ230 (27/10, anh OK):** duyệt khuôn P0 mới "K15 Ngăn dưới" (nội dung theo file đề xuất của Design) kèm hai chỉnh: thêm thanh tay nắm ở đầu ngăn (chỉ vuốt xuống từ thanh này để đóng) và nút "Đóng" ở chân thống nhất theo file. Laptop dùng hộp thoại giữa màn. Code chỉ dựng màn dùng ngăn dưới sau khi Design cập nhật khuôn vào gói P0.
- **QĐ-Đ231 (27/10, anh OK):** Design đăng canvas HMT Platform v120: khuôn K06c và 14 khung BH-02 đổi sang lưới chỉnh sửa theo Đ226–Đ228.
- **QĐ-Đ232 (27/10, anh duyệt):** duyệt BH-02 (14 khung P5 đổi bố cục theo Đ226–Đ228) và duyệt khuôn K06c "Lưới dòng chỉnh sửa trực tiếp". Code được dựng phần sửa Nháp của BH-02 theo K06c: hộp "Chọn em", hộp "Chọn gói", hộp "Chọn chính sách", dòng Số lượng theo đơn vị gói, giờ tặng qua chính sách tặng giờ, % có ô nhập khi chính sách không "áp đúng mức", Tổng cộng báo giá từ `preview_quotation_lines`. Dòng chưa chọn em chưa tính giá ("Chọn em để xem giá"). Dòng quà tặng (R-TIEN-30) chưa vẽ: chờ Design, không tự dựng. Giữ Đ212 và mỗi PR một OK sau commit cuối.
- **QĐ-Đ233 (27/10, anh OK):** Design đăng GV-08 điện thoại và khuôn K15 Ngăn dưới (đã duyệt ở Đ230).
- **QĐ-Đ234 (27/10, anh OK):** Design đăng khung KG_K15 (khuôn P0 K15 Ngăn dưới, anh duyệt Đ230) lên canvas Cổng giáo viên.
- **QĐ-Đ235 (27/10, anh OK):** trên canvas HMT Platform, ghi chú "K15 Ngăn dưới nằm ở canvas Giáo viên (KG_K15)" đặt cạnh khung K06c; không thêm file (canvas đang ở 512 file).
- **QĐ-Đ236 (27/10, anh OK):** Design sửa Ghi chú cuối mục 2, 7, 11, 12: bỏ "chờ gộp #90" vì luật #90 đã gộp 26/10; mục 11 ghi Email phụ huynh, ô Mục tiêu/nhu cầu tiếp theo, Lộ trình tiếp theo đã vào luật R-GD-13. Đăng cùng một lượt với KG_K15.
- **QĐ-Đ237 (27/10, anh OK):** khung GV11_dt chỉ báo hiện trạng so với bản đồ GV-11 (Bản ghi K06, hạng B); chưa sửa.
- **QĐ-Đ238 (27/10, anh OK):** tab "Tình hình học tập" ở TT-02 vẽ lại mờ, không có số mẫu, theo R-GD-13: hiện nhưng mờ, chưa dùng, chỉ bật ở giai đoạn Giáo viên.
- **QĐ-Đ239 (27/10, anh OK):** BH-02 có mục "Huỷ báo giá" trong menu Hành động (R-CRM-19, Đ171). Hàm cancel_quotation đã có: huỷ được báo giá Nháp, Đã gửi, Từ chối; ghi chú không bắt buộc; cần quyền Báo giá · Sửa và công tắc Bán hàng bật; báo giá có đơn đang sống thì chặn. Design vẽ trước, Code dựng sau.
- **QĐ-Đ240 (27/10, anh OK):** các PR xếp chồng nhau gộp bằng merge commit (không squash), để khỏi OK lại dây chuyền. PR độc lập vẫn gộp squash.
- **QĐ-Đ241 (27/10, anh OK):** "Đã chuyển đơn" ở BH-01 và cột "Đơn" ở BH-02 làm sau khi #117 gộp, từ main, không chồng PR.
- **QĐ-Đ242 (27/10, anh OK):** cột "Đơn" ở BH-02 hiện mã đơn và trạng thái đơn của dòng cho ai có quyền Xem báo giá; nút mở đơn chỉ hiện khi có quyền Xem đơn hàng.
- **QĐ-Đ243 (27/10, anh OK):** bộ lọc tình trạng của danh sách và xuất báo giá lọc theo tình trạng hiển thị: "Đã chuyển đơn" là một lựa chọn như các tình trạng khác, các lựa chọn nối bằng HOẶC; "Đã gửi" chỉ gồm báo giá chưa chuyển hết sang đơn.
- **QĐ-Đ244 (27/10, anh OK):** Design đăng canvas HMT Platform v124: K06c và 18 khung BH02 có thêm "Huỷ báo giá" (menu Hành động), dòng quà tặng gắn một em, sửa nút Lưu của khung mẫu BH02.
- **QĐ-Đ245 (27/10, anh OK):** khung GV11_dt trên canvas Cổng giáo viên thêm nút "Mở học sinh" ở mỗi dòng học sinh (theo bản đồ GV-11), ghi rõ lịch sử buổi chỉ gồm buổi của giáo viên đó (R-GV-08). Chỉ sửa khung này.
- **QĐ-Đ247 (27/10, anh OK):** kế hoạch dựng sửa Nháp BH-02 theo K06c gồm các PR: A hàm đọc chính sách quà tặng (chỉ đọc), B Huỷ báo giá, C lưới sửa Nháp, D1 dòng quà tặng, D2 màn Tạo báo giá từ cơ hội. Hộp Huỷ dùng khuôn "điền trường" có sẵn; không chứa được thì dừng và báo. Nút "Tạo báo giá" chỉ nằm ở bản ghi cơ hội.
- **QĐ-Đ248 (27/10, anh OK):** BH-02 trên điện thoại giữ bản chỉ đọc, ẩn nút Sửa và Tạo, đến khi Design vẽ lưới điện thoại.
- **QĐ-Đ249 (27/10, anh OK):** mục "In" trong menu Hành động của BH-02 để mờ, ghi "Có khi làm BH-03".
- **QĐ-Đ253 (27/10, anh OK):** khung GV11_dt và GV11_pc trên canvas Cổng giáo viên đều có nút "Mở học sinh" ở mỗi dòng học sinh (dẫn tới GV-13) và câu "Lịch sử buổi chỉ gồm buổi của giáo viên này" (R-GV-08). Bản đồ GV-11 dùng cho cả hai thiết bị nên sửa cả hai khung; Đ245 chỉ nêu GV11_dt, Đ253 mở rộng sang GV11_pc.
- **QĐ-Đ254 (27/10, anh OK):** ở hộp Chọn gói của BH-02, nhóm "Gợi ý theo cơ hội" bỏ đuôi "· Toán lớp 9" của khung mẫu K06c vì hàm DB chỉ trả mã gói gợi ý, không trả nhãn môn và khối. Thêm nhãn sau khi có việc DB khác nếu cần.
- **QĐ-Đ255 (28/10, anh OK):** ở màn sửa và màn tạo báo giá (BH-02), chấp nhận tạm ngoại lệ "mỗi dòng lỗi thêm một lần gọi xem thử giá", vì `preview_quotation_lines` dừng ở lỗi đầu tiên. Nợ kỹ thuật: sửa `preview_quotation_lines` trả lỗi của tất cả các dòng trong một lần gọi, rồi bỏ ngoại lệ.
- **QĐ-Đ256 (28/10, anh OK):** thứ tự làm Bán hàng: BH-06 (danh sách đơn) và DB-O1 trước. Trong lúc chờ Design vẽ lại BH-05, làm BH-03 (In báo giá). Sau đó BH-05 theo các PR nhỏ.
- **QĐ-Đ257 (28/10, anh OK):** Design vẽ lại khung BH-05 theo K06c: bảng dòng không còn cột Mã lớp, Ngày vào lớp; chiết khấu theo chính sách; giờ mua, giờ tặng nhân viên điền. Gồm cả đơn tạo thẳng từ cơ hội. Dựng màn BH-05 chờ khung mới. Lý do: luật thắng canvas (Đ214, Đ226 đến Đ228, R-TIEN-36).
- **QĐ-Đ258 (28/10, anh OK):** bỏ "Hình thức thanh toán" và "Cơ sở thu tiền" khỏi khung đơn; hai trường này thuộc phiếu thu (TC-03), luật không đặt trên đơn, DB không có.
- **QĐ-Đ259 (28/10, anh OK):** "Chuyển thành đơn" từ báo giá mở form trắng, mặc định mọi dòng báo giá chưa vào đơn, bỏ bớt bằng ✕ (khớp canvas BH05_vao, BH05_tao và ý "chọn dòng" trong bản đồ). Chữ ở dòng BH-02 trong `docs/design/ban-do-man-hinh.md` sửa cho khớp.
- **QĐ-Đ260 (28/10, anh OK):** gộp "tạo đơn" và "lưu điều khoản thanh toán" thành một giao dịch (trong DB-O1), để khớp R-CRM-19. Không chấp nhận hai giao dịch có thể để lại đơn Nháp rác.
- **QĐ-Đ261 (28/10, chờ luật):** BH-11 (cơ hội đã có đơn nháp) thiếu luật; Chat soạn luật mới, chờ anh nói "OK ĐƯA VÀO LUẬT <mã>". Chưa dựng BH-11 và chưa viết luật vào `docs/spec` cho tới khi có chữ luật.
- **QĐ-Đ262 (28/10, anh OK):** BH-06 vẫn hiện cột "Đã thu", "Còn phải thu"; ô để "—" (không hiện "0"); bỏ bộ lọc "đã thu đủ/chưa" và nút "Thu tiền" cho tới khi có phiếu thu.
- **QĐ-Đ263 (28/10, anh OK, anh đổi so với đề xuất):** báo giá ở mọi trạng thái (Nháp, Đã gửi, Từ chối, Huỷ) đều In được. Báo giá Nháp in ra thì ô hạn hiệu lực để trống (R-TIEN-05).
- **QĐ-Đ264 (28/10, anh OK):** bản in v1 dùng logo chung HMT (`assets/`), tên và địa chỉ cơ sở; bỏ điện thoại và khẩu hiệu khỏi khung; thêm sau khi có màn quản lý cơ sở.
- **QĐ-Đ265 (28/10, anh OK):** nút "In" và "Tải PDF" cùng mở hộp in của trình duyệt (chọn "Lưu thành PDF"); không thêm thư viện; bỏ ý "ảnh gửi qua tin nhắn".
- **QĐ-Đ266 (28/10, anh OK):** "In" dùng quyền xem báo giá, không tạo quyền mới; hàm đọc nên không bị chặn khi tắt Bán hàng (Đ181); ẩn trên điện thoại (Đ248).
- **QĐ-Đ267 (28/10, anh OK):** Design ghi K13 vào P0 v5 và vẽ lại BH03 theo K06c. Code chưa dựng BH-03 cho tới khi Chat báo khung mới đã đăng.
- **QĐ-Đ268 (28/10, anh OK):** giữ nguyên chữ tiếng Anh "Filters", "Group By", "Favorites", "Save to Favorites" của khuôn K03 (không Việt hoá). Đây là ngoại lệ có chủ đích của khuôn dùng chung, so với quy tắc "chữ trên giao diện bằng tiếng Việt" ở CLAUDE.md.
- **QĐ-Đ269 (28/10, anh OK):** trên bản ghi đơn (BH-05), "Đã thu" và "Còn phải thu" hiện "—" cho tới khi có phiếu thu (như BH-06, Đ262).
- **QĐ-Đ272 (28/10, anh OK):** bỏ yêu cầu Design vẽ lại BH-05, BH-06, BH02_bh11. Đ257 hết hiệu lực, theo Đ272. Canvas HMT Platform phiên bản `1793154455-8ab9` là chuẩn.
- **QĐ-Đ273 (28/10, anh OK):** giữ nhãn trạng thái "BẢN NHÁP", "ĐÃ TỪ CHỐI", "ĐÃ HUỶ" trên bản in báo giá Nháp, Từ chối, Huỷ.
- **QĐ-Đ274 (28/10, anh OK):** BH-03 dùng một khung BH03_in với hàng nút đổi 5 trạng thái: Đã gửi, Đã gửi quá hạn, Nháp, Từ chối, Huỷ; không xoá file nào ở canvas. Chưa dựng BH-03 cho tới khi Chat báo canvas mới đã đăng.
- **QĐ-Đ270 (28/10, anh quyết):** bản khung BH-05 mà anh Trường đã duyệt là bản đang đăng trên canvas HMT Platform (phiên bản `1793154455-8ab9`); không có bản BH-05 nào khác. Bản Design vẽ lại ở máy theo yêu cầu của Chat không đăng.
- **QĐ-Đ271 (28/10, anh OK):** khi bản canvas anh Trường đã chốt với Design khác gói thiết kế và bản đồ màn hình, bản canvas anh chốt thắng; luật (`docs/spec`) và quyết định thiết kế vẫn ở trên.
- **QĐ-Đ275 (28/10, anh OK):** bỏ gợi ý "dùng báo giá còn hiệu lực" ở bước ② của khung BH05_vao_co_hoi: luật không có, R-TIEN-05 nói hạn báo giá chỉ là nhãn, không chặn. Khi dựng BH-05 đường vào từ cơ hội, bỏ gợi ý này và ghi chỗ lệch với canvas vào mô tả PR.
- **QĐ-Đ276 (28/10, anh OK):** sửa CLAUDE.md: thêm hai dòng theo Đ271 và Đ268 (PR riêng).
- **QĐ-Đ277 (28/10, anh OK):** bản in báo giá (K13, BH-03) giữ số điện thoại phụ huynh che giữa như canvas, dạng "0912 *** 345"; không đổi.
- **QĐ-Đ278 (28/10, anh OK):** đổi tài khoản GitHub: (a) TÀI KHOẢN DEPLOY thay hẳn TÀI KHOẢN GỘP cho cả hai repo `hmt-platform` và `hmt-deploy` (**đã sửa bởi Đ279**: chủ repo là TÀI KHOẢN DEPLOY, không thay hẳn); (b) TÀI KHOẢN DEPLOY bật xác thực hai bước, chỉ dùng trên trình duyệt, không đăng nhập trên máy Mac; (c) việc chuyển repo làm sau khi PR tài liệu này gộp (Chat báo anh khi nào chuyển; chưa đổi remote trên máy Mac cho tới lúc đó). TÀI KHOẢN CHỦ DỰ ÁN là collaborator quyền Write ở `hmt-platform`, Claude Code vẫn dùng tài khoản này. Chỉ gộp PR khi CI xanh và có comment "OK" từ TÀI KHOẢN DEPLOY đăng sau commit cuối (thay TÀI KHOẢN GỘP, các luật còn lại về OK giữ nguyên). `PLATFORM_READ_TOKEN` do TÀI KHOẢN DEPLOY tạo trên trình duyệt. PR này vẫn do TÀI KHOẢN GỘP OK theo luật hiện hành.
- **QĐ-Đ279 (28/10, anh OK):** TÀI KHOẢN DEPLOY là chủ hai repo `hmt-platform` và `hmt-deploy` (đã chuyển xong; `PLATFORM_READ_TOKEN` mới đã đặt, báo cáo dùng phút chạy xanh); **tài khoản OK gộp PR vẫn là TÀI KHOẢN GỘP** như cũ. Đ278 (a) sửa lại: không thay hẳn. TÀI KHOẢN GỘP là collaborator của `hmt-platform` (giữ), chỉ dùng trên trình duyệt, không đăng nhập trên máy Mac; TÀI KHOẢN CHỦ DỰ ÁN là collaborator của Claude Code. Chỉ gộp PR khi CI xanh và có comment "OK" từ TÀI KHOẢN GỘP đăng sau commit cuối.
- **QĐ-Đ261 hết chờ luật (28/10):** R-TIEN-39 đã vào `docs/spec/04` (28/10); BH-11 dựng ở UI-O4.
- **QĐ-Đ280 (28/10, anh OK, Q-C1):** các ngoại lệ Đ208, Đ212 (kiểm nhẹ trên máy thay CI khi hết phút Actions) **hết hiệu lực từ 28/10**: CI chạy lại bằng hạn mức Actions của TÀI KHOẢN DEPLOY (repo đã chuyển). Từ nay gộp PR chỉ khi CI xanh ở commit cuối, như CLAUDE.md (kể cả #147). Chạy tay CI trên `main`; xanh thì chạy tay Deploy staging để `hmt-staging` lên đủ migration và giao diện mới; CI `main` trượt thì không chạy Deploy staging, báo Chat tên bài trượt, sửa bằng PR riêng (Đ208 mục e).
- **QĐ-Đ281 (28/10, anh OK, Q-C2):** một PR workflow "Cắt phút CI" (Đ210 #1, #3, #4, #6): Deploy staging không chạy lại job kiểm nhanh (giữ áp migration và bài kiểm cô lập `hmt-prod`); bản xem trước Cloudflare chỉ chạy khi PR đổi file giao diện; Keepalive ba ngày một lần; lệnh `npm run check:all`; `deploy/**` vào paths-ignore của `deploy-staging.yml`; ở `ci.yml` job `changes` (script `scripts/ci-filter.ts`, có bài kiểm) bỏ DB (pgTAP) + Playwright và bản xem trước CHỈ KHI mọi file PR đổi nằm trong `deploy/**`, `docs/**`, `design/**` hoặc là `*.md` (danh sách được bỏ; file lạ, thư mục mới, `.github/`, `scripts/`, chạy tay, không lấy được danh sách file: chạy đủ); **`deploy/` vẫn qua kiểm nhanh vì `format:check` đọc `deploy/` (Q-C3)**; luật "đẩy một lần" (CLAUDE.md, `docs/quy-trinh-phoi-hop.md`): chỉ mở PR hoặc đẩy commit khi `check:all` trên máy đã xanh, sửa theo góp ý gom lại đẩy một lần, không đẩy commit chỉ để thử CI, PR chỉ tài liệu không cần `check:all`. Không bỏ bước kiểm bắt buộc nào, không thêm dịch vụ tốn tiền; chưa làm Đ210 #2, #5; không làm #7. **Q-C5 (28/10, anh OK):** bài e2e chỉ ghi ảnh vào `docs/anh-chup/` khi đặt `SO_SANH_GHI_VAO_REPO=1` (mặc định ra thư mục tạm, như kịch bản so sánh), để `check:all` không ghi đè ảnh của PR cũ; bài `lich-hen` "Mở lại" chập chờn ghi vào TIEN-DO, sửa gốc khi trượt lần nữa.
- **QĐ-Đ282 (28/10, anh OK, Q-B1):** thứ tự gộp: (1) anh OK #146 thì gộp #146; (2) #147 (UI-O2b): cập nhật nhánh từ `main` (gỡ xung đột bảng TIEN-DO), đẩy MỘT lần, chờ CI xanh, báo Chat soát lại phần TIEN-DO, rồi chờ OK của TÀI KHOẢN GỘP sau commit cuối; (3) gộp #147 rồi mới cập nhật nhánh `ci/cat-phut-ci` từ `main` và đẩy; sau khi cập nhật chạy lại lint, typecheck, test, format:check, chỉ chạy lại e2e nếu phần gỡ xung đột đụng code. **Q-B4 (29/10):** ba chỗ chữ ở TIEN-DO (dòng P5a-UI-O2b "Đã gộp (#147)" kèm câu Đ283, dòng BH-05, ghi Q-B4 vào Đ282) đi cùng PR "Cắt phút CI", không đẩy thêm commit vào #147 (để #147 không phải chạy lại CI và chờ OK lại). Nội dung Q-B4 do Claude Code suy ra từ tin của Chat; anh Trường đồng ý làm theo suy đoán đó (29/10).
- **QĐ-Đ283 (28/10, anh OK, Q-B2):** PR DB "DB-O2c" (migration mới), gộp trước UI-O2c. (a) Làm đúng Q-P6 (anh chốt 19/10): `submit_order` thêm `p_acknowledged boolean default false`; đường duyệt TU_DUYET (người lập là Trưởng cơ sở) thì trong CÙNG giao dịch: chuyển Đã duyệt, ghi hai sự kiện "Trình" và "Tự duyệt", chạy đúng mọi việc mà `approve_order` làm khi duyệt (tạo hoặc khớp hồ sơ học sinh, KD6…) và đúng các điều kiện của nó (Đ102: đơn vượt trần hoặc có chính sách cần duyệt mà chưa tích thì chặn `HMT_CAN_TICH_DONG_Y`; xác thực hai bước nếu `approve_order` đòi); tách phần lõi của `approve_order` thành hàm nội bộ dùng chung, không chép code; đường QUAN_LY giữ nguyên hành vi. (b) `get_order` trả thêm `can_submit`, `can_cancel`, `can_approve`, `can_reject`, tính bằng đúng các hàm quyền mà hàm ghi dùng (`assert_can`, `require_feature`, `can_approve_as_manager`, `order_has_receipt`…), không báo lỗi; pgTAP: với từng vai trò và từng trạng thái, mỗi cờ khớp việc hàm ghi tương ứng chạy được hay bị chặn. (c) pgTAP cho (a): Trưởng cơ sở trình là thành Đã duyệt; vượt trần chưa tích thì bị chặn và đơn vẫn Nháp; lịch sử có đủ hai dòng; Sale, CSKH trình vẫn chỉ Đã trình; EXPLAIN cho `get_order`. UI-O2c dùng các cờ này và bỏ phần tự đoán quyền của UI-O2b (`canSubmitOrder`, `canCancelOrder`); nút Trình của Trưởng cơ sở mở hộp BH-07 rồi gọi `submit_order` kèm tích.
- **QĐ-Đ284 (28/10, anh OK, Q-B3):** làm ở DB2 (phiếu thu): `order_has_receipt` trả true khi đơn có phiếu thu chưa Huỷ (Nháp, chờ quản lý, chờ kế toán, Đã duyệt; phiếu bị từ chối đã về Nháp nên cũng tính). pgTAP: có phiếu thu Nháp thì Huỷ đơn bị chặn `HMT_DON_DA_CO_PHIEU_THU`; phiếu thu đã Huỷ thì Huỷ đơn được.

- **QĐ-Đ285 (04/11, anh chốt):** dừng v2 (`hmt-v2`), làm tiếp v1 (`hmt-platform`) cho Cơ sở 5 chạy thật. Thiết kế bám v1; v2 chỉ lấy nghiệp vụ. **Canvas chuẩn là `6f57`** (`1793759210-6f57`, đăng 04/11 09:26), giống hệt bản `8ab9` ngày 28/10 theo Design (cùng sha256 `canvas.json` với bản `bfd4`); thay `8ab9` ở Đ270, Đ272. Lưu ở `design/hmt-canvas-6f57/`. Canvas Đào tạo và Giáo viên bản `8a0d` (`1793184970-8a0d`, đăng 28/10) lưu ở `design/hmt-canvas-8a0d/`. GV07b và GV08b là bản nháp, Design sẽ sửa lại. **(Cập nhật 04/11 chiều)** `8a0d` được thay bằng bản v41 `1793782759-fcd1`, lưu ở `design/hmt-canvas-fcd1/` (xem Đ291). Thư mục `design/nguon-canvas/` giữ như cũ (lịch sử, không phải nguồn chuẩn).
- **QĐ-Đ286 (04/11, anh chốt):** quyết định nghiệp vụ mang từ v2 (04/11) **thắng `docs/spec/`** khi khác nhau; đã đưa vào `docs/spec/04` mục 14 và `docs/spec/06` mục 6. Chỗ chưa rõ hoặc anh chưa chốt đánh dấu [CHỜ]; hỏi anh trước khi làm.
- **QĐ-Đ287 (04/11, anh chốt):** chưa sửa giao diện Báo giá, Đơn hàng, Phiếu thu cho tới khi anh gửi yêu cầu. DB các phần này vẫn làm trước được.
- **QĐ-Đ288 (04/11, anh chốt):** chưa có thiết kế: Aftersale (Design đang vẽ), GV-07 và GV-08 (Design sửa lại), Thu chi TC-06, TC-12, TC-14, TC-16 (chờ anh chỉnh phiếu thu). Màn Nhập dữ liệu CS5 dựng theo khuôn TS-04 và K4b có sẵn.
- **QĐ-Đ289 (04/11, anh chốt):** mốc: 10/11 Tuyển sinh và nạp dữ liệu CS5; ~12/11 Bán hàng, Thu chi; ~17/11 Đào tạo, Cổng giáo viên, Aftersale. Ngày chốt giờ học 17/11. Code nhanh được thì đẩy sớm hơn.
- **QĐ-Đ290 (04/11, anh chốt):** `_inbox/` đã nằm trong `.gitignore` (không commit); đã xoá khỏi `_inbox/` mọi thứ của v2 (`hmt-wireframe-v2*`, thư mục và zip đi kèm). Tài liệu nghiệp vụ v2 (`quyet-dinh-nghiep-vu-tu-v2.md`, `v2-ke-hoach.md`, `v2-danh-gia-hoc-sinh.md`, `v2-aftersale.md`) giữ trong `_inbox/` làm nguồn đọc, không commit.
- **QĐ-Đ291 (04/11, anh chốt):** canvas Đào tạo và Giáo viên bản v41 (`1793782759-fcd1`) thay bản `8a0d`, lưu ở `design/hmt-canvas-fcd1/` (thư mục `hmt-canvas-8a0d` đã xoá; từ 10/11 bản hiện hành là `design/hmt-canvas-9189/`, `fcd1` giữ để đối chiếu). Không đụng canvas `6f57` (Bán hàng, Thu chi chờ anh gửi gói riêng). Trong gói: nhóm GV07X (giáo viên xuất nhận xét PDF hoặc ảnh, tự gửi tay vào group Zalo lớp chung; gửi tự động và nút Chia sẻ là phase sau, không làm); CS-16 "Nhận xét chờ gửi PH" đã bỏ (CSKH không tham gia); công tắc tiêu chí GV-07 chỉ là ô tick tạm; danh mục ticket giáo viên, 12 loại phiếu, thứ tự ưu tiên Aftersale là minh hoạ, chưa chốt, không coi là luật; điều chỉnh học phí hai cấp duyệt đã bỏ; lời nhắn phụ huynh dùng mẫu câu cố định (4 mức × 3 câu, không dùng AI), mức gợi ý theo điểm trung bình tiêu chí (thang 1 đến 5: 4,5 / 3,5 / 2,5) hoặc điểm tổng ÷ tối đa (90% / 75% / 50%), điểm trung bình chỉ dùng nội bộ; GV07b, GV08b không nằm trong gói, không làm. Bảng khác biệt: `docs/nghiep-vu/doi-chieu-canvas-dao-tao-v41.md`.
- **QĐ-Đ292 (04/11, anh duyệt bảng khác biệt `docs/nghiep-vu/doi-chieu-canvas-dao-tao-v41.md`):** (1) giao BTVN tuỳ giáo viên, BTVN để trống = không giao, bỏ điều kiện R-GIO-06, QĐ-Đ22 (ô tích), phần BTVN của bước 2 (R-V2-35); (2) GV-05 giữ hộp xác nhận khi đổi Có mặt thành Vắng (R-V2-36); (3) GV-02 chỉ buổi trong ngày, quá hạn ở GV-12, menu Cần làm thêm số đếm nhỏ, canvas hiện chưa có số đếm ở menu (R-V2-37); (4) cờ Đã xuất lưu DB, một cờ mỗi em mỗi buổi, không lịch sử (R-V2-38); (5) ngưỡng mức gợi ý là tham số Cài đặt, 24 mẫu câu là danh mục nạp sẵn Admin sửa được, so sánh điểm chưa làm tròn (R-V2-39); (6) Aftersale CSN chưa là luật, chờ anh chốt danh mục ticket giáo viên và thứ tự ưu tiên. Chưa viết mã Đào tạo; Bán hàng làm trước Đào tạo.
- **QĐ-Đ293 (05/11, anh chốt):** canvas HMT Platform v146 (`1793854902-9933`) thay `6f57`, lưu ở `design/hmt-canvas-9933/` (thư mục `hmt-canvas-6f57` đã xoá); canvas HMT Bán hàng & Thu chi · bổ sung v2 (`1793860849-8262`) lưu ở `design/hmt-canvas-8262/` (Thu nợ đầu kỳ; từ 07/11 thay bằng gói v6 (nay là `design/hmt-canvas-abea/`, v11) và thư mục `hmt-canvas-8262` đã xoá, Q-61). Khung có ở cả hai thì bản bổ sung thắng. Canvas vênh luật thì làm theo luật. Chi tiết và việc phải làm: `docs/nghiep-vu/doi-chieu-canvas-ban-hang-v146.md`.
- **QĐ-Q165 (09/11, anh làm, Chat báo):** repo `hmt-platform` chuyển từ TÀI KHOẢN DEPLOY sang TÀI KHOẢN CHỦ DỰ ÁN (chủ repo mới). `hmt-deploy` vẫn ở TÀI KHOẢN DEPLOY. TÀI KHOẢN GỘP và TÀI KHOẢN DEPLOY là collaborator của `hmt-platform`; OK gộp PR vẫn từ TÀI KHOẢN GỘP đăng sau commit cuối. Bước kiểm sau chuyển đã chạy: remote git, 7 secret, các biến, workflow, lịch đêm còn bật. Các mục QĐ-Đ278, Đ279, Đ280 ở trên là lịch sử, giữ nguyên chữ TÀI KHOẢN DEPLOY là chủ `hmt-platform` của thời điểm đó.
- **QĐ-Đ294 (23/11, anh chốt; sửa QĐ-Đ21 chỗ «tự Done sau 15 phút»):** giáo viên lưu mục cuối cùng làm đủ bốn bước và buổi đã kết thúc thì buổi chuyển Done NGAY (trừ giờ, đóng dấu Đúng hạn/Trễ hạn ngay), màn giáo viên hết «Cần hoàn tất». Lịch tự Done (pg_cron, mặc định 15 phút) giữ cho buổi không được giáo viên lưu tới bước cuối và buổi chưa hết giờ kết thúc. Quỹ giờ âm lúc Done: lưu của giáo viên vẫn thành công, buổi giữ Đã chốt, lỗi ghi vào `app.session_auto_done_error` cho vận hành. Hai ghi danh cùng lớp của một em: trừ ghi danh cũ trước nếu đủ cho cả buổi, không đủ thì sang ghi danh mới (không tách một buổi qua hai ghi danh; giờ lẻ cũ do vận hành Điều chỉnh giờ); danh sách LOP-09 một dòng mỗi em, giờ còn là tổng các ghi danh còn hiệu lực (Đ157).
