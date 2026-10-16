# 00_DOC_TRUOC — Gói bàn giao P0 · P1 · P2 (HMT CRM)

Đọc file này trước khi mở gói. Gói chỉ gồm 3 phân hệ đã duyệt: **P0 Khuôn chung**, **P1 Đăng nhập & xác thực**, **P2 Cấu hình & phân quyền**. P3 (Tuyển sinh TS-xx), P13 Báo cáo, P14 Tìm kiếm & thông báo **không nằm trong gói**.

**Bản v4 (16/10/2026)** sửa P1 và P2 theo các quyết định anh Trường đã chốt, thêm 2 token còn nợ. Gói gồm **70 artboard** (P0 38, P1 28, P2 4). Đọc bảng "Đổi gì so với v3" ngay dưới đây trước. Các đợt bổ sung cũ vẫn giữ ở mục 6 (K1 bốn khung, lịch sử phiên bản Ma trận quyền) và mục 7 (ô tìm toàn hệ thống, chuông). Mục 8 là chỗ chưa chắc của đợt v4.

## Đổi gì so với v3

| # | Màn / tệp | v3 | v4 | Lý do |
|---|---|---|---|---|
| 1 | DN03 · Xác thực hai bước | 8 artboard: mã từ ứng dụng + mã dự phòng (`*_backup`, `*_backup_err`) | **Còn 4**: `DN03_pc_code`, `DN03_pc_code_err`, `DN03_mb_code`, `DN03_mb_code_err`. Bỏ 4 artboard mã dự phòng | Bỏ mã dự phòng |
| 2 | DN03 · dòng dưới nút | Liên kết "Mất điện thoại? Dùng mã dự phòng" | Chữ thường (không phải liên kết): "Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước" | Bỏ mã dự phòng |
| 3 | DN04 · Thiết lập 2FA | 3 bước (bước 3 lưu mã dự phòng) | **2 bước**. Bỏ `DN04_pc_s3`, `DN04_mb_s3`. Thanh bước còn 2 khúc; nhãn "BƯỚC 1/2 · QUÉT MÃ", "BƯỚC 2/2 · NHẬP MÃ". Nút chính bước 2 đổi "Xác nhận" → **"Hoàn tất"** (vẫn có "Quay lại") | Bỏ mã dự phòng |
| 4 | DN05 · Quên mật khẩu | Ô nhập email, Turnstile, nút "Gửi link đặt lại", câu học sinh nhờ CSKH; biến thể "đã gửi" (`*_sent`) | Chỉ còn câu "Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm." và nút chính **"Quay lại đăng nhập"**. Bỏ `DN05_pc_sent`, `DN05_mb_sent`. Giữ tên `DN05_pc_form`, `DN05_mb_form` | Quên mật khẩu chỉ liên hệ quản trị viên |
| 5 | DN06 · Đặt mật khẩu mới (link email) | Trong gói (4 artboard) | **Hoãn.** Giữ artboard trên canvas, gắn nhãn "HOÃN", **không đưa vào gói** | Không còn luồng đặt lại qua email |
| 6 | DN08 · Tài khoản bị khoá | 4 artboard: tạm khoá 15 phút, khoá hẳn (`*_temp`, `*_perm`) | **Gộp 1 màn mỗi thiết bị**: `DN08_pc_lock`, `DN08_mb_lock`. Tiêu đề "Không thể đăng nhập", một câu chung: "Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm." Không nói thời gian khoá, không nói lý do. Một nút "Quay lại đăng nhập" | Luật S03-18: không để lộ tài khoản có tồn tại hay không |
| 7 | CauHinh · tab Tham số nghiệp vụ | Dòng đang sửa có ô "Có hiệu lực từ" (ngày); câu cuối "Sửa một tham số thì có hiệu lực từ ngày chọn, bản cũ vẫn giữ trong lịch sử." | Bỏ ô "Có hiệu lực từ". Câu cuối: "Sửa một tham số thì có hiệu lực ngay; giá trị cũ vẫn giữ trong lịch sử thay đổi." | Tham số có hiệu lực ngay |
| 8 | Token mới (`tokens.json` v4, `hmt-tokens.css`) | Chưa có | `--success-border` #BAD9C4, `--warning-border` #F2DE9D, `--danger-border` #ECBBC2 (cùng cách pha với `--info-border` có sẵn); `--table-head-height` 32px, `--table-row-height` 36px | Hai token còn nợ |
| 9 | `bundle.css` | `.hmt-table th` cao 32px, `td` cao 36px viết thẳng | Dùng `var(--table-head-height)` và `var(--table-row-height)`. Giá trị không đổi, ảnh chụp mọi màn giống v3 | Dùng token thay giá trị viết thẳng |
| 10 | K2 Kanban | Thanh màu trên đầu cột chưa có giải thích | Ghi nghĩa ở mục 4 (không đổi bản vẽ) | Anh Trường yêu cầu |

Tổng số artboard: v3 84 → v4 70 (bỏ 4 DN03, 2 DN04, 2 DN05, 4 DN06 hoãn; DN08 4 → 2). P0 và các màn P1, P2 khác **không đổi**.

