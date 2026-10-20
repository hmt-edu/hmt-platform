# Tiến độ HMT Platform

Cập nhật: 19/10/2026, 09:00. Người làm tiếp đọc file này trước, rồi `docs/quy-trinh-phoi-hop.md`, `docs/nhat-ky/` (ba file) và `CLAUDE.md`.

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
| P3e–P3f | Màn: Phiếu kiểm tra (e), Gộp trùng + Nhập file (f) | Chưa |
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

## Đang ở đâu (17/10/2026 tối)

**Đã gộp vào `main`** (mỗi PR có link comment "OK" của `caotruong276` trong commit gộp):

| Nhóm | PR |
|---|---|
| Nền GĐ0: hạ tầng, dữ liệu nền, đăng nhập, phân quyền, quản trị tài khoản, Hội sở CS3, dữ liệu khuôn dùng chung | #1 đến #15, #17, #18 |
| Gói thiết kế P0 đến P2 và giao diện khuôn: gói v1, v2, v4; hệ thiết kế; thành phần và khung CRM; danh sách, Kanban, Calendar; ô nhập; bản ghi, hộp thoại, ghi chú | #19 đến #26 |
| Luật và danh mục: luật 16/10, danh mục L5P, L6, danh mục 33; sửa lệch spec 06; danh mục phẳng và hai cấp | #27 đến #31 |
| Ma trận quyền: phiên bản, tách phân hệ (Cấu hình bán hàng, Cấu hình đào tạo, Ngày nghỉ lễ, Lịch hẹn) | #32, #33 |
| P3 Tuyển sinh: tài liệu (P3a), dữ liệu nền lead và lịch hẹn, ma trận quyền phiên bản 3 (P3b1) | #34, #35 |
| Nguồn canvas Design (P4, P5a, P5b) và nhật ký bàn giao | #37 |
| Tách gói tải theo cổng và màn; nền tảng phối hợp ba bên (nhật ký, khởi động, quy trình mới) | #36, #38 |

#16 đã đóng (không gộp; dữ liệu ở #17, giao diện làm lại ở #22 đến #26).

**Đang mở:** không có PR nào.

**Bản chạy thật** (`hmt-prod.pages.dev`, `app.hoamatoan.edu.vn`) còn ở tag `staging-20261010-1642-75637cf`, tụt nhiều migration (013 đến 026) và toàn bộ giao diện mới.
Anh cập nhật khi sẵn sàng: `hmt-deploy` > Deploy production (chọn tag đã qua staging), kèm chép `deploy/.github/workflows/bootstrap-admin.yml` mới sang `hmt-deploy`.
Môi trường thử nghiệm tự cập nhật sau mỗi lần gộp.

## Thứ tự tiếp theo (anh chốt 17/10)

1. PR 5 Đăng nhập (5a, 5b, 5c; đã OK đề xuất 18/10).
2. PR 5a Trang chủ theo vai trò (K09b, gồm "Việc tuyển sinh hôm nay" TS-12).
3. P3b2b Phiếu kiểm tra, P3b3 Gộp trùng và nhập file (làm trước các màn); rồi các màn P3c đến P3f.

Claude Design: P4 xong; P5a (v6) đóng băng chờ anh; P5b mới xong cụm Ghi danh (xem `docs/nhat-ky/design.md`).

## Đã chốt 18/10 (tối)

- **Giờ test ở quá khứ:** giữ chặn khi tạo và đổi lịch như #47 (không có trường hợp test tại chỗ rồi mới tạo phiếu).
- **Ngưỡng dung lượng gói tải:** giữ "chỉ báo số" (`npm run size`, bước CI chỉ in số), **không đặt ngưỡng trượt** (anh chốt 18/10). Đo hiện tại: trang đầu CRM 238 KB nén. `CLAUDE.md` mục Hiệu năng còn dòng "vượt thì trượt": chờ anh OK sửa cho khớp.
- **P3b3 anh chốt 18/10:** nhập lô lead dùng quyền Lead · Tạo (CSKH nhập được; bản đồ TS-04 đã thêm CSKH); CSV trước, Excel sau; gộp lead chuyển cả cơ hội sang lead giữ lại và vẫn chặn khi bản bị gộp đã có báo giá hoặc đơn (R-CRM-22); nguồn, chiến dịch, cơ sở, người phụ trách của file nhập như đề xuất; nút TS-06 đổi thành "Mở cơ hội cũ" (đã ghi bản đồ, dựng ở P3d); ngoại lệ chuyển ghi chú chỉ trong các hàm gộp (gọi trực tiếp vẫn bị chặn, có bài kiểm); R-CRM-37 vào luật [CHỐT]. Điều kiện chặn "học sinh cùng học hai lớp trùng giờ" (R-CRM-25) vẫn [CHỜ].
- **R-CRM-36** (cơ hội mới luôn bắt đầu ở L1) đã vào `docs/spec/04` [CHỐT]; `create_opportunity` khớp (xem `code.md`).

