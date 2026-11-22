# Tiến độ HMT Platform

Cập nhật: 23/11/2026 (mục «Trạng thái 23/11/2026» bên dưới là bản mới nhất, liệt kê 284 PR (#85 đến #502) gộp từ 19/11 06:30 tới 23/11 02:25; mục «Trạng thái 19/11/2026» liệt kê 114 PR (#50, #67 đến #203) theo ngày gộp; mục «Trạng thái 16/11/2026» ghi: repo chuyển sang `hmt-edu/hmt-platform`, số PR đánh lại từ #1, ghi các PR đã gộp từ 15/11 tới 16/11 chiều, #1 đến #66; các mục ghi ngày cũ hơn (số PR cũ #2xx) là lịch sử).

**Từ 04/11/2026 (Đ285 đến Đ290): v2 (`hmt-v2`) dừng hẳn; v1 (repo này) làm tiếp cho Cơ sở 5 chạy thật.** Thiết kế bám v1; từ v2 chỉ lấy nghiệp vụ (mục 14 của `docs/spec/04`, thắng các mục khác khi khác nhau). Canvas chuẩn là `design/hmt-canvas-9933/` (v146, thay `6f57`, Đ293; `6f57` thay `8ab9`) và `design/hmt-canvas-9189/` (Đào tạo, Giáo viên, bản hiện hành là nội dung thư mục này; `design/hmt-canvas-fcd1/` v41 `1793782759-fcd1` giữ để đối chiếu, không còn là bản hiện hành; bảng khác biệt: `docs/nghiep-vu/doi-chieu-canvas-dao-tao-v41.md`). Mốc: 10/11 Tuyển sinh + màn Nhập CS5; ~12/11 Bán hàng, Thu chi; ~17/11 Đào tạo, Cổng giáo viên, Aftersale (ngày chốt giờ học 17/11). Bảng khác biệt và kế hoạch theo mốc: `docs/nghiep-vu/doi-chieu-quyet-dinh-v2.md` (chờ anh OK trước khi viết migration). Chưa sửa giao diện Báo giá, Đơn hàng, Phiếu thu khi anh chưa gửi yêu cầu.

## Quy trình (đọc `docs/quy-trinh-phoi-hop.md`)

Mỗi phân hệ đi: Vẽ (Claude Design) → anh duyệt → đặc tả (Claude Chat) → code (PR, anh comment "OK") → staging → chạy thật qua `hmt-deploy`.
Không dựng giao diện khi chưa có thiết kế anh đã duyệt; khuôn P0 không có thì dừng màn đó, ghi PR, báo anh.

## Kế hoạch dựng P0, P1, P2 (anh Trường OK 14/10/2026)

Gói thiết kế hiện hành: `design/hmt-p0-p2/` (PR 0), **bản v2 từ 14/10** (thêm 4 khung mở ra của K1: Filters, Lọc nâng cao, Group By, Cột, Favorites, kèm bản điện thoại; thêm lịch sử phiên bản của Ma trận quyền; ma trận bỏ ô "hiệu lực từ"). Gói P5 cũ `design/hmt-platform/` giữ cạnh bên, chỉ lấy logo
(`assets/hmt-logo-cropped.svg`, bản nền sáng chữ đen + cam). Thứ tự PR:

| PR | Nội dung | Trạng thái |
|---|---|---|
| 0 | Đưa gói thiết kế vào repo | Đã gộp (#19); bản v2 ở PR "Cập nhật gói thiết kế v2" |
| 1 | Hệ thiết kế: token, `hmt-theme.css`, font, icon, build thử Tailwind v4 (PR 4d) | Đã gộp (#21) |
| 2 | Thành phần cơ bản + khung ứng dụng CRM (trang mẫu `/dev/khuon`) | Đã gộp (#22) |
| 3 | Danh sách (K1) + Filters, Group By, Cột, Favorites, Lọc nâng cao; Kanban (K2); Calendar (K5); trang mẫu `/dev/danh-sach` | Đã gộp (#23) |
| 4a | Ô chọn có tìm, ô ngày dd/mm/yyyy (lịch của gói), ô tiền, đính kèm; Kanban: thanh tỷ lệ đầu cột, "chỉ đi tới" là tuỳ chọn | Đã gộp (#24) |
| 4b | Chi tiết (K3: giai đoạn, smart button, Ghi chú & hoạt động có @), các hộp thoại K4 (xác nhận, lý do, điền trường, chặn/cảnh báo, nhiều bước, xem trước tác động, chọn có kiểm tra, cảnh báo trùng SĐT), tấm trượt trên điện thoại; trang mẫu `/dev/chi-tiet`, `/dev/hop-thoai` | Đã gộp (#26). Chưa làm: trang chủ theo vai trò (K09/Đ9, bản tạm, ưu tiên sau); ngăn kéo "Tạo nhanh" (K07b) bỏ theo quyết định 13/10 |
| 5a | Trang chủ theo vai trò (K09b), gồm "Việc tuyển sinh hôm nay" (TS-12) trong trang chủ của Sale: PR riêng, **sau PR dữ liệu, trước khi code P3** (anh chốt 16/10) | Đã gộp (PR Trang chủ theo vai trò): khung theo K09b, khối lịch hẹn (thẻ số HÔM NAY, QUÁ HẠN, danh sách 5 dòng), khối hiện theo quyền và công tắc tính năng, Admin xem thử bố cục vai trò khác. Các khối cơ hội, phiếu kiểm tra, ticket, phiếu thu, buổi chưa điểm danh, việc chờ duyệt thêm khi phân hệ có dữ liệu |
| 5 | P1 đăng nhập: 5a form + hai bước, 5b khoá + phiên + cổng, 5c nền động | 5a đã gộp (#41: khung hai cột, đăng nhập nhân viên và học sinh, hai bước 2 bước, hàm công khai tên cơ sở); 5b đã gộp (#43: quên mật khẩu chỉ hướng dẫn liên hệ quản trị viên, đổi mật khẩu lần đầu, không thể đăng nhập, hết phiên có số thời gian theo nhóm vai trò, chọn cổng; sửa nền cột giới thiệu); 5c chưa |
| 6 | PR dữ liệu: bảng đối chiếu đủ 34 danh mục với spec 06, nạp danh mục thiếu (kể cả L5P, L6 đánh lại A–F, danh mục 33 "Lý do bỏ qua test" theo luật 16/10), "phiên bản" ma trận quyền | Đã gộp (6.0 đến 6e: #28 đến #33) |
| 6.0 | Nạp danh mục theo luật 16/10 (migration `20261016000017`): nhóm con L5P, L6 đánh lại A–F (bỏ L6G), L5B "Đã xếp lịch test", danh mục 33 "Lý do bỏ qua test" (mã `TEST_SKIP_REASON`); 18 bài pgTAP. Ngoại lệ một lần với nguyên tắc "mã không đổi nghĩa", chỉ vì hệ thống chưa chạy thật | Đã gộp (#28) |
| 6a | Danh mục sửa lệch: Môn, Khối, Trình độ thành Khoá; khoá mục cha giai đoạn lead và cơ hội, khoá C4D; C4C, C4D đổi chữ "opp" thành "cơ hội"; hai cột mới của mục danh mục (`requires_note`, `applies_to`); sửa dòng #30 của spec 06. migration `20261016000018` + 20 bài pgTAP | Đã gộp (#29) |
| 6b | Danh mục phẳng nạp theo spec 06: #8 Loại gói, #14 Hình thức test, #15 Cấp độ đề test, #17, #21, #22, #23, #24, #25, #26, #28, #31, #32 (13 danh mục, migration `20261016000019`, 21 bài pgTAP). #14, #15 tách riêng; #2 Phòng học để rỗng ở bản chạy thật; #30 nạp dần theo giai đoạn; #27 làm cùng phiếu thu | Đã gộp (#30) |
| 6c | Danh mục hai cấp: #12 Giai đoạn phiếu tái tục (8 + 5 nhóm con), #19 Nhóm đề nghị (7 nhóm, 15 nhóm con; 12 nhóm con có nghiệp vụ bị khoá theo R-CS-11), #20 Nhóm khiếu nại (7 nhóm, 25 nhóm con); #23 Lý do huỷ buổi gắn `applies_to` (TRUNG_TAM, HOC_SINH). Migration `20261016000020`, 29 bài pgTAP | Đã gộp (#31) |
| 6d | Phiên bản ma trận quyền: hàm `app.save_permission_matrix` (một lần Lưu = một phiên bản, hiệu lực ngay, hoàn tác cả lần nếu một ô sai, chặn ghi đè khi có người vừa lưu), bảng `permission_version`, `permission_change` (chỉ thêm, chỉ Quản trị đọc); `app.set_permission` thành hàm nội bộ. Migration `20261016000021`, 34 bài pgTAP mới | Đã gộp (#32) |
| 6e | Tách phân hệ quyền: thêm Cấu hình bán hàng, Cấu hình đào tạo, Ngày nghỉ lễ, Lịch hẹn (quyền theo bảng anh duyệt 16/10, nạp thành phiên bản 2 gồm 57 ô); menu Cấu hình, Ngày nghỉ lễ, Lịch hẹn đổi sang phân hệ mới; luật ADMIN luôn giữ đủ quyền Quản trị; chặn xoá, xoá sạch lịch sử phiên bản. Migration `20261016000022`, 25 bài pgTAP và 4 bài Vitest | Đã gộp (#33) |
| P3a | Tài liệu P3 Tuyển sinh: luật 04c (R-CRM-04, 05, 06, 11, 12, 14, 15 sửa; R-CRM-21…24 mới) vào spec 04; spec 06 (L5Q, danh mục 13 thêm 2 lý do, danh mục 34); đặc tả `docs/design/dac-ta/P3-tuyen-sinh.md`; gói thiết kế `design/hmt-p3/`; sửa `luat-cho-thiet-ke.md`, `ban-do-man-hinh.md`; mục "Hiệu năng" của CLAUDE.md (commit riêng) | Đã gộp (#34) |
| P3b1 | Dữ liệu nền: danh mục (L5Q, 2 lý do huỷ test, danh mục 34, tên tình trạng phiếu), mã LD/CO/PKT, 6 tham số, bảng chiến dịch, phụ huynh, học sinh, lead, lịch hẹn; hàm lead, lịch hẹn, kiểm trùng SĐT, giao người phụ trách, danh sách phân trang; RLS; seed lớn `db:seed-lon`; EXPLAIN. Migration `20261017000023`…`026` (026: ma trận quyền phiên bản 3, 15 ô, anh duyệt 17/10), 163 bài pgTAP mới. Sửa R-CRM-10 (bỏ "từ chối") | Đã gộp (#35) |
| Nguồn Design | Lưu nguồn canvas Design (P4, P5a, P5b) và nhật ký bàn giao | Đã gộp (#37) |
| Tách gói tải | Tách gói tải theo cổng và màn (trang đầu CRM 295 → 235 KB nén; `npm run size`, bước CI chỉ báo số, chưa ngưỡng). Luật 04d đến 04g đã vào spec ở PR "Đưa luật 17/10" | Đã gộp (#36) |
| Luật 17/10 | Đưa luật 04d đến 04g vào `docs/spec/04`, `02`, `06`, bản đồ màn hình, `phan-quyen.md`: R-CRM-22, 25 đến 33; R-GD-01, 02, 03, 14, 15, 18; R-LOP-08, 09, 13, 14, 15; tham số `class_slot_repeat_weeks_max`; mục chờ anh quyết giữ ghi chú (không thành luật); xoá thư mục chờ | Đã gộp (#39) |
| Bàn giao 17/10 | Nhật ký Design (kiểm lại phiên bản canvas), nhật ký Chat, quy trình mục 13 bản 2 (đổi tài khoản: mở canvas gốc đã Share trước; Design đẩy nhánh mới từ `main`), `khoi-dong-design.md` | Đã gộp (#40) |
| Nền tảng phối hợp | `docs/nhat-ky/` (ba file), `docs/phoi-hop/` (khởi động Chat, Design, prompt, luật chờ đưa vào spec), quy trình phối hợp mới, TIEN-DO | Đã gộp (#38) |
| P3b2a | Cơ hội: bảng `app.opportunity` (mã CO, RLS, 14 chỉ mục có lý do), lịch hẹn gắn được cơ hội; hàm tạo (R-CRM-01, 09), sửa, đổi giai đoạn và nhóm con (R-CRM-02, 03, 13, 14, 16; ba ngoại lệ đổi nhóm con), giao người phụ trách, danh sách và Kanban một lần gọi; tìm hoặc tạo phụ huynh, học sinh (R-CRM-27, 28); khoá nhóm con; `seed-lon` thêm 20.000 cơ hội; sửa hiệu năng `list_leads`. Migration `20261018000028`, 134 bài pgTAP | Đã gộp (PR P3b2a) |
| Ma trận v4 | Bảng quyền phiên bản 4 (17 ô Phụ huynh, Học sinh; R-CRM-26, 27, 29): migration `20261018000029`, bài pgTAP 021, chỉnh bài 017, 018, `phan-quyen.md` | Đã gộp (PR Ma trận quyền phiên bản 4) |
| P3b2b | Phiếu kiểm tra: bảng `app.student_test` (mã PKT, RLS có phạm vi được phân công), lịch hẹn nhắc tự sinh (gắn phiếu), hàm tạo / đổi lịch / sửa / bắt đầu / nộp bài / nhập kết quả / hoàn thành / lùi bước / huỷ / mở lại, danh sách và Kanban, thay thân `opportunity_test_state` và `opportunity_l5_substage`, cơ hội tự lên L6A khi phiếu hoàn thành; R-CRM-05, 06, 10, 11, 12, 13, 14, 15, 21, 27; `seed-lon` thêm 10.000 học sinh, 15.000 phiếu. Migration `20261018000030`, 174 bài pgTAP mới | Đã gộp (PR P3b2b) |
| P3b3a | Gộp trùng lead, cơ hội, học sinh, phụ huynh (R-CRM-22, 25, 37): bốn hàm gộp, xem trước, bản "Đã gộp" chỉ đọc và tìm được bằng mã, ghi chú chuyển sang chỉ trong hàm gộp, ghi chú hệ thống trên cả hai bản; lịch nhắc tự sinh của phiếu tự đóng bằng Huỷ khi phiếu sang Đang test. Migration `20261018000031`, 131 bài pgTAP mới | Đã gộp (PR P3b3a) |
| P3b3b | Nhập lô lead từ file: `import_leads` (xem trước và nhập cùng một đường mã qua `create_lead`, bỏ dòng lỗi và dòng trùng SĐT, tối đa 500 dòng, một giao dịch), quyền Lead · Tạo (CSKH nhập được), bảng nhật ký nhập `lead_import_log`. Migration `20261019000032`, 53 bài pgTAP mới. Giao diện đọc CSV ở P3f. **Làm trước các màn P3c đến P3f** (anh chốt 18/10) | Đã gộp (PR P3b3b) |
| P3c-1a | Dữ liệu màn Lead danh sách và Kanban: bộ lọc mới của `list_leads` (kênh, chiến dịch, lịch hẹn kế tiếp, quá hạn, chưa có lịch, chỉ bản đã gộp), `lead_board` (kèm số đếm thanh màu trên cả cột), `lead_group_counts` (Group By hai cấp), `list_assignable_staff`, `export_leads` (tham số `export_max_rows` 5.000), bài kiểm C4 không tự gắn C4D | Đã gộp (PR P3c-1a) |
| P3c-1b | Màn `/crm/lead`: danh sách (TS-01) và Kanban (TS-01b) nối cơ sở dữ liệu (lọc, sắp xếp, trang 50, Group By, tổng và thanh màu từ máy chủ), hộp Giao (TS-05, dùng lại cho cơ hội), Xuất CSV (`export_leads`, chỉ ai có quyền Xuất), bản "Đã gộp" mờ, kéo thả C1 đến C4 kèm Hoàn tác; ẩn nút Tạo, Nhập và dấu "+"; migration `034` (lọc nhiều lựa chọn cùng nhóm, R-CRM-07); P0 v5 số 12, 13, 14 và một nửa số 2 | Đã gộp (PR P3c-1b) |
| P3c-2a | DB cho trang Lead: `get_lead`, dời lịch hẹn đổi người phụ trách và ghi chú (R-CRM-38, migration `035`); tách riêng gộp trước để bản xem trước của PR giao diện chạy được | Đã gộp (PR P3c-2a) |
| P3c-2b | Giao diện: trang Lead (TS-02), Tạo lead (TS-03) kèm hộp trùng SĐT (TS-14), hộp Tạo và Dời lịch hẹn (TS-13), Huỷ lịch hẹn chọn lý do, đổi giai đoạn và nhóm con kèm Hoàn tác; đường dẫn trên thanh trên cho trang con; Tỉnh trên Phường, ô bắt buộc viền cam, khu Stage đầy đủ chiều ngang, bấm cả dòng mở lead; sửa lỗi hiện câu chung thay câu nghiệp vụ (`errorOf`) | Đã gộp (PR P3c-2b) |
| P1-sửa | Sửa nhóm đăng nhập theo gói hiện hành `design/hmt-p0-p2` (DN01 đến DN10, máy tính và điện thoại): ô và nút cao 44px, nhãn không dấu `*`, nút con mắt, câu lỗi trên các ô, liên kết căn giữa, DN03/DN04/DN05/DN07/DN08/DN09/DN10 đúng chữ và bố cục; 28 ảnh so sánh `docs/so-sanh/DN*.jpg` | Đã gộp (PR P1-sửa) |
| P3c-3b | Màn `/crm/lich-hen` (TS-11): danh sách chia nhóm Quá hạn / Đã qua / Hôm nay / Sắp tới (TS11b), Kanban ba cột (TS11c), Lịch ngày, tuần, tháng (TS11_K5); Hoàn thành một bấm, Dời, Huỷ chọn lý do, **Mở lại** có xác nhận (R-CRM-04); tìm tên, SĐT, mã; lọc loại hoạt động, người phụ trách, cơ sở, thời gian; dải "Còn N lịch Quá hạn đang bị ẩn" kèm nút Xem; **Tạo** gắn với một lead (ô tìm ở máy chủ); nút "Lịch hẹn" trên trang Lead mở danh sách chỉ của lead đó; 3 ảnh so sánh `docs/so-sanh/TS11*_pc.jpg` | Đã gộp (PR P3c-3b) |
| P3d-1 | DB màn Cơ hội (migration `038`): `get_opportunity`, `list_opportunities` và `opportunity_board` mở rộng bộ lọc như Lead (nguồn, chiến dịch, lịch hẹn dạng HOẶC, tôi phụ trách/hỗ trợ, chỉ bản đã gộp, thanh màu Kanban), `opportunity_group_counts`, `export_opportunities`; bài kiểm 030, EXPLAIN trên seed lớn | Đã gộp (PR P3d-1) |
| P3d-2 | Màn `/crm/co-hoi` (TS-07 danh sách, Group By, Xuất, Assign hàng loạt; Kanban L1–L8 chỉ đi tới, L6 do hệ thống chuyển), trang Cơ hội (TS-08: thanh giai đoạn khoá bước đã qua, nhóm con theo R-CRM-15, 17, 34, 35, sáu nút liên kết, Sửa thông tin học sinh, tab Kiểm tra đầu vào chỉ đọc, ghi chú và lịch hẹn), hộp chuyển giai đoạn TS-09 đủ năm dạng (R-CRM-03, 12, 14, 16), Tạo cơ hội từ lead TS-06 kèm cảnh báo đã có cơ hội (R-CRM-01), ô "Gắn với" của Lịch hẹn chọn được cơ hội; 10 ảnh so sánh `docs/so-sanh/TS0*_pc.jpg` | Đã gộp (PR P3d-2) |
| Nợ nhỏ P3c, P3d | Sửa gốc lỗi bài kiểm chập chờn: hộp Tạo lịch hẹn chốt loại hoạt động mặc định lúc mở, danh mục tải sau thì ô trống mãi (cả người dùng thật gặp khi mạng chậm), nay lấy mặc định theo danh mục đang có; bài tái hiện bằng cách làm chậm danh mục; Playwright chờ kết quả tối đa 10 giây; Hoàn tác sau Hoàn thành, Huỷ ở Lead, Cơ hội, Lịch hẹn | Đã gộp (PR nợ nhỏ) |
| P3e-1 | DB màn Phiếu kiểm tra (migration `039`): `get_student_test`, `list_student_tests` và `student_test_board` thêm lọc nhiều lựa chọn (tôi tạo, tôi phụ trách, tôi chấm; quá hạn, hôm nay, sắp tới; môn, hình thức, cấp độ), `student_test_group_counts`, `export_student_tests`, `list_test_graders`, `list_test_rooms`; bài kiểm 031, EXPLAIN trên seed lớn | Đã gộp (PR P3e-1) |
| P3e-2 | Giao diện Phiếu kiểm tra (`/crm/phieu-kiem-tra`): danh sách + Kanban (đếm theo cột) + Lịch (TS-16), trang phiếu (TS-17: thanh trạng thái chỉ đọc, Nhập kết quả, Hoàn thành, Lùi bước, Huỷ, Mở lại, Đổi lịch, Sửa), tạo phiếu từ cơ hội (TS-15); mở khoá mã phiếu, nút "Mở phiếu" ở trang Cơ hội, hộp chặn L7, màn Lịch hẹn lọc theo phiếu | Đã gộp (PR P3e-2) |
| P3f-1 | DB hộp Gộp trùng (migration `040`): `merge_candidates` (gợi ý bản trùng, chỉ trong phạm vi xem của người gọi), `merge_preview` thêm so sánh hai bên và danh sách lịch hẹn, ghi chú sẽ chuyển, tham số `merge_preview_max_items`; bài kiểm 032 (50 bài), EXPLAIN trên seed lớn | Đã gộp (PR P3f-1) |
| P3f-2 | Giao diện: hộp Gộp trùng lead, cơ hội (TS-10; Hành động → Gộp trùng ở trang Lead và Cơ hội, quyền Duyệt) và hộp Nhập lead từ file CSV (TS-04; nút Nhập ở màn Lead cho ai có quyền Tạo; 3 bước, xem trước bằng `import_leads`) | Đã gộp (PR P3f-2) |
| Lịch hẹn bổ sung-1 | DB (migration `041`): `export_appointments` (Xuất, ghi nhật ký xuất), `appointment_group_counts` (Group By 1 đến 2 cấp: trạng thái, loại hoạt động, người phụ trách, cơ sở, loại hồ sơ gắn), `assign_appointments` (giao hàng loạt: chỉ lịch Chưa làm, không giao tay lịch nhắc tự sinh của phiếu, trả số giao được và lý do từng nhóm bị bỏ), `list_appointments` thêm bộ lọc `kind`; `reschedule_appointment` chặn đổi người phụ trách lịch nhắc tự sinh (Đ37); bài kiểm 033 (77 bài), EXPLAIN trên seed lớn | Đã gộp (#80) |
| Lịch hẹn bổ sung-2 | Giao diện màn Lịch hẹn: nút Xuất (CSV, theo bộ lọc), Group By ở máy chủ (trạng thái, loại hoạt động, người phụ trách, cơ sở, loại hồ sơ; Đ35), chọn hàng loạt kèm Giao việc (kết quả nêu lý do từng nhóm bị bỏ; Đ33, Đ36), Lịch "Theo người" ở chế độ Ngày (người có lịch trong ngày, trong phạm vi xem theo ma trận quyền; Đ34, Đ38; cuộn ngang; bỏ "Theo phòng", "Nhập"). Sửa lỗi Group By của màn Phiếu kiểm tra (mở nhóm ra mọi phiếu) | Đã gộp (#81) |
| Quản trị người dùng-1 | DB (migration `042`): `list_users`, `get_user` (QT-01, QT-02), `export_users` (chỉ Admin, Đ45; ghi nhật ký xuất), `admin_revoke_sessions` và `admin_reset_mfa` (Thu hồi phiên, Đặt lại hai bước bằng hàm DB, chặn thao tác lên chính mình; Đ49, Đ50), tham số `user_login_history_rows`; bài kiểm 034 (78 bài), EXPLAIN trên 5.000 tài khoản; bước thử quyền ghi bảng Auth trên hmt-staging ở deploy-staging | Đã gộp (#82); bước thử quyền ghi bảng Auth trên hmt-staging: ĐẠT (24/10) |
| Quản trị người dùng-2 | Giao diện QT-01 (danh sách, lọc, tìm, Xuất CSV, Khoá, Mở khoá ngay ở dòng), QT-02 (bản ghi: thông tin, lịch sử đăng nhập; Hành động: Sửa vai trò, Đổi cơ sở, Quản lý trực tiếp, Khoá, Mở khoá, Thu hồi phiên, Đặt lại hai bước); màn mở ở mục menu "Người dùng" (Đ46). **Chưa làm, chờ khuôn K4g, K4e4 ở #69: Đặt lại mật khẩu (QT-02) và Tạo người dùng (QT-03)** (không có nút Tạo, không có mục Đặt lại mật khẩu) | Đã gộp (PR Quản trị người dùng-2) |
| P5a-DB0 | Cấu hình bán hàng (migration `044`): gói (không số giờ, không loại lớp), bảng giá có ngày hiệu lực, chiết khấu (`fixed_value`), quà tặng, điều khoản thanh toán (đợt 1 cọc cố định, các đợt sau %), đơn vị theo loại gói (Đ101), sáu hàm ghi của Admin; danh mục "Lý do huỷ đơn" và `applies_to` lý do từ chối (Đ103, Đ104); tham số `debt_due_soon_days`; ma trận quyền phiên bản 5 (Đ105); bài kiểm 036 (122 bài), EXPLAIN trên `seed-lon`. Chưa có màn CH-01 đến CH-09 | Đã gộp (#89) |
| P5a-DB1a | Báo giá (migration `045`): bảng báo giá, dòng, chiết khấu từng dòng; `price_line` (nơi duy nhất tính tiền, DB1b dùng lại); lưu, gửi, từ chối, huỷ; danh sách, bản ghi, xuất; `opportunity_sales_documents` trả mã báo giá thật; bài kiểm 037 (161 bài), EXPLAIN trên `seed-lon`. Công tắc BAN_HANG kiểm trong hàm ghi (Đ173); Gửi tính lại theo giá ngày Gửi (Đ175); làm tròn (Đ176). Chưa có giao diện | Đã gộp (#91) |
| P5a-DB1c | Danh sách báo giá trả `student_names` (mảng tên các em theo thứ tự dòng) cho cột Học sinh của BH-01 (migration `053`). | Đã gộp (#108) |
| P5a-DB1b-1 | Đơn hàng, bảng và hàm ghi (migration `051`): đơn, dòng, chiết khấu, lịch đóng tiền, lịch sử; tạo từ báo giá Đã gửi (sao nguyên giá, R-TIEN-14) hoặc thẳng từ cơ hội L8; lưu, trình (chốt người duyệt, Đ205), duyệt (tạo hoặc khớp hồ sơ học sinh, KD6), từ chối, huỷ (R-TIEN-38); bài kiểm 043 (148 bài), `seed-lon` thêm 8.000 đơn, EXPLAIN. Lớp (R-GD-08) chờ bảng lớp P5b, phiếu thu chờ DB2. **Đ214: tuần này đơn chưa chọn lớp (em vào hàng chờ xếp lớp); giao diện đơn chưa có bước chọn lớp; kiểm lớp R-GD-08 và BH-08 chờ P5b.** Đ215: ai có quyền Sửa ở cơ sở đều sửa, trình được đơn Nháp của đồng nghiệp. Hàm đọc, xuất ở DB1b-2 | Đã gộp (#107) |
| P5a-DB1b-2 | Đơn hàng, hàm đọc và xuất (migration `052`): `get_order`, `list_orders` (phân trang, lọc, chờ tôi duyệt), `export_orders` (Đ105); bài kiểm 044 (87 bài), EXPLAIN trên `seed-lon`. Không áp kiểm độc lập (Đ216, chỉ hàm đọc) | Đã gộp (#114) |
| P5a-UI-1 | BH-01 Báo giá (danh sách): khuôn K03 nối `list_quotations`, lọc, tìm, Xuất theo quyền, mục menu theo công tắc Bán hàng; ảnh chụp ở `docs/anh-chup/bh01/`. | Đã gộp (#109) |
| P5a-DB1c-3 | Lọc Đã chuyển đơn cho danh sách và xuất báo giá (migration `054`): khoá `converted` của `list_quotations`, `export_quotations` (đọc `quotation_converted`); 18 bài kiểm 047 (đúng, bị chặn, phạm vi). Tuỳ chọn trên giao diện BH-01 làm sau khi PR gộp. | Đã gộp (#115) |
| P5a-DB1c-2 | Hàm chỉ đọc cho BH-02 (migration `055`): xem thử báo giá (cùng `price_line`, không ghi gì), gói bán và "Hay dùng" (Đ228), chính sách chiết khấu hiệu lực (Đ226), ghi chú và lịch sử cho báo giá; bài kiểm 046 (80 bài), EXPLAIN. Mã đơn từng dòng: P5a-DB1c-4 | Đã gộp (#110) |
| P5a-UI-2a | BH-02 Báo giá (bản ghi) chỉ đọc: khuôn K06, khối thông tin hai cột, bảng Gói học, tổng tiền, Ghi chú và hoạt động; ảnh chụp ở `docs/anh-chup/bh02/`. Phần sửa Nháp chờ canvas mới (K06c, Đ232). | Đã gộp (#111) |
| P5a-UI-3 | BH-02: nút Gửi (Nháp) và Từ chối qua hộp BH-04 (Đã gửi, chưa lên đơn); lý do từ chối chỉ lấy mục áp dụng cho báo giá. Chưa có: Huỷ báo giá (Đ239: menu Hành động, chờ Design vẽ), Chuyển thành đơn (chờ màn Đơn hàng), phần sửa Nháp (khuôn K06c, Đ232, chờ canvas mới trong repo). | Đã gộp (#116) |
| P5a-DB1c-4 | `get_quotation` trả mã đơn đang sống của từng dòng và số đơn đang sống (migration `056`); bài kiểm 048 (15 bài). | Đã gộp (#117) |
| P5a-DB1c-5 | Lọc tình trạng báo giá theo tình trạng hiển thị (Đ243, migration `057`): `status` của `list_quotations`, `export_quotations` nhận `DA_CHUYEN_DON`, nối bằng HOẶC, `DA_GUI` không gồm báo giá đã chuyển hết; 24 bài kiểm 049. Sau khi gộp mới sửa #118 dùng giá trị mới. | Đã gộp (#119) |
| P5a-UI-4 | BH-01: lọc nhanh và điều kiện lọc có "Đã chuyển đơn" (tình trạng hiển thị, Đ243: gửi trong `status`, nối bằng HOẶC). BH-02: cột "Đơn" (mã và trạng thái đơn đang sống của dòng, Đ242) và số trên nút Đơn hàng. Chưa có: nút mở đơn (chờ màn Đơn hàng BH-05). | Đã gộp (#118) |
| P5a-DB1d | Hàm đọc chính sách quà tặng cho hộp Chọn chính sách quà tặng của BH-02 (migration `058`, Đ247 PR A): `list_applicable_gift_policies`; câu lỗi quà vượt mức in "không quá 2." (đổi một chỗ trong `price_line`, luật giá giữ nguyên); 24 bài kiểm 050. Tiếp theo: B Huỷ báo giá, C lưới sửa Nháp, D1 quà tặng, D2 Tạo báo giá từ cơ hội. | Đã gộp (#123) |
| P5a-UI-5 | BH-02: menu Hành động có "In" (mờ, "Có khi làm BH-03", Đ249) và "Huỷ báo giá" (khung ⑥ của K06c, Đ239, PR B của Đ247): hộp xác nhận có ô Ghi chú không bắt buộc, nút "Xác nhận huỷ" viền; có đơn đang xử lý thì hộp báo lỗi và không đóng; sau huỷ chỉ còn xem. Chỉ cho báo giá Nháp, Đã gửi, Từ chối, có quyền Sửa và công tắc Bán hàng. | Đã gộp (#124) |
| P5a-DB1e | `price_line` trả thêm `total_discount_percent` (migration `059`) để BH-02 hiện Tổng chiết khấu mà giao diện không tự cộng; 10 bài kiểm 051. Làm trước PR C (lưới sửa Nháp). | Đã gộp (#125) |
| P5a-UI-6 (C1) | BH-02 sửa Nháp, phần 1 của PR C (Đ247): bấm Sửa thì thành lưới K06c (máy tính; điện thoại giữ chỉ đọc, Đ248): chọn em, hộp Chọn gói (Hay dùng, Gợi ý theo cơ hội, Tất cả gói, lọc loại), hình thức, số lượng kèm đơn vị, Thêm dòng, ✕, Lưu, Huỷ; thiếu số lượng báo lỗi theo khung. Chính sách chiết khấu, giờ tặng, Tổng cộng, tính xem thử, trạng thái đang tính và vượt trần: C2. Xếp chồng trên #124 và #125. | Đã gộp (#127) |
| P5a-UI-7 (C2) | BH-02 sửa Nháp, phần 2 của PR C (Đ247): hộp Chọn chính sách chiết khấu (chọn nhiều, tối đa một chính sách tặng giờ), chip chính sách có ô nhập %, giờ tặng, Tổng chiết khấu / trần, vượt trần (viền cam, vẫn lưu được), xem thử giá bằng `preview_quotation_lines` (đang tính, lỗi từng dòng nêu đúng dòng, lỗi mạng có Thử lại), dòng chưa chọn em ghi "Chọn em để xem giá", Tổng cộng báo giá do máy chủ trả. Còn: D1 dòng quà tặng, D2 Tạo báo giá từ cơ hội. | Đã gộp (#129) |
| P5a-UI-8 (D1) | BH-02 sửa Nháp: dòng quà tặng (PR D1 của Đ247, R-TIEN-30): nút "Thêm quà tặng" mở hộp Chọn chính sách quà tặng (hàm `list_applicable_gift_policies`); dòng quà gắn một em, số lượng từ 1 đến mức tối đa, giá 0 đ, ngoài trần chiết khấu; lỗi vượt mức "Dòng N: số lượng quà không quá M." do máy chủ trả; quà cần duyệt chỉ ghi "· cần duyệt". D2 đã gộp (#131). | Đã gộp (#130) |
| P5a-UI-9 (D2) | Tạo báo giá từ cơ hội (PR D2 của Đ247, R-CRM-19, R-TIEN-02): nút "Tạo báo giá" trên bản ghi cơ hội (máy tính; điện thoại ẩn, Đ248) mở form trắng `/crm/bao-gia/tao?co-hoi=…` (khung BH02_tao); chỉ Lưu mới tạo báo giá Nháp và cấp mã, Huỷ bỏ hết và về cơ hội; danh sách báo giá không có nút Tạo. Dòng mới mặc định em đầu của cơ hội (R-TIEN-35). Chỉ nhánh gốc cơ hội; nhánh gốc phiếu tái tục (TT-02, L6 và L7) làm riêng, chờ bảng phiếu tái tục (P5b). | Đã gộp (#131) |
| P5a-UI-O1 (BH-06) | Danh sách đơn hàng (khuôn K03; `list_orders`, `export_orders`): Nháp, Đã trình, Đã duyệt, Huỷ (Từ chối là Nháp, R-TIEN-06); cột Đã thu, Còn phải thu để "—" và bỏ bộ lọc đã thu đủ, nút Thu tiền cho tới khi có phiếu thu (Đ262); không có nút Tạo (R-TIEN-02). | Đã gộp (#135) |
| P5a-DB-O1a | Chỉ đọc (migration `060`, Đ256): hàm kiểm quyền chung của bốn hàm đọc phụ cho phép Báo giá HOẶC Đơn hàng Tạo/Sửa; `list_orders` trả thêm `student_names`. Bài kiểm 052. Ma trận quyền không đổi. | Đã gộp (#136) |
| P5a-DB-O1b | Đụng đường ghi đơn (migration `061`): `find_student_match`, `order_student_duplicates`, `preview_order_students`, tạo đơn kèm điều khoản trong một giao dịch (Đ260); có kiểm độc lập (Đ209, Đ216). Bài kiểm 053. | Đã gộp (#137) |
| P5a-DB-O1c | Chỉ đọc (migration `062`, Đ270, Đ271): `get_quotation` và `get_order` trả thêm `gross_total`, `discount_total` (DB cộng từ dòng đã đóng băng, quà tặng không tính); `get_order` của đơn Nháp trả `expected_route` (QUAN_LY, TU_DUYET, THIEU), người duyệt dự kiến và `expected_approver_can_approve`, tính đúng như `submit_order` chốt người duyệt (R-HT-06), người lập chưa có quản lý thì THIEU, không lỗi; ghi chú và lịch sử cho đơn (`SALES_ORDER`) giống hệt báo giá. pgTAP `054` (77 bài). | Đã gộp |
| P5a-UI-11 | BH-03 In báo giá (K13, A4 dọc), route `/crm/bao-gia/:id/in`: khuôn dùng chung `src/print/PrintSheet` (dải cam, logo chung HMT, tên và địa chỉ cơ sở từ DB, không điện thoại cơ sở, không khẩu hiệu), bảng dòng theo K06c, quà tặng giá 0, hai dòng Tổng niêm yết và Tổng chiết khấu (`get_quotation` migration 062, trình duyệt không cộng), số tiền bằng chữ (`amountInWords`, chỉ đọc lại tổng máy chủ trả, R-TIEN-13), mã cũ cạnh số. In được ở mọi tình trạng (Đ263); nhãn BẢN NHÁP, ĐÃ TỪ CHỐI, ĐÃ HUỶ, Nháp để trống hạn, "Đã quá hạn N ngày" khi quá hạn (Đ273). "In" và "Tải PDF" cùng mở hộp in của trình duyệt (`window.print`), ghi chú "Chọn “Lưu thành PDF” để tải"; nút "In" ẩn trên điện thoại. Mục "In" ở menu Hành động BH-02 đã bật (Đ249). Không dựng cột ghi chú bên phải và dãy nút đổi trạng thái của khung (chỉ để xem mẫu). | Đã gộp |
| P5a-UI-O2a (BH-05, xem đơn) | Bản ghi đơn `/crm/don-hang/:id` (khuôn K06, `get_order`): thanh tình trạng Nháp, Đã trình, Đã duyệt (Huỷ là nhánh khác), Nháp bị từ chối kèm khối "Đơn bị từ chối" lấy lý do từ lịch sử (R-TIEN-06), khung "Người duyệt" và cảnh báo chưa có quản lý trực tiếp hoặc người duyệt chưa có quyền Duyệt (Đ205), tab Dòng đơn (lưới K06c chỉ đọc, Tổng niêm yết, Tổng chiết khấu, Thành tiền từ máy chủ; Đã thu, Còn phải thu "—", Đ269), Thanh toán (lịch đóng tiền), Ghi danh (làm ở phân hệ sau), Lịch sử xử lý, Ghi chú và hoạt động (`SALES_ORDER`). Mở từ BH-06 (mã đơn) và từ cột Đơn, smart button Đơn hàng của BH-02. Trình, Huỷ đơn: UI-O2b; Duyệt, Từ chối: UI-O2c; sửa Nháp: UI-O3. | Đã gộp |
| P5a-UI-O2b (BH-05, Trình và Huỷ đơn) | Nút **Trình duyệt** ở đơn Nháp (quyền Đơn hàng · Sửa, Bán hàng bật; điện thoại ẩn, Đ248): lỗi máy chủ hiện thẳng câu tiếng Việt, em thiếu họ tên hoặc năm sinh chặn và chỉ đúng dòng (R-TIEN-35), lỗi mạng có nút Thử lại. Mục **Huỷ đơn** (R-TIEN-38): đơn Nháp chỉ người lập, đơn Đã trình, Đã duyệt do người duyệt đã chốt hoặc người duyệt thay; hộp K08 có lý do từ danh mục, "Khác" bắt ghi chú. `order_has_receipt` vẫn là bản tạm (luôn trả không có phiếu thu) tới khi có bảng phiếu thu (DB2). | Đã gộp (#147). Tiếp theo: DB-O2c (Đ283) gộp trước UI-O2c |
| P5a-DB-O2c | `submit_order(đơn, đã tích)`: Trưởng cơ sở lập và chính họ trình thì tự duyệt trong cùng giao dịch (Q-P6): Trình rồi Tự duyệt, lõi duyệt tách `order_approve_core` dùng chung với `approve_order`; `get_order` trả `can_submit`, `can_cancel`, `can_approve`, `can_reject` (migration `063`, Đ283). pgTAP 055 (67 bài), 043b sửa theo luật mới. Có kiểm độc lập. | Đã gộp (#150) |
| BH-05 (bản ghi đơn) | Đ257 hết hiệu lực theo Đ272: dùng khung BH05_* hiện có trên canvas `9933` (v146, thay `6f57`, Đ293), làm theo luật khi canvas vênh (Đ270: bản này là bản duy nhất anh duyệt; bản phân tích đã được Chat duyệt 28/10). Bỏ Hình thức thanh toán, Cơ sở thu tiền khỏi khung (Đ258). Chuyển thành đơn: form trắng, dòng chưa vào đơn, bỏ bớt bằng ✕ (Đ259). R-TIEN-39 đã vào luật (BH-11 hết chờ luật, còn chờ UI-O4); bỏ gợi ý "dùng báo giá còn hiệu lực" (Đ275). | Xem đơn (UI-O2a) và Trình, Huỷ đơn (UI-O2b) đã gộp; còn lại UI-O2c (Duyệt, Từ chối), UI-O3 (sửa Nháp), UI-O4 (Chuyển thành đơn, BH-11) |
| Ma trận quyền phiên bản 6 (Đ204, migration `050`): Sale, CSKH có Huỷ đơn hàng (cơ sở mình); đúng hai ô đổi; bài kiểm 042 | Đã gộp (#105) |
| Danh sách em-1 (DB) | Bảng `prospect_student` (một dòng một em của lead hoặc cơ hội; đọc thẳng từ hồ sơ học sinh khi đã gắn, Đ86), tham số `prospect_max_students` (Đ88), chuyển dữ liệu chữ cũ sang dòng 1 và bỏ cột cũ, chuyển 24 hàm sang bảng mới giữ đúng hành vi cũ (migration `043`); bài kiểm 035 (69 bài), EXPLAIN trên `seed-lon`; bước kiểm trên hmt-staging ở deploy-staging. Luật mới để PR Danh sách em-2 (DB) | Đã gộp (PR Danh sách em-1) |
| Đường dẫn theo trang gốc | Sửa lỗi 26/10: mở trang con từ smart button, bảng hay liên kết của trang bản ghi (Lead, Cơ hội, Phiếu) thì đường dẫn thanh trên nối tiếp trang gốc ("Tuyển sinh / Cơ hội / <tên cơ hội> / Phiếu kiểm tra / mã phiếu"), sống qua tải lại; bấm tên trang đã đi qua thì cắt đường dẫn, không nối dài; vào bằng thanh bên thì theo menu như cũ. Điện thoại hẹp chỉ hiện hai mục cuối. Vitest `crumbTrail`, Playwright `co-hoi` | Đã gộp (#95) |
| Cơ hội hiện ghi chú lead | Sửa lỗi 26/10: trang Cơ hội hiện ghi chú của lead gốc kèm nhãn "Từ Lead LD…" (đọc xuyên, không sao chép; chỉ khi người xem thấy được lead); `record_notes` thêm cột `source_label` (migration `047`); bài kiểm 039 (12 bài), Vitest, Playwright | Đã gộp (#96) |
| Lịch hẹn: đồng bộ | Sửa lỗi 26/10: Hoàn thành, Mở lại ở màn Lịch hẹn không làm mới trang Cơ hội (và ngược lại) bằng một hàm làm mới chung; Hoàn thành, Mở lại, Huỷ ghi dòng vào dòng thời gian của lead, cơ hội, phiếu (migration `046`, R-CRM-04); bài kiểm 038 (25 bài) và Playwright `lich-hen-dong-bo` | Đã gộp (#93) |
| 7 | P2 Cấu hình | Chưa |
| 8 | P2 Ma trận quyền (giải thích "tách 3 phân hệ" và lập bảng đối chiếu hành động, phạm vi trước khi làm) | Chưa |

Anh đã chốt: bỏ mã dự phòng, thiết lập hai bước còn 2 bước (giữ chốt 12/10); màn khoá một câu chung (S03-18); hàm công
khai chỉ trả tên cơ sở dạy học (CS1, CS2, CS4, CS5); mỗi lần Lưu ma trận quyền là một phiên bản, hiệu lực ngay;
**không đổi cấu trúc quyền trong cơ sở dữ liệu**, màn theo cơ sở dữ liệu.
Luật 16/10 đã đưa vào `docs/spec/04` (R-CRM-03 bổ sung, R-CRM-12…20) và `docs/spec/06` (mục 1.3, danh mục 33). **Việc cho PR dữ liệu giai đoạn 1** (chưa làm):
- Hàm đổi giai đoạn cơ hội kiểm R-CRM-12, 14, 02, 03; pgTAP ghi tên luật tiếng Việt, cả trường hợp đúng và bị chặn.
- Hàm tạo đơn và hàm chuyển báo giá thành đơn kiểm R-CRM-16 (phải ở L8).
- Hàm duyệt phiếu thu gọi kiểm tra R-CRM-17 trong cùng giao dịch; đối chiếu "lệch" theo R-CRM-18.
- Hàm/trigger phiếu test: đổi trạng thái phiếu cập nhật nhóm con L5 (R-CRM-15) và lên L6A (R-CRM-13).
- R-CRM-19: bấm Tạo chỉ mở form trắng, Lưu mới cấp mã; nút Tạo nằm trên bản ghi cơ hội, danh sách đơn và báo giá không có nút Tạo (R-TIEN-02).
- Danh mục #25 Lý do điều chỉnh giờ: mục "Tặng giờ chăm sóc (cần duyệt)" cần một **cờ "cần duyệt" thật** (cột hoặc cấu hình) khi viết hàm điều chỉnh giờ; hiện chỉ là chữ trong tên mục.
- Danh mục #23 Lý do huỷ buổi: hàm nghiệp vụ lọc theo cột `applies_to` (TRUNG_TAM, HOC_SINH), không đọc tiền tố mã.
- Hàm phiếu tái tục: khoá các giai đoạn con **L7A, L7B, L8A** của `UPSALE_SUBSTAGE` (không Ngừng được), cùng cách khoá L5A, L5B, L5P của cơ hội, khi viết hàm dùng chúng.
- Hàm sửa ngày nghỉ lễ: ngày nghỉ chung (không gắn cơ sở) chỉ Admin sửa; Trưởng cơ sở chỉ tạo, sửa, huỷ ngày nghỉ của cơ sở mình (chốt 16/10).
- Đơn từ phiếu tái tục, chuyển phí: tính khi làm màn tái tục.

## Trạng thái 23/11/2026 (PR đã gộp từ 19/11 06:30 tới 23/11 02:25 giờ Việt Nam; 284 PR, #85 đến #502)

Danh sách lấy từ `gh pr list --state merged` của `hmt-edu/hmt-platform` (tiêu đề PR giữ nguyên), theo ngày gộp, mới nhất ở trên. Tiếp tục mô hình kéo việc (xem mục 19/11); từ 23/11 đội dùng tài khoản chung lead.vanhanh.hmt, luật L-01 đến L-18 ở hộp thư điều phối. Mục «Trạng thái 19/11/2026» bên dưới giữ nguyên làm lịch sử.

### 23/11

| Giờ | PR | Việc |
|---|---|---|
| 02:25 | #501 | Tài liệu: báo cáo BC-02..07, BC-10 ở Looker, không dựng màn (D-23-06) |
| 02:25 | #502 | Bản đồ màn hình: CS-05..CS-14 theo mô hình phiếu nghiệp vụ (B-23-03) |
| 02:25 | #500 | Bảng màn theo trạng thái: CS-01..09 nhận khung CSN (B-23-01) |
| 02:24 | #499 | Tài liệu: bản đồ việc BAN-DO.md (D-23-04) |
| 02:24 | #498 | CLAUDE.md gọn: tối đa 3 file đầu phiên, canvas ra file riêng (D-23-03) |
| 02:24 | #497 | CLAUDE.md: kiểm nhanh trên Mac theo L-09 (D-23-02) |
| 02:24 | #496 | Tài liệu: quy-trinh-theo-ca CŨ, bỏ khỏi CLAUDE.md (D-23-01) |
| 01:35 | #474 | GV-18 giao diện: danh sách em, chấm bốn bước, Mở lại (base main; cần PR migration 598 gộp trước) |
| 01:27 | #472 | GV-17 giao diện: Bài đã giao, Giao bài, Sửa, Gỡ (đăng lại cho đúng base main) |
| 01:26 | #495 | TC-09: bảng màn nhầm «Chỉ có DB»: màn đã có (hành động Hoàn tác ở TC-08) |

### 21/11

| Giờ | PR | Việc |
|---|---|---|
| 14:30 | #490 | Bảng màn theo trạng thái: cập nhật 7 màn nhóm Code A (tài liệu) |
| 13:47 | #492 | LMS: lms_giveable_sessions (buổi giao được) + pgTAP, sửa gốc e2e GV-17 đỏ ở Tester (CAO, base main) |
| 13:31 | #482 | KH-01: bộ lọc Đang học tại (giao diện, phụ thuộc #477) |
| 13:30 | #473 | Group By còn thiếu: Người lập (BH-01), Sale (BH-06), Hình thức (TC-10) (migration 604, CAO) |
| 13:25 | #477 | KH-01: bộ lọc Đang học tại (migration 603, rủi ro thấp) |
| 13:22 | #488 | LMS: ghi kết quả EXPLAIN trên dữ liệu giả lớn (chỉ tài liệu) |
| 13:21 | #489 | Tài liệu: làm mới bảng màn hình theo trạng thái (21/11 trưa) |
| 13:21 | #491 | QT-18: bốn bước trong một hộp K4b (anh chốt giữ khuôn K4b) |
| 12:42 | #476 | CH-04: quà tặng «Áp dụng cho» (migration 602, rủi ro CAO) |
| 08:50 | #480 | CH-04: hộp Lịch sử thay đổi chính sách (giao diện, phụ thuộc #475) |
| 08:29 | #479 | KH-02, KH-05: tab Ticket ở hồ sơ phụ huynh, học sinh (giao diện, phụ thuộc #470) |
| 08:29 | #471 | LOP-02, LOP-03: so canvas lại, câu trên đầu bản ghi lớp theo tình trạng (không migration) |
| 08:29 | #475 | CH-04: Lịch sử thay đổi chính sách (migration 601, rủi ro thấp) |
| 08:07 | #470 | KH-02/KH-05: bộ lọc ticket theo phụ huynh, học sinh (migration 600, rủi ro thấp) |
| 07:46 | #478 | e2e: pickOption lấy nút mở hộp chọn (sửa lỗi strict mode, ticket.spec iPhone đỏ ở #466) |
| 07:46 | #469 | LMS chấm bài (GV-18) phần DB: migration 598 + pgTAP (mức CAO, cần Tester ĐẠT lại) |
| 07:03 | #468 | Tài liệu: làm mới bảng màn hình theo trạng thái (21/11 sáng) |
| 05:39 | #457 | So canvas TS-15: ô Em trong hộp Tạo phiếu kiểm tra (giao diện, phụ thuộc #456) |
| 05:19 | #456 | TS-15: tạo phiếu kiểm tra chọn em (migration 599, rủi ro CAO) |
| 04:57 | #462 | GV-17 giao diện: Bài đã giao, Giao bài, Sửa, Gỡ (phụ thuộc #461) |
| 04:57 | #465 | LMS chấm bài (GV-18) phần DB: migration 598 + pgTAP (mức CAO, phụ thuộc #461) |
| 04:35 | #460 | Đề xuất DB 587, 588 và KH-01 Đang học tại (chỉ tài liệu, chờ duyệt) |
| 04:35 | #461 | LMS giao bài (GV-17) phần DB: migration 597 + pgTAP (mức CAO) |
| 04:14 | #464 | So canvas TC01, TC04, TC08, TC10, TC13, BH01, BH06: khung «Không có quyền» của danh sách (C94) |
| 04:14 | #463 | BH-02: so canvas báo giá, ô Hạn hiệu lực nêu số ngày theo tham số (không migration) |
| 04:14 | #453 | So canvas TS-06: chọn em khi tạo cơ hội, Thêm em vào cơ hội cũ (giao diện, phụ thuộc #451) |
| 04:14 | #447 | KH-07 PR2: hộp Gộp phụ huynh, học sinh + nút Gộp ở KH-02, KH-05 (migration 589, rủi ro cao) |
| 03:53 | #451 | TS-06: chọn em khi tạo cơ hội từ lead, Thêm em vào cơ hội cũ (migration 595, rủi ro CAO) |
| 03:31 | #454 | QT-07: nối nhóm con bắt buộc cho Lý do huỷ test (migration 594), QT-06 trạng thái, sửa R-CRM-06 |
| 03:11 | #452 | TC-01, TC-04: chip nhiều Cơ sở, branch_ids (migration 593, CAO; thay #437) |
| 02:49 | #441 | TC-17, TC-02: Tài khoản nhận của phiếu thu (migration 582, CAO) |
| 02:29 | #455 | BH-09: tab Ghi danh của đơn nêu tiền cọc tối thiểu theo tham số, so canvas BH-03 BH-09 (không migration) |
| 02:28 | #459 | Tài liệu: rà Group By Thu chi, Bán hàng; so canvas TC-08, TC-09, TC-13, TC-15 (C93) |
| 02:28 | #458 | Đề xuất DB LMS cho GV-17, GV-18 (chỉ tài liệu, chờ Chat duyệt) |
| 02:28 | #450 | R-LOP-14: kiểm môn theo khối khi tạo lớp, sau tham số mặc định tắt (migration 589, CAO) |
| 02:07 | #448 | GV-17/GV-18: thành phần dùng chung (công tắc, tiến độ, hàng tệp, thẻ chọn, khung xem bài nộp) |
| 02:07 | #449 | So canvas CH-01 đợt 2: ô Mã cũ ở hộp Tạo gói (rủi ro THẤP) |

### 20/11

| Giờ | PR | Việc |
|---|---|---|
| 23:59 | #444 | KH-07 PR1 (DB): gộp phụ huynh, học sinh chuyển toàn bộ dữ liệu kể cả tiền (migration 583, rủi ro CAO) |
| 23:38 | #446 | GD-02, GD-03: hàm đọc bổ sung số liệu (migration 591, CAO) |
| 23:17 | #434 | TC-04: Group By «Sao kê» (migration 579, CAO) |
| 22:55 | #436 | GD-07: tình trạng «Sắp hết hạn gói» (migration 590, CAO) |
| 22:34 | #442 | QT-18: báo tên cột lỗi khi nạp dữ liệu cũ (migration 584) |
| 22:12 | #440 | Phiếu chi: Tài khoản nhận, Ngày chi dự kiến, Hình thức chi ghi trước (migration 581, CAO) |
| 22:09 | #433 | Danh sách em: Thêm, Sửa, Bỏ em cho lead và cơ hội (migration 586, rủi ro CAO) |
| 21:49 | #445 | Spec: R-V2-46..49 theo anh chốt 20/11 (Thu chi theo canvas) |
| 21:49 | #443 | So canvas TS-02, TS-08: danh sách em ở hồ sơ lead, cơ hội (PR2, phụ thuộc #433) |
| 21:49 | #431 | QT-18: bảng Cột nhận của loại, Tải dòng lỗi và trùng ở bước xem trước |
| 21:49 | #432 | TC-17: xem trước chia tiền vào dòng đơn, cột Lớp, Giờ cấp, Dồn trước (migration 578, CAO) |
| 21:27 | #429 | TC-12 bản in phiếu chi đủ dòng tính hoàn; so luật TC-14, TC-16; đo dung lượng gói (C86) |
| 21:27 | #435 | QT-03: chọn vai trò dạng chip, nút Thêm vai trò |
| 21:27 | #438 | Hướng dẫn Giáo viên: Cần làm, Lớp và học sinh, Giờ dạy, Ticket lớp |
| 21:27 | #439 | TT-02: câu theo giai đoạn của phiếu tái tục (không migration) |
| 21:27 | #430 | TT-04: Group By ở máy chủ (cơ sở, campaign, lý do chưa có phiếu), migration 585 (CAO) |
| 20:44 | #428 | Đề xuất DB GD-02, GD-03: năm chỗ chỉ đọc (chưa code, tài liệu) |
| 20:44 | #427 | So canvas TS-15: chữ hộp Tạo phiếu kiểm tra (rủi ro THẤP) |
| 20:44 | #426 | So canvas BH-05, TC-02, TC-05: khối «Người xử lý và cơ sở», «Duyệt bởi» (C85) |
| 20:44 | #422 | Rà security definer cụm 3: thu quyền gọi 5 hàm trợ giúp (migration 577, rủi ro cao) |
| 20:22 | #423 | Tài liệu: đề xuất DB còn lại của Thu chi (TC-17, TC-10/11, TC-04, chip Cơ sở), chờ anh duyệt |
| 20:22 | #424 | So canvas GV-04: số bước viết bằng chữ |
| 20:22 | #425 | GD-07: so canvas Sắp hết giờ: câu giải thích, thứ tự cột, ô phiếu tái tục (không migration) |
| 20:22 | #420 | LOP-02, LOP-05, LOP-06: câu theo tình trạng duyệt của lớp (không migration) |
| 19:58 | #418 | So canvas TC-01, TC-04: lọc nhanh «Hình thức»; so TC-06, BH-04, BH-10, BH-11 (C83, thay #414) |
| 19:57 | #421 | So canvas dc47: QT-02, QT-03, QT-08, QT-09 (sửa chữ) |
| 19:57 | #419 | So canvas KH-02: nút Tạo ticket ở hồ sơ phụ huynh (rủi ro THẤP) |
| 19:15 | #412 | GD-02: câu giải thích theo tình trạng và quỹ giờ trên bản ghi ghi danh (không migration) |
| 19:15 | #417 | So canvas CH-01 Gói bán (dc47): chữ hộp Sửa gói, Ngừng bán; CH-03 ghi chú (rủi ro THẤP) |
| 18:50 | #416 | QT-18: so canvas dc47, sửa chữ ô đếm, cột Giải thích, báo file sai định dạng |
| 18:50 | #413 | Tài liệu: làm mới bảng màn hình theo trạng thái (20/11 tối) |
| 18:50 | #415 | GD-04, LOP-09: so canvas, chữ trạng thái Sổ giờ và tên lớp ở tiêu đề (không migration) |
| 18:50 | #411 | BH-08: cảnh báo lệch hình thức học khi chọn lớp cho dòng đơn (không migration) |
| 18:50 | #404 | TC-04: cột và nhóm lọc «Sao kê» (migration 439, Kho #14) |
| 18:29 | #406 | Kho #19: Group By ở máy chủ cho KH-01 Phụ huynh và CS-01 Ticket (migration 571, rủi ro THẤP) |
| 18:08 | #408 | Sửa bài e2e GV-01: nhãn menu «Cần làm» chấp nhận số đếm (rủi ro THẤP) |
| 18:08 | #407 | LOP-02/03: Hình thức học của lớp, Tổ chức lớp tự suy, Tạo lớp còn lại, xem trước ngày kết thúc (migration 571, CAO) |
| 17:46 | #410 | Sửa bài pgTAP 572 chập chờn: so mã học sinh theo thứ tự mã (rủi ro THẤP) |
| 17:25 | #405 | Rà security definer cụm 2: danh sách, bản ghi phụ huynh theo phạm vi Xem (migration 573, rủi ro cao) |
| 17:03 | #403 | Rà security definer: duplicate_students_of_parent không lộ tên, mã ngoài phạm vi (migration 572, rủi ro cao) |
| 16:42 | #369 | QT-15: Người duyệt ticket theo loại phiếu, có ngày hiệu lực (migration 479, CAO) |
| 16:21 | #402 | Tài liệu: KH-07 câu hỏi luật; làm mới bảng màn hình theo trạng thái |
| 05:18 | #399 | QT-09: Lịch sử thay đổi tham số (migration 480) |
| 04:51 | #394 | KH-03, KH-06: Sửa phụ huynh, Sửa học sinh (migration 570, rủi ro cao) |
| 04:46 | #401 | QT-07: Lịch sử thay đổi danh mục (migration 481) |
| 04:15 | #400 | CS-07: docs/nghiep-vu Phiếu Chuyển cơ sở + pgTAP 568 thêm ba bài chặn lúc tạo |
| 03:44 | #398 | Tài liệu hiệu năng 20/11: EXPLAIN QT-16, KH-08, CS-07, CS-10 (+QT-13, QT-15 nhánh); đề xuất sửa list_tasks_for_destination |
| 03:44 | #395 | Đề xuất LOP-02/03: bốn câu quyết định DB cho anh Trường |
| 03:44 | #397 | E73 GV-01/GV-12: số đếm trên menu «Cần làm» (R-V2-37) + bài kiểm |
| 03:44 | #396 | Vitest bổ sung: Time Table lớp, Lịch tuần cơ sở (LOP-03, LOP-08) |
| 03:44 | #370 | QT-13 Tài khoản học sinh: danh sách, cấp, đặt lại mật khẩu, khoá (migration 569, rủi ro cao) |
| 02:46 | #371 | QT-16 Hồ sơ giáo viên, trợ giảng (Chat 23:05, anh Trường duyệt; migration 313, mức CAO) |
| 02:43 | #393 | GD-05: đoạn giải thích hộp Điều chỉnh giờ theo canvas 9933 |
| 02:42 | #392 | BUOI-03: chữ chặn quyền và gợi ý theo canvas 9189 |
| 02:42 | #391 | LOP-08: chú giải Lịch tuần cơ sở theo canvas 9189 |
| 02:42 | #390 | CSN so canvas: câu hướng dẫn hộp Duyệt/Từ chối/Huỷ phiếu và gợi ý ô ticket |
| 02:42 | #389 | E72 So canvas GV-10, 12, 13, 14, 15, 16 (chữ trạng thái trống) |
| 02:42 | #387 | B66 CS-07 PR2 (giao diện): Chuyển cơ sở qua phiếu |
| 02:42 | #379 | KH-08 Lên khối đầu năm học (migration 566, rủi ro cao) |
| 02:10 | #380 | B66 CS-07 PR1 (DB): Chuyển cơ sở, hai quản lý cơ sở duyệt tuần tự (migration 568) |
| 01:54 | #388 | BUOI-07/08/09: nhãn khối theo canvas 9189 (rà màn chưa kiểm) |
| 01:38 | #386 | CH-06 danh sách bài học lên main (#140 gộp nhầm vào nhánh chồng) + CH-05 chú thích; So canvas CH-05/06/07 |
| 01:23 | #385 | Cập nhật bảng màn hình theo trạng thái 20/11 (chỉ tài liệu) |
| 01:23 | #384 | E71 Tài liệu: yêu cầu khung Design cho GV-17, GV-18 |
| 01:17 | #383 | Sửa bài BUOI-15: lật trang tìm dòng của lớp (hết đỏ ngẫu nhiên) |
| 01:17 | #382 | KHẨN: e2e ổn định quanh nửa đêm giờ Việt Nam (ngày giả theo giờ VN, bài 18 T4, BUOI-15) |
| 00:56 | #381 | E70 GV-03: Lịch dạy khớp canvas (nhãn phạm vi, trạng thái trống) |
| 00:16 | #375 | B64 CS-10: Thực hiện phiếu Chuyển phí → số dư khách hàng (migration 567) |
| 00:03 | #355 | Chi tiết lớp: thêm khoảng cách giữa các khối (ảnh staging stg-lop-chi-tiet) |
| 00:03 | #360 | TC-16: Dùng số dư cho đơn mới (hộp K08 ở đơn Đã duyệt; DB sẵn từ migration 454) |

### 19/11

| Giờ | PR | Việc |
|---|---|---|
| 23:50 | #378 | E69 GV-11: khối «Tiến độ khung chương trình» (ước tính) theo canvas |
| 23:50 | #377 | E68 GV-07K: chấm kiểm tra khớp canvas (lỗi vượt tối đa, lỗi mạng, ticket sửa điểm) |
| 23:49 | #373 | E67 KHẨN: cảnh báo trùng SĐT không lộ mã, cơ sở của hồ sơ ngoài phạm vi (TS-03) |
| 23:36 | #372 | BH-02: nút «Thêm cả nhà» ở lưới dòng báo giá (so canvas BH02_chon) |
| 23:31 | #368 | TC-09: «Đã hoàn tác bằng <mã khoản đảo>» theo canvas (list_money_in trả reversed_by_code) |
| 23:31 | #374 | Vá e2e GV-16: hai nút Đóng trong hộp Buổi trong tháng (strict mode) |
| 23:23 | #367 | B64: bỏ mục menu CS-16 «Nhận xét chờ gửi» (R-V2-40) |
| 23:12 | #361 | B65: Huỷ đơn bị chặn thì giải thích và mời Tạo ticket hoàn tiền (BH05_huy_chan, migration 565) |
| 23:11 | #363 | TC-17: bảng chia tiền về dòng đơn thêm Học sinh, Thành tiền (so canvas) |
| 23:11 | #364 | BH-09, TC-03: chữ bản ghi đơn theo canvas (Lịch đóng tiền, Phiếu thu) |
| 23:11 | #365 | docs: so canvas nhóm Bán hàng, Thu chi lượt C (TC-17, TC-03, BH-09, TC-09...) |
| 23:10 | #366 | F71: TS-12 gộp vào CHUNG-14; sáu câu hỏi luật KH-08 |
| 22:56 | #359 | F70: sửa nhầm «chưa có» trong bảng màn hình; đề xuất 5 màn CRM còn thiếu |
| 22:55 | #362 | So canvas KH-01..07 (Code D, chỉ tài liệu) |
| 22:55 | #358 | TC-11 Phiếu chi: cột «Cách tính» của bảng tính hoàn (theo canvas, luật giữ nguyên) |
| 22:41 | #357 | F69: rà nhóm B (40 màn không có khung canvas) |
| 22:29 | #345 | Kho #18 TC-08, TC-13: Group By ở máy chủ cho Khoản tiền vào và Công nợ |
| 22:29 | #352 | QT-03: nhãn Vai trò và gợi ý nhiều vai trò theo canvas dc47 (nhỏ) |
| 22:29 | #353 | E66 TS-03: cảnh báo trùng SĐT inline dưới ô Số điện thoại (theo canvas) |
| 22:28 | #354 | F68: TS-08 canvas vênh luật; rà tiếp 17 màn nhóm A với canvas |
| 22:28 | #356 | TC-11: nhãn bảng tính hoàn theo canvas («Còn lại sau khi trừ giờ đã học») |
| 22:20 | #350 | Kho #19 TT-01: Group By ở máy chủ cho Tái tục (giai đoạn, nhóm con, đợt, phụ trách, cơ sở) |
| 22:15 | #347 | Kho #18 TC-10: Group By ở máy chủ cho Phiếu chi (tình trạng, cơ sở) |
| 22:15 | #348 | So canvas nhóm A (Code D): TC-10 Đúng, TC-11 Lệch cần chốt (chỉ tài liệu) |
| 22:15 | #351 | TT-02: chữ trống Báo giá và đơn, thanh L6 theo canvas + bảng so canvas Tái tục |
| 22:07 | #349 | F67: rà 13 màn nhóm A (Tuyển sinh, Quản trị, Cấu hình) với canvas |
| 22:03 | #338 | TC-15: Đối soát thu tiền (danh mục Tài khoản nhận, cờ khớp sao kê, migration 478, CAO) |
| 21:59 | #340 | Kho #18 TC-01, TC-04: Group By ở máy chủ cho Phiếu thu (tình trạng, hình thức, cơ sở) |
| 21:59 | #346 | B63: Quản trị viên vào được mọi màn để xem (menu và phân hệ) |
| 21:54 | #339 | LOP-02: khối Nhóm lớp «Lớp còn lại của nhóm» + câu Time Table (KHO dòng 20 phần đọc, migration 310 chỉ đọc) |
| 21:50 | #335 | E65 Kho #17: Group By ở máy chủ cho Ghi danh GD-01 và Buổi học BUOI-01 (migration 512, 513) |
| 21:47 | #336 | Kho #18 BH-01: Group By ở máy chủ cho Báo giá (tình trạng, cơ sở) |
| 21:43 | #337 | B62: Phiếu chi cột Hình thức (danh mục chung với Phiếu thu, migration 564) |
| 21:33 | #342 | B50: Phiếu thu Huỷ hiện «Lý do huỷ» trong khối thông tin (TC02_huy) |
| 21:26 | #333 | Group By ở máy chủ cho Lớp LOP-01 (KHO dòng 17, phần 1/3; migration 309 chỉ đọc) |
| 21:22 | #272 | F51: thêm cột thiếu theo canvas: Phiếu tái tục (GD-07, mig 561), Điểm, Cơ hội gốc, Cơ sở tạo (TS-16) |
| 21:22 | #341 | GV-16 Giờ dạy của tôi: điện thoại có nút Xem chi tiết mở danh sách buổi (canvas 9189) |
| 21:15 | #332 | Kho #18 BH-06: Group By ở máy chủ cho Đơn hàng (tình trạng, cơ sở) |
| 21:11 | #331 | BUOI-02 Buổi học (bản ghi): cột Giờ trừ theo canvas 9933 (migration 308 chỉ đọc) |
| 21:08 | #329 | E64: Lớp: cột Ghi chú và hoạt động (LOP-02, migration 511) |
| 20:53 | #327 | Kho #14: TC-01 cột Người duyệt, TC-04 cột Mã giao dịch (đúng canvas) |
| 20:53 | #334 | F66: rà màn Lớp, Buổi, Giáo viên với canvas (điền Đúng/Lệch) |
| 20:40 | #311 | C60 CS-11 học bù: phiếu Đổi lịch sinh buổi Học bù mới (xếp chồng sau #297) |
| 20:40 | #326 | GD-02 Ghi danh (bản ghi): sổ giờ gần đây và thẻ Học sinh theo canvas GD02 (không DB) |
| 20:39 | #330 | F65: rà Group By các danh sách K03 với canvas (14 danh sách lệch) |
| 20:26 | #328 | LOP-09: Học sinh của lớp (danh sách K03 theo canvas 9933, migration 477) |
| 20:26 | #323 | GD-07 Sắp hết giờ: dựng lại theo khuôn danh sách K03 đúng canvas (đóng «Lệch chưa sửa») |
| 20:26 | #324 | B61: cột K03 giữ sau khi tải lại trang (sửa ở khuôn dùng chung) |
| 19:55 | #322 | E63: Ghi danh chia tab (GD-02) + khối «Em có N ghi danh ở lớp này» (migration 510) |
| 19:50 | #325 | F64: rà 11 màn Bán hàng, Thu chi, Ghi danh với canvas (điền Đúng/Lệch) |
| 19:29 | #320 | KHO-VIEC 6: danh sách nhãn tiếng Anh (đều là chữ canvas, không đổi mã; chỉ tài liệu) |
| 19:15 | #318 | Danh sách Lớp: lịch học ghi rõ giáo viên và phòng (T2 mục 10, migration 307 nhẹ) |
| 19:15 | #313 | B51 cụm 3: dải đỏ tự mất, Số tiền phiếu thu gợi ý theo đợt, «Chờ … duyệt» thay thanh nút trống |
| 19:05 | #319 | Tên cơ sở nhất quán ở trang bản ghi (Kho #7) |
| 19:04 | #321 | F63: kịch bản chụp ảnh hướng dẫn dùng seed-staging (sau #309) |
| 18:51 | #316 | Cổng GV: khung tải lỗi có Thử lại cho GV-14 (Kho #12) |
| 18:51 | #317 | Kho #2: Lead lưu thiếu ô bắt buộc báo ngay; nút Phụ huynh ở Cơ hội mở được |
| 18:47 | #309 | Seed staging: supabase/seed-staging.sql dựng bằng hàm nghiệp vụ, dữ liệu giả (F62) |
| 18:47 | #297 | C60 CS-11: phiếu Đổi lịch học (dời một buổi, đổi ca cố định) — xếp chồng sau #287 |
| 18:38 | #274 | F51: BUOI-15 Điểm danh trong ngày: thêm Tình trạng buổi, CSKH (mig 562), Xử lý theo canvas |
| 18:33 | #300 | B50 cụm 2: Đơn hàng hiện Đã thu, Còn phải thu, Thu tiền; Phiếu thu hiện Người nhận tiền (migration 563) |
| 18:29 | #298 | CH-04: Chiết khấu thêm «Áp dụng cho» (Báo giá, Đơn, Phiếu thu), tách Giá trị / Mức tối đa (migration 476, CAO) |
| 18:17 | #314 | Form Tạo/Sửa lớp: ghim thanh nút Lưu/Huỷ khi cuộn (T2 mục 3) |
| 18:17 | #295 | C60: người duyệt kế tiếp (tên) ở danh sách phiếu và bảng Duyệt (CSN-05, CSN-06) |
| 18:04 | #307 | E62: Ghi danh chia tab theo canvas GD-02 (xếp chồng trên #292) |
| 18:04 | #280 | B51 cụm 1: ô đếm Báo giá/Đơn hàng ở Cơ hội; Chuyển thành đơn mờ khi chưa L8 |
| 18:04 | #296 | Kho #4: tìm mã thô hiện ra giao diện; sửa hình thức học ở tạo đơn |
| 18:04 | #301 | e2e: bao phủ LOP-09 (KHO-VIEC dòng 10, lane A) |
| 18:04 | #304 | GV-11: chi tiết lớp một trang theo canvas 9189 (bỏ bốn tab) |
| 18:04 | #312 | Calendar: sự kiện theo giờ Việt Nam (đóng phần «chưa làm» Q-172, R-HT-07) |
| 18:04 | #315 | Cổng GV: thẻ «Việc sắp trễ hạn» ở Hôm nay bấm được (Kho #5) |
| 18:04 | #305 | D61b: deploy-staging nạp seed-staging.sql (khung bước, chờ file của Code F) và kiểm đếm dòng |
| 18:03 | #292 | E61: Ghi danh và Buổi học: cột Ghi chú và hoạt động + tab (theo bảng lệch K06 của Tester 2) |
| 17:50 | #269 | D50 đợt 2: QT-09 Tham số tách cột Đơn vị, nhãn Giá trị hiện tại |
| 17:50 | #310 | docs: đo hiệu năng năm danh sách lane E (Kho #11) |
| 17:50 | #294 | GV-07K PR1: điện thoại chấm kiểm tra từng em một; máy tính giữ danh sách cả lớp |
| 17:50 | #299 | Kho #13: Phiếu kiểm tra (TS-16) thêm cột Điểm, Cơ hội gốc, Cơ sở tạo |
| 17:50 | #302 | Sửa bảng màn hình theo trạng thái: hết báo thừa HT, thêm DB, Đúng/Lệch, số theo cổng (F61) |
| 17:36 | #306 | pgTAP 106: bài phụ thuộc giờ thật (buổi 19h00 hôm nay tự chốt) đỏ mọi PR |
| 17:08 | #287 | C60 CS-14: Thực hiện Dừng học từ ticket (phiếu Dừng học giữ số dư) |
| 17:08 | #293 | B51 cụm 2: đổi tài khoản trong cùng thẻ thì xoá bộ nhớ đệm dữ liệu |
| 17:08 | #278 | KHẨN: Time Table form Tạo/Sửa lớp thành 7 tab theo thứ (bảng gọn) |
| 16:54 | #291 | docs: bảng màn hình theo trạng thái, 197 mã (script sinh tự động) |
| 16:54 | #285 | docs: phạm vi đào tạo, nạp dữ liệu và triển khai CS5 (bảng, mục cần anh quyết) |
| 16:54 | #284 | docs: bảng rà UI cổng Giáo viên với canvas 9189 (Đúng/Lệch) |
| 16:54 | #290 | E60 CHUNG-20 (2/2): giao diện huỷ lead nhập nhầm |
| 16:54 | #289 | E60 CHUNG-20 (1/2): huỷ lead nhập nhầm: DB + pgTAP (migration 508) |
| 16:47 | #288 | D60: kiểm QT-17, CHUNG-18 (chỉ tài liệu): CHUNG-18 đã có nhật ký theo từng danh sách; QT-17 dừng chờ chốt cách đăng nhập phụ huynh |
| 16:47 | #286 | B52: kế hoạch chuyển dữ liệu thật CS5 (tài liệu) |
| 16:47 | #279 | KHẨN: trang chi tiết lớp theo khuôn chung (tab Time Table, Học sinh, Buổi học dạng bảng) |
| 16:47 | #265 | D50 đợt 1: rà UI Quản trị, danh sách Người dùng có cột Tên đăng nhập (migration 475) |
| 16:47 | #276 | KHẨN: trang chặn có nút Đăng xuất (/khong-co-quyen, lỗi tải quyền, chọn cổng, đổi mật khẩu lần đầu) |
| 16:34 | #261 | A50 PR2: ô chọn Khung chương trình và Bài bắt đầu ở Tạo/sửa lớp (không DB) |
| 16:33 | #283 | Lớp (báo cáo T2): thanh duyệt không còn mã thô, Duyệt lớp có số buổi dự kiến, hộp Xếp lớp không dịch nút |
| 16:16 | #281 | Cổng GV: thẻ buổi ở Hôm nay bấm được; tiến độ không nói «bốn bước» khi chỉ có 3 (T2-TONG-HOP) |
| 16:15 | #282 | Cổng GV cụm 2: chấm nhận xét có «Lưu và em tiếp theo», tiêu đề «Em n/m · tên» (GV-07) |
| 16:15 | #262 | B50 cụm 1: danh sách Phiếu thu theo canvas TC01 (Ngày nhận, Cơ sở, Cơ sở đơn tách riêng) |
| 15:52 | #277 | KHẨN: deploy-staging tự bật Auth Hook token và đồng bộ cài đặt Auth; kiểm đăng nhập thật |
| 15:52 | #275 | Sửa bài lead.spec «Đã gộp» đỏ sau khi tách cột Lead, Cơ hội |
| 15:25 | #273 | KHẨN: deploy-staging tự mở schema app qua Data API và kiểm cuối (đăng nhập staging báo lỗi hệ thống) |
| 15:12 | #270 | E41: danh sách buổi: tách cột Ngày học và Giờ bắt đầu (cột không gộp thông tin) |
| 15:12 | #271 | C50 cụm 4: thẻ Kanban ticket (CSN-02) đúng canvas, không gộp thông tin |
| 15:00 | #268 | C50 cụm 3: chi tiết phiếu nghiệp vụ (CSN-06) bảng cấp duyệt, không gộp thành dòng chữ |
| 15:00 | #266 | Rà UI nhóm Đào tạo với canvas: cột danh sách Lớp, bảng lệch (thẻ F50) |
| 15:00 | #267 | docs: prompt Design cho khuôn xem trước hàng loạt (KH-08 Lên khối) |
| 14:51 | #264 | C50 cụm 2: chi tiết ticket (CSN-03) đúng canvas: Tiếp nhận / Liên kết, Nhóm và Nhóm con tách riêng |
| 14:51 | #263 | C50 cụm 1: danh sách ticket (CSN-01) đúng canvas, cột không gộp thông tin + bảng lệch |
| 14:21 | #259 | A50 PR1: màn Tạo/sửa lớp (LOP-03) và Time Table theo canvas 9933 (không DB) |
| 14:19 | #255 | E34: công cụ chụp ảnh hướng dẫn hỗ trợ bước bấm (clicks); lead-hanh-dong mở menu Hành động |
| 14:18 | #260 | Lead, Cơ hội: tách cột gộp theo canvas (thẻ F40) |
| 14:18 | #256 | Menu CRM: rà lại nhãn với canvas 9933, nhãn Tái tục (thẻ F30) |
| 14:00 | #244 | A25 PR2: Danh mục sửa form Loại buổi, ô Loại kiểm tra ở yêu cầu buổi, giao diện GV theo review_form (migration 306) |
| 13:51 | #254 | B41 e2e đường Kế toán tích hợp: thu tiền, duyệt hai bước, hoàn tác khoản tiền, tổng và công nợ |
| 13:51 | #228 | CHUNG-15: tối ưu hiệu năng việc chờ tôi duyệt (migration 559) trên main |
| 13:49 | #246 | C40: e2e Bảo lưu toàn luồng từ ticket (xếp chồng sau C31) |
| 13:43 | #248 | C41: pgTAP chặn chéo cơ sở: Bảo lưu, Tiếp tục học, nâng cấp khiếu nại (xếp chồng sau C32) |
| 13:40 | #258 | E36: seed nhỏ cho ảnh hướng dẫn (buổi hôm nay của gv.cs5); cổng Giáo viên chụp 8 ảnh đúng màn |
| 13:31 | #238 | CH-02: màn Gói bán (bản ghi): giá theo hiệu lực, Sửa, Thêm giá mới |
| 13:20 | #230 | CH-08: màn Chiến dịch marketing, mọi vai trò cổng CRM tạo được (migration 560) |
| 13:11 | #257 | KHẨN: dựng lại hàm token gộp D41 (hai bước theo tham số) và E31 (đổi mật khẩu lần đầu theo tham số), migration 473 |
| 12:39 | #241 | e2e: đường đi trọn của một học sinh giả, ghi danh đến Done trừ giờ (A40, chỉ thêm bài kiểm thử) |
| 12:22 | #252 | C42: e2e đường CSKH: khiếu nại → nâng cấp → Bảo lưu → Tiếp tục học |
| 12:22 | #233 | Menu Đào tạo: danh sách phẳng theo canvas (bỏ tiêu đề nhóm con trùng mục) |
| 12:21 | #235 | D41: bỏ bắt buộc xác thực hai bước cho Admin và Kế toán bằng tham số (migration 472, CAO) [nháp: chờ CI liệt kê bài cần chỉnh] |
| 12:11 | #250 | docs: lane E migration 507 (E31 đổi mật khẩu lần đầu theo tham số) |
| 12:10 | #251 | B40 e2e đường Sale tích hợp: báo giá → đơn → duyệt → phiếu thu → hai bước duyệt → khoản tiền vào, công nợ |
| 12:10 | #245 | C32: Nâng cấp khiếu nại thủ công (CS-13, R-CS-06) |
| 12:00 | #249 | E32 bước 3: chụp ảnh hướng dẫn bỏ bộ lọc mặc định trước khi mở bản ghi |
| 11:59 | #224 | e2e: kịch bản G1 qua giao diện (A31, chỉ thêm bài kiểm thử) |
| 11:59 | #240 | Menu CRM: sửa nhãn theo canvas và bảng đối chiếu (thẻ F20) |
| 11:59 | #236 | E31 (CAO): học sinh không bắt đổi mật khẩu lần đầu; tham số hai phạm vi (migration 507) |
| 11:48 | #227 | D40: sửa G2, điều chỉnh giờ tay có trần, chặn ghi danh đóng, cộng giờ cần Kế toán (migration 471, CAO) |
| 11:37 | #239 | E32: chụp ảnh tự động cho hướng dẫn người dùng (npm run chup-anh), chạy trên DB local |
| 11:32 | #242 | D42: pgTAP ma trận quyền cho bảng mới từ 17/11 (chỉ thêm bài, nháp chờ CI) |
| 11:25 | #247 | KHẨN: sửa e2e thu-tien TC-09 chập chờn (gốc: đếm nút trên danh sách chưa lọc, lẫn khoản bài chạy song song) |
| 11:25 | #237 | C31: Tiếp tục học (quay lại sớm) từ phiếu Bảo lưu (CS-09, CSN06b_tiep_tuc) |
| 11:13 | #243 | E33: chữ cổng Giáo viên khớp canvas 9189 (GV-04, GV-07, GV-16), chỉ đổi chữ |
| 11:02 | #231 | A25 PR1 (DB, CAO): loại buổi quyết định form nhận xét; thêm Kiểm tra giữa kỳ, cuối kỳ |
| 10:40 | #234 | docs: hướng dẫn chung, Giáo viên, Quản trị (nội dung chưa ảnh) (B32, chỉ tài liệu) |
| 10:40 | #232 | docs: hướng dẫn người dùng cổng CRM (nội dung chưa ảnh) cho Sale, CSKH, Kế toán, Trưởng cơ sở (B31, chỉ tài liệu) |
| 10:03 | #229 | C30 (một phần): Gia hạn bảo lưu từ phiếu nghiệp vụ CSN-06b |
| 09:13 | #225 | KHẨN D35: sửa P1, Học sinh đổi được mật khẩu lần đầu (get_setting cho phép luật mật khẩu; R2c) (migration 470, CAO) |
| 08:56 | #222 | E27 (KHẨN, Soát S16): màn đặt mật khẩu mới báo lỗi khi không tải được luật mật khẩu; bài e2e học sinh đổi mật khẩu lần đầu |
| 08:56 | #85 | CHUNG-11 Tìm kiếm toàn hệ thống: nhiều loại bản ghi (migration 552), ô tìm ở thanh trên |
| 08:42 | #223 | C28: đóng R1c, R1d, R3 của Soát S16 (phạm vi hẹp ở hàm và chính sách còn sót) |
| 08:34 | #220 | E26: axe trên màn mới: sửa ô tìm không nhãn ở Việc chờ tôi duyệt; thêm bài axe (Loại buổi, Nhật ký QT-11/12, Việc chờ duyệt) |
| 08:30 | #219 | docs: rà soát chữ tiếng Anh trên giao diện và câu báo lỗi HMT_* (B23, chỉ tài liệu) |
| 08:30 | #162 | BC-08: màn Giáo viên trễ hạn hằng tháng (giao diện + migration 558) |
| 08:22 | #215 | e2e: sửa chập chờn lead-ban-ghi trên iPhone (cuộn dòng Website vào khung nhìn) |
| 08:17 | #218 | D34: bọc (select ...) hàm quyền còn trần trong 20 chính sách RLS (migration 469, CAO) |
| 08:03 | #221 | C27: bài pgTAP quét RLS và audit_log toàn bảng (chỉ thêm bài kiểm) |
| 08:03 | #214 | G1: chốt danh sách tính giờ giữ chỗ của buổi Đã chốt chưa Done (A30, mức CAO) |
| 07:51 | #174 | CHUNG-15: tối ưu hiệu năng việc chờ tôi duyệt (migration 559) |
| 07:51 | #209 | D33: sửa E6 (nhân viên tự đổi email), E2, E3, E5 của Soát S13 (Edge Function, Vitest) |
| 07:48 | #216 | Seed giả lớn Lớp/Buổi/Ghi danh + EXPLAIN danh sách (A28, không cần chỉ mục mới) |
| 07:47 | #217 | C25: e2e ca N1 (Kế toán không tự duyệt phiếu nợ đầu kỳ do mình lập, gửi) |
| 07:37 | #151 | CHUNG-15: màn Việc chờ tôi duyệt (giao diện + migration 557 thêm open_id) |
| 07:28 | #155 | C16 cụm 1: dòng chặn trình của phiếu thu (migration 420) |
| 07:23 | #210 | C25: phiếu thu nợ đầu kỳ đúng khung (3 bước, nút Gửi kế toán) và e2e ca chặn quyền |
| 07:23 | #208 | N1 (CAO, tiền): người lập hoặc người gửi không tự duyệt phiếu thu nợ đầu kỳ (migration 421) |
| 07:20 | #211 | E23: Danh mục «Loại buổi» có cột Form nhận xét (chỉ đọc, phương án b) |
| 07:10 | #213 | docs: nạp dữ liệu, quy trình năm bước khi nạp hỏng giữa chừng (B22, chỉ tài liệu) |
| 07:10 | #212 | docs: danh sách kiểm tay trên staging cho 28 màn LÕI (B21, chỉ tài liệu) |
| 06:55 | #204 | D32: rà chỉ mục bảng lane D, thêm chỉ mục opening_debt_student_id (migration 468) |
| 06:42 | #205 | docs: đề xuất G1 tính giờ giữ chỗ khi chốt danh sách (thẻ A29, chờ duyệt, chỉ tài liệu) |
| 06:42 | #207 | docs: nghiệp vụ, mô tả 10 hàm còn thiếu (đối chiếu migration 300-349, 400-467, 500-599) (B20, chỉ tài liệu) |
| 06:42 | #206 | docs: TIEN-DO cập nhật 19/11, 114 PR đã gộp từ 16/11 18:00 (B19, chỉ tài liệu) |

## Trạng thái 19/11/2026 (PR đã gộp từ 16/11 18:00 tới 19/11 06:30 giờ Việt Nam; 114 PR; #50 và #67 đến #203)

Từ 17/11 làm theo **mô hình kéo việc**: Chat soạn thẻ việc ở hộp thư (HOP-THU/VIEC), mỗi lane (A đào tạo và buổi, B Aftersale và nạp dữ liệu, C bán hàng và tiền, D hàm áp dụng phiếu, hoàn phí, dừng học, E cổng giáo viên, F cấu hình, quản trị, báo cáo) một dải migration riêng (300–599). Từ 18/11 CI chạy trên GitHub (miễn phí, repo công khai): trên máy chỉ chạy bộ nhanh; pgTAP và Playwright do CI chạy; job Playwright chạy trong ảnh chính thức, tách khỏi pgTAP (#142, #149). Lỗi axe 4.14 («tên đọc không chứa chữ hiển thị») làm Playwright đỏ hàng loạt tới #105, #196. Danh sách dưới đây theo ngày gộp (giờ Việt Nam), đúng tiêu đề PR; hàm và cờ của từng lane xem `docs/nghiep-vu/`.

### 19/11

| Giờ | PR | Việc |
|---|---|---|
| 06:29 | #203 | CI: chạy pgTAP trên main mỗi lần đẩy có đụng migration (D31) |
| 06:15 | #84 | QT-12 Nhật ký đăng nhập và xuất file: hàm danh sách, mở khoá tạm (migration 551), màn hai tab, Vitest, pgTAP |
| 05:49 | #133 | R-HT-07: mốc nhanh lọc theo 00:00 giờ Việt Nam (datePresetInstants), không theo múi giờ máy (không migration) |
| 05:49 | #80 | QT-11 Nhật ký thao tác: hàm list_audit_log (migration 550), màn quan-tri/nhat-ky, Vitest, pgTAP |
| 05:36 | #148 | A9: hâm nóng Function đăng nhập bằng pg_cron + pg_net (migration 301, CAO, mặc định TẮT) |
| 05:22 | #110 | TC-16: cấn số dư khách hàng vào đơn (migration 454), khoản tiền vào không phiếu thu, hoàn tác trả số dư, pgTAP |
| 05:09 | #171 | D24: bỏ cỡ trang ghi cứng 50 và 100 ở ba hàm danh sách (migration 464) |
| 04:55 | #166 | R1 (Soát): chính sách đọc nhóm lead, cơ hội, lịch hẹn dùng phạm vi CO_SO thay «khác rỗng» (migration 463), pgTAP |
| 04:42 | #108 | TT-E: màn TT-04 Đối chiếu tái tục theo tháng (migration 553) |
| 04:42 | #165 | R1 (Soát): chính sách đọc nhóm báo giá, phiếu tái tục dùng phạm vi CO_SO thay «khác rỗng» (migration 462), pgTAP |
| 04:29 | #103 | TC-02 PR3: giao diện Thu nợ đầu kỳ (không đơn, nợ từng em) |
| 04:29 | #164 | R1 (Soát): chính sách đọc nhóm đơn hàng dùng phạm vi CO_SO thay «khác rỗng» (migration 461), pgTAP |
| 04:16 | #202 | A25 PR-2: giao diện chọn Buổi kiểm tra ở ba form yêu cầu buổi (chồng trên #200) |
| 04:15 | #163 | R1 (Soát): chính sách đọc nhóm phiếu thu, khoản tiền vào dùng phạm vi CO_SO thay «khác rỗng» (migration 460), pgTAP |
| 04:03 | #199 | R2b (Soát): get_setting không cho Học sinh đọc tham số nội bộ (migration 467, CAO; xếp sau #195) |
| 03:50 | #197 | A24 PR-1 (DB, migration 302, CAO): đọc danh sách em đã xuất nhận xét (GV-07X) |
| 03:50 | #200 | A25 PR-1 (DB): yêu cầu buổi chọn loại Kiểm tra kèm cấu hình điểm; kiểm tra bù không trừ giờ (no_charge); migration 303, pgTAP 303 |
| 03:48 | #141 | Hiệu năng đăng nhập vòng 2: tải sẵn cỡ trang danh sách cùng lúc với dữ liệu quyền (không đợi màn mở) |
| 03:48 | #187 | D26: e2e Phiếu chi và Số dư khách hàng, máy tính và điện thoại (chỉ thêm bài kiểm) |
| 03:47 | #82 | R-V2-44 + TC-17: Admin «Chuyển người duyệt» (migration 400) |
| 03:37 | #176 | E18: chân trang Bảng giá ghi đúng R-TIEN-10 (giá trống = gói không bán hình thức đó) theo luật và khung CH03 |
| 03:24 | #147 | A10: client Supabase mỏng (auth-js + postgrest-js), bỏ realtime, storage, functions khỏi gói: đăng nhập 225 → 199 KB nén; giữ khoá lưu phiên; Vitest |
| 03:21 | #81 | Phiếu Bảo lưu, Chuyển lớp: nối hàm áp dụng (262), tuỳ chọn biểu mẫu (350) và giao diện tạo phiếu |
| 03:20 | #79 | GV-12 phiếu test chờ chấm + GV-15 chấm kiểm tra đầu vào (migration 500) |
| 03:05 | #104 | TT-D2: tạo đơn từ phiếu tái tục (migration 417, 418) + hộp Tạo đơn ở TT-02 |
| 03:04 | #190 | CI: thử lại có chờ tăng dần khi supabase start và kéo ảnh Playwright gặp «Rate exceeded» (D28) |
| 03:03 | #195 | R2 (Soát): Học sinh không đọc cấu hình nội bộ; is_staff theo cổng, student_portal_config (migration 466), pgTAP mọi vai trò |
| 02:47 | #100 | TT-B: tự sinh và đối soát phiếu tái tục (migration 415) |
| 02:29 | #196 | Gộp ba sửa Playwright: chuông thông báo (axe), e2e GV-11/GV-13, thu-tien TC-09/TC-13 (BC-09 đã vào main #191) |
| 01:48 | #198 | A24 PR-2: lõi xuất nhận xét GV-07X (dựng phiếu buổi thường và kiểm tra, điều kiện xuất, tên file, ngắt dòng); Vitest |
| 01:03 | #191 | e2e BC-09: tự bật phân hệ BAO_CAO ở CS5 (và trả lại) thay vì dựa vào bài khác; chạy riêng không còn trượt «Phân hệ chưa bật» |
| 01:00 | #193 | docs: đề xuất A25 «loại kiểm tra» trong yêu cầu buổi và form Loại buổi ở Danh mục (chờ Chat duyệt, chưa code) |
| 00:57 | #192 | docs: đề xuất GV-07X Xuất nhận xét (thẻ A24; chờ Chat duyệt, chưa code) |
| 00:47 | #168 | docs: đề xuất chặn Học sinh đọc cấu hình nội bộ (Soát R2), chờ Chat duyệt |
| 00:46 | #189 | D27: ma trận vai trò cho hàm tiền ra: tạo, duyệt hai bước, xem (CSKH, Marketing, Trợ giảng, Admin, Trưởng cơ sở, Kế toán) |
| 00:25 | #185 | docs: khung chương trình CH-05, CH-06 (migration 300) trong docs/nghiep-vu (thẻ A21; chỉ tài liệu) |
| 00:25 | #182 | docs: nghiệp vụ Aftersale lane B (danh sách phiếu, khoá ticket, hàm nội bộ, Bảo lưu, Chuyển lớp, Hoàn học phí, cấp duyệt) (B15) |
| 00:25 | #181 | Thẻ C21: tài liệu R-V2-44 chuyển người duyệt, cập nhật mục lục hàm lane C (PR đang chờ gộp) |
| 00:25 | #180 | docs: hàm và chính sách lane E, thêm migration 503, 504, 506 (rubric CH-07, câu mẫu) |
| 00:25 | #169 | Thẻ C20: tài liệu đo hiệu năng phiếu tái tục trên 50.000 phiếu (EXPLAIN, trước và sau migration 419) |
| 00:25 | #159 | docs: bảng mã lỗi HMT_* của lane D (D21) |
| 00:24 | #146 | docs: CI tách hai job DB (pgTAP) và Playwright, khi nào cần job nào, cách chạy lại (D17) |
| 00:24 | #177 | E19: Cơ sở và phòng hiện lỗi kèm Thử lại; Chiết khấu, Giờ tặng có trạng thái trống |
| 00:24 | #184 | B17: pgTAP 357 phiếu nghiệp vụ theo vai (quản lý cơ sở khác, giáo viên, CSKH) bị chặn, phiếu giữ nguyên |
| 00:23 | #186 | A22: link «Giờ dạy của tôi» ở GV-03 đủ vùng chạm 44px trên điện thoại |
| 00:18 | #137 | docs: tổng hợp hàm, cờ, bản sửa mới của Code D (migration 235 đến 459) |

### 18/11

| Giờ | PR | Việc |
|---|---|---|
| 23:57 | #179 | KHẨN: bài pgTAP 461 tạo ticket Aftersale hợp lệ trước khi hoàn phí (T6), thêm ca chặn không có ticket, ticket không tồn tại |
| 23:39 | #132 | E1+E10 (sạch, thay #125 và #109): giáo viên chỉ đọc học sinh và ghi chú học sinh trong lớp mình (migration 501, 502) |
| 23:28 | #167 | Thẻ C18: e2e TC-09 Kế toán hoàn tác khoản tiền (cờ bật rồi trả lại), khoản đã hoàn tác không còn nút; chỉ chạy bằng CI |
| 23:28 | #170 | B12: màn lỗi tải dữ liệu dùng chung có nút Thử lại cho bản ghi ticket, bản ghi phiếu, SLA, nhóm ticket |
| 23:27 | #172 | A14: GV-12 Cần làm và GV-14 Ticket giáo viên hiện trạng thái không có quyền khi máy chủ từ chối |
| 23:27 | #175 | BC-09: chữ trạng thái trống đúng khung BC09_trong_pc |
| 23:18 | #135 | T6: hoàn phí, dừng học bắt buộc qua ticket Aftersale (migration 459, R-V2-24A), pgTAP đúng và bị chặn |
| 23:18 | #145 | CH-07 màn Rubric nhận xét (chồng trên #144): tab Mô tả mức + migration 504 |
| 23:18 | #153 | B10 CSN-05: cột Hạn, chip Đã duyệt chờ thực hiện ở danh sách phiếu; Chờ tôi duyệt chỉ vai Kế toán cho cấp kế toán (migration 355) |
| 23:18 | #120 | BH-08: Chọn lớp chỉ ghi vào bản đang sửa, lưu khi bấm Lưu đơn, huỷ Sửa thì bỏ (theo khung BH08); Vitest, e2e |
| 23:18 | #119 | CS-01 danh sách ticket theo CSN01: cột Nhóm · Nhóm con, Học sinh, Tạo lúc (migration 351, pgTAP, e2e) |
| 23:06 | #94 | TC-02: nợ đầu kỳ theo từng em (migration 253) |
| 23:05 | #88 | CHUNG-12 Trung tâm thông báo: chuông ở thanh trên CRM, số chưa đọc, đánh dấu đã đọc, mở bản ghi (không migration), Vitest |
| 23:05 | #114 | BUOI-10 danh sách yêu cầu buổi theo khung BUOI10: cột Lớp, Ngày đề nghị, chữ «chỉ Trưởng cơ sở duyệt» cho người không duyệt, chữ trạng thái trống; e2e |
| 23:04 | #160 | A13 cụm 2 / A14: trạng thái «không có quyền» riêng cho GV-02, 03, 10, 11, 13, 16 khi máy chủ từ chối (HMT_KHONG_CO_QUYEN); Vitest |
| 23:04 | #161 | C16 cụm 2: khung Tạo báo giá, Tạo đơn theo khuôn chung (BH02_tao_moi, BH05_tao_moi): câu «Chưa lưu…», nút Gửi/Trình duyệt mờ kèm «Lưu rồi mới…», cột ghi chú «Lưu để bắt đầu ghi chú» |
| 22:56 | #131 | B3 bản ghi ticket theo CSN03: thêm Kênh, Cơ sở, Lớp, Ghi danh, Ticket gốc (migration 352) |
| 22:48 | #152 | A13 cụm 1 (chữ theo khung 9189): GV-04 dấu thời hạn, GV-07 em chưa điểm danh, GV-10 lớp được phân công, GV-11 lịch sử buổi, GV-12 sắp theo hạn, GV-16 giờ dạy tính cho người dạy thật |
| 22:48 | #156 | BC-09: màn Giờ dạy giáo viên (phần đọc, chưa có Chốt tháng), Vitest, e2e |
| 22:47 | #154 | B11: pgTAP 356 bị chặn cho hàm ticket (CSKH cơ sở khác, giáo viên, CSKH không phải Admin, khách anon) |
| 22:47 | #158 | D19: bài pgTAP bổ sung cho ca bị chặn của hàm tiền ra (phiếu chi, số dư, hoàn phí, dừng học, hàm nội bộ) |
| 22:37 | #144 | CH-07 Rubric nhận xét, phần DB: phiên bản theo bộ, hàm ghi cho Admin, buổi chụp mô tả mức (migration 503) |
| 22:36 | #149 | CI: job Playwright chạy trong ảnh chính thức mcr.microsoft.com/playwright, PR chỉ chạy chromium (D18) |
| 22:17 | #111 | BC-08: hàm báo cáo giáo viên trễ hạn hằng tháng (migration 554, chỉ đọc); pgTAP 14 bài, EXPLAIN 150.000 buổi |
| 22:16 | #130 | T8: người tạo, kể cả Admin, không tự duyệt bước quản lý hoàn phí và dừng học (migration 458), pgTAP |
| 22:16 | #117 | Sửa T5: dừng học trừ giờ đã hoàn một phần, giờ tặng không thành tiền (migration 456), pgTAP tái hiện |
| 22:16 | #113 | Q1 (Soát): Admin không thể được cấp Kế toán · Duyệt qua ma trận (migration 455, CAO), pgTAP tái hiện |
| 22:14 | #138 | CH-05, CH-06 khung chương trình: phần DB (migration 300, CAO) |
| 22:14 | #123 | P1 (Soát): bọc auth.uid() trong bốn chính sách RLS còn sót (migration 457), pgTAP kiểm không còn chính sách trần |
| 21:58 | #99 | TT-C: màn Tái tục TT-01 (danh sách, Kanban), hộp Tạo TT-03, hộp Giao (migration 414) |
| 21:54 | #124 | CHUNG-15: hàm gộp «việc chờ tôi duyệt» (migration 556) |
| 21:54 | #121 | BC-09: hàm báo cáo giờ dạy giáo viên theo tháng, tách loại buổi (migration 555, chỉ đọc; chưa có Chốt tháng) |
| 21:53 | #101 | TC-14 Số dư khách hàng: hàm đọc (migration 453), màn danh sách và lịch sử, pgTAP (xếp sau #95) |
| 21:48 | #91 | Sửa T3, T4 của Soát: chặn huỷ đơn còn ghi danh, không cấp lại giờ ghi danh đã Dừng/Hoàn phí (migration 451), pgTAP |
| 21:43 | #86 | Hàm áp dụng hoàn phí và dừng học cho phiếu Aftersale (migration 235, nội bộ, chưa nối), pgTAP |
| 21:38 | #89 | Sửa T1, T2 của compute_refund: trừ tiền đã hoàn, không hoàn giờ tặng (migration 450), pgTAP |
| 21:13 | #105 | AccountMenu: nhãn nút bắt đầu bằng chữ hiển thị, «Tài khoản» đặt sau (axe label-content-name-mismatch) |
| 17:05 | #142 | CI: tách job «DB (pgTAP) + Playwright» thành hai job riêng DB (pgTAP) và Playwright (D13) |
| 16:24 | #136 | B8 kiểm thử phiếu: pgTAP công tắc AFTERSALE, e2e từ chối và huỷ phiếu (chỉ thêm bài kiểm) |
| 16:20 | #134 | B4 CSN-04: hộp thoại đổi trạng thái ticket (Huỷ, Mở lại, Đóng làm tay, Đóng khiếu nại) theo canvas |
| 16:04 | #107 | Đề xuất báo giá từ phiếu tái tục (chỉ tài liệu): hiện trạng DB, kế hoạch sửa 8 hàm, rủi ro |
| 16:03 | #122 | docs: đề xuất lịch tự kết thúc bảo lưu đã tới hạn (chờ anh duyệt, chưa bật) |
| 16:03 | #129 | docs: hàm bổ sung vùng Lớp, Buổi, Ghi danh (thẻ A8; chỉ tài liệu) |
| 16:02 | #128 | Thẻ C12: mục lục các hàm Postgres mới của lane C (R-V2-44, thu nợ đầu kỳ, phiếu tái tục) |
| 16:02 | #126 | docs: hàm và chính sách của lane E (cổng Giáo viên, migration 500 đến 502) |
| 16:01 | #127 | P2 (Soát): public/_headers cho /assets/* cache một năm, immutable (tên tệp đã có mã băm) |
| 15:49 | #116 | design: nhập gói HMT 6 màn còn thiếu (canvas 1aab, 18/11/2026); CLAUDE.md thêm mục canvas (chỉ tài liệu) |
| 15:49 | #118 | docs/spec: chép 3 quyết định anh Trường chốt 18/11 (chỉ tài liệu) |
| 15:49 | #115 | docs: luật kiểm tra mới 18/11: bộ nhanh trên máy, pgTAP và Playwright do CI, khoá DB lần lượt (chỉ tài liệu) |
| 14:40 | #106 | Hiệu năng đăng nhập: tải sẵn khung CRM, trang chủ, khung giáo viên và phông chữ lúc rảnh ở trang đăng nhập; Vitest |
| 13:32 | #92 | e2e: luồng bị chặn quyền BUOI-13 và BUOI-06 (không migration; LOP-09 bỏ theo Chat 11:35) |
| 12:20 | #98 | docs: CHUNG-12 thông báo, màn BC-01 (chỉ tài liệu) |
| 12:20 | #93 | TT-01..04: đề xuất chia 5 PR và câu hỏi cần chốt (chỉ tài liệu) |
| 12:19 | #83 | R-V2-25: chốt lại 18/11, giữ phiếu tái tục theo canvas 9933 |
| 12:19 | #96 | e2e: người không phải Admin mở thẳng QT-11, QT-12 phải bị chặn |
| 12:18 | #90 | BC-01 Tổng quan Ban giám đốc: màn bao-cao/tong-quan trên hàm report_overview có sẵn (không migration), Vitest |
| 12:14 | #87 | Sửa pgTAP 260: thứ tự phân trang ổn định (chỉ sửa bài kiểm) |
| 10:31 | #68 | Đề xuất luật R-V2-44: Admin chuyển người duyệt khi người đã chốt bị khoá (chỉ tài liệu, chờ Chat chốt) |
| 09:10 | #50 | Bump the npm-patch-minor group across 1 directory with 23 updates |

### 16/11

| Giờ | PR | Việc |
|---|---|---|
| 19:40 | #78 | AccountMenu: nhãn nút tài khoản chứa tên và dòng vai trò đang hiện (luật axe label-content-name-mismatch); Vitest |
| 18:55 | #77 | docs: chuyển lớp, bảo lưu ghi chú hàm áp dụng (migration 234) |
| 18:43 | #76 | docs: lời gọi hai hàm áp dụng bảo lưu và chuyển lớp cho execute_ticket_task (dành cho Code B) |
| 18:39 | #75 | Hàm áp dụng bảo lưu và chuyển lớp cho phiếu nghiệp vụ Aftersale (migration 234, nội bộ, chưa nối), pgTAP |
| 18:38 | #74 | Tạo phiếu nghiệp vụ từ chi tiết ticket (migration 261) |
| 18:33 | #67 | TC-02 Thu nợ đầu kỳ, phần DB (migration 251, 252; khoá theo phụ huynh; cờ tắt mặc định) |
| 18:33 | #70 | Playwright: người không phải Admin mở thẳng 6 màn Quản trị phải bị chặn (chỉ thêm bài kiểm) |
| 18:32 | #71 | Aftersale phiếu nghiệp vụ: màn CS-05 danh sách, CS-06 chi tiết (migration 260) |
| 18:32 | #69 | View báo cáo BTVN BC-07: report.homework_summary (migration 233), pgTAP |

## Trạng thái 16/11/2026 (repo mới `hmt-edu/hmt-platform`, PR đánh số lại từ #1; đã gộp tới #66, 17:50)

Từ 15/11 chạy **chế độ tự chủ** (Tester gộp bằng `gh pr merge --squash --match-head-commit`, cổng gộp tự động đọc `DANH-SACH-DAT`), 4 Code song song, repo **đã công khai** ngày 16/11 (đã dọn tên tài khoản, họ tên, tên miền; `docs/van-hanh/cong-khai-repo.md`). Mọi tính năng chạm luồng ổn định (bán hàng, thu tiền, ghi danh, điểm danh) đi qua cờ phân hệ **mặc định tắt**; Chat bật theo cơ sở khi Tester đạt (Cấu hình > Công tắc tính năng, QT-10).

| Mảng | Đã gộp (số PR) |
|---|---|
| Cổng giáo viên và buổi học (Code A) | GV-11 (#1), P7 tự Done ghi lỗi (#2), BUOI-14 sửa điểm danh sau Done (#4), BUOI-13 đổi giáo viên một buổi (#5), GD-05 điều chỉnh giờ (#6), F5 F6 F7 làm cứng hàm (#8), GV-03 lịch tháng (#14), dấu Đúng/Trễ hạn (#15), GV-13 hồ sơ rút gọn (#17), GV-16 giờ dạy của tôi (#19), BUOI-08/10 yêu cầu buổi củng cố (#20), BUOI-09 học bổ trợ (#21), BUOI-07 học bù (#23), GD-07 sắp hết giờ (#30), BUOI-15 điểm danh trong ngày (#31), GV-14 ticket từ cổng giáo viên (#53), BUOI-06 thêm học thử (#62) và Playwright (#65), chấm BTVN thông báo lưu (#55), tài liệu hàm (#59) |
| Bán hàng, tiền (Code C) | UI-O4 tạo đơn từ cơ hội (#9), TC-09 hoàn tác khoản tiền vào (#29), CH-09 điều khoản thanh toán (#40), CH-04 chính sách chiết khấu (#42), BH-09 cho học trước đóng tiền sau (#64) |
| Aftersale (Code B) | luật AS-01..13 (#16), ticket CS lát đầu (#18), chi tiết, giao, tạo mới, SLA, nhóm (#28), phiếu nghiệp vụ A1 (#66) |
| Chuyển lớp, hoàn phí, bảo lưu, dừng học, báo cáo (Code D) | chuyển lớp, chuyển cơ sở (#32), BC-01 tổng quan (#33), tính hoàn phí (#36), view báo cáo (#39, #61), bảo lưu (#41), hoàn phí bản ghi và phiếu chi (#54), dừng học giữ số dư (#56) |
| Quản trị, cấu hình | QT-09 tham số (#34), QT-10 công tắc (#35), QT-14 ngày nghỉ lễ (#37), QT-05 ma trận quyền (#43, #58), QT-04 vai trò (#52), QT-08 cơ sở và phòng (#60, #63) |
| Nạp dữ liệu (Code B) | PR-1 (#10), PR-2 số dư (#44), PR-3 kiểm trước nạp (#45), seed lớn (#12) |
| Kiểm thử và hạ tầng | T4 đường học sinh mới (#13), sửa bài nháy (#7, #22, #24, #27), thay số điện thoại giả (#11), dọn trước khi công khai (#46, #47, #48), siết workflow, Environment staging và preview (#49, #51), `--include-all` ở deploy staging (#57) |

Còn chờ (cần quyết hoặc cần khung thiết kế): BC-08, BC-09 (giáo viên trễ hạn, giờ dạy theo tháng và chốt tháng), CH-05..07 (khung chương trình, rubric), CHUNG-15 (hàng chờ duyệt) chưa vẽ; BUOI-06 làm theo phương án an toàn (cơ hội từ L5, chờ Chat xác nhận); GD-07 chưa có cột phiếu tái tục (R-V2-25 bỏ tự sinh).


## Trạng thái 13/11/2026 (PR đã gộp từ 00:00 giờ Việt Nam tới 04:32, #260 đến #267)

Từ 13/11 quy trình làm việc theo `docs/hmt/quy-trinh-lam-viec.md` của repo `dieu-phoi-kit` (phiếu là issue có nhãn `phieu`, báo cáo ở issue #260 của repo đó): Chat gộp PR; PR rủi ro cao chỉ gộp khi tester báo ĐẠT đúng commit cuối (Q-42). Mỗi PR dưới đây có đúng một dòng. «Chưa làm» lấy từ mô tả PR và báo cáo tester; chưa dòng nào có bằng chứng trên staging hay dữ liệu thật.

| PR | Màn / luật | Làm được | Chưa làm |
|---|---|---|---|
| #260 | R-CRM-17 (migration 126, rủi ro cao) | Duyệt phiếu thu: cơ hội L8A/L8B tự lên L8C khi mọi đơn đã duyệt thu đủ (xét từng đơn, chỉ tính phiếu đã duyệt), cùng giao dịch; đã L8C không lùi; pgTAP 7 ca; tester ĐẠT (nhật ký có dòng L8B sang L8C) | Kịch bản 17 bước bấm tay, hiển thị dòng lịch sử trên giao diện thật, staging; chưa thử riêng hoàn tiền sau khi đã L8C |
| #261 | Quay lại khi deploy production lỗi (phiếu T3, chỉ tài liệu) | `docs/van-hanh/quay-lai-khi-deploy-loi.md`: chụp gì trước deploy, bảng triệu chứng, quay giao diện bằng Rollback của Cloudflare Pages, quay DB bằng bản sao lưu | Chưa diễn tập trên production; chưa có workflow Restore production; `nap-du-lieu-17-11.md` chưa có mục xử lý nạp hỏng giữa chừng |
| #262 | CLAUDE.md, luật gộp PR (Q-42, chỉ tài liệu) | Chat điều phối toàn quyền soát và gộp; rủi ro cao cần tester ĐẠT đúng sha; thay luật gộp 10/10/2026 và Đ279 | Không đổi luật deploy chạy thật |
| #263 | GV-03 Lịch dạy, R-GV-08 | Màn thật cho `/gv/lich-day`: tuần 7 cột (máy tính), dải 7 ngày và danh sách theo giờ (điện thoại), chỉ buổi của mình, bấm buổi tới GV-04; không migration | Chế độ tháng (phiếu chỉ yêu cầu tuần); chưa thử dữ liệu thật |
| #264 | GV-09 Hoàn tất buổi, R-GV-04, R-GV-05, R-GV-08 | Nút Hoàn tất ở GV-04 mở hộp (tấm trượt trên điện thoại) liệt kê em chưa điểm danh, chưa chấm, thiếu BTVN, nút Đi tới, Hoàn tất khoá khi còn thiếu; không đổi tình trạng buổi; không migration; tester ĐẠT | **Dấu Đúng hạn/Trễ hạn hệ thống để sau 17/11** (Chat quyết 13/11, mục dưới): hiện chỉ so giờ hiện tại với hạn máy chủ khi chưa Done; buổi đã Done không đóng dấu; chưa kiểm trạng thái buổi trong DB sau Hoàn tất, staging |
| #265 | GV-10 Lớp của tôi, R-GV-08, R-GV-09, R-GV-13 | Màn thật cho `/gv/lop`: lớp được phân công (giáo viên, trợ giảng), sĩ số, lịch học, buổi tiếp theo; không hiện phụ huynh, học phí; không migration; tester ĐẠT | Trang đích `/gv/lop/:id` (GV-11, phiếu P4) chưa gộp nên bấm lớp ra trang không tìm thấy; kiểm sĩ số trên dữ liệu có học sinh xếp lớp |
| #266 | GV-12 Việc cần làm, R-GV-05, R-GV-11 | Màn thật cho `/gv/viec-can-lam`: buổi chưa hoàn tất kèm hạn còn lại hoặc quá hạn, bài BTVN Nộp sau chờ cập nhật theo lớp, Mở tới GV-04 và GV-08; không migration; tester ĐẠT | Mục «phiếu test chờ chấm» ẩn, để sau 17/11; bài Nộp sau lấy bằng một lần gọi mỗi lớp (90 ngày), gọn hơn cần hàm DB mới (phiếu riêng, rủi ro cao); staging |
| #267 | Cờ và tham số CS5 cho 17/11 (chỉ tài liệu và SQL) | `docs/van-hanh/cau-hinh-cs5.md` và khối (d) chỉ đọc trong `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql`: 7 giá trị bắt buộc (cờ VAN_HANH_LOP, BAN_HANG; opening_balance_date; session_done_requires_review; teacher_session_complete_hours; chu kỳ tự chốt, tự Done) khớp trên DB cục bộ; tester ĐẠT | Chưa chạy trên hmt-prod hay staging; pg_cron trên production chưa kiểm; `import_user_email_domain` chưa có giá trị chốt cho production (chờ anh, Q-44) |

**Tiến độ cổng Giáo viên (LÕI 17/11) sau 13/11:** thêm GV-03, GV-09, GV-10 và GV-12 vào `main` (ngoài GV-01, 02, 04 đến 08, 07K đã có). GV-11 (Chi tiết lớp) đang làm ở phiếu P4: PR còn mở, chưa gộp. Về nghiệp vụ bán hàng, thu tiền: R-CRM-17 đã có (#260).

**Để sau 17/11 (Chat đã quyết):** cột lưu dấu Đúng hạn/Trễ hạn do hệ thống ghi lúc Done (cần cột và sửa hàm Done; không dùng cột cập nhật cuối vì sai khi sửa sau Done); phiếu test chờ chấm ở GV-12; chế độ tháng của GV-03.

**Đang mở:** PR phiếu P4 (GV-11, rủi ro cao, thêm hàm đọc `app.teacher_class_overview`).

## Trạng thái 12/11/2026 (theo `main`; PR đã gộp tới #251; #234 là PR tài liệu TIEN-DO 10/11)

Kế hoạch, quy tắc hai Code và hàng đợi tới 17/11: `docs/ke-hoach/ke-hoach-17-11.md`, `docs/quy-tac-cung-cho-code.md`. Mục tiêu 17/11: cơ sở 5, LÕI 28 màn.

**Đã gộp vào `main` từ 28/10 đến 11/11 (mỗi PR có link OK của TÀI KHOẢN GỘP trong commit gộp; PR chỉ tài liệu hoặc thiết kế không có CI):**

| Nhóm | PR |
|---|---|
| Nạp dữ liệu: màn Nhập (QT-18), loại Cơ hội, nạp Người dùng và chốt chặn username, bảng chọn 8 loại (lát 1), nạp Cơ hội (migration 072), D1e nạp dữ liệu đào tạo (migration 105) | #167, #173, #175, #183, #221, #223 |
| Quản trị người dùng và danh mục: Tạo người dùng, Sửa email, Đặt lại mật khẩu, Danh mục (QT-06, QT-07), nhóm tự đăng xuất (migration 070), phòng CS5 (071) | #163, #166, #172, #178, #201 |
| Bán hàng: Gói bán và Bảng giá theo gói, Sửa, Duyệt, Từ chối đơn, dòng thời gian, LineTable và Báo giá Tạo, Sửa, Ưu đãi linh hoạt, chip, người duyệt khi chưa có quản lý trực tiếp, BH-11 phần máy chủ (cơ hội đã có đơn Nháp) | #179, #181, #187, #188, #190, #193, #195 đến #198, #200, #204, #205, #215 |
| Thu chi: Phiếu thu (migration 076, TC-01 đến TC-04, TC-07), nối duyệt phiếu thu với ghi danh (migration 106) | #180, #199, #224 |
| Đào tạo, DB: Lớp, Ghi danh, Sổ giờ, Buổi, Điểm danh (D1, migration 100 đến 102), Nhận xét và Kiểm tra (D2, migration 103), pg_cron tự chốt và tự Done (104) | #209, #219, #220 |
| Nền và công cụ: ngày hôm nay giờ Việt Nam (R-HT-07), nguồn lead (Q-137), cổng xem trước Playwright theo biến (Q-222), khoá nặng `scripts/heavy-lock.sh`, CI giảm phút | #185, #192, #203, #207, #210, #213, #222, #227 |
| Tài liệu và thiết kế: canvas Bán hàng & Thu chi (abea), Đào tạo & Giáo viên (9189), Quản trị (dc47); hướng dẫn chạy thật, quay lại bằng bản sao lưu, đổi chủ repo | #164, #168, #169, #170, #176, #177, #189, #202, #208, #211, #212, #216 đến #218, #225 đến #226, #229, #231 |

**Đã gộp 10/11 đến 11/11 (theo `git log` của `main`):**

| Nhóm | PR |
|---|---|
| Cổng Giáo viên, dữ liệu đọc và nội dung buổi (migration 107) | #228 |
| QT-18 lát 2: nạp Lớp và Ghi danh, cột Cảnh báo | #230 |
| Tài liệu nạp 17/11: file mẫu, MO_TA_COT, bật VAN_HANH_LOP, R-GV-07 | #233 |
| Tài liệu: quy tắc cứng cho Code, kế hoạch 17/11, TIEN-DO theo trạng thái 10/11 | #234 |
| GV-01, GV-02 (tab Cần làm, trang Hôm nay) | #232 |
| GV-04 Buổi dạy, GV-06 Nội dung buổi và BTVN (migration 109, 110); GV-05 Điểm danh | #236, #235 |
| Cụm Ghi danh: GD-01, 02, 03, 04, 06, BH-08 (migration 113, 114); e2e xếp lớp theo nhóm lớp (GD-03) | #238, #249 |
| Cụm Lớp: LOP-01, 02, 03, 05, 06, 08 (migration 116) | #237 |
| Cụm Khách hàng: KH-01, 02, 04, 05 (migration 117) | #239 |
| Cụm Buổi A: BUOI-01, 02, 03, 11 và ghi chú vận hành GV-05 (migration 120); Cụm Buổi B: BUOI-04, 05, 12, lý do huỷ buổi, Nhắc GV (migration 123) | #240, #242 |
| GV-07 Chấm nhận xét và GV-08 Chấm BTVN buổi trước (migration 121); GV-07K Chấm kiểm tra (migration 124) | #241, #246 |
| Cụm Thu tiền: TC-08 Khoản tiền vào, TC-13 Công nợ (migration 122) | #243 |
| Công cụ và CI: nâng giới hạn bước Playwright 20 lên 35 phút; cổng kiểm trước khi gộp `scripts/kiem-truoc-khi-gop.sh`; `.vanphong/du-an.yaml` (chỉ cấu hình) | #248, #250, #251 |
| Tài liệu: dải số migration, GD-06, quy tắc hiển thị tạm, quy trình theo ca | #247 |

(#244 và #245 không phải PR trên GitHub; #244 là kênh issue của quy trình theo ca.)

**Đang mở:** không có PR mở (kiểm 12/11).

**Chưa làm cho 17/11 (xem kế hoạch):** 28 màn LÕI đã gộp (GV-01, 02, 04 đến 08, 07K, cụm Ghi danh, Lớp, Buổi, Khách hàng, Thu tiền); phần anh kiểm tay trên staging chưa có bằng chứng. Mốc còn lại: 13/11 đếm tiến độ, 14/11 diễn tập staging, 16/11 đóng băng và deploy production, 17/11 nạp dữ liệu. Cột Đúng hạn/Trễ hạn và báo cáo tham số, cờ CS5: để sau 17/11 theo quyết định của anh Trường 12/11. Migration: 108 bỏ, không dùng lại; Code 1 dùng 111, 113, 114, 115; Code 2 dùng 109, 110, 112, 116, 117, 118 (kế hoạch, giữ nguyên).

**hmt-prod: migration chưa xác nhận.** Lần xác nhận cuối: tag `staging-20261010-1642-75637cf`, có thể tụt xa so với `main` (migration 124). Claude Code không đọc chạy thật (anh Trường biết trạng thái thật). Lần thử deploy production dự kiến tối 12/11, deploy thật 16/11, nạp dữ liệu 17/11.

## Đang ở đâu (28/10/2026)

**Đã gộp vào `main`** (mỗi PR có link comment "OK" của TÀI KHOẢN GỘP trong commit gộp; PR chỉ tài liệu không có CI):

| Nhóm | PR |
|---|---|
| Nền GĐ0: hạ tầng, dữ liệu nền, đăng nhập, phân quyền, quản trị tài khoản, Hội sở CS3, dữ liệu khuôn dùng chung | #1 đến #15, #17, #18 |
| Gói thiết kế P0 đến P2 và giao diện khuôn: gói v1, v2, v4; hệ thiết kế; thành phần và khung CRM; danh sách, Kanban, Calendar; ô nhập; bản ghi, hộp thoại, ghi chú | #19 đến #26 |
| Luật và danh mục: luật 16/10, danh mục L5P, L6, danh mục 33; sửa lệch spec 06; danh mục phẳng và hai cấp | #27 đến #31 |
| Ma trận quyền: phiên bản, tách phân hệ (Cấu hình bán hàng, Cấu hình đào tạo, Ngày nghỉ lễ, Lịch hẹn) | #32, #33 |
| P3 Tuyển sinh: tài liệu (P3a), dữ liệu nền lead và lịch hẹn, ma trận quyền phiên bản 3 (P3b1) | #34, #35 |
| Nguồn canvas Design (P4, P5a, P5b) và nhật ký bàn giao; tách gói tải; nền tảng phối hợp ba bên; luật 17/10 | #36 đến #40 |
| Đăng nhập (5a, 5b), Trang chủ theo vai trò, cập nhật tiến độ | #41 đến #44 |
| P3b Tuyển sinh dữ liệu: Cơ hội, ma trận quyền phiên bản 4, Phiếu kiểm tra đầu vào, Gộp trùng, Nhập lô lead; luật và tiến độ 18/10 | #45 đến #52 |
| P3c Lead, Lịch hẹn: dữ liệu và giao diện màn Lead (danh sách, Kanban, trang Lead, Tạo lead), DB và giao diện màn Lịch hẹn; lưu canvas v64; luật 19/10 (bảy luật Bán hàng, Thu chi, quản lý trực tiếp) | #53 đến #58, #60, #63, #64 |
| Sửa nhóm đăng nhập theo gói hiện hành; nền động đăng nhập (5c) | #59, #62 |
| Quản lý trực tiếp (R-HT-06, migration 036); luật bổ sung 19/10 (người duyệt chốt lúc trình, Admin không duyệt thay phiếu thu) | #61, #65 |
| P3d Cơ hội: DB (migration 038) và giao diện (danh sách, Kanban, trang bản ghi, chuyển giai đoạn, tạo từ lead) | #66, #67 |
| Tuyển sinh tiếp: Phiếu kiểm tra (DB, giao diện), Gộp trùng và Nhập lead (DB, giao diện), Lịch hẹn bổ sung (DB, giao diện), Quản trị người dùng (DB, giao diện); dọn khung cũ; CI cắt sớm; luật giáo viên, nghiên cứu chấm bằng AI | #68, #70 đến #85 |
| Bán hàng, nền: danh sách em, cấu hình bán hàng và ma trận quyền v5, báo giá (bảng, tính tiền), luật và quyết định bán hàng (R-TIEN-37, Đ169 đến Đ259) | #87 đến #91, #99, #101, #104, #106, #112, #113, #120, #121, #126, #128, #132 đến #134 |
| Sửa lỗi 26/10 và canvas lưu nguồn: nhóm con lead, đường dẫn thanh trên, ghi chú lead ở cơ hội, lịch hẹn đồng bộ, Sub-stage L6; canvas v117, v118, v124 | #92 đến #98, #100, #102, #103, #122 |
| Quyết định v2 (04/11): bảng khác biệt (#153); T1 vai trò Marketing, CS3 dạy học thường, hồ sơ phụ huynh mọi cơ sở xem, hàm gợi ý tên đăng nhập (#154, migration 064); T2 SĐT thứ hai và cột mới phụ huynh, học sinh (#155, migration 065); T3 nhóm con L4E đến L4H, L7M đến L7S, danh mục 33 thành BQ1 đến BQ5 (#156, migration 066); T3b nhóm con L5, L6 theo Config mới: L6 đánh lại A đến G, L5P và L5Q Ngừng, hàm gắn nhóm con sửa theo (#157, migration 067); T4a nạp Phụ huynh và Học sinh theo loại, chỉ Admin, xem trước rồi nạp, không in họ tên, SĐT (#158, migration 068); T4b nạp Người dùng: Edge Function `import-users`, mật khẩu tạm trả một lần, email quy ước theo tham số, nhiều cơ sở lấy cơ sở đầu kèm cảnh báo (#162, migration 069); nhóm tự đăng xuất đọc từ cột `idle_group` của bảng vai trò thay danh sách viết cứng, sửa 3 vai trò Marketing bị tính như học sinh (migration 070) | #153 đến #158, #162, PR nhóm vai trò |
| Bán hàng, DB: ma trận quyền v6, đơn hàng (ghi, đọc, xuất), báo giá (tên em, xem thử, gói bán, chính sách, lọc Đã chuyển đơn, quà tặng, tổng chiết khấu) | #105, #107, #108, #110, #114, #115, #117, #119, #123, #125 |
| Bán hàng, giao diện: BH-01 danh sách báo giá; BH-02 xem, Gửi, Từ chối, Huỷ, sửa Nháp (lưới K06c, chính sách, quà tặng), Tạo báo giá từ cơ hội | #109, #111, #116, #118, #124, #127, #129 đến #131 |
| 28/10: BH-06 danh sách đơn (#135, #142 tên các em); DB-O1a, O1b, O1c (#136, #137, #141: quyền hàm đọc phụ, tạo đơn kèm điều khoản, tổng niêm yết, người duyệt dự kiến, ghi chú đơn); BH-03 bản in báo giá (#140, #143); BH-05 xem đơn (#144); luật R-TIEN-39, CLAUDE.md, đổi tài khoản GitHub (#138, #139, #145) | #135 đến #145 |
| Lead đổi giai đoạn bắt chọn nhóm con (R-CRM-41, QĐ-Đ183): migration 049, hộp chọn Sub-stage ở trang Lead và Kanban (DB và giao diện cùng PR để CI không đỏ) | #98 |
| Lead chỉ tạo cơ hội ở nhóm con C4C (migration 048, luật R-CRM-40 ở #90; nút Tạo cơ hội mờ kèm lý do) | #97 |

#16 đã đóng (không gộp; dữ liệu ở #17, giao diện làm lại ở #22 đến #26).

**Đã gộp 23/10:** #68 (nợ nhỏ: sửa gốc bài kiểm chập chờn, Hoàn tác), #70 (luật TD14, QĐ-Đ7, bản đồ màn hình, TIEN-DO).

**Đã gộp 23 đến 24/10 (tiếp):** #71 (P3e-1 DB), #72 (P3e-2 giao diện), #73 (dọn khung cũ, GD-02), #74 (QĐ-Đ10 đến Đ20), #75 (P3f-1 DB), #76 và #78 (CI: cắt sớm, thử lại, cache gói apt của bước cài trình duyệt), #77 (P3f-2 giao diện Gộp trùng, Nhập file), #79 (luật giáo viên vào spec 04, QĐ-Đ21 đến Đ32), #80 (Lịch hẹn bổ sung-1 DB, Đ37), #81 (Lịch hẹn bổ sung-2 giao diện), #82 (Quản trị người dùng-1 DB).

**Đang mở:** #69 (lưu canvas Design, khuôn K4g, K4e4): chờ Design lưu bản cuối (bản 25 trở đi, sau khi Design sửa K12 thành biểu mẫu: bỏ Filters/Group By/Favorites, nút Làm mới, nút Cột, ô tìm kiếm; QĐ-Đ12, QĐ-Đ17) và anh nói "lưu". PR giao diện Quản trị người dùng (QT-01, QT-02): chờ CI và OK.

**Bản chạy thật** (`<tên-miền-chạy-thật>.pages.dev`, `app.hoamatoan.edu.vn`) lần xác nhận cuối còn ở tag `staging-20261010-1642-75637cf` (lúc đó tụt nhiều migration, 013 đến 038, và toàn bộ giao diện mới); migration hiện tại chưa xác nhận, có thể tụt xa so với `main` (migration 124).
Anh cập nhật khi sẵn sàng: `hmt-deploy` > Deploy production (chọn tag đã qua staging), kèm chép `deploy/.github/workflows/bootstrap-admin.yml` mới sang `hmt-deploy`.
Môi trường thử nghiệm tự cập nhật sau mỗi lần gộp.

**Thứ tự việc anh làm trên bản chạy thật trước khi nạp người dùng thật (anh chốt 05/11; hmt-prod hiện chưa có migration 069, vì còn dừng ở tag cũ):**
1. **Đưa bản mới lên chạy thật qua `hmt-deploy`** > Deploy production, chọn tag đã qua staging và có migration mới nhất (071 là mục tiêu của bước 1, không phải trạng thái đang chạy; migration mới nhất trên `main` hiện là 124; hmt-prod: migration chưa xác nhận; phải gồm 069 nạp Người dùng, 070 nhóm tự đăng xuất, 071 phòng học tạm). Việc này cũng đưa giao diện mới và Edge Function (kể cả `import-users`) lên. Kèm chép `deploy/.github/workflows/bootstrap-admin.yml` mới sang `hmt-deploy` nếu chưa chép. Sau đó kiểm: `select max(version) from supabase_migrations.schema_migrations;` đúng số migration mới nhất của tag đã chọn.
2. **Đặt miền email quy ước:** `select app.set_setting('import_user_email_domain', 'nv.hmt.invalid');` rồi đọc lại `select app.get_setting('import_user_email_domain');` phải ra `nv.hmt.invalid`. Chạy trước bước 1 sẽ báo "Chưa khai báo tham số" (anh đã gặp). Staging anh đã đặt xong 05/11.
3. **Kiểm trước khi nạp:** (a) `select code, idle_group from app.role order by sort_order;` đúng: ADMIN, BRANCH_MANAGER, SALES, CSKH, ACCOUNTANT, MARKETER, MARKETING_MANAGER, MARKETING là `staff`; TEACHER, TA là `teacher`; STUDENT, PARENT là `student`; (b) `select code, name from app.room order by code;` có 5 phòng mỗi cơ sở CS1 đến CS5 (CSx_T1_01 đến CSx_T3_01), không có P101, P102, ONL1; (c) bản chạy thật không có dữ liệu giả: `select exists (select from app.holiday where name like '%(thử nghiệm)');` phải ra `false` (lệnh tạo tài khoản giả chỉ chạy khi thấy `true`, nên không bao giờ chạy trên bản chạy thật).
4. **Cần kiểm thêm trước khi nạp (em chưa xác nhận được, anh hoặc em kiểm khi bước 1 xong):** secret của Edge Function trên hmt-prod (khoá `sb_secret_`, khoá bí mật Turnstile) đã đặt trong `hmt-deploy`; công tắc tính năng theo cơ sở (`app.feature_flag`) cho các phân hệ đang dùng ở CS5; tài khoản Admin chạy thật còn đăng nhập được sau cập nhật.
5. **Nạp người dùng thật** (Edge Function `import-users`, xem trước rồi nạp, mật khẩu tạm tải một lần), rồi các lần nạp sau theo `docs/nghiep-vu/nap-du-lieu.md`.


## Thứ tự tiếp theo (anh chốt 23/10)

1. **P3e Phiếu kiểm tra:** PR 1 DB (migration 039: `get_student_test`, đếm nhóm, Xuất, danh sách giáo viên chấm và phòng) rồi PR 2 giao diện (TS-16 danh sách + Kanban + Lịch, TS-17 trang phiếu, TS-15 tạo và đổi lịch; mở khoá mã phiếu ở trang Cơ hội và hộp chặn L7, L8). Anh duyệt kế hoạch 23/10 (QĐ-T6: gộp ba kiểu xem một PR). **Cả hai PR đã gộp** (P3e-1 DB, P3e-2 giao diện).
2. **P3f:** Gộp trùng (TS-10) và Nhập file (TS-04). Anh duyệt kế hoạch 23/10: **Cả hai PR đã gộp** (PR 1 DB migration 040, PR 2 giao diện) (CSV trước; đọc UTF-8 có BOM, dấu phân cách "," hoặc ";"). Chỉ gộp Lead và Cơ hội (QĐ-P3f-1).
3. **PR "Lịch hẹn bổ sung":** Xuất, Group By, chọn hàng loạt kèm Giao việc, Lịch "Theo người" (anh chốt QĐ-Đ6, Đ33 đến Đ38); bỏ "Theo phòng" và "Nhập". **Cả hai PR (DB, giao diện) đã làm.**
4. **QT-01, QT-02, QT-03 Người dùng** (kèm ô "Quản lý trực tiếp"): anh duyệt kế hoạch 24/10 (Đ44 đến Đ50): **PR 1 DB (migration 042) đã gộp; PR 2 giao diện (QT-01, QT-02) đã làm**; còn **Đặt lại mật khẩu (QT-02) và Tạo người dùng (QT-03)**, chờ khuôn hộp mật khẩu tạm K4g, K4e4 ở #69.
5. **P5a Bán hàng + Thu chi:** đặc tả đã viết (Chat), đứng sau các mục trên; tới lượt thì em gửi kế hoạch P5a-DB1 cho anh duyệt trước khi viết migration. Ghi danh và Lớp thuộc P5b (anh chốt QĐ-P5a-1).

Claude Design: P4 xong. **Thiết kế P5 (canvas v118): đã duyệt ngày 27/10.** Giao diện bán hàng: BH-01, BH-02 (xem, Gửi, Từ chối, Huỷ, sửa Nháp, Tạo báo giá từ cơ hội), BH-06, BH-03 (bản in) và BH-05 xem đơn (UI-O2a) đã gộp; DB-O1a, O1b, O1c đã gộp; UI-O2b (Trình, Huỷ đơn) đã gộp (#147); tiếp theo UI-O2c (Duyệt, Từ chối), UI-O3 (sửa Nháp), UI-O4 (Chuyển thành đơn, BH-11 theo R-TIEN-39; Đ257 hết hiệu lực theo Đ272). Giao diện đào tạo dựng sau phần dữ liệu đào tạo (xem `docs/nhat-ky/design.md`).

## Đã chốt 18/10 (tối)

- **Giờ test ở quá khứ:** giữ chặn khi tạo và đổi lịch như #47 (không có trường hợp test tại chỗ rồi mới tạo phiếu).
- **Ngưỡng dung lượng gói tải:** giữ "chỉ báo số" (`npm run size`, bước CI chỉ in số), **không đặt ngưỡng trượt** (anh chốt 18/10). Đo hiện tại: trang đầu CRM 238 KB nén. `CLAUDE.md` mục Hiệu năng còn dòng "vượt thì trượt": chờ anh OK sửa cho khớp.
- **P3b3 anh chốt 18/10:** nhập lô lead dùng quyền Lead · Tạo (CSKH nhập được; bản đồ TS-04 đã thêm CSKH); CSV trước, Excel sau; gộp lead chuyển cả cơ hội sang lead giữ lại và vẫn chặn khi bản bị gộp đã có báo giá hoặc đơn (R-CRM-22); nguồn, chiến dịch, cơ sở, người phụ trách của file nhập như đề xuất; nút TS-06 đổi thành "Mở cơ hội cũ" (đã ghi bản đồ, dựng ở P3d); ngoại lệ chuyển ghi chú chỉ trong các hàm gộp (gọi trực tiếp vẫn bị chặn, có bài kiểm); R-CRM-37 vào luật [CHỐT]. Điều kiện chặn "học sinh cùng học hai lớp trùng giờ" (R-CRM-25) vẫn [CHỜ].
- **R-CRM-36** (cơ hội mới luôn bắt đầu ở L1) đã vào `docs/spec/04` [CHỐT]; `create_opportunity` khớp (xem `code.md`).

## Đang chờ anh Trường

- Comment OK cho PR giao diện Quản trị người dùng (sau commit cuối); #69 chờ bản cuối của Design và anh nói "lưu" (khi đó làm Đặt lại mật khẩu và Tạo người dùng).
- **Đã chốt 24/10 cho PR DB Lịch hẹn bổ sung:** Đ37 (chặn đổi người phụ trách lịch nhắc tự sinh của phiếu cả ở Dời lịch, trong DB, đã làm trong cùng PR; R-CRM-38 đã vào spec) và Đ38 (lịch "Theo người" theo phạm vi xem của ma trận quyền hiện có, không thu hẹp quyền Sale, CSKH; sửa Đ34). Bài kiểm hiện trạng phạm vi xem của Tuyển sinh giữ nguyên.
- **Chỗ vênh khi chép luật 24/10 (anh xác nhận 24/10, đã xử lý):** R-GIO-05 trùng số với "Tự chốt buổi" nên luật giáo viên không thấy danh sách điểm danh trước khi Đã chốt là **R-GIO-08**; QĐ-Đ27 = duyệt khuôn K09 (báo cáo tháng) và GV-15 "đã nộp, chỉ xem"; không có Đ31 riêng (nằm trong Đ29); R-GV-14 chỉ thêm "tháng tính theo ngày buổi diễn ra"; D-12 ghi ở quyết định thiết kế.
- Cài hạn xử lý ticket chăm sóc tháng (R-CRM-30) trong màn Cấu hình khi có.
- Chưa có quyết định nào khác đang chờ (23/10). Việc sắp tới cần anh duyệt: kế hoạch P5a-DB1 (khi tới lượt).

## Việc phải nhớ khi viết hàm (luật đã chốt)

- **DB2 phiếu thu (Đ284, Q-B3):** `order_has_receipt` (hiện bản tạm luôn trả không) trả true khi đơn có phiếu thu chưa Huỷ (Nháp, chờ quản lý, chờ kế toán, Đã duyệt; phiếu bị từ chối đã về Nháp nên cũng tính). pgTAP: có phiếu thu Nháp thì Huỷ đơn bị chặn `HMT_DON_DA_CO_PHIEU_THU`; phiếu thu đã Huỷ thì Huỷ đơn được.
- **DB-O2c (Đ283, Q-B2; đã gộp #150; UI-O2c còn phải truyền `p_acknowledged` và hiện ô tích ở bước Trình của Trưởng cơ sở, thêm `status`, `auto_approved` vào `SubmitOrderResult`), gộp trước UI-O2c:** `submit_order` thêm `p_acknowledged` (Trưởng cơ sở tự duyệt: Trình và Tự duyệt trong một giao dịch, lõi `approve_order` tách hàm nội bộ dùng chung); `get_order` trả `can_submit`, `can_cancel`, `can_approve`, `can_reject` tính bằng đúng hàm quyền của hàm ghi, kèm pgTAP từng vai trò, từng trạng thái; EXPLAIN `get_order`.
- **Phần Giáo viên (luật 24/10, đã vào spec 04):** (1) R-GV-05: hàm tự đóng dấu Đúng hạn hoặc Trễ hạn **một lần**, đúng lúc lưu mục cuối đủ các bước R-GIO-06; sửa điểm sau không đổi dấu; báo cáo trễ tính cho người lưu mục cuối (R-GV-09). (2) R-GV-11: **trường mới của buổi** "Buổi này không giao BTVN" (cần migration và bài kiểm); vắng buổi giao bài thì đặt sẵn Không áp dụng. (3) R-GV-04: đổi sang Vắng giữ điểm nhưng không tính. (4) R-GV-07: không xoá dòng nội dung đã có điểm; nội dung buổi ít nhất một dòng (QĐ-Đ23). (5) R-GIO-08: giáo viên không thấy danh sách điểm danh trước khi Đã chốt. (6) R-GV-13: hồ sơ học sinh cho giáo viên không có SĐT, học phí, phụ huynh. (7) R-GV-14: tháng tính theo ngày buổi diễn ra. (8) R-CS-10: giáo viên tạo mọi nhóm ticket cho lớp mình. Gửi anh kế hoạch DB giáo viên trước khi viết migration.

- Cơ hội: đã khoá nhóm con L5A, L5B, L5P, L5C đến L5Q, L6A, L8A đến L8C (P3b2a). Giai đoạn phiếu tái tục: khoá L7A, L7B, L8A khi viết hàm tái tục. Đổi giai đoạn cơ hội đã kiểm R-CRM-02, 03, 13, 14, 16 (P3b2a); phiếu: R-CRM-05, 06, 12, 13, 15, 21 (P3b2b, đã làm).
- **Hoãn (ghi 18/10):** R-CRM-16 phần chặn tạo đơn khi chưa L8, R-CRM-17 (tự L8C), R-CRM-18 (cảnh báo lệch): chờ đơn hàng, phiếu thu. R-CRM-12, 13, 15 đã làm ở P3b2b (hai hàm nối đã thay bằng truy vấn bảng phiếu).
- Đã vào luật 18/10: R-CRM-34 (nhóm con L6), R-CRM-35 (đổi nhóm con cùng giai đoạn).
- Đã vào luật 19/10: R-CRM-38 (dời lịch hẹn), R-CRM-39 (lead mới luôn bắt đầu ở C1; `create_lead` đã khớp, bỏ qua giai đoạn người gọi truyền vào, có bài pgTAP 027).
- **Kiểm lại quyền (anh dặn 18/10):** `update_opportunity` kiểm quyền Học sinh · Sửa theo cơ sở của hồ sơ học sinh. Hồ sơ học sinh nay sinh tự động khi tạo phiếu (cơ sở tiếp nhận = cơ sở cơ hội); nhân viên cơ sở khác sửa học sinh ở cơ hội của mình sẽ bị chặn nếu học sinh tiếp nhận ở cơ sở khác. Xem lại khi làm màn.
- Phụ huynh, học sinh (R-CRM-26 đến 28): chỉ sinh trong hàm (phụ huynh khi tạo cơ hội, khớp SĐT chuẩn hoá; học sinh khi tạo phiếu hoặc duyệt đơn, khớp phụ huynh + tên + năm sinh chuẩn hoá); chặn ghi trực tiếp.
- **Cho P3e (ghi 18/10):** (1) bản vẽ TS15 cho **chọn Khối** (ô "Lớp" là danh sách chọn, không khoá; đã kiểm bản vẽ), bản đồ TS-15 đã sửa "Khối chọn khi tạo". (2) **Cơ sở test khác cơ sở cơ hội:** phiếu chép `branch_id` của cơ hội để xét quyền, nên nhân viên cơ sở test chưa thấy phiếu (giáo viên chấm được phân công thì thấy); xem lại ở P3e. (3) **Lịch nhắc tự sinh của phiếu (anh chốt 18/10):** hệ thống tự đóng (Hoàn thành) lịch nhắc tự sinh còn Chưa làm khi phiếu sang Đang test, để thẻ QUÁ HẠN ở Trang chủ và thanh đỏ Kanban không tăng oan; lịch nhắc người dùng sửa tay hoặc tự tạo giữ nguyên; lùi về Nháp không tự mở lại lịch đã đóng. Đã làm ở P3b3a (`start_student_test`, kèm bài kiểm); đóng bằng Huỷ, lý do Khác, ghi chú "Phiếu đã bắt đầu" (anh chỉnh 18/10). (4) Khối "Phiếu kiểm tra hôm nay" của Trang chủ thêm một dòng vào cấu hình khối khi làm P3e.
- **Cho P3f (ghi từ P3b3a, P3b3b):** nhập lô: hộp TS-04 đọc CSV ở trình duyệt, ghép cột (ô "ghi chú" của file ghép vào "Nhu cầu", hiện rõ ở bước ghép cột), gọi `import_leads` xem trước rồi nhập; Excel làm sau.  hộp gộp (TS-10, KH-07) dùng `merge_preview` để hiện số bản ghi chuyển sang, điều kiện chặn và cảnh báo (bản bị gộp ở giai đoạn cao hơn); sau gộp phụ huynh, hiện danh sách học sinh trùng từ `duplicate_students_of_parent`. Hàm sửa phụ huynh, học sinh (KH-03, KH-06) và danh sách phụ huynh, học sinh (KH-01, KH-04) làm sau phải kiểm bản "Đã gộp" chỉ đọc và ẩn khỏi danh sách mặc định (vẫn tìm bằng mã). Điểm nối báo giá, đơn: `opportunity_sales_documents` (hiện rỗng), P5 thay thân.
- **Cho đợt sau (ghi từ P3c-3b, P3d, 19–20/10):** (1) Ô "Gắn với" của hộp Tạo lịch hẹn chọn được lead và cơ hội; phiếu kiểm tra có lịch nhắc tự sinh nên không chọn tay. (2) Bốn nút của màn Lịch hẹn làm sau P3f thành một PR riêng (anh chốt 20/10, QĐ-T5): Xuất (hàm xuất DB), Group By (hàm đếm nhóm DB), chọn hàng loạt kèm Giao việc (mở rộng `assign_owner` sang lịch hẹn), Lịch "Theo người" ở chế độ Ngày. **Bỏ** "Theo phòng" (lịch hẹn không có phòng) và "Nhập" (luật chưa nói về nhập lịch hẹn). (3) Nút "Hoàn tác" trên thông báo sau Hoàn thành, Huỷ đã có ở trang Lead, trang Cơ hội và màn Lịch hẹn (mở lại lịch ngay, không hỏi xác nhận; nút Mở lại ở màn Lịch hẹn vẫn có hộp xác nhận). (4) Khối Lịch hẹn của Trang chủ (CHUNG-14) vẫn mở danh sách chung; lọc sẵn "hôm nay" khi cần. (5) **Màn Cơ hội, chỗ khác bản vẽ:** không có nút Tạo, Nhập (cơ hội chỉ tạo từ trang Lead, R-CRM-01; Nhập là P3f) và trang bản ghi không có nút Tạo; cột "Cơ hội" hiện tên học sinh (bản vẽ ghi "Toán lớp 8 · tên" nhưng cơ hội chưa lưu môn, lớp); hộp TS-09 ở L5 không có ô Sub-stage vì nhóm con L5 do hệ thống gắn (R-CRM-15, bản vẽ TS09d vẫn vẽ ô này); ô "Ghi chú" của hộp (trừ khi bỏ qua test) được gắn vào cơ hội như một ghi chú thường; nút "Mở phiếu" và mã phiếu chờ màn Phiếu kiểm tra (P3e); "Tạo báo giá", "Tạo đơn hàng", "Tạo lịch Test" mờ có chú thích (P5, P3e). (6) Nên thay phần lịch hẹn trên trang Lead bằng hook dùng chung `useOpportunityAppointments` (làm cho Cơ hội).
- **Cho đợt sau (ghi từ P3c-2):** thanh "n / tổng ‹ ›" của trang bản ghi cần ngữ cảnh danh sách đang xem, đang ẩn (anh chốt). Nút "Theo dõi" ẩn vì chưa có hàm. "Tạo chiến dịch mới" của bản vẽ TS-03 chưa làm: chưa có luật ai được tạo chiến dịch và chưa có hàm; ô Chiến dịch chỉ chọn chiến dịch có sẵn. "Gộp trùng" trong menu Hành động hiện ở P3f (hộp TS-10 chờ khuôn), "Tạo cơ hội" ở P3d-1. Hộp trùng SĐT chỉ có "Gắn vào hồ sơ có sẵn" khi đã có hồ sơ phụ huynh (phụ huynh sinh khi tạo cơ hội); chỉ có lead trùng thì chỉ "Vẫn tạo mới" và liên kết mở lead đó. "Học lực", "Mục tiêu" là ô chữ tự do (R-CRM-31). Bản vẽ làm nổi C4 ở màn Tạo lead; làm theo R-CRM-39 (lead mới ở C1).
- **Sửa nhóm đăng nhập (làm 19/10):** màn đăng nhập (P1) từng dựng nhầm theo gói cũ `design/hmt-platform`; đã sửa theo `design/hmt-p0-p2/png` (PR P1-sửa). Đã xác nhận Trang chủ (K09b), khung CRM, danh sách, Kanban, bản ghi dựng theo gói hiện hành; Cấu hình và Khách hàng chưa dựng (menu đang là trang "Sắp có"); khung cổng Giáo viên và Học tập (GV-01, HT-09) vẫn theo gói cũ vì gói hiện hành chưa có bản vẽ. **Nền động (5c)** làm PR sau (bản tĩnh chưa có các ký hiệu toán mờ). Điểm khác bản vẽ: hộp hết phiên (DN09) hiện trên trang đăng nhập mờ chứ không phải trên trang đang mở mờ; DN04 không có liên kết "Đăng nhập bằng tài khoản khác" như bản vẽ; DN03 giữ mã đã nhập sau khi nhập sai.
- **Cho P3c-2 (ghi từ P3c-1b, đã làm ở PR P3c-2b trừ ghi chú ở trên):** màn Lead đang ẩn nút Tạo, Nhập và dấu "+" ở cột C1; P3c-2 dựng màn Tạo rồi hiện Tạo và "+" (chỉ C1, theo anh chốt), P3f hiện Nhập. Mã lead và tên phụ huynh mở `/crm/lead/:id` đang là trang "Sắp có": P3c-2 thay bằng trang bản ghi, và dòng "Đã gộp · vào <mã>" thành liên kết mở bản chỉ đọc (cần trả thêm mã bản giữ lại từ `list_leads`). Hộp Giao `src/features/assign` dùng lại cho cơ hội, phiếu, lịch hẹn (hàm `assign_owner` hiện chỉ lead và cơ hội). Thẻ Kanban rời C4D thì không có Hoàn tác (C4D chỉ hệ thống gắn).
- **Việc phải làm khi đến phân hệ liên quan (anh dặn 19/10):** (1) `opportunity_sales_documents` đang trả rỗng; **P5 (báo giá, đơn hàng) phải thay thân** để luật chặn R-CRM-22 (không gộp cơ hội khi bản bị gộp đã có báo giá hoặc đơn) chạy thật. (2) Mở lại phiếu đã huỷ (`reopen_student_test`) đang nhận biết lịch nhắc bị huỷ theo phiếu bằng cách **so chữ ghi chú** "Phiếu kiểm tra đã huỷ"; **đổi sang cột riêng ở P3e** (ví dụ cột ghi lý do đóng lịch nhắc) để đổi chữ ghi chú không làm hỏng việc nhận biết. (3) Nhập lô 500 dòng đo ở máy em 1 đến 3 giây (xem mô tả PR P3b3b); màn nhập ở P3f hiện tiến trình, khoá nút khi đang nhập.
- Hàm tạo đơn, chuyển báo giá thành đơn kiểm R-CRM-16 (phải ở L8); hàm duyệt phiếu thu gọi kiểm tra R-CRM-17 trong cùng giao dịch, đối chiếu "lệch" R-CRM-18.
- R-CRM-19: bấm Tạo chỉ mở form trắng, Lưu mới cấp mã; nút Tạo nằm trên bản ghi cơ hội (R-TIEN-02).
- Danh mục #25: mục "Tặng giờ chăm sóc (cần duyệt)" cần cờ "cần duyệt" thật khi viết hàm điều chỉnh giờ. Danh mục #23: hàm lọc theo cột `applies_to`, không đọc tiền tố mã.
- Hàm sửa ngày nghỉ lễ: ngày nghỉ chung chỉ Admin sửa; Trưởng cơ sở chỉ tạo, sửa, huỷ ngày nghỉ của cơ sở mình. Đơn từ phiếu tái tục, chuyển phí: tính khi làm màn tái tục.
- Mỗi lớp một dòng đơn, một ghi danh, một quỹ giờ (R-GD-01, 02, 03, 14, 18); lớp Đại + Hình xen kẽ, nhóm lớp (R-LOP-13 đến 15): khi làm Ghi danh, Lớp học, Buổi. Các mục chờ anh quyết: mục "13. Còn mở" của `docs/spec/04`.
- Tham số mới cần khai báo bằng migration: `class_slot_repeat_weeks_max` (4 tuần, khoảng 1 đến 8, R-LOP-13).
- Cách tính phạm vi quyền hiện coi mọi phạm vi khác "toàn hệ thống" là "cùng cơ sở": xử lý khi có phạm vi "được phân công" (`docs/nghiep-vu/tuyen-sinh.md`).

## Việc sau 28/11 (anh Trường chốt 05/11/2026)

- **PDF hướng dẫn người dùng theo quy trình, có ảnh chụp màn hình.** Code viết kịch bản Playwright chụp ảnh trên staging bằng dữ liệu giả; nội dung do Chat soạn theo từng vai trò.
- **Năm màn quản trị và cấu hình, dựng sau mốc 17/11 và xong trước 28/11 (anh chốt 05/11, danh sách cuối), theo thứ tự, mỗi màn một PR riêng, làm song song:** (1) Người dùng, thêm nút Tạo (mật khẩu tạm hiện một lần theo khuôn K4g) **, chức năng Sửa email và đăng nhập bằng tên đăng nhập** (anh chốt 05/11: tên đăng nhập là tên viết tắt có đánh số, `annv`, `annv1`, theo R-V2-08; Edge Function `login` đổi tên đăng nhập thành email, cột `username` không trùng lấy từ cột mã cũ đã nạp, tên cấm trùng mã HS, tên không có trả lời như sai mật khẩu; làm sau 10/11 trong đợt dựng màn Người dùng; ước 6 đến 8 giờ) **và chức năng Sửa email** (anh yêu cầu 05/11: người nạp bằng email quy ước sau này đổi sang email thật; cần Edge Function `admin-users` thêm thao tác đổi email ở Supabase Auth, và bỏ luật "không đổi `login_name`" riêng cho thao tác này của Admin, kiểm trùng email, ghi nhật ký, phiên cũ bị thu hồi; luật này chưa có trong `docs/spec/`: hỏi anh qua Chat ghi luật trước khi làm); (2) Danh mục (QT-06, QT-07); (3) Bảng giá (CH-03); (4) Gói bán (CH-01); (5) Cơ sở và phòng học (QT-08, cần thêm hàm thêm, sửa phòng ở DB).
  - Gói bán và Cơ sở và phòng học chưa có khung: Code tự dựng theo khuôn K10 (cấu hình), anh không nhờ Design vẽ trước; anh báo Design sau.
  - **Để SQL:** Điều khoản thanh toán, Chính sách chiết khấu; nếu đến 27/11 còn thời gian thì làm tiếp. Vai trò, Ma trận quyền, Tham số, Công tắc, nhật ký và các màn Cấu hình, Quản trị còn lại giữ SQL hoặc làm theo phân hệ của nó (bảng đối chiếu 20 mục ở báo cáo 05/11: chỉ Người dùng có màn, 19 mục là trang "Sắp có").
  - Anh OK ngay khi Code báo CI xanh. Nếu xong màn thứ ba mà còn dư nhiều ngày, Code báo anh để anh xem có kéo Điều khoản thanh toán hoặc Chính sách chiết khấu vào không.
  - **Ước lượng (Code, 05/11, thô, chưa kiểm kỹ hàm đọc của Danh mục và Bảng giá):**

    | Màn | Giờ code |
    |---|---|
    | Người dùng, nút Tạo và Sửa email | 5 đến 6 (thêm 2 giờ cho Sửa email: Edge Function, kiểm trùng, bài kiểm thử) |
    | Danh mục | 6 đến 8 |
    | Bảng giá | 5 đến 7 |
    | Ba màn đầu | 14 đến 19 giờ, khoảng 2 đến 3 ngày làm việc |
    | Gói bán, Cơ sở và phòng học | chưa ước lượng lại; trước đó mỗi màn 2 đến 3 ngày |

    Giờ code đã gồm pgTAP cho phần DB mới, Playwright và tài liệu. Mỗi PR còn khoảng 45 đến 60 phút máy chạy (bộ kiểm trên máy khoảng 10 phút cộng chạy lại bài chập chờn, CI khoảng 17 đến 20 phút, gộp và cập nhật staging khoảng 5 phút) chưa tính chờ OK. Code viết PR kế tiếp trong lúc CI chạy; PR có migration gộp theo thứ tự số. Nếu anh OK nhanh: ba màn đầu khoảng 3 đến 4 ngày làm việc; nếu mỗi PR chờ OK nửa ngày: khoảng 5 đến 6 ngày. Code báo thêm nếu thấy con số lệch.
- **Trang hướng dẫn đổi cấu hình bằng SQL cho người tiếp quản.** Viết một trang (kèm đoạn SQL mẫu để sao chép) cho hai màn để SQL (Điều khoản thanh toán, Chính sách chiết khấu) và các mục Quản trị khác theo bảng đối chiếu (Vai trò, Ma trận quyền, Tham số, Công tắc, nhật ký). Nêu hàm DB tương ứng, ai được chạy, cách chạy qua PR, cách kiểm lại. Không viết khoá hay dữ liệu thật vào trang.
- **Dữ liệu gói bán khi nạp (anh chốt 05/11):** 12 sản phẩm nạp dạng đang bán, giá online của 2 sản phẩm để trống, mã gói giữ như file; gói bán không có cột số giờ (giờ do nhân viên điền trên dòng báo giá). Khi làm Bán hàng: hộp chọn gói hiện ô trống cho giá chưa có thì đổi thành chữ "Chưa cấu hình".

## Việc để sau

- **Bài e2e đăng nhập chập chờn (04/11, anh Trường: xử lý sau mốc 10/11, không chặn T3, T4):** chạy cả bộ `check:all` lúc máy bận thì 1 đến 6 bài đăng nhập (SĐT, `enterAs`, tên khác nhau mỗi lượt) trượt ở bước chờ về `/crm`, chạy riêng từng bài đều đạt (T2: `auth.spec` dòng 27 đạt 10/10). Chưa xác định gốc; nghi cùng nguyên nhân dịch vụ đăng nhập local ở mục dưới. Cần: đọc nhật ký auth lúc trượt, thử tăng độ chờ có điều kiện, không nới mù.
- **Bài e2e chập chờn (29/10): đã sửa gốc phần lỗi ứng dụng.** Làm mới danh sách bị lấy kết quả cũ khi một lượt tải đầu của khoá mới (ví dụ vừa gõ ô tìm kiếm) bắt đầu trước lúc thao tác ghi xong: `src/lib/query.ts` huỷ lượt tải đang chạy trước khi làm mới (bài Vitest `query.test.ts`, hai chiều); `lich-hen` chạy lặp 20 lượt (cả máy tính và iPhone) đều đạt. Bài `ban-ghi` (hộp chặn R-CRM-03) đóng hộp bằng nút thay vì Esc ngay khi hộp vừa hiện; nguyên nhân phím Esc bị bỏ qua chỉ NGHI NGỜ, chưa xác nhận (hai lần thử chờ điều kiện vẫn trượt). **Còn theo dõi:** (1) bài Esc ở "Thư viện hộp thoại" (`e2e/ban-ghi.spec.ts`, bài "mở … Esc đóng", khoảng dòng 147) trượt lần nữa thì mở PR điều tra, vì có thể là lỗi thật của hộp thoại; (2) `auth.spec` ở đầu lượt `check:all`: **đã xác định gốc** (29/10): dịch vụ đăng nhập (GoTrue) của Supabase local mất kết nối tới cơ sở dữ liệu ngay sau khi dựng lại DB và tạo tài khoản. Nhật ký auth: `500: error finding user: unable to fetch records: failed to connect to host=supabase_db_hmt-platform user=supabase_auth_admin database=postgres: failed SASL auth (read tcp …: i/o timeout)` và `500: error finding session from refresh token: error finding session: …`; giao diện hiện "Không đăng nhập được, thử lại sau.". Sửa bằng bước chờ sẵn sàng trong `scripts/check-all.sh` (PR "Hạ tầng kiểm thử: chờ dịch vụ đăng nhập, bộ lọc CI"); giả thuyết giới hạn đăng nhập đã loại; (3) bài `lich-hen` "Dời lịch hẹn" trên điện thoại (hàm `pickChip`) trượt một lần trong tám lượt trước khi sửa, 20 lượt sau không trượt. Giả thuyết giới hạn đăng nhập của Supabase local đã loại (không có 429 trong nhật ký auth).
- **Nợ kỹ thuật BH-02 (Đ255, anh OK, tạm chấp nhận):** lưới sửa Nháp gọi xem thử thêm một lần cho mỗi dòng lỗi, vì `preview_quotation_lines` dừng ở lỗi đầu tiên. Cần sửa: `preview_quotation_lines` trả lỗi của tất cả các dòng trong một lần gọi, rồi bỏ ngoại lệ (PR DB riêng, chưa xếp lịch).
- **Danh sách em của lead và cơ hội (QĐ-Đ75 đến Đ117):** DB-1 đã gộp (#88, migration `043`, staging đạt). Còn: PR Danh sách em-2 (DB, luật mới: thêm, sửa, bỏ em, kiểm trùng, tối đa số em, gộp hợp danh sách, ít nhất một em đủ tên và năm sinh), PR giao diện (khuôn K06b, K08b, K08c; sáu màn TS-08, TS-02, TS-06, TS-15, BH-02, BH-05). Chữ luật (spec 04: R-CRM-23, 03, 05, 13, 27, 37, R-TIEN-35, 02, 07; R-GD-13; spec 06 L8A) vào PR sửa luật riêng sau khi #87 gộp. P5a-DB0 đã gộp (#89, migration `044`); P5a-DB1 (báo giá, đơn): chỉ lập kế hoạch gửi anh duyệt trước khi viết migration.
- **LMS và chấm bài bằng AI (giai đoạn 4b/4c, QĐ-Đ62 đến Đ64):** còn mở: (1) lệch R-LMS-04 (20 trang mỗi bài) với tài liệu `docs/nghien-cuu/cham-tu-luan-ai.md` (khoảng 10 trang mỗi bài); (2) "mục D phiếu chấm buổi" chưa có trong luật; (3) cần chốt thời hạn giữ ảnh trên R2; (4) chi phí gói trả phí chưa quyết; (5) bộ chấm chạy ở đâu (Edge Function có giới hạn thời gian) chưa quyết.
- **Quản lý trực tiếp (PR DB `feat/hts-quan-ly-truc-tiep`):** cột, `set_manager`, `approval_route`, `can_approve_as_manager` đã có. **Trường "Quản lý trực tiếp" trên màn Người dùng (QT-01) chưa làm được vì màn QT-01 chưa dựng**; thêm trường khi dựng QT-01 (gọi `app.set_manager`).
- **Quyết định cho Bán hàng (P5), anh chốt 19/10:** Q-P5 người duyệt chốt lúc trình, đổi quản lý sau không đổi (đã vào R-HT-06); Q-P8 Admin không duyệt thay bước quản lý của phiếu thu, quản lý vắng thì Admin "Chuyển người duyệt" sang người khác đủ điều kiện, có nhật ký (đã vào R-TIEN-01); Q-P6 Trưởng cơ sở trình đơn thì mở hộp BH-07, một lần xác nhận, đơn sang Đã duyệt trong cùng giao dịch, lịch sử ghi "trình" và "tự duyệt", vượt trần vẫn phải tick; phiếu thu của Trưởng cơ sở đi thẳng "Chờ kế toán". **Việc còn lại:** nút "Chuyển người duyệt" chưa có trong bản vẽ (nhờ Design vẽ khi dựng TC-17 và hộp duyệt đơn); hàm `can_approve_as_manager` (migration 036) đã khớp: phiếu thu Admin không duyệt thay.
- **Điểm mở Q-P7 (KD6, anh để mở 19/10; 23/10 anh chọn giữ nguyên, QĐ-P3f-2) [CHỐT chờ]:** giữ hành vi nhận trùng phụ huynh theo họ tên + năm sinh học sinh; hai học sinh trùng tên cùng năm sinh của một phụ huynh (ví dụ sinh đôi) chưa có cách phân biệt, nên coi là một hồ sơ và hai cơ hội của hai em gộp được. Chưa thêm cảnh báo mềm; bàn lại khi gặp thật.

- **Nền động trang đăng nhập (PR 5c):** robot, đường nét, ký hiệu toán chuyển động theo bản vẽ DN01; bật "giảm chuyển động" thì đứng yên. Ảnh và video: `docs/so-sanh/DN-dong-*`.
- Giao diện QT-01, QT-02 (tạo người dùng, đặt lại mật khẩu, hai bước, thu hồi phiên, lý do khoá từ danh mục) và QT-08: chờ thiết kế; phần cơ sở dữ liệu đã làm một phần (xem lịch sử PR).
- Trước giai đoạn 4: L2 trong `docs/nghiep-vu/phan-quyen.md` (học sinh, phụ huynh chỉ đọc phần của mình). Giai đoạn 3: chốt trường dữ liệu giáo viên được xem.
- Quên mật khẩu qua email (Resend hoặc SMTP + DNS); khôi phục thử sao lưu, cảnh báo (bước 5).
- `main` chưa bắt buộc PR (kho riêng tư GitHub Free không cho bật bảo vệ nhánh); muốn bắt buộc thì nâng GitHub Pro hoặc thêm workflow kiểm comment OK.

## Anh Trường chốt 16/10/2026 (ghi để PR sau làm đúng)

- **Trưởng cơ sở** xem được danh sách người dùng của cơ sở mình, **chỉ xem** (không sửa, không khoá, không đặt lại mật khẩu). Quyền xem đã có trong ma trận (`ACCOUNT · Xem`, phạm vi cơ sở); màn Người dùng (PR 7 trở đi) phải ẩn mọi nút sửa với vai trò này.
- **Thông báo khi được @**: chỉ ghi ai nhắc và ở bản ghi nào, bấm thì mở bản ghi; **không chép nội dung ghi chú** (đã đúng trong `app.notification`, đã có bài pgTAP).
- **Kanban:** thanh tỷ lệ đầu cột (xanh còn hạn, vàng hôm nay, đỏ quá hạn, xám chưa có lịch); "chỉ đi tới" là tuỳ chọn của từng màn, luôn hiện đủ cột. Riêng **Cơ hội** thì "chỉ đi tới" phải chặn **ở cơ sở dữ liệu** (R-CRM-02): hiện chưa có bảng cơ hội và hàm đổi giai đoạn nên chưa có gì để kiểm; khi làm giai đoạn 1, hàm đổi giai đoạn của Cơ hội từ chối lùi kèm bài pgTAP (ghi vào PR dữ liệu giai đoạn 1).
- **Smart button ở K3 (PR 4b):** nhiều bản ghi thì mở danh sách K1 đã lọc theo bản ghi cha (chip kiểu "Cơ hội: CO000121", đường dẫn "Cơ hội / CO000121 / Lịch hẹn", bấm mã để quay lại); đúng một bản ghi thì mở thẳng bản ghi đó; không có bản ghi nào là tuỳ chọn của khung, tạm mở danh sách rỗng có câu "Chưa có …".
- **Thứ tự ưu tiên khi vênh:** luật (spec 04, 02, 06) > `docs/design/quyet-dinh-thiet-ke-13-10.md` (chỉ phần giao diện, màu, thương hiệu, khuôn; mục 1 quy trình đã cũ) > bản đồ màn hình > gói thiết kế.
- **Quyết định thiết kế 13/10 §4 vênh với gói v4 ở một chỗ cần anh xác nhận trước PR 4b:** quyết định ghi "bấm Tạo mở thẳng khuôn Chi tiết ở trạng thái trống, bỏ biểu mẫu tạo riêng", còn gói có ngăn kéo "Tạo nhanh lead" (K07b, K07c). Em làm theo quyết định 13/10 trừ khi anh nói giữ ngăn kéo.


## Quyết định gần đây chưa nằm trong docs/spec

Chi tiết ở `docs/nghiep-vu/phan-quyen.md` (ma trận, soát bảo mật) và `docs/van-hanh/chong-do-mat-khau.md`.

- **Tách môi trường Supabase**: `hmt-staging` ở org HMT (TÀI KHOẢN CHỦ DỰ ÁN); `hmt-prod` ở org HMT Prod (tài khoản
  `[tài khoản chạy thật]`, MFA). Không khoá nào trong hmt-platform chạm được hmt-prod; CI kiểm chủ động hai chiều mỗi lần Deploy
  staging (`scripts/check-isolation.sh`).
- **Đăng nhập qua Edge Function `login`**: Function tự kiểm Turnstile (Supabase Auth bỏ qua Turnstile khi gọi bằng khoá
  secret); sai tên, sai mật khẩu, không có tài khoản, bị khoá đều trả cùng một câu; khoá tạm (10 lần sai, 15 phút) chỉ là
  lớp thứ hai, lớp chính là Turnstile, giới hạn theo IP (20/5 phút, IP forwarding bật) và hai bước cho ADMIN, Kế toán.
- **Ma trận quyền**: chỉ Kế toán duyệt phiếu thu, kế toán (ADMIN cũng không); kế toán vắng thì Admin gán tạm vai trò
  ACCOUNTANT (có nhật ký). Trưởng cơ sở: Kế toán chỉ Xem; phiếu tái tục Xem, Giao việc, Xuất file (không có bước Duyệt
  tái tục). Phân hệ mới `ACCOUNT` (xem tài khoản, vai trò, nhật ký đăng nhập).
- **Thu hồi phiên**: khoá, bỏ bớt vai trò, đổi cơ sở thì token cũ mất tác dụng ngay (`session_version`) và phiên Supabase
  bị xoá. Luôn còn ít nhất một ADMIN hoạt động.
- **CS3 = Hội sở**, cơ sở văn phòng (chỉ gắn tài khoản nhân viên). Spec 02 trong repo đã sửa; anh Trường sửa bản gốc.
- **Hàm mới trong schema `app` mặc định không ai chạy được**: mỗi migration phải `GRANT` rõ hàm nào cho ai.
- **Giao diện (từ PR 4a)**: màu, cỡ chữ, khoảng cách chỉ lấy từ `design/hmt-platform/tokens/HMT_DESIGN_TOKENS.css`
  (Tailwind 4, `src/index.css`); thành phần dựng lại trên Radix ở `src/ui/`, giữ tên như gói thiết kế; biểu tượng qua từ
  điển `src/ui/icons.tsx`. Menu CRM (`src/nav/crmMenu.ts`) chỉ khai cấu trúc và quyền cần có; ai thấy mục nào đọc từ ma
  trận quyền và công tắc tính năng trong DB. Khi vênh: spec 04 > bản đồ màn hình > gói thiết kế, ghi vào PR.
- **Đường dẫn**: `/dang-nhap`, `/dang-nhap/hoc-sinh`, `/xac-thuc-hai-buoc`, `/thiet-lap-hai-buoc`, `/quen-mat-khau`,
  `/dat-mat-khau`, `/doi-mat-khau`, `/khong-dang-nhap-duoc`, `/chon-cong`, `/khong-co-quyen`, `/trang-thai` (trang kiểm
  tra kết nối cũ), `/crm/...`, `/gv/...`, `/hoc/...`. Hồ sơ cá nhân: `/<cổng>/tai-khoan`.
- **Khuôn dùng chung (từ PR 4b)**: màn mới dựng bằng các thành phần có sẵn, không tự chế: danh sách = `PageHeader` +
  `FilterBar` + `Table` + `Pagination` (+ `BulkActionBar`, `SavedFiltersMenu`, `ExportDialog`); bản ghi = `PageHeader`
  + `StatusBar` + `RecordLayout` + `Tabs` + `RecordChatter`; hộp thoại = `ConfirmDialog` (có lý do), `BlockingDialog`,
  `UnsavedGuard`; ô nhập = `Combobox`, `DateRange`, `MoneyInput`, `FileUpload`. Xem mẫu sống ở `/crm/khuon-mau` (chỉ
  Admin mở được, dữ liệu giả). Hàm DB đi kèm: `docs/nghiep-vu/khuon-dung-chung.md`. Màn QT-01 là ví dụ đầy đủ nhất.
- **Gọi DB từ giao diện**: `rpc`, `fetchRows`, `callFunction` trong `src/lib/db.ts` (lỗi nghiệp vụ thành `HmtError` có
  mã `HMT_*` và câu tiếng Việt hiện thẳng). Số trang, giới hạn đọc bằng `useIntSetting`, không viết số.
- **Đính kèm tệp**: giao diện đã có nhưng nút tải lên tắt (chưa bật R2, giai đoạn 4).
- **Quên mật khẩu**: hai màn đã dựng nhưng chưa gửi thư; màn luôn trả cùng một câu và bảo liên hệ quản trị viên.

## Lưu ý cho người làm tiếp

- **Ảnh chụp trong bài e2e** (`docs/anh-chup/…`: bh03, bh05, …) mặc định ghi ra thư mục tạm, không ghi đè ảnh trong repo. Muốn làm mới ảnh cho một PR thì đặt `SO_SANH_GHI_VAO_REPO=1` khi chạy bài đó, rồi kiểm `git status` trước khi commit (Q-C5, Đ281).
- **Ảnh so sánh với thiết kế**: `SO_SANH=1 npx playwright test e2e/so-sanh.spec.ts --project=may-tinh` ghép ảnh thiết kế
  và bản dựng, mặc định ra thư mục tạm (không ghi đè ảnh trong repo). Chỉ khi màn mới dựng hoặc anh yêu cầu thì thêm `SO_SANH_GHI_VAO_REPO=1` để ghi vào `docs/so-sanh/<MÃ>.jpg`; chạy xong chạy lại `npm run db:seed-users`. Màn mới thì thêm vào kịch bản này.
- **Kiểm thử giao diện**: Playwright hai cỡ `may-tinh` (1440×900) và `dien-thoai` (390×844), mỗi màn gọi
  `expectAccessible` (axe, chặn lỗi nghiêm trọng). Tua thời gian bằng `page.clock`, không sửa tay mốc thời gian. Cần
  quản trị viên thì dùng `loginAdmin` (tài khoản giả `admin.hs1` cho máy tính, `admin.hs2` cho điện thoại).
- **File anh Trường đưa vào** nằm ở `_inbox/` (không commit), dùng xong xoá.
- **Mỗi PR** cập nhật luôn file này (viết như sau khi PR đã gộp).

- **Duyệt PR**: chỉ gộp khi CI xanh **và** có comment "OK" từ TÀI KHOẢN GỘP **sau commit cuối**. Trước khi nhắc anh
  duyệt, kiểm comment trên PR trước (anh hay OK sẵn). Gộp squash, ghi link comment OK vào thân commit gộp.
- **Khoá chạy thật**: không bao giờ đọc, xin, tìm. Mọi việc với hmt-prod, Cloudflare thật, `hmt-deploy` do anh làm trên
  trình duyệt; Claude hướng dẫn từng việc một, viết cho người mới, nhắc "không chụp màn hình lúc khoá hiện".
- **Chép file sang hmt-deploy**: `LANG=en_US.UTF-8 pbcopy < deploy/…`, anh dán vào
  `https://github.com/TÀI KHOẢN DEPLOY/hmt-deploy/edit/main/<đường dẫn>` (file mới: `/new/main?filename=<đường dẫn>`).
- **Mật khẩu chung tài khoản giả** nằm ở secret `STAGING_SEED_PASSWORD` và ứng dụng Mật khẩu của anh (mục
  `<tên-miền-thử-nghiệm>.pages.dev`). Không in ra chat; nếu cần tạo mới thì sinh thẳng vào bộ nhớ copy (`pbcopy`).
- **Hạn token**: `SUPABASE_ACCESS_TOKEN` (hmt-platform, chỉ hmt-staging) và `PROD_SUPABASE_ACCESS_TOKEN` (hmt-deploy, chỉ
  Edge Functions của hmt-prod) đều hết hạn 09/10/2027; báo cáo tuần nhắc trước 30 ngày. Token Supabase tối đa 1 năm, chọn
  lùi một ngày nếu báo lỗi.
- **Máy local**: Docker không nằm trong PATH mặc định, thêm `/Applications/Docker.app/Contents/Resources/bin`. Sửa Edge
  Function xong phải `docker restart` container `edge_runtime` mới nạp code mới. Chạy `db:seed-users` trên DB local rồi
  chạy pgTAP vẫn đúng (bài ADMIN cuối cùng đã tự loại ADMIN giả), nhưng `db:reset` cho sạch thì chắc hơn.
- **Chẩn đoán trên thử nghiệm** (không có khoá staging trên máy): tạo nhánh tạm thêm job `workflow_dispatch` vào `ci.yml`
  đọc secret, chạy `gh workflow run ci.yml --ref <nhánh>`, đọc log job, huỷ lượt chạy, xoá nhánh. Không in khoá.
- **File không đưa vào git**: `PROMPT-GD0-BUOC1.md`.

- **Nút "Đặt lại mật khẩu" ở màn Người dùng (QT-02)** làm trước 10/11, một PR nhỏ riêng (anh chốt 05/11): người nạp bằng email quy ước không dùng được "Quên mật khẩu" qua email nên Admin đặt lại; dùng thao tác `reset_password` của Edge Function `admin-users`, mật khẩu tạm hiện một lần theo khuôn K4g. Miền email quy ước chốt `nv.hmt.invalid` (anh đặt bằng `app.set_setting` trên staging và prod trước khi nạp prod). Bước chuyển file nhân sự sang mẫu nạp (chạy ngoài repo, không lưu file nhân sự): tạo cột tên đăng nhập (viết tắt, trùng thì đánh số), email sai dạng để trống và báo số dòng cùng 4 chữ số đầu mã NV; bước nạp vẫn báo LOI với email sai dạng.
- Phòng học tạm (05/11, migration 071): mỗi cơ sở dạy học CS1 đến CS5 có 5 phòng CSx-T1-01, CSx-T1-02, CSx-T2-01, CSx-T2-02, CSx-T3-01 (sức chứa để trống); phòng giả P101, P102, ONL1 của bản thử nghiệm chuyển Ngừng. Nguồn và kênh: đối chiếu `HMT_CRM_01_Config` với danh mục trong DB, đủ 6 loại, 11 nguồn, 14 kênh, không thiếu mục nào. Tên thật phòng anh sửa trên màn Cơ sở và phòng học.

- **Giảm phút CI (anh chốt 05/11):** Playwright trên CI chỉ chạy khi PR đổi `src/`, `e2e/`, `supabase/functions/`, `supabase/seed.sql`, cấu hình Playwright hoặc file lạ; PR chỉ đổi migration, test pgTAP (và tài liệu) chạy pgTAP, bỏ Playwright (`scripts/ci-filter.ts`, hàm `needsE2e`). Thêm nhãn **`full-ci`** vào PR để buộc chạy đủ (thêm nhãn tự chạy lại CI). Trước khi đẩy vẫn chạy `npm run check:all` đầy đủ trên máy; `check:all` chạy lại bài trượt tối đa 2 lần như CI (`E2E_RETRIES=2`). Mỗi PR có code tốn khoảng 28 phút CI, gồm 12 phút Playwright; số phút theo từng bước: kiểm nhanh 2,5; pgTAP khoảng 4; Playwright 12,3; triển khai staging khi gộp 3,0.
- **Màn Nhập (QT-18, T5, 05/11):** Người dùng, Phụ huynh, Học sinh; CSV UTF-8; xem trước từng dòng, nạp, tải dòng lỗi, mật khẩu tạm một lần. Loại tối thiểu cho Tuyển sinh 10/11 là Người dùng và Cơ hội (Cơ hội làm ở T4c); Phụ huynh, Học sinh dùng cho Đào tạo và Bán hàng sau. Bộ chuyển xlsx sang CSV (giữ SĐT dạng chữ, xử lý ngày, tiền nghìn đồng nhân 1000) chạy trên máy anh/em, ngoài repo, không lưu dữ liệu thật vào repo.
- **Diễn tập trước khi nạp thật trên bản chạy thật (anh chốt 05/11):** (1) em soạn file giả nhỏ cho từng loại (có dòng hợp lệ, trùng, lỗi, không email); (2) anh thử trên staging bằng màn Nhập: xem trước, nạp, tải dòng lỗi, tải mật khẩu tạm, đăng nhập thử một tài khoản mới, rồi em đưa câu SQL xoá dữ liệu thử; (3) trên bản chạy thật nạp thử 3 dòng thật, anh kiểm (đăng nhập, phân quyền, cơ sở); (4) nạp toàn bộ, anh đối chiếu số dòng với nhật ký nạp (`app.import_log`).
