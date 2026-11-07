# Khung canvas còn thiếu cho các màn trong kế hoạch (05/11/2026)

Mục đích: anh giao Design vẽ song song. Quy ước mới (anh chốt 05/11): màn nào thiếu khung thì Code báo ngay, **không tự dựng rồi mới báo**. Riêng T5 (màn Nhập) Code vẫn dựng theo khuôn có sẵn để kịp 10/11, chỉnh lại khi có khung.
Nguồn kiểm: canvas `design/hmt-canvas-9933` (HMT Platform v146, 485 khung), `design/ban-hang-thu-chi-bo-sung` (bổ sung v6, thay bản v2 `hmt-canvas-8262` đã xoá), gói `design/hmt-p0-p2` (khuôn P0, P2 CauHinh, MaTranQuyen). Trường "theo hàm DB" lấy từ hàm trong `supabase/migrations/`.
Mốc "cần trước" tính theo kế hoạch dựng sau 17/11, xong trước 28/11, thứ tự: Người dùng, Danh mục, Bảng giá, Gói bán, Cơ sở và phòng; mỗi khung cần có **trước ngày bắt đầu dựng màn đó khoảng 2 ngày**.

## Tóm tắt

| # | Màn | Khung đã có | Khung thiếu | Cần trước |
|---|---|---|---|---|
| 1 | T5 Nhập dữ liệu (QT-18, mã màn mới) | `K4b` (hộp nhiều bước), `TS04` (nhập lead: tải file, ghép cột, xem trước), `K4g` (mật khẩu tạm một lần) | 5 khung (mục 1) | 13/11 (Code đã dựng bản tối giản cho 10/11, chỉnh lại sau) |
| 2 | Nút Đặt lại mật khẩu (QT-02) | `K4g`, `K4e4` (hộp mật khẩu tạm, điện thoại) | 2 khung nhỏ (mục 2) | Không chặn: Code dựng bằng hộp xác nhận có sẵn + `K4g` cho 10/11 |
| 3 | Form Tạo người dùng (QT-03) | `K07b` (biểu mẫu ngăn kéo, Tạo nhanh lead), `K4g` | Form Tạo, form Sửa email (mục 3) | 15/11 |
| 4 | Danh mục (QT-06, QT-07) | `CauHinh` (P2, tab Danh mục, danh sách các danh mục và mục) | 4 khung (mục 4) | 17/11 |
| 5 | Bảng giá (CH-03) | `CH03_chinh`, `CH03_loi` | Gần đủ; 1 khung nhỏ (mục 5) | 19/11 |
| 6 | Gói bán (CH-01) | Không có | Danh sách + form + Ngừng (mục 6) | 20/11 |
| 7 | Cơ sở và phòng học (QT-08) | Không có | Danh sách + form phòng (mục 7) | 22/11 |
| 8 | Chiết khấu (CH-04) | `CH04_chinh` (hai tab Chiết khấu, Quà tặng, có form), `CH04_loi` | Đủ cho màn hiện tại (mục 8); bản chip, ưu đãi linh hoạt, voucher ở bảng nhóm B | Làm SQL trước, màn nếu còn thời gian 27/11 |
| 9 | Điều khoản thanh toán (CH-09) | `CH09_chinh` (danh sách, các đợt, Thêm điều khoản, Ngừng), `CH09_loi` | Đủ (mục 9) | Như trên |

