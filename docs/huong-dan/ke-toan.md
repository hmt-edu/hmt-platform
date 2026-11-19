# Hướng dẫn cho Kế toán (cổng CRM)

Vai: Kế toán. Menu: **Bán hàng và thu chi** (Phiếu thu, Khoản tiền vào, Công nợ, Phiếu chi, Số dư khách hàng, Chờ kế toán duyệt). Kế toán cần thiết lập **hai bước** khi đăng nhập lần đầu. Xem `README.md` về cách đọc.

**Nguyên tắc tiền:** Admin **không** duyệt tiền; chỉ vai Kế toán duyệt bước kế toán. Hai bước duyệt phải là **hai người khác nhau**. Không có nút xoá: sai thì huỷ (phiếu chưa duyệt) hoặc đảo khoản (đã duyệt).

## 1. Duyệt phiếu thu (bước kế toán)
- **Mục đích:** xác nhận khoản thu đã vào tài khoản, sinh khoản tiền vào và ghi danh.
- **Ai làm:** Kế toán (sau khi Trưởng cơ sở duyệt bước quản lý).
- **Các bước:**
  1. **Phiếu thu** (`/crm/phieu-thu`): lọc «Chờ kế toán duyệt», hoặc vào mục **Chờ kế toán duyệt** (`/crm/cho-ke-toan-duyet`).
  2. Mở phiếu. Đối chiếu «Số tiền», «Hình thức», «Ngày nhận», «Mã giao dịch», «Người nhận tiền», «Cơ sở thu tiền», ảnh chứng từ; xem «Chia về các dòng đơn».
  3. Khớp với sao kê thì bấm **«Duyệt phiếu thu»**. Không khớp thì **«Từ chối phiếu thu»**, ghi lý do (phiếu về Nháp).
