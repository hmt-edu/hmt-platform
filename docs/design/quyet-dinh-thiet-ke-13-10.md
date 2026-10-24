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
Giữ tiếng Anh cho khung Odoo: Sidebar, Topbar, Header, Toolbar, Stage, Sub-stage, Smart button, Filters, Group By, Favorites, Source, Sub-source, **Calendar** (anh chốt 13/10, thay cho "Lịch"). Từ nghiệp vụ HMT dùng tiếng Việt. Nút hành động dùng tiếng Việt. Cột phải ghi tên **"Ghi chú & hoạt động"** (không dùng Lognote & Activity).
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
- **QĐ-Đ22:** GV-06 giữ ô "Buổi này không giao BTVN". Buổi đánh dấu "không giao" thì buổi sau không phải chấm BTVN buổi trước và không chặn Done (R-GIO-06). Là trường dữ liệu mới của buổi. Luật: R-GV-11 (đã vào spec 24/10).
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
