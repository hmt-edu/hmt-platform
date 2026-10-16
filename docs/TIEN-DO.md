# Tiến độ HMT Platform

Cập nhật: 14/10/2026 (quy trình thiết kế đổi 13/10 và 14/10, xem mục ngay dưới; #16 tách phần dữ liệu ra PR riêng). Người làm tiếp đọc file này trước, rồi CLAUDE.md, `docs/quy-trinh-phoi-hop.md`, `docs/spec/` (01, 02, 03, 04, 06), `docs/design/ban-do-man-hinh.md`, `docs/nghiep-vu/`.

## Thay đổi quy trình thiết kế (anh Trường báo 13/10/2026): đọc trước khi làm gì

- **Không bắt đầu PR dựng giao diện mới nào khi chưa có "thiết kế đã duyệt" từ anh Trường.**
- Bộ thiết kế `design/hmt-platform/` (P5) sẽ được thay bằng bản kiểu Odoo mới. **Không dựng thêm màn nào theo bộ cũ.**
  Prompt "bước 4 giai đoạn 0" cũ (PR 4a, 4b, 4c) đã hết hiệu lực: **không làm PR 4c-1, 4c-2 phần giao diện.**
- **14/10: anh Trường sẽ vẽ lại wireframe màn đăng nhập và khung các cổng** (thay câu "giữ nguyên trang đăng nhập" của
  13/10). Tạm dừng mọi việc giao diện của các màn đó; chỉ làm phần nền, dữ liệu, quyền.
- **Việc không phụ thuộc giao diện thì làm tiếp**: cơ sở dữ liệu, quyền, pgTAP, logic đăng nhập (tự đăng xuất, tạm
  khoá, hai bước). Các luật an toàn giữ nguyên.
- **Quy trình mới, mỗi phân hệ qua 4 cổng**: wireframe (anh duyệt) → thiết kế Claude Design (anh duyệt) → code (anh
  comment "OK" trên PR) → staging (anh thử, rồi tự cập nhật bản chạy thật qua hmt-deploy). Thiết kế được duyệt thì anh
  đưa file vào `_inbox/` kèm prompt mới.
- **Khi các nguồn vênh nhau**: theo tài liệu quyết định thiết kế 13/10 (chưa có trong repo, chờ anh đưa vào), rồi tới
  luật nghiệp vụ. Dòng thứ tự ưu tiên trong CLAUDE.md còn ghi theo bộ P5; sửa khi tài liệu 13/10 vào repo.

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
| 5a | Trang chủ theo vai trò (K09b), gồm "Việc tuyển sinh hôm nay" (TS-12) trong trang chủ của Sale: PR riêng, **sau PR dữ liệu, trước khi code P3** (anh chốt 16/10) | Chưa |
| 5 | P1 đăng nhập: 5a form + hai bước, 5b khoá + phiên + cổng, 5c nền động | Chưa |
| 6 | PR dữ liệu: bảng đối chiếu đủ 33 danh mục với spec 06, nạp danh mục thiếu (kể cả L5P, L6 đánh lại A–F, danh mục 33 "Lý do bỏ qua test" theo luật 16/10), "phiên bản" ma trận quyền | Chưa |
| 6.0 | Nạp danh mục theo luật 16/10 (migration `20261016000017`): nhóm con L5P, L6 đánh lại A–F (bỏ L6G), L5B "Đã xếp lịch test", danh mục 33 "Lý do bỏ qua test" (mã `TEST_SKIP_REASON`); 18 bài pgTAP. Ngoại lệ một lần với nguyên tắc "mã không đổi nghĩa", chỉ vì hệ thống chưa chạy thật | Đã gộp (PR này) |
| 6a | Danh mục sửa lệch: Môn, Khối, Trình độ thành Khoá; khoá mục cha giai đoạn lead và cơ hội, khoá C4D; C4C, C4D đổi chữ "opp" thành "cơ hội"; hai cột mới của mục danh mục (`requires_note`, `applies_to`); sửa dòng #30 của spec 06. migration `20261016000018` + 20 bài pgTAP | Đã gộp (#29) |
| 6b | Danh mục phẳng nạp theo spec 06: #8 Loại gói, #14 Hình thức test, #15 Cấp độ đề test, #17, #21, #22, #23, #24, #25, #26, #28, #31, #32 (13 danh mục, migration `20261016000019`, 21 bài pgTAP). #14, #15 tách riêng; #2 Phòng học để rỗng ở bản chạy thật; #30 nạp dần theo giai đoạn; #27 làm cùng phiếu thu | Đã gộp (#30) |
| 6c | Danh mục hai cấp: #12 Giai đoạn phiếu tái tục (8 + 5 nhóm con), #19 Nhóm đề nghị (7 nhóm, 15 nhóm con; 12 nhóm con có nghiệp vụ bị khoá theo R-CS-11), #20 Nhóm khiếu nại (7 nhóm, 25 nhóm con); #23 Lý do huỷ buổi gắn `applies_to` (TRUNG_TAM, HOC_SINH). Migration `20261016000020`, 29 bài pgTAP | Đã gộp (#31) |
| 6d | Phiên bản ma trận quyền: hàm `app.save_permission_matrix` (một lần Lưu = một phiên bản, hiệu lực ngay, hoàn tác cả lần nếu một ô sai, chặn ghi đè khi có người vừa lưu), bảng `permission_version`, `permission_change` (chỉ thêm, chỉ Quản trị đọc); `app.set_permission` thành hàm nội bộ. Migration `20261016000021`, 34 bài pgTAP mới | Đã gộp (#32) |
| 6e | Tách phân hệ quyền: thêm Cấu hình bán hàng, Cấu hình đào tạo, Ngày nghỉ lễ, Lịch hẹn (quyền theo bảng anh duyệt 16/10, nạp thành phiên bản 2 gồm 57 ô); menu Cấu hình, Ngày nghỉ lễ, Lịch hẹn đổi sang phân hệ mới; luật ADMIN luôn giữ đủ quyền Quản trị; chặn xoá, xoá sạch lịch sử phiên bản. Migration `20261016000022`, 25 bài pgTAP và 4 bài Vitest | Đã code, chờ anh OK (nhánh `feat/gd1-tach-phan-he-quyen`) |
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

## Đang ở đâu

**Giai đoạn 0 (GĐ0), bước 4. Phần giao diện tạm dừng chờ thiết kế mới; phần cơ sở dữ liệu, quyền làm tiếp.**

| PR | Nội dung | Trạng thái |
|---|---|---|
| 4a (#15) | Gói thiết kế P5, token, khung ba cổng, đăng nhập và các màn CHUNG-01…09, 13, 16, 17, 24, 25 | Đã gộp 12/10 |
| 4b (#16) | Giao diện khuôn dùng chung (bảng, bộ lọc, bản ghi, ghi chú + lịch sử, ô nhập, hộp thoại), CHUNG-11, 12, 14, 18, 19, 22, 26, màn Người dùng QT-01, QT-02, trang mẫu | **Nháp (draft), không gộp.** Dựng theo bộ P5 cũ, chờ thiết kế mới. Nhánh `feat/gd0-b4b-khuon-dung-chung` giữ nguyên |
| 4b-dữ-liệu | Chỉ phần dữ liệu của #16: migration `20261012000016` + 68 bài pgTAP, không có giao diện (xem `docs/nghiep-vu/khuon-dung-chung.md`) | PR riêng, chờ anh OK |
| 4c-1, 4c-2 | Màn quản trị | **Huỷ theo prompt cũ.** Phần giao diện chờ thiết kế mới; phần cơ sở dữ liệu tách ra làm riêng (mục "Việc dở") |

**Luồng đăng nhập đã code (giao diện chờ wireframe mới của anh Trường):** đăng nhập nhân viên (CHUNG-01) và học sinh (CHUNG-06); hai bước: nhập mã
(CHUNG-02), thiết lập lần đầu (CHUNG-03), tối đa 2 thiết bị; quên mật khẩu (CHUNG-04) và đặt mật khẩu mới (CHUNG-05),
chưa gửi thư nên bảo liên hệ quản trị viên; đổi mật khẩu bắt buộc lần đầu (CHUNG-07); không đăng nhập được, gồm tài
khoản bị khoá và tạm chặn (CHUNG-08); hết phiên, tự đăng xuất (CHUNG-09); hồ sơ cá nhân (CHUNG-13); không có quyền
(CHUNG-16); không tìm thấy, lỗi hệ thống (CHUNG-17); phân hệ chưa bật (CHUNG-24); chọn cổng (CHUNG-25).

| Bước GĐ0 | Trạng thái | PR |
|---|---|---|
| 1. Hạ tầng: React/Vite, Supabase, CI, Cloudflare Pages, repo `hmt-deploy`, sao lưu, báo cáo tuần | Xong, đã lên chạy thật | #1 |
| 2. Nền dữ liệu: danh mục, nhật ký thao tác, cấp mã, Cài đặt, công tắc, ghi chú | Xong, đã lên chạy thật | #2–#5 |
| 3. Đăng nhập, phân quyền: Edge Function đăng nhập, 9 vai trò, ma trận quyền, RLS, quản trị tài khoản (hàm + Edge Function), soát bảo mật | Xong, đã lên chạy thật (trừ #12) | #6–#12 |
| 4. Khung giao diện ba cổng + màn quản trị (tài khoản, quyền, danh mục, Cài đặt, nhật ký) | Giao diện tạm dừng chờ thiết kế mới (4a đã gộp, 4b nháp); phần cơ sở dữ liệu làm tiếp | #15, #16, PR dữ liệu |
| 5. Khôi phục thử sao lưu, cảnh báo | Chưa bắt đầu | |

Bản chạy thật (`hmt-prod.pages.dev`) đang ở tag `staging-20261010-1642-75637cf` (trước #12). Đã cấu hình Supabase
hmt-prod (schema `app`, hook, Turnstile hai chỗ, IP forwarding, giới hạn 20/5 phút, chặn tự đăng ký, mật khẩu 8 ký tự
chữ + số, TOTP). Đã có Admin đầu tiên là anh Trường (gắn tạm CS5, đã xác thực hai bước).

## PR đang mở

**#16** (4b, giao diện): **nháp, không gộp**, chờ thiết kế mới. **PR dữ liệu** (nhánh `feat/gd0-du-lieu-khuon-chung`, chỉ migration 016 + pgTAP + tài liệu): chờ anh Trường comment "OK".
Mọi PR #1–#15 đã gộp, mỗi commit gộp có link comment "OK" của `caotruong276`.

## Anh Trường chốt 16/10/2026 (ghi để PR sau làm đúng)

- **Trưởng cơ sở** xem được danh sách người dùng của cơ sở mình, **chỉ xem** (không sửa, không khoá, không đặt lại mật khẩu). Quyền xem đã có trong ma trận (`ACCOUNT · Xem`, phạm vi cơ sở); màn Người dùng (PR 7 trở đi) phải ẩn mọi nút sửa với vai trò này.
- **Thông báo khi được @**: chỉ ghi ai nhắc và ở bản ghi nào, bấm thì mở bản ghi; **không chép nội dung ghi chú** (đã đúng trong `app.notification`, đã có bài pgTAP).
- **Kanban:** thanh tỷ lệ đầu cột (xanh còn hạn, vàng hôm nay, đỏ quá hạn, xám chưa có lịch); "chỉ đi tới" là tuỳ chọn của từng màn, luôn hiện đủ cột. Riêng **Cơ hội** thì "chỉ đi tới" phải chặn **ở cơ sở dữ liệu** (R-CRM-02): hiện chưa có bảng cơ hội và hàm đổi giai đoạn nên chưa có gì để kiểm; khi làm giai đoạn 1, hàm đổi giai đoạn của Cơ hội từ chối lùi kèm bài pgTAP (ghi vào PR dữ liệu giai đoạn 1).
- **Smart button ở K3 (PR 4b):** nhiều bản ghi thì mở danh sách K1 đã lọc theo bản ghi cha (chip kiểu "Cơ hội: CO000121", đường dẫn "Cơ hội / CO000121 / Lịch hẹn", bấm mã để quay lại); đúng một bản ghi thì mở thẳng bản ghi đó; không có bản ghi nào là tuỳ chọn của khung, tạm mở danh sách rỗng có câu "Chưa có …".
- **Thứ tự ưu tiên khi vênh:** luật (spec 04, 02, 06) > `docs/design/quyet-dinh-thiet-ke-13-10.md` (chỉ phần giao diện, màu, thương hiệu, khuôn; mục 1 quy trình đã cũ) > bản đồ màn hình > gói thiết kế.
- **Quyết định thiết kế 13/10 §4 vênh với gói v4 ở một chỗ cần anh xác nhận trước PR 4b:** quyết định ghi "bấm Tạo mở thẳng khuôn Chi tiết ở trạng thái trống, bỏ biểu mẫu tạo riêng", còn gói có ngăn kéo "Tạo nhanh lead" (K07b, K07c). Em làm theo quyết định 13/10 trừ khi anh nói giữ ngăn kéo.

## Việc dở, việc tiếp theo

1. **Tài liệu 12/10 của anh Trường đã gộp vào repo (PR #14)**: spec 04 (132 luật, §10 Báo cáo, §11 Học tập, §12 Quyền và hệ
   thống), spec 02, mới `docs/spec/06-danh-muc-va-tham-so.md`, `docs/design/ban-do-man-hinh.md`,
   `docs/design/luat-cho-thiet-ke.md`, `docs/design/ma-luat-S02-S03.md`, `docs/van-hanh/so-tay-van-hanh.md`. **Chưa sửa code.** Mọi chỗ luật mới vênh với
   code, kèm bước nên sửa: `docs/nghiep-vu/doi-chieu-luat-1210.md` (mục A: các điểm anh đã chốt 12/10; mục B, C: việc
   phải sửa, phần lớn ở bước 4).
2. **Đưa #12 (CS3 Hội sở) lên chạy thật** khi anh muốn: hmt-deploy > Deploy production, tag
   `staging-20261010-1840-c3bc365`. Cùng lúc chép `deploy/.github/workflows/bootstrap-admin.yml` mới sang hmt-deploy (chỉ đổi
   mô tả ô cơ sở).
3. **Hai bước tối đa 2 thiết bị**: anh Trường đã đặt "Maximum number of per-user MFA factors" = 2 trên cả hmt-staging và
   hmt-prod (12/10; mặc định Supabase là 10). Local đặt trong `supabase/config.toml`.
4. **Anh Trường chốt 12/10** (phần ma trận quyền trong cơ sở dữ liệu làm ở PR cơ sở dữ liệu kế tiếp; phần menu chờ
   thiết kế mới; ghi vào `docs/nghiep-vu/phan-quyen.md` và phần
   phân quyền của spec 03 trong chính PR đó):
   - Gửi anh danh sách chỗ lệch giữa ma trận quyền trong DB và bảng vai trò (RoleMenu) của gói thiết kế.
   - Tách quyền menu Cấu hình/Quản trị thành 3 phân hệ (hiện cả 20 mục dùng chung quyền Quản trị · Xem):
     **Quản trị** (người dùng, vai trò, quyền, nhật ký, công tắc, tham số, danh mục): chỉ Admin.
     **Cấu hình bán hàng** (gói, bảng giá, chiết khấu, điều khoản thanh toán, chiến dịch): Admin sửa; Kế toán, Trưởng
     cơ sở, Tuyển sinh, CSKH xem.
     **Cấu hình đào tạo** (khung chương trình, rubric, ngày nghỉ lễ): Admin sửa; Trưởng cơ sở sửa ngày nghỉ lễ và xem
     phần còn lại; CSKH, giáo viên xem khung chương trình.
5. **Chờ anh Trường chốt (hỏi trong PR 4b)**: (a) ai được lưu bộ lọc dùng chung (hiện chỉ Admin); (b) Trưởng cơ sở được
   DB cho xem tài khoản cơ sở mình nhưng menu Quản trị chỉ Admin, nên khi được nhắc tên trong ghi chú của một tài khoản
   thì nhận thông báo mà mở ra gặp "Không có quyền".
6. **QT-01, QT-02 còn thiếu (giao diện chờ thiết kế mới)**: tạo người dùng, sửa vai trò và cơ sở, đặt lại mật khẩu, đặt lại hai bước,
   thu hồi phiên, lý do khoá chọn từ danh mục (hiện gõ tay), mã nhân viên cho tài khoản giả.
7. **Phần cơ sở dữ liệu của bước 4, làm tiếp không cần giao diện** (mỗi việc có migration + pgTAP). Đã hứa làm:
   - Cơ sở là danh mục khoá (chốt 12/10): thêm cột hotline; mở cơ sở mới qua migration. (Màn QT-08 chờ thiết kế mới.)
   - Tách ma trận quyền Cấu hình/Quản trị thành 3 phân hệ (mục 4), nạp danh mục theo spec 06 (trừ #27, #30).
   - Các mục "Bước 4" trong `docs/nghiep-vu/doi-chieu-luat-1210.md` (anh đã đồng ý thứ tự): tham số (đổi "ghi đè theo cơ
     sở", 3 tham số mới, giữ khoảng cho phép), khoá danh mục Môn/Khối/Trình độ và mục cha giai đoạn, đổi tên C4C, C4D,
     L5B, lý do khoá tài khoản theo danh mục, hai bước tối đa 2 thiết bị, đặt lại hai bước, vai trò gán tạm có thời hạn,
     hotline cơ sở, công tắc tính năng không có CS3, chế độ khôi phục của workflow `bootstrap-admin` (soạn ở
     `docs/hmt-deploy/`, anh tự chép sang hmt-deploy).
8. **Trước GĐ4**: L2 trong `docs/nghiep-vu/phan-quyen.md` (học sinh, phụ huynh chỉ đọc phần của mình). Giai đoạn 3: chốt
   trường dữ liệu giáo viên được xem (đề xuất: không thấy số điện thoại, địa chỉ phụ huynh).
9. **Để sau, khi anh sẵn sàng**: quên mật khẩu qua email (Resend/SMTP + DNS, Edge Function `send-email` đã có), tên miền
   riêng (CNAME `app` → `hmt-prod.pages.dev`), bước 5.

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
  và bản dựng vào `docs/so-sanh/<MÃ>.jpg`; chạy xong chạy lại `npm run db:seed-users`. Màn mới thì thêm vào kịch bản này.
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