## Đang chờ anh Trường

- Cài hạn xử lý ticket chăm sóc tháng (R-CRM-30) trong màn Cấu hình khi có.

## Việc phải nhớ khi viết hàm (luật đã chốt)

- Cơ hội: đã khoá nhóm con L5A, L5B, L5P, L5C đến L5Q, L6A, L8A đến L8C (P3b2a). Giai đoạn phiếu tái tục: khoá L7A, L7B, L8A khi viết hàm tái tục. Đổi giai đoạn cơ hội đã kiểm R-CRM-02, 03, 13, 14, 16 (P3b2a); phiếu: R-CRM-05, 06, 12, 13, 15, 21 (P3b2b, đã làm).
- **Hoãn (ghi 18/10):** R-CRM-16 phần chặn tạo đơn khi chưa L8, R-CRM-17 (tự L8C), R-CRM-18 (cảnh báo lệch): chờ đơn hàng, phiếu thu. R-CRM-12, 13, 15 đã làm ở P3b2b (hai hàm nối đã thay bằng truy vấn bảng phiếu).
- Đã vào luật 18/10: R-CRM-34 (nhóm con L6), R-CRM-35 (đổi nhóm con cùng giai đoạn).
- Đã vào luật 19/10: R-CRM-38 (dời lịch hẹn), R-CRM-39 (lead mới luôn bắt đầu ở C1; `create_lead` đã khớp, bỏ qua giai đoạn người gọi truyền vào, có bài pgTAP 027).
- **Kiểm lại quyền (anh dặn 18/10):** `update_opportunity` kiểm quyền Học sinh · Sửa theo cơ sở của hồ sơ học sinh. Hồ sơ học sinh nay sinh tự động khi tạo phiếu (cơ sở tiếp nhận = cơ sở cơ hội); nhân viên cơ sở khác sửa học sinh ở cơ hội của mình sẽ bị chặn nếu học sinh tiếp nhận ở cơ sở khác. Xem lại khi làm màn.
- Phụ huynh, học sinh (R-CRM-26 đến 28): chỉ sinh trong hàm (phụ huynh khi tạo cơ hội, khớp SĐT chuẩn hoá; học sinh khi tạo phiếu hoặc duyệt đơn, khớp phụ huynh + tên + năm sinh chuẩn hoá); chặn ghi trực tiếp.
- **Cho P3e (ghi 18/10):** (1) bản vẽ TS15 cho **chọn Khối** (ô "Lớp" là danh sách chọn, không khoá; đã kiểm bản vẽ), bản đồ TS-15 đã sửa "Khối chọn khi tạo". (2) **Cơ sở test khác cơ sở cơ hội:** phiếu chép `branch_id` của cơ hội để xét quyền, nên nhân viên cơ sở test chưa thấy phiếu (giáo viên chấm được phân công thì thấy); xem lại ở P3e. (3) **Lịch nhắc tự sinh của phiếu (anh chốt 18/10):** hệ thống tự đóng (Hoàn thành) lịch nhắc tự sinh còn Chưa làm khi phiếu sang Đang test, để thẻ QUÁ HẠN ở Trang chủ và thanh đỏ Kanban không tăng oan; lịch nhắc người dùng sửa tay hoặc tự tạo giữ nguyên; lùi về Nháp không tự mở lại lịch đã đóng. Đã làm ở P3b3a (`start_student_test`, kèm bài kiểm); đóng bằng Huỷ, lý do Khác, ghi chú "Phiếu đã bắt đầu" (anh chỉnh 18/10). (4) Khối "Phiếu kiểm tra hôm nay" của Trang chủ thêm một dòng vào cấu hình khối khi làm P3e.
- **Cho P3f (ghi từ P3b3a, P3b3b):** nhập lô: hộp TS-04 đọc CSV ở trình duyệt, ghép cột (ô "ghi chú" của file ghép vào "Nhu cầu", hiện rõ ở bước ghép cột), gọi `import_leads` xem trước rồi nhập; Excel làm sau.  hộp gộp (TS-10, KH-07) dùng `merge_preview` để hiện số bản ghi chuyển sang, điều kiện chặn và cảnh báo (bản bị gộp ở giai đoạn cao hơn); sau gộp phụ huynh, hiện danh sách học sinh trùng từ `duplicate_students_of_parent`. Hàm sửa phụ huynh, học sinh (KH-03, KH-06) và danh sách phụ huynh, học sinh (KH-01, KH-04) làm sau phải kiểm bản "Đã gộp" chỉ đọc và ẩn khỏi danh sách mặc định (vẫn tìm bằng mã). Điểm nối báo giá, đơn: `opportunity_sales_documents` (hiện rỗng), P5 thay thân.
- **Cho đợt sau (ghi từ P3c-3b, P3d, 19–20/10):** (1) Ô "Gắn với" của hộp Tạo lịch hẹn chọn được lead và cơ hội; phiếu kiểm tra có lịch nhắc tự sinh nên không chọn tay. (2) Chưa làm các nút có trong bản vẽ nhưng ngoài kế hoạch anh duyệt: Nhập, Xuất của màn Lịch hẹn; Lịch "Theo người", "Theo phòng"; ô chọn hàng loạt, Group By của màn Lịch hẹn. (3) Nút "Hoàn tác" cho Hoàn thành, Huỷ trên trang Lead vẫn chưa có (đã có Mở lại ở màn Lịch hẹn). (4) Khối Lịch hẹn của Trang chủ (CHUNG-14) vẫn mở danh sách chung; lọc sẵn "hôm nay" khi cần. (5) **Màn Cơ hội, chỗ khác bản vẽ:** không có nút Tạo, Nhập (cơ hội chỉ tạo từ trang Lead, R-CRM-01; Nhập là P3f) và trang bản ghi không có nút Tạo; cột "Cơ hội" hiện tên học sinh (bản vẽ ghi "Toán lớp 8 · tên" nhưng cơ hội chưa lưu môn, lớp); hộp TS-09 ở L5 không có ô Sub-stage vì nhóm con L5 do hệ thống gắn (R-CRM-15, bản vẽ TS09d vẫn vẽ ô này); ô "Ghi chú" của hộp (trừ khi bỏ qua test) được gắn vào cơ hội như một ghi chú thường; nút "Mở phiếu" và mã phiếu chờ màn Phiếu kiểm tra (P3e); "Tạo báo giá", "Tạo đơn hàng", "Tạo lịch Test" mờ có chú thích (P5, P3e). (6) Nên thay phần lịch hẹn trên trang Lead bằng hook dùng chung `useOpportunityAppointments` (làm cho Cơ hội) khi làm PR nợ nhỏ.
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