## 1. T5 Nhập dữ liệu (QT-18)
- **Đã có:** K4b (khuôn hộp nhiều bước), TS04 (Nhập lead: tải file, ghép cột, xem trước, dòng lỗi), K4g.
- **Thiếu (5):**
  1. Trang "Nhập dữ liệu": chọn loại nạp (Người dùng, Phụ huynh, Học sinh, Cơ hội, Phiếu test, sau này Lớp, Ghi danh, Số dư), mỗi loại có mô tả và nút Nhập.
  2. Bước Tải file cho loại có **tên cột cố định** (không ghép cột): hiện danh sách cột nhận, cột bắt buộc, báo cột thiếu, cột lạ bị bỏ qua.
  3. Bước Xem trước theo loại: ô đếm Hợp lệ, Trùng, Lỗi (bấm để lọc), bảng từng dòng (số dòng, chữ cái đầu tên, kết quả, câu giải thích, cảnh báo), phân trang.
  4. Hộp kết quả sau khi nạp: số nạp, trùng, lỗi, nút **Tải dòng lỗi và trùng**.
  5. Hộp mật khẩu tạm **hàng loạt** (Người dùng): K4g chỉ có một mật khẩu; cần bản "tải file mật khẩu tạm, hiện một lần, chưa tải chưa đóng được".
- **Trường theo hàm DB:** loại nạp; file CSV (cột theo file mẫu `HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx`: Người dùng `username, ho_ten, ma_nv, vai_tro, co_so_truy_cap, trang_thai, email, quan_ly`; Phụ huynh `ma_cu, ho_ten, sdt, sdt_2, ho_ten_2, dia_chi, co_so`; Học sinh `ma_cu, ho_ten, ngay_sinh, gioi_tinh, sdt_ph, truong, loai_truong, khoi, ghi_chu, co_so`); kết quả mỗi dòng: `row, initial, status (HOP_LE/TRUNG/LOI), message, warnings`; tổng `total, imported, duplicates, errors`; Người dùng: `passwords [{username, password}]`.
- **Cần trước:** 13/11.

## 2. Nút Đặt lại mật khẩu (QT-02, Hành động)
- **Đã có:** K4g (hộp mật khẩu tạm hiện một lần), K4e4 (điện thoại).
- **Thiếu (2 khung nhỏ):** mục "Đặt lại mật khẩu" trong menu Hành động của bản ghi người dùng (QT-02); hộp xác nhận ("Đặt lại mật khẩu của …? Mật khẩu cũ hết hiệu lực, mọi phiên đăng nhập bị thu hồi") rồi mở K4g.
- **Trường theo hàm DB:** Edge Function `admin-users`, thao tác `reset_password`: `userId`; kết quả mật khẩu tạm.
- **Cần trước:** không chặn (Code dựng bằng khuôn xác nhận có sẵn + K4g).

## 3. Form Tạo người dùng (QT-03) và Sửa email
- **Đã có:** K07b (biểu mẫu ngăn kéo), K4g (mật khẩu tạm sau khi tạo).
- **Thiếu:** (1) form Tạo người dùng (QT-03, khuôn K07); (2) hộp Sửa email (nhập email mới, xác nhận, báo trùng).
- **Trường theo hàm DB (`app.admin_create_account`):** họ tên (`display_name`), email đăng nhập (`login_name`), cơ sở (`branch_code`, một cơ sở), vai trò (`roles`, nhiều), mã NV/GV/TG (`staff_code`, để trống thì hệ thống cấp), loại nhân sự (`staff_kind`: nhân viên, giáo viên, trợ giảng), quản lý trực tiếp (gắn sau tạo). Kết quả: mật khẩu tạm hiện một lần ở K4g. Đăng nhập bằng tên đăng nhập (viết tắt có đánh số): làm sau 10/11, form sẽ có thêm trường **tên đăng nhập** (hệ thống gợi ý theo họ tên, sửa được trước khi tạo).
- **Cần trước:** 15/11.