- **Kết quả mong đợi:** phiếu «Đã duyệt»; hệ thống tự sinh **khoản tiền vào** (mục 2) và các ghi danh cho đơn đủ điều kiện.
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_KHONG_CO_QUYEN` | tài khoản không phải Kế toán, hoặc chưa qua bước hai bước |
| `HMT_CHI_KE_TOAN_DUYET_TIEN` | chỉ vai Kế toán có quyền Kế toán · Duyệt (Admin và vai khác không duyệt tiền) |
| Người duyệt bước quản lý trùng người duyệt kế toán | hệ thống chặn; để người khác duyệt |

- **Ảnh:** [ẢNH: phieu-thu-cho-ke-toan], [ẢNH: phieu-thu-duyet], [ẢNH: phieu-thu-tu-choi]

## 2. Khoản tiền vào và đảo khoản
- **Mục đích:** sổ thu tiền, chỉ đọc; sửa sai bằng đảo khoản.
- **Ai làm:** Kế toán (đảo khoản chỉ Kế toán), Trưởng cơ sở và Admin xem.
- **Các bước:** 1) **Khoản tiền vào** (`/crm/khoan-tien-vao`): các cột «Cơ sở», «Phiếu thu», «Đơn hàng», «Phụ huynh», «Số tiền (đ)», «Ngày», «Loại» (Khoản thu, Khoản đảo âm). 2) Khoản sai: bấm **«Hoàn tác»** ở dòng đó; hộp «Hoàn tác khoản tiền» xác nhận. 3) Hệ thống tạo **khoản đảo (âm)** trỏ về khoản gốc; khoản gốc hiện «Đã hoàn tác».
- **Kết quả mong đợi:** thông báo «Đã hoàn tác khoản tiền.»; số liệu thu và quỹ giờ điều chỉnh theo.
- **Lỗi thường gặp:** khoản đã hoàn tác không còn nút; thiếu quyền thì không thấy nút. **Ảnh:** [ẢNH: khoan-tien-vao-ds], [ẢNH: khoan-tien-hoan-tac]

## 3. Công nợ
- **Mục đích:** biết đơn nào còn phải thu, đến hạn hay quá hạn.
- **Ai làm:** Kế toán, Trưởng cơ sở, Sale, CSKH (theo phạm vi).
- **Các bước:** **Công nợ** (`/crm/cong-no`): các cột «Phụ huynh», «Đơn hàng», «Sale», «Đợt», «Hạn đóng», «Phải đóng (đ)», «Đã đóng (đ)», «Còn nợ (đ)», «Tình trạng»; lọc sắp đến hạn, quá hạn; bấm dòng để mở đơn.
- **Kết quả mong đợi:** chỉ đợt còn phải thu; đợt đã đóng đủ không hiện. Lịch đóng theo điều khoản của đơn.
- **Lỗi thường gặp:** «Không có công nợ nào» là bình thường khi đã thu đủ. **Ảnh:** [ẢNH: cong-no]

## 4. Thu nợ đầu kỳ
- **Mục đích:** thu khoản phụ huynh còn nợ từ trước, không có đơn.
- **Ai làm:** Kế toán duyệt; người lập có quyền lập phiếu thu.
- **Các bước:** 1) **Phiếu thu** → «Thu nợ đầu kỳ». 2) Chọn «Phụ huynh», nhập «Số tiền» và «Hình thức»; «Tạo phiếu nháp». 3) Trình rồi Kế toán duyệt như mục 1.
- **Kết quả mong đợi:** nợ đầu kỳ của phụ huynh giảm đúng số đã duyệt.
- **Lỗi thường gặp:** `HMT_TINH_NANG_TAT` («Thu nợ đầu kỳ chưa được bật cho cơ sở này») → báo Trưởng cơ sở/Admin bật phân hệ. **Ảnh:** [ẢNH: thu-no-dau-ky]

## 5. Phiếu chi hoàn học phí
- **Mục đích:** chi trả tiền hoàn cho phụ huynh sau khi yêu cầu hoàn phí được duyệt đủ hai cấp.
- **Ai làm:** Kế toán (duyệt cấp kế toán ở phiếu hoàn học phí, rồi ghi nhận chi).
- **Các bước:**
  1. Phiếu **Hoàn học phí** (mục Phiếu nghiệp vụ, cấp 2 là Kế toán): mở phiếu, kiểm số liệu, **«Duyệt»**.
  2. Người tạo phiếu bấm **«Thực hiện»**: hệ thống tính hoàn, trừ giờ, và tạo **phiếu chi** (mã `PC-…`) ở «Chờ chi».
  3. **Phiếu chi** (`/crm/phieu-chi`): mở phiếu; xem «Phụ huynh đã đóng cho ghi danh», «Số tiền hoàn trước phí», «Số tiền hoàn», «Ticket hoàn tiền». Sau khi chuyển tiền thật, ghi «Ghi chú chi» rồi **«Ghi nhận đã chi»**. Có bản in «Hoàn học phí cho phụ huynh».
- **Kết quả mong đợi:** phiếu chi sang «Đã chi»; hồ sơ phụ huynh thấy khoản hoàn.
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_HOAN_PHI_DANG_MO` | ghi danh đã có yêu cầu hoàn phí chưa xong: xử lý yêu cầu đó trước |
| `HMT_HOAN_PHI_GIO_SAI` | giờ hoàn phải lớn hơn 0 và không quá giờ còn lại (không tính giờ tặng) |
| `HMT_PHIEU_MOT_NGUOI_HAI_CAP` | một người không duyệt hai cấp của cùng một phiếu |

- **Ảnh:** [ẢNH: phieu-chi-ban-ghi], [ẢNH: phieu-chi-in], [ẢNH: hoan-hoc-phi-duyet]

## 6. Số dư khách hàng
- **Mục đích:** theo dõi tiền phụ huynh còn dư (ví dụ sau dừng học giữ số dư).
- **Ai làm:** Kế toán, Trưởng cơ sở.
- **Các bước:** **Số dư khách hàng** (`/crm/so-du-khach-hang`): các cột «Mã phụ huynh», «Số dư (đ)», «Phát sinh gần nhất», «Số dòng sổ»; bấm dòng để xem lịch sử số dư. Số dư dùng để cấn vào đơn khi lập phiếu cho đơn mới.
- **Kết quả mong đợi:** mọi biến động số dư có dòng sổ, chỉ thêm, không sửa.
- **Lỗi thường gặp:** «Chưa có số dư khách hàng nào» là bình thường lúc chưa có dừng học hoặc thu dư. **Ảnh:** [ẢNH: so-du-ds], [ẢNH: so-du-lich-su]