## Việc để sau

- **Quản lý trực tiếp (PR DB `feat/hts-quan-ly-truc-tiep`):** cột, `set_manager`, `approval_route`, `can_approve_as_manager` đã có. **Trường "Quản lý trực tiếp" trên màn Người dùng (QT-01) chưa làm được vì màn QT-01 chưa dựng**; thêm trường khi dựng QT-01 (gọi `app.set_manager`).
- **Quyết định cho Bán hàng (P5), anh chốt 19/10:** Q-P5 người duyệt chốt lúc trình, đổi quản lý sau không đổi (đã vào R-HT-06); Q-P8 Admin không duyệt thay bước quản lý của phiếu thu, quản lý vắng thì Admin "Chuyển người duyệt" sang người khác đủ điều kiện, có nhật ký (đã vào R-TIEN-01); Q-P6 Trưởng cơ sở trình đơn thì mở hộp BH-07, một lần xác nhận, đơn sang Đã duyệt trong cùng giao dịch, lịch sử ghi "trình" và "tự duyệt", vượt trần vẫn phải tick; phiếu thu của Trưởng cơ sở đi thẳng "Chờ kế toán". **Việc còn lại:** nút "Chuyển người duyệt" chưa có trong bản vẽ (nhờ Design vẽ khi dựng TC-17 và hộp duyệt đơn); hàm `can_approve_as_manager` (migration 036) đã khớp: phiếu thu Admin không duyệt thay.
- **Điểm mở Q-P7 (KD6, anh để mở 19/10):** giữ hành vi nhận trùng phụ huynh theo họ tên + năm sinh học sinh; hai học sinh trùng tên cùng năm sinh của một phụ huynh chưa có cách phân biệt, bàn lại khi gặp.

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