## 4. Danh mục (QT-06 danh sách các danh mục, QT-07 sửa các mục)
- **Đã có:** `CauHinh` (P2): tab Danh mục, danh sách danh mục bên trái (Giai đoạn cơ hội, Nguồn lead, Môn học …), các mục bên phải.
- **Thiếu (4):** (1) form Thêm mục (một ngăn kéo hoặc hộp); (2) Đổi tên mục (sửa tại dòng); (3) hộp xác nhận Ngừng và Dùng lại; (4) danh mục nhiều cấp (mục cha: giai đoạn → nhóm con; nguồn 3 cấp Source type → Source → Sub-source) và mục liên kết (lý do huỷ nối sang nhóm con).
- **Trường theo hàm DB (`catalog_add_item`, `catalog_rename_item`, `catalog_reorder_item`, `catalog_set_item_active`):** mã (chữ hoa, không đổi), tên, thứ tự, mục cha, mục liên kết, trạng thái Đang dùng/Ngừng. Danh mục hệ thống (khoá) không thêm, không Ngừng.
- **Cần trước:** 17/11.

## 5. Bảng giá (CH-03)
- **Đã có:** `CH03_chinh` (danh sách bản và giá; nút Thêm bảng giá mới, So sánh với bản trước; ô Hiệu lực từ, Sao chép từ bản trước; cột Loại gói, Môn · Khối, Giá offline, Giá online), `CH03_loi`.
- **Thiếu (1):** ô giá **để trống** (chưa có giá, ví dụ 2 sản phẩm chưa có giá online) và dòng "Chưa cấu hình".
- **Trường theo hàm DB (`add_package_price`):** gói, hình thức (offline, online), đơn giá (đồng, để trống = ngừng bán hình thức đó), ngày hiệu lực.
- **Cần trước:** 19/11.

## 6. Gói bán (CH-01)
- **Đã có:** không có khung nào.
- **Thiếu:** danh sách gói (cột mã, tên, loại gói, môn, khối, trạng thái; lọc), form Tạo gói và Sửa tên, xác nhận Ngừng. Khuôn gần nhất: K10 (danh sách cấu hình).
- **Trường theo hàm DB (`save_sales_package`):** mã (cấp theo chuẩn, không đổi), tên, loại gói, môn, khối từ, khối đến, mã cũ (`legacy_ref`). Sửa chỉ đổi tên, mã cũ. Chưa có cột số giờ (anh chốt 05/11).
- **Cần trước:** 20/11.

## 7. Cơ sở và phòng học (QT-08)
- **Đã có:** không có khung nào.
- **Thiếu:** danh sách cơ sở (mỗi cơ sở mở ra danh sách phòng), form Thêm phòng và Sửa phòng, xác nhận Ngừng phòng. Khuôn gần nhất: K10. Cơ sở là danh mục khoá (anh chốt 12/10): không thêm, không Ngừng trên màn; có thể sửa tên hiển thị và địa chỉ (chờ anh xác nhận).
- **Trường theo DB (bảng `app.room`; hàm thêm, sửa phòng **chưa có**, Code viết mới):** cơ sở (cố định), mã phòng (không đổi), tên, sức chứa, thứ tự, trạng thái.
- **Cần trước:** 22/11.

## 8. Chiết khấu (CH-04)
- **Đã có:** `CH04_chinh` (hai tab Chiết khấu, Quà tặng; form: Tên chính sách, Kiểu %/Giờ tặng/Số tiền cố định, Giá trị, Mức tối đa, Hiệu lực từ–đến, Cơ sở, Cần duyệt, Nhóm gói), `CH04_loi`.
- **Thiếu cho màn hiện tại:** không. Phần chip, ưu đãi linh hoạt, voucher (gói canvas v146) nằm trong bảng nhóm B, chưa vào luật.
- **Trường theo hàm DB (`save_discount_policy`):** mã, tên, kiểu, mức tối đa, giá trị cố định, cần duyệt, hiệu lực từ, đến, nhóm gói, cơ sở.

## 9. Điều khoản thanh toán (CH-09)
- **Đã có:** `CH09_chinh`, `CH09_loi`.
- **Thiếu:** không.
- **Trường theo hàm DB (`create_payment_term`):** mã, tên, hiệu lực từ, các đợt (số thứ tự, % hoặc số tiền cố định, số ngày đến hạn).
