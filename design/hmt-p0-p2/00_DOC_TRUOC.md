# 00_DOC_TRUOC — Gói bàn giao P0 · P1 · P2 (HMT CRM)

Đọc file này trước khi mở gói. Gói chỉ gồm 3 phân hệ đã duyệt: **P0 Khuôn chung**, **P1 Đăng nhập & xác thực**, **P2 Cấu hình & phân quyền**. P3 (Tuyển sinh TS-xx), P13 Báo cáo, P14 Tìm kiếm & thông báo **không nằm trong gói**.

## 0. Cấu trúc gói
```
00_DOC_TRUOC.md
ds/hmt/handoff/hmt-tokens.css      token màu, chữ, khoảng cách, bo góc
ds/hmt/components/bundle.css       thành phần dùng chung (.hmt-btn, .hmt-toast, ...)
ds/hmt/tokens.json                 cùng token dạng JSON
artboards/*.dc.html                59 artboard (P0 15, P1 42, P2 2)
artboards/ds/hmt/...               bản sao token để mở artboard độc lập (đường dẫn tương đối ds/hmt/...)
png/*.png                          ảnh từng artboard; tên PNG trùng tên artboard
```
- Artboard 1440×1000 là bản **máy tính**; 390×844 là bản **điện thoại** (tên có `_mb` hoặc K4e). P1 có đủ pc và mb. P0 và P2 chỉ có bản máy tính, riêng K4e là bản điện thoại.
- Ảnh PNG xuất bằng trình duyệt không có phông Inter / Be Vietnam Pro nên chữ là phông thay thế, hơi lệch so với bản thật. Kích thước và màu đúng. Phông chuẩn lấy theo token (`--font-ui` Inter, `--font-heading` Be Vietnam Pro).
- Các file `.dc.html` là artboard của Design canvas. Mỗi file tham chiếu `ds/hmt/...` theo đường dẫn tương đối; cần có `support.js` của công cụ canvas mới mở độc lập được. Khi dựng thật, lấy HTML trong `<x-dc>` và CSS token làm chuẩn, không cần chạy `support.js`.
- Quy ước thiết kế: giao diện sáng, màu thương hiệu cam (`--brand-600` #CB4D0E), mỗi màn một nút chính, nút nguy hiểm viền đỏ có biểu tượng. Nút và bố cục chỉ lấy từ wireframe/brief; chỗ chưa có thì liệt kê ở mục 5.


## 1. Danh sách mã màn trong gói

### P0 · Khuôn chung (15 artboard, máy tính; K4e là điện thoại)

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

### P1 · Đăng nhập & xác thực (10 màn, 42 artboard: máy tính + điện thoại)

| Artboard (gốc) | Mã màn | Nội dung | Các biến thể (có `pc_` và `mb_`) |
|---|---|---|---|
| DN01 | CHUNG-01 | Đăng nhập nhân viên | pc_ok, pc_err, mb_ok, mb_err |
| DN02 | CHUNG-06 | Đăng nhập học sinh | pc_ok, pc_err, mb_ok, mb_err |
| DN03 | CHUNG-02 | Xác thực hai bước (nhập mã) | pc_code, pc_code_err, pc_backup, pc_backup_err, mb_code, mb_code_err, mb_backup, mb_backup_err |
| DN04 | CHUNG-03 | Thiết lập 2FA lần đầu (3 bước) | pc_s1, pc_s2, pc_s3, mb_s1, mb_s2, mb_s3 |
| DN05 | CHUNG-04 | Quên mật khẩu | pc_form, pc_sent, mb_form, mb_sent |
| DN06 | CHUNG-05 | Đặt mật khẩu mới (link từ email) | pc_new, pc_ok, mb_new, mb_ok |
| DN07 | CHUNG-07 | Đổi mật khẩu lần đầu | pc_new, pc_ok, mb_new, mb_ok |
| DN08 | CHUNG-08 | Tài khoản bị khoá (tạm 15 phút / khoá hẳn) | pc_temp, pc_perm, mb_temp, mb_perm |
| DN09 | CHUNG-09 | Hộp thoại hết phiên đăng nhập | pc_end, mb_end |
| DN10 | CHUNG-25 | Chọn cổng (CRM / Giáo viên) | pc_ok, mb_ok |

Tên file đầy đủ = `<DNxx>_<biến thể>`, ví dụ `DN03_pc_code_err.dc.html` và `png/DN03_pc_code_err.png`.

### P2 · Cấu hình & phân quyền (2 artboard, máy tính)

| Artboard | Mã màn | Nội dung | PNG |
|---|---|---|---|
| CauHinh | QT-07 / QT-09 | Cấu hình: Danh mục, Tham số nghiệp vụ, Công tắc tính năng | `png/CauHinh.png` |
| MaTranQuyen | QT-05 | Ma trận quyền theo vai trò | `png/MaTranQuyen.png` |

## 2. Khuôn dùng cho màn nào

| Khuôn | Dùng cho | Ghi chú |
|---|---|---|
| Vỏ CRM (thanh trái + thanh trên) | K1, K2, K3, K5, K07b, K07c, K09b, CauHinh, MaTranQuyen | Thanh trái: Tổng quan, Tuyển sinh, Khách hàng, Bán hàng & thu chi, Đào tạo, Chăm sóc KH, Báo cáo, Cấu hình, Quản trị |
| K1 List / K2 Kanban | Mọi danh sách và bảng Kanban cùng nhóm | Mẫu là “Cơ hội” |
| K3 Chi tiết bản ghi | Mọi chi tiết có giai đoạn | Mẫu là CO000121 |
| K4 Hộp thoại 5 biến thể | Huỷ/từ chối có lý do, Assign, chặn, cảnh báo | Biến thể ①②③③b④⑤ |
| K4b Nhiều bước | Nhập từ file và quy trình tương tự | 3 bước |
| K4c Xem trước tác động | Đổi giáo viên, đổi lịch hàng loạt | Cảnh báo, không chặn |
| K4d Chọn từ danh sách có kiểm tra | Chọn lớp cho dòng đơn | Tối đa 2 lý do, rồi “+N lý do” |
| K4e Bottom sheet | Duyệt/từ chối trên điện thoại | 390×844 |
| K5 Calendar | Lịch hẹn tuần | |
| K07b Ngăn kéo biểu mẫu | Tạo nhanh bản ghi | Nút: Huỷ, Lưu |
| K07c Hộp thoại cảnh báo trùng | Trùng SĐT khi tạo | Nút: Vẫn tạo mới, Gắn vào hồ sơ có sẵn; đóng bằng X |
| K09b Trang chủ theo vai trò | CHUNG-14 | Năm vai trò |
| K0x Trạng thái chung | Tải, rỗng, thông báo lỗi/cảnh báo | |
| Khuôn đăng nhập (thẻ giữa trang, logo, tiêu đề, 1 nút chính) | DN01–DN10 | Máy tính: thẻ giữa nền; điện thoại: toàn màn |
| Khuôn ngăn kéo/bảng cấu hình | CauHinh, MaTranQuyen | |

Mỗi artboard P1 đi theo khuôn đăng nhập; DN04 và DN10 có phần bố cục riêng (3 bước; hai thẻ cổng).

## 3. Chữ trên nút và thông báo của từng màn

Danh sách được trích tự động từ các artboard. Đã bỏ nhãn thanh điều hướng chung (Tổng quan … Quản trị). Chữ dạng “lấy từ dữ liệu” là nhãn do dữ liệu quyết định (giai đoạn, tab…), không cố định.

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
- `DN03_pc_code` — Máy tính · Mã từ ứng dụng
  - **Nút:** “Xác nhận”
- `DN03_pc_code_err` — Máy tính · Mã từ ứng dụng · Sai mã
  - **Nút:** “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “Mã không đúng. Kiểm tra lại mã đang hiện trong ứng dụng rồi nhập lại.”
- `DN03_pc_backup` — Máy tính · Mã dự phòng
  - **Nút:** “Xác nhận”
- `DN03_pc_backup_err` — Máy tính · Mã dự phòng · Sai hoặc đã dùng
  - **Nút:** “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “Mã dự phòng không đúng hoặc đã được dùng. Mỗi mã chỉ dùng một lần.”
- `DN03_mb_code` — Điện thoại · Mã từ ứng dụng
  - **Nút:** “Xác nhận”
- `DN03_mb_code_err` — Điện thoại · Mã từ ứng dụng · Sai mã
  - **Nút:** “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “Mã không đúng. Kiểm tra lại mã đang hiện trong ứng dụng rồi nhập lại.”
- `DN03_mb_backup` — Điện thoại · Mã dự phòng
  - **Nút:** “Xác nhận”
- `DN03_mb_backup_err` — Điện thoại · Mã dự phòng · Sai hoặc đã dùng
  - **Nút:** “Xác nhận”
  - **Thông báo / chữ cảnh báo:**
    - “Mã dự phòng không đúng hoặc đã được dùng. Mỗi mã chỉ dùng một lần.”
#### DN04 · CHUNG-03 — Thiết lập 2FA lần đầu (3 bước)
- `DN04_pc_s1` — Máy tính · Bước 1
  - **Nút:** “Tiếp”
- `DN04_pc_s2` — Máy tính · Bước 2
  - **Nút:** “Quay lại” · “Xác nhận”
- `DN04_pc_s3` — Máy tính · Bước 3
  - **Nút:** “Tải xuống” · “Sao chép” · “Hoàn tất”
- `DN04_mb_s1` — Điện thoại · Bước 1
  - **Nút:** “Tiếp”
- `DN04_mb_s2` — Điện thoại · Bước 2
  - **Nút:** “Quay lại” · “Xác nhận”
- `DN04_mb_s3` — Điện thoại · Bước 3
  - **Nút:** “Tải xuống” · “Sao chép” · “Hoàn tất”
#### DN05 · CHUNG-04 — Quên mật khẩu
- `DN05_pc_form` — Máy tính · Nhập email
  - **Nút:** “Gửi link đặt lại”
- `DN05_pc_sent` — Máy tính · Đã gửi
  - **Nút:** “Gửi lại” · “Mở link trong email (minh hoạ)”
  - **Thông báo / chữ cảnh báo:**
    - “Nếu email này có trong hệ thống, link đặt lại mật khẩu đã được gửi. Kiểm tra hộp thư, cả mục Spam.”
- `DN05_mb_form` — Điện thoại · Nhập email
  - **Nút:** “Gửi link đặt lại”
- `DN05_mb_sent` — Điện thoại · Đã gửi
  - **Nút:** “Gửi lại” · “Mở link trong email (minh hoạ)”
  - **Thông báo / chữ cảnh báo:**
    - “Nếu email này có trong hệ thống, link đặt lại mật khẩu đã được gửi. Kiểm tra hộp thư, cả mục Spam.”
#### DN06 · CHUNG-05 — Đặt mật khẩu mới (link từ email)
- `DN06_pc_new` — Máy tính · Mới mở, chưa nhập
  - **Nút:** “Lưu mật khẩu”
- `DN06_pc_ok` — Máy tính · Đủ điều kiện
  - **Nút:** “Lưu mật khẩu”
- `DN06_mb_new` — Điện thoại · Mới mở, chưa nhập
  - **Nút:** “Lưu mật khẩu”
- `DN06_mb_ok` — Điện thoại · Đủ điều kiện
  - **Nút:** “Lưu mật khẩu”
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
#### DN08 · CHUNG-08 — Tài khoản bị khoá (tạm 15 phút / khoá hẳn)
- `DN08_pc_temp` — Máy tính · Tạm khoá 15 phút
  - **Nút:** “Quên mật khẩu?” · “Quay lại đăng nhập”
- `DN08_pc_perm` — Máy tính · Khoá hẳn
  - **Nút:** “Quay lại đăng nhập”
- `DN08_mb_temp` — Điện thoại · Tạm khoá 15 phút
  - **Nút:** “Quên mật khẩu?” · “Quay lại đăng nhập”
- `DN08_mb_perm` — Điện thoại · Khoá hẳn
  - **Nút:** “Quay lại đăng nhập”
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
  - Khuôn K5-biến thể trang Cấu hình (vỏ CRM + cột trái nhóm danh mục + bảng)
  - **Nút:** “Lịch sử thay đổi” · “Danh mục” · “Tham số nghiệp vụ” · “Công tắc tính năng” · “Giai đoạn cơ hội Khoá 8” · “Nguồn lead 7” · “Môn học 10” · “Phân loại lớp Khoá 3” · “Trình độ Khoá 4” · “Hình thức học Khoá 2” · “Loại gói 6” · “Loại hoạt động 5” · “Hình thức test 2” · “Cấp độ đề test 2” · “Lý do từ chối 5” · “Lý do huỷ buổi 8” · “Lý do không tái tục 7” · “Hình thức thu tiền 3” · “Mức độ khiếu nại 4” · “Kênh tiếp nhận ticket 6” · “Source” · “Sub-source” · “Ngừng” · “Thêm” · “Huỷ” · “Lưu” · (một số nhãn lấy từ dữ liệu: giai đoạn, sub-stage, tab…)
- **MaTranQuyen** (QT-05) — Ma trận quyền theo vai trò
  - Khuôn trang Ma trận quyền (vỏ CRM + bảng ô quyền)
  - **Nút:** “Lịch sử thay đổi quyền” · “Cơ sở” · “Của tôi” · “Không có” · “Tất cả” · “Huỷ” · “Lưu thay đổi” · “Sửa”

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
- **Cơ hội quá hạn chăm**: cơ hội có lịch hẹn kế tiếp đã quá hạn, chưa hoàn thành.
- **Mã ticket**: `DN-<CS>-<YYMM>-<STT>` (đề nghị) và `KN-…` (khiếu nại), ví dụ DN-CS1-2610-0007.
- **Source / Sub-source** là hai ô riêng; “Loại” tự hiện dưới Source. **Chiến dịch** là ô độc lập, có “+ Tạo chiến dịch mới”.
- **Nhập lead từ file**: bỏ qua dòng trùng SĐT; tổng kết “Đã nhập 112 · Bỏ qua 9 trùng SĐT · 7 dòng lỗi”; dòng trùng hiện mã sẵn có (“Trùng với LD000231”).
- **Đổi giáo viên**: trùng lịch chỉ cảnh báo, vẫn bấm Xác nhận được.
- **Chọn lớp (K4d)**: mỗi dòng hiện tối đa 2 lý do không chọn được, còn lại gộp “+N lý do”; lớp trùng giờ với lớp em đang học thì mờ đi.
- **Trang chủ theo vai trò (K09b)**: nút “Mở danh sách” dẫn tới đích theo bảng của anh; quyền xem từng khối chờ QT-05.

## 5. Những chỗ còn chưa chắc
1. **P1 còn thiếu (Đợt 3)**: chưa vẽ màn không có quyền, module chưa bật, 404, lỗi hệ thống, và khung cổng KC.
2. **Chữ lỗi OTP** (DN03: “Sai mã”, “Sai hoặc đã dùng”, hết hạn mã) chưa được duyệt từng câu.
3. **Mã mẫu tự đặt**: mã đơn hàng, ticket, phiếu thu/PKT/PT trong dữ liệu mẫu em tự đặt theo định dạng trong file ngữ cảnh; chưa có bảng mã thật.
4. **Quyền từng khối của K09b** chưa khớp Ma trận quyền (QT-05); đây mới là bản tạm theo bảng vai trò.
5. **Ngưỡng 25%** cho “sắp quá hạn” chưa phải luật chính thức.
6. **“Cơ hội quá hạn chăm”** đã định nghĩa theo lịch hẹn kế tiếp quá hạn chưa hoàn thành; em chưa đối chiếu với các bộ lọc ở màn khác.
7. **Hộp cảnh báo trùng SĐT** ở TS-03 đã thống nhất theo K07c (bỏ nút “Huỷ”, đóng bằng X). TS-03 thuộc P3 nên không nằm trong gói; K07b/K07c là bản chuẩn.
8. **Source 3 cấp** trong danh mục chỉ hiện 2 ô (Source, Sub-source); “Loại” hiện như chữ phụ. Chưa rõ có cần ô thứ ba không.
9. **Tiêu đề trong file** CauHinh.dc.html ghi “K5 · Cấu hình” và MaTranQuyen.dc.html ghi “Đ1 · Ma trận quyền”: tên cũ, mã đúng là QT-07/QT-09 và QT-05.
10. **K1, K2, K3, K5, K4*, K0x** chưa có mã màn trong brief nên cột “Mã màn” để “—”; gọi theo tên artboard.
11. Ảnh PNG dùng phông thay thế (xem mục 0); các màn có tương tác (chọn vai trò K09b, các bước K4b, mở hộp thoại) chỉ chụp ở trạng thái mở đầu. Muốn xem các trạng thái khác thì mở file `.dc.html`.