- **Tách môi trường Supabase**: `hmt-staging` ở org HMT (tài khoản `hmt-vanhanh`); `hmt-prod` ở org HMT Prod (tài khoản
  `truongcx.work`, MFA). Không khoá nào trong hmt-platform chạm được hmt-prod; CI kiểm chủ động hai chiều mỗi lần Deploy
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

- **Ảnh so sánh với thiết kế**: `SO_SANH=1 npx playwright test e2e/so-sanh.spec.ts --project=may-tinh` ghép ảnh thiết kế
  và bản dựng, mặc định ra thư mục tạm (không ghi đè ảnh trong repo). Chỉ khi màn mới dựng hoặc anh yêu cầu thì thêm `SO_SANH_GHI_VAO_REPO=1` để ghi vào `docs/so-sanh/<MÃ>.jpg`; chạy xong chạy lại `npm run db:seed-users`. Màn mới thì thêm vào kịch bản này.
- **Kiểm thử giao diện**: Playwright hai cỡ `may-tinh` (1440×900) và `dien-thoai` (390×844), mỗi màn gọi
  `expectAccessible` (axe, chặn lỗi nghiêm trọng). Tua thời gian bằng `page.clock`, không sửa tay mốc thời gian. Cần
  quản trị viên thì dùng `loginAdmin` (tài khoản giả `admin.hs1` cho máy tính, `admin.hs2` cho điện thoại).
- **File anh Trường đưa vào** nằm ở `_inbox/` (không commit), dùng xong xoá.
- **Mỗi PR** cập nhật luôn file này (viết như sau khi PR đã gộp).

- **Duyệt PR**: chỉ gộp khi CI xanh **và** có comment "OK" từ `caotruong276` **sau commit cuối**. Trước khi nhắc anh
  duyệt, kiểm comment trên PR trước (anh hay OK sẵn). Gộp squash, ghi link comment OK vào thân commit gộp.
- **Khoá chạy thật**: không bao giờ đọc, xin, tìm. Mọi việc với hmt-prod, Cloudflare thật, `hmt-deploy` do anh làm trên
  trình duyệt; Claude hướng dẫn từng việc một, viết cho người mới, nhắc "không chụp màn hình lúc khoá hiện".
- **Chép file sang hmt-deploy**: `LANG=en_US.UTF-8 pbcopy < deploy/…`, anh dán vào
  `https://github.com/caotruong276/hmt-deploy/edit/main/<đường dẫn>` (file mới: `/new/main?filename=<đường dẫn>`).
- **Mật khẩu chung tài khoản giả** nằm ở secret `STAGING_SEED_PASSWORD` và ứng dụng Mật khẩu của anh (mục
  `hmt-staging.pages.dev`). Không in ra chat; nếu cần tạo mới thì sinh thẳng vào bộ nhớ copy (`pbcopy`).
- **Hạn token**: `SUPABASE_ACCESS_TOKEN` (hmt-platform, chỉ hmt-staging) và `PROD_SUPABASE_ACCESS_TOKEN` (hmt-deploy, chỉ
  Edge Functions của hmt-prod) đều hết hạn 09/10/2027; báo cáo tuần nhắc trước 30 ngày. Token Supabase tối đa 1 năm, chọn
  lùi một ngày nếu báo lỗi.
- **Máy local**: Docker không nằm trong PATH mặc định, thêm `/Applications/Docker.app/Contents/Resources/bin`. Sửa Edge
  Function xong phải `docker restart` container `edge_runtime` mới nạp code mới. Chạy `db:seed-users` trên DB local rồi
  chạy pgTAP vẫn đúng (bài ADMIN cuối cùng đã tự loại ADMIN giả), nhưng `db:reset` cho sạch thì chắc hơn.
- **Chẩn đoán trên thử nghiệm** (không có khoá staging trên máy): tạo nhánh tạm thêm job `workflow_dispatch` vào `ci.yml`
  đọc secret, chạy `gh workflow run ci.yml --ref <nhánh>`, đọc log job, huỷ lượt chạy, xoá nhánh. Không in khoá.
- **File không đưa vào git**: `PROMPT-GD0-BUOC1.md`.