## 0. Cấu trúc gói
```
00_DOC_TRUOC.md
ds/hmt/handoff/hmt-tokens.css      token màu, chữ, khoảng cách, bo góc
ds/hmt/components/bundle.css       thành phần dùng chung (.hmt-btn, .hmt-toast, ...)
ds/hmt/tokens.json                 cùng token dạng JSON
artboards/*.dc.html                70 artboard (P0 38, P1 28, P2 4)
artboards/ds/hmt/...               bản sao token để mở artboard độc lập (đường dẫn tương đối ds/hmt/...)
png/*.png                          ảnh từng artboard; tên PNG trùng tên artboard
assets/Logo-HMT-cropped.svg        logo dùng ở màn đăng nhập (thêm v4)
```
- **Logo (thêm v4):** trong các artboard `DN*`, thẻ `<img class="lg-logo">` trỏ tới `/_blob/98cf606dea491365f7cf1aba35be25ee`, là đường dẫn nội bộ của canvas. Khi dựng thật, thay bằng file `assets/Logo-HMT-cropped.svg` trong gói (cùng một file). Bản nền tối và bản đủ khổ nằm trong hệ thiết kế HMT Platform.
- Artboard 1440×1000 là bản **máy tính**; 390×844 là bản **điện thoại** (tên có `_mb`, `K1m_` hoặc K4e). P1 có đủ pc và mb. P0 và P2 chủ yếu là bản máy tính; điện thoại chỉ có K4e và K1m_*.
- Ảnh PNG xuất bằng trình duyệt không có phông Inter / Be Vietnam Pro nên chữ là phông thay thế, hơi lệch so với bản thật. Kích thước và màu đúng. Phông chuẩn lấy theo token (`--font-ui` Inter, `--font-heading` Be Vietnam Pro).
- Các file `.dc.html` là artboard của Design canvas. Mỗi file tham chiếu `ds/hmt/...` theo đường dẫn tương đối; cần có `support.js` của công cụ canvas mới mở độc lập được. Khi dựng thật, lấy HTML trong `<x-dc>` và CSS token làm chuẩn, không cần chạy `support.js`.
- Quy ước thiết kế: giao diện sáng, màu thương hiệu cam (`--brand-600` #CB4D0E), mỗi màn một nút chính, nút nguy hiểm viền đỏ có biểu tượng. Nút và bố cục chỉ lấy từ wireframe/brief; chỗ chưa có thì liệt kê ở mục 5 và 6.


## 1. Danh sách mã màn trong gói

### P0 · Khuôn chung (38 artboard, máy tính; K4e và K1m_* là điện thoại)

| Artboard | Mã màn | Nội dung | PNG |
|---|---|---|---|
| K1 | — | Tổng quan dạng List (Cơ hội) | `png/K1.png` |
| K2 | — | Tổng quan dạng Kanban (Cơ hội) | `png/K2.png` |
| K3 | — | Chi tiết Cơ hội (mẫu CO000121) | `png/K3.png` |
| K4 | — | Hộp thoại, 5 biến thể ①②③③b④⑤ (huỷ/từ chối có lý do, Assign, chặn/cảnh báo…) | `png/K4.png` |
| K4b | — | Hộp thoại nhiều bước: Nhập lead từ file (3 bước) | `png/K4b.png` |
| K4c | — | Hộp thoại xem trước tác động (đổi giáo viên 12 buổi) | `png/K4c.png` |
| K4d | — | Hộp thoại chọn từ danh sách có kiểm tra (chọn lớp) | `png/K4d.png` |
| K4e1 | — | Bottom sheet điện thoại: Duyệt đơn hàng | `png/K4e1.png` |
| K4e3 | — | Bottom sheet điện thoại: Từ chối đơn hàng, bước 2 (bắt buộc lý do) | `png/K4e3.png` |
| K4e2 | — | Bottom sheet điện thoại: Từ chối ticket (DN-CS1-2610-0007) | `png/K4e2.png` |
| K5 | — | Calendar Lịch hẹn (tuần) | `png/K5.png` |
| K07b | TS-03 | Biểu mẫu ngăn kéo: Tạo nhanh lead | `png/K07b.png` |
| K07c | TS-03 | Hộp thoại cảnh báo trùng SĐT, đè lên ngăn kéo | `png/K07c.png` |
| K09b | CHUNG-14 | Trang chủ theo vai trò (Sale / CSKH / Trưởng cơ sở / Kế toán / Admin) | `png/K09b.png` |
| K0x | — | Trạng thái chung: tải (skeleton), rỗng, thông báo lỗi/cảnh báo | `png/K0x.png` |
| K1_loc | K1+ | Filters: khung lọc nhanh thả xuống (đã tick vài lọc) | `png/K1_loc.png` |
| K1_loc_chip | K1+ | Filters: đã áp dụng, chip lọc trên thanh tìm, bảng đã lọc | `png/K1_loc_chip.png` |
| K1_loc_nc | K1+ | Lọc nâng cao: hộp thoại có 3 dòng điều kiện | `png/K1_loc_nc.png` |
| K1_loc_nc0 | K1+ | Lọc nâng cao: rỗng, chưa có điều kiện | `png/K1_loc_nc0.png` |
| K1_nhom | K1+ | Group By: khung thả xuống, đã chọn 2 cấp | `png/K1_nhom.png` |
| K1_nhom_bang | K1+ | Group By: bảng đã nhóm 2 cấp (Stage › Source), dòng nhóm gập/mở, có đếm | `png/K1_nhom_bang.png` |
| K1_nhom0 | K1+ | Group By: rỗng, chưa chọn cấp nào (bảng phẳng) | `png/K1_nhom0.png` |
| K1_cot | K1+ | Cột: tick cột hiển thị, kéo đổi thứ tự, nút Mặc định | `png/K1_cot.png` |
| K1_fav | K1+ | Favorites: danh sách bộ lọc đã lưu của tôi | `png/K1_fav.png` |
| K1_fav_luu | K1+ | Favorites: lưu bộ lọc hiện tại (đặt tên, tick Dùng cho mọi người) | `png/K1_fav_luu.png` |
| K1_fav0 | K1+ | Favorites: rỗng “Chưa có bộ lọc nào được lưu” | `png/K1_fav0.png` |
| K1m_loc | K1+ | Filters (điện thoại): bottom sheet | `png/K1m_loc.png` |
| K1m_nhom | K1+ | Group By (điện thoại): bottom sheet | `png/K1m_nhom.png` |
| K1m_cot | K1+ | Cột (điện thoại): bottom sheet | `png/K1m_cot.png` |
| K1m_fav | K1+ | Favorites (điện thoại): bottom sheet | `png/K1m_fav.png` |
| K1_tim | K1+ | Thanh trên: ô tìm kiếm toàn hệ thống (đóng, có phím tắt “/”) | `png/K1_tim.png` |
| K1_tim_go | K1+ | Tìm kiếm: đang gõ, khung kết quả nhóm theo loại | `png/K1_tim_go.png` |
| K1_tim0 | K1+ | Tìm kiếm: “Không tìm thấy” | `png/K1_tim0.png` |
| K1_chuong | K1+ | Chuông thông báo: danh sách ngắn (3 dòng mẫu) | `png/K1_chuong.png` |
| K1_chuong0 | K1+ | Chuông thông báo: rỗng “Chưa có thông báo” | `png/K1_chuong0.png` |
| K1m_tim_dong | K1+ | Điện thoại: ô tìm thu thành biểu tượng | `png/K1m_tim_dong.png` |
| K1m_tim | K1+ | Điện thoại: tìm kiếm toàn màn hình (đang gõ) | `png/K1m_tim.png` |
| K1m_tim0 | K1+ | Điện thoại: tìm kiếm toàn màn hình (không tìm thấy) | `png/K1m_tim0.png` |

### P1 · Đăng nhập & xác thực (9 màn trong gói, 28 artboard: máy tính + điện thoại; DN06 hoãn)

| Artboard (gốc) | Mã màn | Nội dung | Các biến thể (có `pc_` và `mb_`) |
|---|---|---|---|
| DN01 | CHUNG-01 | Đăng nhập nhân viên | pc_ok, pc_err, mb_ok, mb_err |
| DN02 | CHUNG-06 | Đăng nhập học sinh | pc_ok, pc_err, mb_ok, mb_err |
| DN03 | CHUNG-02 | Xác thực hai bước (nhập mã, không có mã dự phòng) | pc_code, pc_code_err, mb_code, mb_code_err |
| DN04 | CHUNG-03 | Thiết lập 2FA lần đầu (2 bước) | pc_s1, pc_s2, mb_s1, mb_s2 |
| DN05 | CHUNG-04 | Quên mật khẩu (chỉ hướng dẫn liên hệ quản trị viên) | pc_form, mb_form |
| ~~DN06~~ | CHUNG-05 | Đặt mật khẩu mới (link từ email): **HOÃN, không có trong gói** | — |
| DN07 | CHUNG-07 | Đổi mật khẩu lần đầu | pc_new, pc_ok, mb_new, mb_ok |
| DN08 | CHUNG-08 | Không thể đăng nhập (một câu chung, gộp tạm khoá và khoá hẳn) | pc_lock, mb_lock |
| DN09 | CHUNG-09 | Hộp thoại hết phiên đăng nhập | pc_end, mb_end |
| DN10 | CHUNG-25 | Chọn cổng (CRM / Giáo viên) | pc_ok, mb_ok |

Tên file đầy đủ = `<DNxx>_<biến thể>`, ví dụ `DN03_pc_code_err.dc.html` và `png/DN03_pc_code_err.png`.

### P2 · Cấu hình & phân quyền (4 artboard, máy tính)

| Artboard | Mã màn | Nội dung | PNG |
|---|---|---|---|
| CauHinh | QT-07 / QT-09 | Cấu hình: Danh mục, Tham số nghiệp vụ, Công tắc tính năng | `png/CauHinh.png` |
| MaTranQuyen | QT-05 | Ma trận quyền theo vai trò; đầu màn ghi “Phiên bản 12 · lưu bởi … lúc …”; đã bỏ ngày hiệu lực | `png/MaTranQuyen.png` |
| MaTranQuyen_ls | QT-05 | Lịch sử thay đổi quyền: danh sách phiên bản (ngăn kéo) | `png/MaTranQuyen_ls.png` |
| MaTranQuyen_ct | QT-05 | Lịch sử thay đổi quyền: chi tiết một phiên bản (ô đã đổi: vai trò · phân hệ · hành động · từ → sang) | `png/MaTranQuyen_ct.png` |

## 2. Khuôn dùng cho màn nào

| Khuôn | Dùng cho | Ghi chú |
|---|---|---|
| Vỏ CRM (thanh trái + thanh trên) | K1, K2, K3, K5, K07b, K07c, K09b, K1_*, CauHinh, MaTranQuyen, MaTranQuyen_* | Thanh trái: Tổng quan, Tuyển sinh, Khách hàng, Bán hàng & thu chi, Đào tạo, Chăm sóc KH, Báo cáo, Cấu hình, Quản trị |
| K1 List / K2 Kanban | Mọi danh sách và bảng Kanban cùng nhóm | Mẫu là “Cơ hội” |
| Khung thả xuống (popover) neo dưới nút | K1_loc, K1_nhom, K1_cot, K1_fav* | Rộng 300–340, bóng md, bo góc lớn; dùng cho mọi danh sách có Filters, Group By, Cột, Favorites |
| K3 Chi tiết bản ghi | Mọi chi tiết có giai đoạn | Mẫu là CO000121 |
| K4 Hộp thoại 5 biến thể | Huỷ/từ chối có lý do, Assign, chặn, cảnh báo; K1_loc_nc* (Lọc nâng cao) | Biến thể ①②③③b④⑤ |
| K4b Nhiều bước | Nhập từ file và quy trình tương tự | 3 bước |
| K4c Xem trước tác động | Đổi giáo viên, đổi lịch hàng loạt | Cảnh báo, không chặn |
| K4d Chọn từ danh sách có kiểm tra | Chọn lớp cho dòng đơn | Tối đa 2 lý do, rồi “+N lý do” |
| K4e Bottom sheet | Duyệt/từ chối trên điện thoại; K1m_* (4 khung của K1) | 390×844 |
| K5 Calendar | Lịch hẹn tuần | |
| K07b Ngăn kéo biểu mẫu | Tạo nhanh bản ghi; MaTranQuyen_ls/ct (ngăn kéo lịch sử, chỉ xem) | Nút K07b: Huỷ, Lưu |
| K07c Hộp thoại cảnh báo trùng | Trùng SĐT khi tạo | Nút: Vẫn tạo mới, Gắn vào hồ sơ có sẵn; đóng bằng X |
| K09b Trang chủ theo vai trò | CHUNG-14 | Năm vai trò |
| K0x Trạng thái chung | Tải, rỗng, thông báo lỗi/cảnh báo | |
| Khuôn đăng nhập (thẻ giữa trang, logo, tiêu đề, 1 nút chính) | DN01–DN10 | Máy tính: thẻ giữa nền; điện thoại: toàn màn |
| Khuôn trang cấu hình / ma trận | CauHinh, MaTranQuyen | |

Mỗi artboard P1 đi theo khuôn đăng nhập; DN04 và DN10 có phần bố cục riêng (2 bước; hai thẻ cổng).

## 3. Chữ trên nút và thông báo của từng màn

Danh sách được trích tự động từ các artboard. Đã bỏ nhãn thanh điều hướng chung (Tổng quan … Quản trị). Với các artboard K1_*, K1m_* và MaTranQuyen_* đã bỏ thêm nút của màn nền; phần “Chữ trong khung” ghi tay. Chữ dạng “lấy từ dữ liệu” là nhãn do dữ liệu quyết định (giai đoạn, tab…), không cố định.

### P0

- **K1** (—) — Tổng quan dạng List (Cơ hội)
  - Khuôn K1 – danh sách (List) trong vỏ CRM
  - **Nút:** “Tạo” · “Nhập” · “Xuất” · “Làm mới” · “Cột” · “Ngày tạo” · “Tất cả thời gian” · “Filters” · “Group By” · “Favorites” · “Xoá tất cả” · “Save to Favorites”
- **K2** (—) — Tổng quan dạng Kanban (Cơ hội)
  - Khuôn K2 – Kanban trong vỏ CRM
  - **Nút:** “Tạo” · “Nhập” · “Xuất” · “Làm mới” · “Cột” · “Ngày tạo” · “Tất cả thời gian” · “Filters” · “Group By” · “Favorites”
- **K3** (—) — Chi tiết Cơ hội (mẫu CO000121)
  - Khuôn K3 – chi tiết bản ghi: thanh giai đoạn, thẻ số liệu, hộp ghi chú/hoạt động bên phải
  - **Nút:** “Sửa” · “Tạo” · “Assign” · “Đính kèm (2)” · “Hành động” · “Lưu” · “Huỷ” · “Tạo báo giá” · “Tạo đơn hàng” · “1 Phụ huynh” · “1 Lead gốc” · “Đang theo dõi Theo dõi” · “Lên lịch hẹn” · “Tạo lịch Test” · “Gửi ghi chú” · “Hoàn thành” · “Dời” · “Đóng” · (một số nhãn lấy từ dữ liệu: giai đoạn, sub-stage, tab…)
  - **Thông báo / chữ cảnh báo:**
    - “Cần nhập Họ tên phụ huynh; từ giai đoạn L5 còn phải có Tên học sinh và Năm sinh. Nhập đủ rồi bấm Lưu.”
    - “{{ toast }}”
- **K4** (—) — Hộp thoại, 5 biến thể ①②③③b④⑤ (huỷ/từ chối có lý do, Assign, chặn/cảnh báo…)
  - Khuôn K4 – hộp thoại xác nhận/nhập lý do
  - **Nút:** “Huỷ” · “Duyệt” · “Chọn lý do…” · “Giữ lại” · “Xác nhận huỷ” · “Chọn sale cùng cơ sở…” · “Giao” · “CS1 Nguyễn Chí Thanh” · “Chọn nhân sự thuộc cơ sở…” · “L4 Khách hàng tiềm năng” · “L4B Cần tư vấn thêm” · “Assign” · “Chặn” · “Cảnh báo, không chặn” · “Đã hiểu” · “Tiếp”
  - **Thông báo / chữ cảnh báo:**
    - “Còn 3 em còn giờ học. Chuyển hoặc kết thúc ghi danh của các em trước.”
- **K4b** (—) — Hộp thoại nhiều bước: Nhập lead từ file (3 bước)
  - Khuôn K4b – hộp thoại nhiều bước (import)
  - **Nút:** “Huỷ” · “Tiếp” · “Tên phụ huynh” · “SĐT” · “Tên học sinh” · “Source” · “Sub-source” · “Chiến dịch” · “Chọn trường…” · “Quay lại” · “Nhập”
  - **Thông báo / chữ cảnh báo:**
    - “2 cột chưa ghép: Ghi chú KH , Mã nội bộ . Dữ liệu của 2 cột này không được nhập vào hệ thống.”
    - “Đã nhập 112 · Bỏ qua 9 trùng SĐT · 7 dòng lỗi”
- **K4c** (—) — Hộp thoại xem trước tác động (đổi giáo viên 12 buổi)
  - Khuôn K4c – xem trước tác động, chỉ cảnh báo
  - **Nút:** “Huỷ” · “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “2 buổi trùng lịch của giáo viên mới (dòng tô đỏ: 29/10 và 12/11). Chỉ cảnh báo, vẫn bấm Xác nhận được; hai buổi này giữ nguyên để CSKH xử lý sau.”
- **K4d** (—) — Hộp thoại chọn từ danh sách có kiểm tra (chọn lớp)
  - Khuôn K4d – danh sách có kiểm tra điều kiện
  - **Nút:** “T3 20/10” · “T5 22/10” · “T3 27/10” · “T5 29/10” · “Huỷ” · “Chọn”
  - **Thông báo / chữ cảnh báo:**
    - “Dòng đơn: Toán lớp 9 · Offline · Học sinh Lê Gia Huy (HS000123) · Cơ sở CS1. Chỉ lớp Đã duyệt, còn chỗ, đúng môn, khối, cơ sở và không trùng giờ lớp em đang học mới chọn được.”
- **K4e1** (—) — Bottom sheet điện thoại: Duyệt đơn hàng
  - Khuôn K4e – bottom sheet 390×844
  - **Nút:** “Từ chối” · “Duyệt”
- **K4e3** (—) — Bottom sheet điện thoại: Từ chối đơn hàng, bước 2 (bắt buộc lý do)
  - Khuôn K4e – bottom sheet 390×844
  - **Nút:** “Chọn lý do…” · “Giữ lại” · “Xác nhận từ chối”
- **K4e2** (—) — Bottom sheet điện thoại: Từ chối ticket (DN-CS1-2610-0007)
  - Khuôn K4e – bottom sheet 390×844
  - **Nút:** “Giữ lại” · “Xác nhận từ chối”
- **K5** (—) — Calendar Lịch hẹn (tuần)
  - Khuôn K5 – lịch tuần
  - **Nút:** “Tạo” · “Nhập” · “Xuất” · “Làm mới” · “Cột” · “Thời gian” · “Tất cả thời gian” · “Filters” · “Group By” · “Favorites” · “Xoá tất cả” · “Save to Favorites” · “Hôm nay” · “Ngày” · “Tuần” · “Tháng” · “Tất cả” · “Theo người” · “Theo phòng” · “Hoàn thành” · “Dời” · “Huỷ”
- **K07b** (TS-03) — Biểu mẫu ngăn kéo: Tạo nhanh lead
  - Khuôn K07b – ngăn kéo (drawer) dạng biểu mẫu
  - **Nút:** “Tạo” · “Nhập” · “Xuất” · “Làm mới” · “Cột” · “Ngày tạo” · “Tất cả thời gian” · “Filters” · “Group By” · “Favorites” · “Xoá tất cả” · “Save to Favorites” · “Facebook Ads” · “Lead Form” · “Trần Thu Hà” · “Huỷ” · “Lưu” · “Chọn…” · “Chọn Source trước”
  - **Thông báo / chữ cảnh báo:**
    - “Số này đã có lead LD000227 (Lê Thị Hằng). Không chặn: khi bấm Lưu, hệ thống sẽ hỏi gắn vào hồ sơ có sẵn hay vẫn tạo mới.”
    - “Còn 3 trường chưa hợp lệ. Sửa các ô viền đỏ rồi lưu lại.”
- **K07c** (TS-03) — Hộp thoại cảnh báo trùng SĐT, đè lên ngăn kéo
  - Khuôn K07c – hộp thoại cảnh báo trùng
  - **Nút:** “Tạo” · “Nhập” · “Xuất” · “Làm mới” · “Cột” · “Ngày tạo” · “Tất cả thời gian” · “Filters” · “Group By” · “Favorites” · “Xoá tất cả” · “Save to Favorites” · “Facebook Ads” · “Lead Form” · “Trần Thu Hà” · “Huỷ” · “Lưu” · “Vẫn tạo mới” · “Gắn vào hồ sơ có sẵn”
  - **Thông báo / chữ cảnh báo:**
    - “Số này đã có lead LD000227 (Lê Thị Hằng). Không chặn: khi bấm Lưu, hệ thống sẽ hỏi gắn vào hồ sơ có sẵn hay vẫn tạo mới.”
- **K09b** (CHUNG-14) — Trang chủ theo vai trò (Sale / CSKH / Trưởng cơ sở / Kế toán / Admin)
  - Khuôn K09b – trang chủ có bộ chuyển vai trò
  - **Nút:** “Sale” · “CSKH” · “Trưởng cơ sở” · “Kế toán” · “Admin” · “Mở danh sách”
- **K0x** (—) — Trạng thái chung: tải (skeleton), rỗng, thông báo lỗi/cảnh báo
  - Khuôn K0x – trạng thái dùng chung
  - **Nút:** “Xoá bộ lọc”
  - **Thông báo / chữ cảnh báo:**
    - “Không lưu được. Kiểm tra kết nối rồi thử lại.”
    - “Lead này đã có người phụ trách khác.”
- **K1_loc** (K1+) — Filters: khung lọc nhanh thả xuống (đã tick vài lọc)
  - K1 + khung thả xuống (popover) neo dưới nút Filters
  - **Nút:** “Lọc nâng cao…”
  - **Chữ trong khung:**
    - Tên khung: “Lọc nhanh”
    - Nhóm “Của tôi”: Tôi là sale · Tôi hỗ trợ
    - Nhóm “Lịch hẹn”: Hôm nay · Quá hạn chăm (phụ: “lịch hẹn kế tiếp đã quá hạn, chưa xong”) · Chưa có lịch hẹn
    - Gợi ý: “Cùng nhóm là HOẶC, khác nhóm là VÀ.”
    - Mục mở hộp thoại: “Lọc nâng cao…”
    - Chip sau khi chọn: “Của tôi: Tôi là sale”, “Lịch hẹn: Hôm nay hoặc Quá hạn chăm”
- **K1_loc_chip** (K1+) — Filters: đã áp dụng, chip lọc trên thanh tìm, bảng đã lọc
  - K1 (trạng thái)
  - **Nút:** —
  - **Chữ trong khung:**
    - Chip: Của tôi: Tôi là sale · Lịch hẹn: Hôm nay hoặc Quá hạn chăm · Tìm Tên: Toán · Group By: Stage
    - Bộ đếm: “1–5 / 5”
- **K1_loc_nc** (K1+) — Lọc nâng cao: hộp thoại có 3 dòng điều kiện
  - Khuôn hộp thoại (như K4) đè lên K1 mờ
  - **Nút:** “Source” · “là” · “Facebook Ads” · “Stage” · “là một trong” · “L4 Khách hàng tiềm năng L5 Đồng ý…” · “từ ngày” · “Thêm điều kiện” · “Xoá lọc” · “Áp dụng”
  - **Chữ trong khung:**
    - Tên hộp: “Lọc nâng cao” (đóng bằng X)
    - Dòng điều kiện: trường · phép so sánh · giá trị; nút xoá dòng (biểu tượng thùng rác); “Thêm điều kiện”
    - Phép so sánh mẫu: là · là một trong · từ ngày
    - Gợi ý: “Cơ hội phải khớp tất cả các điều kiện. Bộ lọc này gộp với các lọc nhanh đang chọn.”
    - Nút: “Xoá lọc”, “Áp dụng” (nút chính)
- **K1_loc_nc0** (K1+) — Lọc nâng cao: rỗng, chưa có điều kiện
  - Khuôn hộp thoại (như K4)
  - **Nút:** “Thêm điều kiện” · “Xoá lọc” · “Áp dụng”
  - **Chữ trong khung:**
    - Rỗng: “Chưa có điều kiện nào” · “Bấm “Thêm điều kiện” để chọn trường, phép so sánh và giá trị.”
    - “Xoá lọc” và “Áp dụng” bị tắt
- **K1_nhom** (K1+) — Group By: khung thả xuống, đã chọn 2 cấp
  - K1 + khung thả xuống neo dưới nút Group By
  - **Nút:** “Cấp 1 Stage” · “Sub-stage” · “Cấp 2 Source” · “Sub-source” · “Sale phụ trách” · “Cơ sở”
  - **Chữ trong khung:**
    - Tên khung: “Nhóm theo”; dòng “Thứ tự nhóm: Stage › Source”
    - Trường để nhóm: Stage · Sub-stage · Source · Sub-source · Sale phụ trách · Cơ sở; nhãn “Cấp 1”, “Cấp 2” trên trường đã chọn
    - Khi đủ 2 cấp: “Đã đủ 2 cấp. Bỏ một trường để chọn trường khác. Bấm lại một trường để bỏ chọn.” (các trường còn lại mờ)
- **K1_nhom_bang** (K1+) — Group By: bảng đã nhóm 2 cấp (Stage › Source), dòng nhóm gập/mở, có đếm
  - K1 (trạng thái)
  - **Nút:** —
  - **Chữ trong khung:**
    - Chip: Group By: Stage › Source
    - Dòng nhóm: tên nhóm + số đếm, mũi tên gập/mở (cấp 1 và cấp 2)
- **K1_nhom0** (K1+) — Group By: rỗng, chưa chọn cấp nào (bảng phẳng)
  - K1 + khung thả xuống
  - **Nút:** “Stage” · “Sub-stage” · “Source” · “Sub-source” · “Sale phụ trách” · “Cơ sở”
  - **Chữ trong khung:**
    - Rỗng: “Chưa chọn cấp nào, bảng đang hiện dạng phẳng. Chọn tối đa 2 cấp.” · “Thứ tự nhóm: chưa chọn”
- **K1_cot** (K1+) — Cột: tick cột hiển thị, kéo đổi thứ tự, nút Mặc định
  - K1 + khung thả xuống neo dưới nút Cột
  - **Nút:** “Mặc định”
  - **Chữ trong khung:**
    - Tên khung: “Cột hiển thị”, bộ đếm “8 / 12”
    - Danh sách: Mã, Cơ hội (khoá, luôn hiện), Phụ huynh · SĐT, Stage · Sub-stage, Source · Sub-source, Sale phụ trách, Cơ sở, Lịch hẹn kế tiếp, Ngày tạo, Nhân sự hỗ trợ, Chiến dịch, Trường học
    - Gợi ý: “Tick để hiện hoặc ẩn. Kéo tay nắm bên trái để đổi thứ tự. Mã và Cơ hội luôn hiện.”
    - Nút: “Mặc định”
- **K1_fav** (K1+) — Favorites: danh sách bộ lọc đã lưu của tôi
  - K1 + khung thả xuống neo dưới nút Favorites
  - **Nút:** “Lưu bộ lọc hiện tại”
  - **Chữ trong khung:**
    - Tên khung: “Bộ lọc đã lưu của tôi”
    - Mỗi dòng: tên, mô tả điều kiện, thẻ “Dùng chung” (nếu có), nút xoá (thùng rác)
    - Nút: “Lưu bộ lọc hiện tại”
- **K1_fav_luu** (K1+) — Favorites: lưu bộ lọc hiện tại (đặt tên, tick Dùng cho mọi người)
  - K1 + khung thả xuống
  - **Nút:** “Huỷ” · “Lưu”
  - **Chữ trong khung:**
    - Tên khung: “Lưu bộ lọc hiện tại”; khối “Điều kiện đang áp dụng”
    - Ô “Tên bộ lọc” (bắt buộc); tick “Dùng cho mọi người”; gợi ý “Ô này chỉ hiện với người có quyền chia sẻ bộ lọc.”
    - Nút: “Huỷ”, “Lưu” (nút chính)
- **K1_fav0** (K1+) — Favorites: rỗng “Chưa có bộ lọc nào được lưu”
  - K1 + khung thả xuống
  - **Nút:** “Lưu bộ lọc hiện tại”
  - **Chữ trong khung:**
    - Rỗng: “Chưa có bộ lọc nào được lưu” · “Chọn bộ lọc rồi bấm “Lưu bộ lọc hiện tại” để dùng lại lần sau.”
    - Nút: “Lưu bộ lọc hiện tại”
- **K1m_loc** (K1+) — Filters (điện thoại): bottom sheet
  - Khuôn K4e (bottom sheet 390×844)
  - **Nút:** “Lọc nâng cao…” · “Xoá lọc” · “Áp dụng”
  - **Chữ trong khung:**
    - Sheet “Filters”: như bản máy tính; nút “Xoá lọc”, “Áp dụng” (nút chính); mục “Lọc nâng cao…”
- **K1m_nhom** (K1+) — Group By (điện thoại): bottom sheet
  - Khuôn K4e
  - **Nút:** “Áp dụng”
  - **Chữ trong khung:**
    - Sheet “Group By”: “Thứ tự nhóm: Stage › Source”, nhãn Cấp 1, Cấp 2; nút “Áp dụng” (nút chính)
- **K1m_cot** (K1+) — Cột (điện thoại): bottom sheet
  - Khuôn K4e
  - **Nút:** “Mặc định” · “Áp dụng”
  - **Chữ trong khung:**
    - Sheet “Cột hiển thị”; nút “Mặc định”, “Áp dụng” (nút chính)
- **K1m_fav** (K1+) — Favorites (điện thoại): bottom sheet
  - Khuôn K4e
  - **Nút:** “Lưu bộ lọc hiện tại”
  - **Chữ trong khung:**
    - Sheet “Bộ lọc đã lưu của tôi”; nút “Lưu bộ lọc hiện tại” (nút chính)
- **K1_tim** (K1+) — Thanh trên: ô tìm kiếm toàn hệ thống (đóng, có phím tắt “/”)
  - Vỏ CRM: thanh trên
  - **Nút:** —
  - **Chữ trong khung:**
    - Thanh trên: ô tìm kiếm đặt sau đường dẫn; gợi ý “Tìm khách hàng, học sinh, lớp, mã…”; phím tắt “/”
- **K1_tim_go** (K1+) — Tìm kiếm: đang gõ, khung kết quả nhóm theo loại
  - Vỏ CRM + khung kết quả thả xuống
  - **Nút:** —
  - **Chữ trong khung:**
    - Đang gõ “huy”: viền cam, nút xoá nội dung (X)
    - Khung kết quả nhóm theo loại, tiêu đề nhóm có số đếm: “Học sinh · 2”, “Khách hàng · 1”, “Cơ hội · 1”; mỗi dòng: mã, tên (tô đậm phần khớp), mô tả, thẻ trạng thái
    - Dòng đầu được tô nền (đang chọn)
- **K1_tim0** (K1+) — Tìm kiếm: “Không tìm thấy”
  - Vỏ CRM + khung kết quả thả xuống
  - **Nút:** —
  - **Chữ trong khung:**
    - “Không tìm thấy” · “Không có kết quả cho “xyzabc”. Thử mã, số điện thoại hoặc tên khác.”
- **K1_chuong** (K1+) — Chuông thông báo: danh sách ngắn (3 dòng mẫu)
  - Vỏ CRM + khung thả xuống
  - **Nút:** —
  - **Chữ trong khung:**
    - Tên khung: “Thông báo”; 3 dòng mẫu có chấm chưa đọc: “Lịch hẹn 14:00 với Lê Gia Huy sắp đến”, “Ticket DN-CS1-2610-0007 sắp quá hạn”, “Đơn hàng DH-CS1-2610-0388 đã được duyệt”
    - Không có nút “Xem tất cả” hay “Đánh dấu đã đọc”
- **K1_chuong0** (K1+) — Chuông thông báo: rỗng “Chưa có thông báo”
  - Vỏ CRM + khung thả xuống
  - **Nút:** —
  - **Chữ trong khung:**
    - “Chưa có thông báo” · “Thông báo mới sẽ hiện ở đây.”; chuông không còn số đỏ
- **K1m_tim_dong** (K1+) — Điện thoại: ô tìm thu thành biểu tượng
  - Khuôn điện thoại
  - **Nút:** —
  - **Chữ trong khung:**
    - Ô tìm thu thành biểu tượng kính lúp ở góc phải thanh tiêu đề
- **K1m_tim** (K1+) — Điện thoại: tìm kiếm toàn màn hình (đang gõ)
  - Khuôn điện thoại
  - **Nút:** —
  - **Chữ trong khung:**
    - Toàn màn hình: nút quay lại, ô tìm có viền cam và nút xoá; kết quả nhóm theo loại như bản máy tính
- **K1m_tim0** (K1+) — Điện thoại: tìm kiếm toàn màn hình (không tìm thấy)
  - Khuôn điện thoại
  - **Nút:** —
  - **Chữ trong khung:**
    - Toàn màn hình: “Không tìm thấy” · “Không có kết quả cho “xyzabc”. Thử mã, số điện thoại hoặc tên khác.”

### P1

#### DN01 · CHUNG-01 — Đăng nhập nhân viên
- `DN01_pc_ok` — Máy tính · Bình thường
  - **Nút:** “Đăng nhập”
- `DN01_pc_err` — Máy tính · Sai thông tin
  - **Nút:** “Đăng nhập”
  - **Thông báo / chữ cảnh báo:**
    - “Email hoặc mật khẩu không đúng. Kiểm tra lại rồi thử lần nữa.”
- `DN01_mb_ok` — Điện thoại · Bình thường
  - **Nút:** “Đăng nhập”
- `DN01_mb_err` — Điện thoại · Sai thông tin
  - **Nút:** “Đăng nhập”
  - **Thông báo / chữ cảnh báo:**
    - “Email hoặc mật khẩu không đúng. Kiểm tra lại rồi thử lần nữa.”
#### DN02 · CHUNG-06 — Đăng nhập học sinh
- `DN02_pc_ok` — Máy tính · Bình thường
  - **Nút:** “Vào học”
  - **Thông báo / chữ cảnh báo:**
    - “Quên mật khẩu? Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng ở cơ sở cấp lại.”
- `DN02_pc_err` — Máy tính · Sai thông tin
  - **Nút:** “Vào học”
  - **Thông báo / chữ cảnh báo:**
    - “Mã học sinh hoặc mật khẩu chưa đúng. Em kiểm tra lại nhé.”
    - “Quên mật khẩu? Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng ở cơ sở cấp lại.”
- `DN02_mb_ok` — Điện thoại · Bình thường
  - **Nút:** “Vào học”
  - **Thông báo / chữ cảnh báo:**
    - “Quên mật khẩu? Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng ở cơ sở cấp lại.”
- `DN02_mb_err` — Điện thoại · Sai thông tin
  - **Nút:** “Vào học”
  - **Thông báo / chữ cảnh báo:**
    - “Mã học sinh hoặc mật khẩu chưa đúng. Em kiểm tra lại nhé.”
    - “Quên mật khẩu? Em nhờ thầy cô hoặc bộ phận chăm sóc khách hàng ở cơ sở cấp lại.”
#### DN03 · CHUNG-02 — Xác thực hai bước (nhập mã)
Dưới nút của cả 4 artboard có dòng chữ thường: “Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước” và “Bắt buộc với tài khoản Admin và Kế toán.”
- `DN03_pc_code` — Máy tính · Mã từ ứng dụng
  - **Nút:** “Xác nhận”
- `DN03_pc_code_err` — Máy tính · Mã từ ứng dụng · Sai mã
  - **Nút:** “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “Mã không đúng. Kiểm tra lại mã đang hiện trong ứng dụng rồi nhập lại.”
- `DN03_mb_code` — Điện thoại · Mã từ ứng dụng
  - **Nút:** “Xác nhận”
- `DN03_mb_code_err` — Điện thoại · Mã từ ứng dụng · Sai mã
  - **Nút:** “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “Mã không đúng. Kiểm tra lại mã đang hiện trong ứng dụng rồi nhập lại.”
#### DN04 · CHUNG-03 — Thiết lập 2FA lần đầu (2 bước)
- `DN04_pc_s1` — Máy tính · Bước 1/2 · Quét mã
  - **Nút:** “Tiếp”
- `DN04_pc_s2` — Máy tính · Bước 2/2 · Nhập mã (bước cuối)
  - **Nút:** “Quay lại” · “Hoàn tất”
- `DN04_mb_s1` — Điện thoại · Bước 1/2 · Quét mã
  - **Nút:** “Tiếp”
- `DN04_mb_s2` — Điện thoại · Bước 2/2 · Nhập mã (bước cuối)
  - **Nút:** “Quay lại” · “Hoàn tất”
#### DN05 · CHUNG-04 — Quên mật khẩu
- `DN05_pc_form` — Máy tính · Liên hệ quản trị viên
  - **Nút:** “Quay lại đăng nhập”
  - **Chữ:** “Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.”
- `DN05_mb_form` — Điện thoại · Liên hệ quản trị viên
  - **Nút:** “Quay lại đăng nhập”
  - **Chữ:** “Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.”
#### DN06 · CHUNG-05 — Đặt mật khẩu mới (link từ email)
- **HOÃN.** Không có trong gói v4. Artboard vẫn trên canvas, gắn nhãn “HOÃN”.
#### DN07 · CHUNG-07 — Đổi mật khẩu lần đầu
- `DN07_pc_new` — Máy tính · Mới mở, chưa nhập
  - **Nút:** “Đổi mật khẩu và tiếp tục”
  - **Thông báo / chữ cảnh báo:**
    - “Mật khẩu hiện tại là mật khẩu tạm do trung tâm cấp. Đặt mật khẩu của riêng mình để tiếp tục.”
- `DN07_pc_ok` — Máy tính · Đủ điều kiện
  - **Nút:** “Đổi mật khẩu và tiếp tục”
  - **Thông báo / chữ cảnh báo:**
    - “Mật khẩu hiện tại là mật khẩu tạm do trung tâm cấp. Đặt mật khẩu của riêng mình để tiếp tục.”
- `DN07_mb_new` — Điện thoại · Mới mở, chưa nhập
  - **Nút:** “Đổi mật khẩu và tiếp tục”
  - **Thông báo / chữ cảnh báo:**
    - “Mật khẩu hiện tại là mật khẩu tạm do trung tâm cấp. Đặt mật khẩu của riêng mình để tiếp tục.”
- `DN07_mb_ok` — Điện thoại · Đủ điều kiện
  - **Nút:** “Đổi mật khẩu và tiếp tục”
  - **Thông báo / chữ cảnh báo:**
    - “Mật khẩu hiện tại là mật khẩu tạm do trung tâm cấp. Đặt mật khẩu của riêng mình để tiếp tục.”
#### DN08 · CHUNG-08 — Không thể đăng nhập (một câu chung)
- `DN08_pc_lock` — Máy tính
  - **Nút:** “Quay lại đăng nhập”
  - **Thông báo:** tiêu đề “Không thể đăng nhập”; câu “Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm.”
- `DN08_mb_lock` — Điện thoại
  - **Nút:** “Quay lại đăng nhập”
  - **Thông báo:** như bản máy tính.
- Dùng chung cho mọi trường hợp không cho đăng nhập (tạm khoá do sai nhiều lần, tài khoản bị khoá). Không nói thời gian khoá, không nói lý do (luật S03-18).
#### DN09 · CHUNG-09 — Hộp thoại hết phiên đăng nhập
- `DN09_pc_end` — Máy tính · Hết phiên
  - **Nút:** “Đăng nhập lại”
- `DN09_mb_end` — Điện thoại · Hết phiên
  - **Nút:** “Đăng nhập lại”
#### DN10 · CHUNG-25 — Chọn cổng (CRM / Giáo viên)
- `DN10_pc_ok` — Máy tính · Chọn cổng
  - **Nút:** “CRM Tuyển sinh, khách hàng, bán hàng, lớp, buổi học, chăm sóc khách hàng.” · “Giáo viên Lịch dạy, điểm danh, chấm nhận xét, bài tập về nhà.”
- `DN10_mb_ok` — Điện thoại · Chọn cổng
  - **Nút:** “CRM Tuyển sinh, khách hàng, bán hàng, lớp, buổi học, chăm sóc khách hàng.” · “Giáo viên Lịch dạy, điểm danh, chấm nhận xét, bài tập về nhà.”

### P2

- **CauHinh** (QT-07 / QT-09) — Cấu hình: Danh mục, Tham số nghiệp vụ, Công tắc tính năng
  - Khuôn trang Cấu hình (vỏ CRM + cột trái nhóm danh mục + bảng)
  - **Tham số (v4):** không còn ô “Có hiệu lực từ”; câu cuối tab Tham số: “Sửa một tham số thì có hiệu lực ngay; giá trị cũ vẫn giữ trong lịch sử thay đổi.”
  - **Nút:** “Lịch sử thay đổi” · “Danh mục” · “Tham số nghiệp vụ” · “Công tắc tính năng” · “Giai đoạn cơ hội Khoá 8” · “Nguồn lead 7” · “Môn học 10” · “Phân loại lớp Khoá 3” · “Trình độ Khoá 4” · “Hình thức học Khoá 2” · “Loại gói 6” · “Loại hoạt động 5” · “Hình thức test 2” · “Cấp độ đề test 2” · “Lý do từ chối 5” · “Lý do huỷ buổi 8” · “Lý do không tái tục 7” · “Hình thức thu tiền 3” · “Mức độ khiếu nại 4” · “Kênh tiếp nhận ticket 6” · “Source” · “Sub-source” · “Ngừng” · “Thêm” · “Huỷ” · “Lưu” · (một số nhãn lấy từ dữ liệu: giai đoạn, sub-stage, tab…)
- **MaTranQuyen** (QT-05) — Ma trận quyền theo vai trò; đầu màn ghi “Phiên bản 12 · lưu bởi … lúc …”; đã bỏ ngày hiệu lực
  - Khuôn trang Ma trận quyền (vỏ CRM + bảng ô quyền)
  - **Nút:** “Lịch sử thay đổi quyền” · “Cơ sở” · “Của tôi” · “Không có” · “Tất cả” · “Huỷ” · “Lưu thay đổi” · “Sửa”
  - **Chữ trong khung:**
    - Đầu màn: thẻ “Hiện hành” + “Phiên bản 12” + “lưu bởi Cao Trường lúc 12/10/2026 16:20”
    - Thanh lưu: “Lưu tạo phiên bản mới, có hiệu lực ngay.”; thông báo sau lưu: “Đã lưu N thay đổi thành phiên bản mới, có hiệu lực ngay.”
- **MaTranQuyen_ls** (QT-05) — Lịch sử thay đổi quyền: danh sách phiên bản (ngăn kéo)
  - Khuôn ngăn kéo (như K07b) đè lên Ma trận quyền
  - **Nút:** —
  - **Chữ trong khung:**
    - Tên ngăn kéo: “Lịch sử thay đổi quyền”; dòng phụ “Phiên bản hiện hành: 12. Mỗi lần lưu tạo một phiên bản mới, có hiệu lực ngay.”
    - Mỗi dòng: “Phiên bản N”, thẻ “Hiện hành” (bản mới nhất), “Đổi X ô”, người lưu · giờ lưu
    - Chân: “Bấm một dòng để xem các ô đã đổi. Chỉ xem, không khôi phục phiên bản cũ.”
    - Không có nút khôi phục
- **MaTranQuyen_ct** (QT-05) — Lịch sử thay đổi quyền: chi tiết một phiên bản (ô đã đổi: vai trò · phân hệ · hành động · từ → sang)
  - Khuôn ngăn kéo
  - **Nút:** —
  - **Chữ trong khung:**
    - Dòng phụ: “Phiên bản 11 · lưu bởi … lúc … · đổi 3 ô”; nút quay lại danh sách
    - Cột: Vai trò · Phân hệ · Hành động · Từ → Sang
    - Chân: “Chỉ xem. Muốn đổi lại, sửa trong ma trận rồi lưu thành phiên bản mới.”
    - Không có nút khôi phục

**Chuỗi tương tác nhúng trong MaTranQuyen.dc.html (bản mẫu, chưa phải chữ chính thức):**
- “Đang xem quyền của vai trò ”
- “Bấm Sửa để thay đổi quyền.”
- “Đã bỏ các thay đổi chưa lưu.”
- “Giai đoạn đã qua bị khoá. Muốn quay lại Nháp: Hành động → Đưa về Nháp (bắt buộc lý do).”
- “Đã chuyển sang ”
- “Đã chuyển lead sang ”
- “Còn ô bắt buộc chưa điền.”
- “Chuyển sang bản ghi ”
- “Đã làm mới lúc ”
- “Hành động: ”
- “Nhóm theo: Giai đoạn, Nguồn, Sale.”
- “Chọn cột hiển thị”
- “Đã giao ”
- “Dời lịch hẹn: mở hộp thoại Dời (TS-13).”
- “Nhập nội dung ghi chú trước.”
- “Đã gửi ghi chú.”
- “Mở bản ghi trùng: LD000227 (TS-02).”
- “Đã chuyển ”

## 4. Ghi chú đã đặt trên canvas (cần đưa vào dựng)
- **Quyền xem từng khối** theo Ma trận quyền (QT-05), chốt sau.
- **Ngưỡng “sắp quá hạn”**: còn ≤ 25% thời hạn xử lý của ticket (ví dụ ticket đề nghị 2 ngày thì từ 12 giờ cuối). Chưa phải luật chính thức.
- **Lưu nháp**: chỉ khi bản ghi có giai đoạn Nháp (lớp, đơn hàng, báo giá, phiếu thu). Lead không có bước Nháp.
- **Cơ hội quá hạn chăm**: cơ hội có lịch hẹn kế tiếp đã quá hạn, chưa hoàn thành (dùng làm lọc nhanh “Quá hạn chăm” ở K1).
- **Mã ticket**: `DN-<CS>-<YYMM>-<STT>` (đề nghị) và `KN-…` (khiếu nại), ví dụ DN-CS1-2610-0007.
- **Source / Sub-source** là hai ô riêng; “Loại” tự hiện dưới Source. **Chiến dịch** là ô độc lập, có “+ Tạo chiến dịch mới”.
- **Nhập lead từ file**: bỏ qua dòng trùng SĐT; tổng kết “Đã nhập 112 · Bỏ qua 9 trùng SĐT · 7 dòng lỗi”; dòng trùng hiện mã sẵn có (“Trùng với LD000231”).
- **Đổi giáo viên**: trùng lịch chỉ cảnh báo, vẫn bấm Xác nhận được.
- **Chọn lớp (K4d)**: mỗi dòng hiện tối đa 2 lý do không chọn được, còn lại gộp “+N lý do”; lớp trùng giờ với lớp em đang học thì mờ đi.
- **Trang chủ theo vai trò (K09b)**: nút “Mở danh sách” dẫn tới đích theo bảng của anh; quyền xem từng khối chờ QT-05.
- **Ma trận quyền (10/10)**: mỗi lần bấm “Lưu thay đổi” tạo MỘT phiên bản mới, có hiệu lực ngay, không hẹn ngày. Lịch sử chỉ xem, không khôi phục.
- **Bộ lọc nhanh của K1**: cùng nhóm là HOẶC, khác nhóm là VÀ. Group By tối đa 2 cấp.
- **Thanh màu trên đầu cột Kanban (K2)** (`.hmt-kbar`, ghi thêm v4): chia khúc theo tình trạng lịch hẹn của các thẻ trong cột. **Xanh** (`.ok`, `--success-solid`) = lịch hẹn còn hạn; **vàng** (`.warn`, `--warning-solid`) = lịch hẹn hôm nay; **đỏ** (`.bad`, `--danger-solid`) = quá hạn; **xám** (phần nền còn lại, `--divider`) = chưa có lịch. Độ dài mỗi khúc theo tỉ lệ số thẻ. **Bấm một khúc màu thì lọc cột theo nhóm đó** (bản vẽ chưa thể hiện trạng thái đang lọc).
- **Tham số nghiệp vụ** (v4): có hiệu lực ngay khi lưu, không hẹn ngày; giá trị cũ giữ trong lịch sử thay đổi.
- **Đăng nhập** (v4): không có mã dự phòng; quên mật khẩu chỉ liên hệ quản trị viên; mọi trường hợp bị chặn đăng nhập dùng một câu chung (DN08).

## 5. Những chỗ còn chưa chắc
1. **P1 còn thiếu (Đợt 3)**: chưa vẽ màn không có quyền, module chưa bật, 404, lỗi hệ thống, và khung cổng KC.
2. **Chữ lỗi OTP** (DN03: “Sai mã”, hết hạn mã) chưa được duyệt từng câu. (v4 đã bỏ lỗi mã dự phòng.)
3. **Mã mẫu tự đặt**: mã đơn hàng, ticket, phiếu thu/PKT/PT trong dữ liệu mẫu em tự đặt theo định dạng trong file ngữ cảnh; chưa có bảng mã thật.
4. **Quyền từng khối của K09b** chưa khớp Ma trận quyền (QT-05); đây mới là bản tạm theo bảng vai trò.
5. **Ngưỡng 25%** cho “sắp quá hạn” chưa phải luật chính thức.
6. **“Cơ hội quá hạn chăm”** đã định nghĩa theo lịch hẹn kế tiếp quá hạn chưa hoàn thành; em chưa đối chiếu với các bộ lọc ở màn khác.
7. **Hộp cảnh báo trùng SĐT** ở TS-03 đã thống nhất theo K07c (bỏ nút “Huỷ”, đóng bằng X). TS-03 thuộc P3 nên không nằm trong gói; K07b/K07c là bản chuẩn.
8. **Source 3 cấp** trong danh mục chỉ hiện 2 ô (Source, Sub-source); “Loại” hiện như chữ phụ. Chưa rõ có cần ô thứ ba không.
9. **Tiêu đề trong file** CauHinh.dc.html ghi “K5 · Cấu hình” và MaTranQuyen.dc.html ghi “Đ1 · Ma trận quyền”: tên cũ, mã đúng là QT-07/QT-09 và QT-05.
10. **K1, K2, K3, K5, K4*, K0x, K1_*** chưa có mã màn trong brief nên cột “Mã màn” để “—” hoặc “K1+”; gọi theo tên artboard.
11. Ảnh PNG dùng phông thay thế (xem mục 0); các màn có tương tác (chọn vai trò K09b, các bước K4b, mở hộp thoại) chỉ chụp ở trạng thái mở đầu. Muốn xem các trạng thái khác thì mở file `.dc.html`.
12. Các chỗ chưa chắc của đợt bổ sung nằm ở mục 6.


## 6. Đợt bổ sung: K1 bốn khung mở ra và lịch sử phiên bản Ma trận quyền
Luật chốt (10/10): mỗi lần bấm “Lưu thay đổi” tạo MỘT phiên bản mới của ma trận, có hiệu lực ngay, không hẹn ngày. Đã bỏ ô “Có hiệu lực từ” và câu “có hiệu lực từ ngày chọn” trong màn Ma trận quyền.

| Khung | Artboard | Chưa chắc |
|---|---|---|
| Filters (khung thả xuống) | K1_loc, K1_loc_chip | Nội dung hai nhóm lọc nhanh em lấy từ chip và định nghĩa có sẵn: “Của tôi” (Tôi là sale, Tôi hỗ trợ) và “Lịch hẹn” (Hôm nay, Quá hạn chăm, Chưa có lịch hẹn). “Tôi hỗ trợ” và “Chưa có lịch hẹn” em thêm cho đủ hai nhóm; chờ anh chốt danh sách. Tick lọc nhanh áp dụng ngay, không có nút Áp dụng riêng. |
| Lọc nâng cao | K1_loc_nc, K1_loc_nc0 | Các dòng điều kiện nối bằng VÀ (chưa có ô chọn HOẶC). Danh sách trường và phép so sánh theo kiểu dữ liệu (là, là một trong, từ ngày…) mới là ví dụ. Chưa vẽ ô chọn giá trị đang mở. Hộp thoại có thêm nút đóng X ngoài hai nút anh liệt kê. |
| Group By | K1_nhom, K1_nhom_bang, K1_nhom0 | Danh sách trường nhóm lấy từ các cột của K1 (Stage, Sub-stage, Source, Sub-source, Sale phụ trách, Cơ sở). Bấm lại để bỏ chọn; khi đủ 2 cấp các trường còn lại mờ. Nhóm cấp 2 gập/mở độc lập với cấp 1. Chưa vẽ đổi thứ tự cấp (chỉ đổi bằng cách bỏ chọn rồi chọn lại). |
| Cột | K1_cot | Mã và Cơ hội luôn hiện (khoá) là em tự đặt. Bốn cột thêm (Ngày tạo, Nhân sự hỗ trợ, Chiến dịch, Trường học) lấy từ trang chi tiết K3, chờ anh chốt. Không có trạng thái rỗng vì Mã và Cơ hội luôn bật. Chưa rõ “Mặc định” là bộ cột nào. |
| Favorites | K1_fav, K1_fav_luu, K1_fav0 | Ô “Dùng cho mọi người” chỉ hiện với người có quyền chia sẻ; em chưa biết tên quyền này, đang ghi “quyền chia sẻ bộ lọc”, cần đối chiếu Ma trận quyền (QT-05). Tên ba bộ lọc mẫu là em đặt. Chưa vẽ lỗi trùng tên và hỏi xác nhận khi xoá. |
| Bản điện thoại (4 bottom sheet) | K1m_loc, K1m_nhom, K1m_cot, K1m_fav | Điện thoại dùng nút “Áp dụng” vì sheet đóng lại, khác bản máy tính (áp dụng ngay). Nền điện thoại là danh sách thẻ cơ hội do em phác (K1 chưa có bản điện thoại). Chưa vẽ: Lọc nâng cao trên điện thoại, lưu bộ lọc trên điện thoại, và trạng thái rỗng của Favorites trên điện thoại. |
| Ma trận quyền: đầu màn | MaTranQuyen | Câu “Phiên bản 12 · lưu bởi Cao Trường lúc 12/10/2026 16:20” là ví dụ. Mục “Lịch sử thay đổi gần đây” ở cuối màn (đã duyệt) vẫn ghi theo từng thay đổi, chưa gắn số phiên bản; nội dung dòng đầu (“Giao việc trên Ticket”) không khớp 5 hành động của ma trận (Xem, Tạo, Sửa, Duyệt, Xuất). |
| Lịch sử phiên bản | MaTranQuyen_ls, MaTranQuyen_ct | Dữ liệu phiên bản 7 đến 12 là mẫu em đặt. Phiên bản 10 ghi “đổi 40 ô” vì thêm vai trò mới, chưa chắc cách đếm này. Chưa vẽ: lọc theo người lưu hoặc ngày, phân trang khi nhiều phiên bản. Quyền xem lịch sử chưa rõ. |
| Cấu hình (CauHinh) | CauHinh | **Đã xử lý ở v4**: anh xác nhận tham số có hiệu lực ngay, đã bỏ ô “Có hiệu lực từ”. |


## 7. Đợt bổ sung v3: ô tìm kiếm toàn hệ thống và chuông thông báo (chỉ vẽ vỏ)

| Khung | Artboard | Chưa chắc |
|---|---|---|
| Ô tìm toàn hệ thống (đóng) | K1_tim | Vị trí: ngay sau đường dẫn, rộng 460. Trên K1 vẫn còn ô “Tìm tên, SĐT, mã (cả mã cũ)…” riêng của danh sách; hai ô này đứng cạnh nhau, cần anh xác nhận không gây nhầm. Phím tắt “/” là ví dụ anh đưa; chưa vẽ hành vi phím. |
| Đang gõ + kết quả | K1_tim_go | Các nhóm em vẽ là Học sinh, Khách hàng, Cơ hội (chỉ hiện nhóm có kết quả, tối đa vài dòng mỗi nhóm). Chữ “lớp” trong gợi ý chưa có dòng mẫu vì từ khoá “huy” không khớp lớp nào; nhóm Lớp chưa vẽ. Chưa vẽ mục “Xem tất cả kết quả”, lịch sử tìm, tìm gần đây. Dữ liệu là mẫu. |
| Không tìm thấy | K1_tim0 | Câu gợi ý dưới “Không tìm thấy” là em viết. |
| Chuông: danh sách | K1_chuong | Ba dòng mẫu là em đặt (lịch hẹn, ticket, đơn hàng). Chưa có “Xem tất cả” và “Đánh dấu đã đọc” vì chưa thuộc danh sách anh nêu. Chưa rõ bấm một dòng mở đâu. |
| Chuông: rỗng | K1_chuong0 | Câu phụ “Thông báo mới sẽ hiện ở đây.” là em viết. |
| Điện thoại | K1m_tim_dong, K1m_tim, K1m_tim0 | Chuông thông báo trên điện thoại chưa vẽ (anh chưa yêu cầu). Chưa vẽ trạng thái vừa mở, chưa gõ (bàn phím và gợi ý). |


## 8. Đợt v4: chỗ còn chưa chắc

| Khung | Artboard | Chưa chắc |
|---|---|---|
| DN03 dòng "Mất điện thoại?" | DN03_* | Em để là chữ thường, không phải liên kết, vì không có nơi để bấm tới. Nếu anh muốn liên kết mở thông tin liên hệ quản trị viên thì cần nêu đích. |
| DN05 tên artboard | DN05_pc_form, DN05_mb_form | Giữ tên `_form` cho khỏi đổi mã, dù màn không còn biểu mẫu. Câu “Học sinh quên mật khẩu thì nhờ chăm sóc khách hàng cấp lại.” đã bỏ theo yêu cầu “chỉ có câu … và nút”. Học sinh vẫn có câu riêng ở DN02. |
| DN08 tên và nội dung | DN08_pc_lock, DN08_mb_lock | Tên `_lock` là em đặt cho màn gộp. Tiêu đề “Không thể đăng nhập” em lấy từ câu anh đưa (cần có tiêu đề theo khuôn). Biểu tượng ổ khoá giữ từ bản cũ; nếu sợ gợi ý “tài khoản bị khoá” thì có thể đổi sang biểu tượng thông tin. Bỏ nút “Quên mật khẩu?” của bản tạm khoá cũ (màn gộp lấy theo bản khoá hẳn, một nút). |
| DN09 hết phiên | DN09_* | Không đổi; chưa đối chiếu lại với quyết định đăng nhập mới. |
| Token viền trạng thái | tokens.json, hmt-tokens.css | Ba màu viền mới em pha 21% màu đậm vào màu nền, cùng cách với `--info-border` có sẵn. **Chưa gắn vào `.hmt-alert` / `.hmt-toast`** để khỏi đổi các màn đã duyệt; dùng khi dựng thành phần mới hoặc khi anh duyệt thêm viền cho thông báo. |
| Chiều cao hàng bảng | bundle.css | Chỉ đưa hàng tiêu đề (32) và hàng dữ liệu (36) của `.hmt-table` vào token. Hàng nhóm `.ghead` (34) và `.grp` (28) cùng các bảng tự dựng bằng lưới (CauHinh 40–44, MaTranQuyen) vẫn viết thẳng; hai kiểu hàng nhóm cao khác nhau, cần anh chốt một số. |
| Thanh màu K2 | K2 | Bản vẽ chưa có trạng thái “đang lọc theo khúc màu” và chưa có chú thích màu trên màn. |
