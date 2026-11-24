# Vai: Kế toán (cổng CRM)

Vai: **Kế toán**. Nếu bạn mới, đọc trước [Giới thiệu hệ thống](/crm/huong-dan/bat-dau). Chữ trong dấu «…» là chữ hiện trên màn.

Menu của bạn: **Trang chủ**, **Việc chờ tôi duyệt**, **Bán hàng và thu chi** (Đơn hàng, Phiếu thu, Khoản tiền vào, Công nợ, Phiếu chi, Số dư khách hàng, Chờ kế toán duyệt). Chỉ hiện mục bạn có quyền. 

**Nguyên tắc tiền (nhớ kỹ):**

- Chỉ vai **Kế toán** duyệt bước kế toán của phiếu tiền. **Admin KHÔNG duyệt tiền.**
- Hai bước duyệt của một phiếu phải do **hai người khác nhau**. Người tạo không tự duyệt phiếu của mình.
- Không có nút xoá. Sai thì **huỷ** (phiếu chưa duyệt) hoặc **hoàn tác khoản tiền** (đã duyệt, tạo khoản đảo âm).
- Kế toán chỉ duyệt phiếu nghiệp vụ ở **cấp Kế toán**. Phiếu ở cấp «Quản lý cơ sở» (Cập nhật hồ sơ, Bảo lưu…) là việc của Trưởng cơ sở hoặc Admin: bạn không thấy nút «Duyệt» ở đó và phiếu đó không nằm trong «Việc chờ tôi duyệt» của bạn.

## Việc hằng ngày của bạn (gợi ý thứ tự)

1. Mở **Trang chủ**: xem khối «Việc chờ tôi duyệt» và «Công nợ quá hạn».
2. Mở **Chờ kế toán duyệt**: duyệt hoặc từ chối từng phiếu thu đã qua bước quản lý.
3. Mở **Phiếu chi**: ghi nhận các khoản hoàn đã chuyển tiền.
4. Cuối ngày xem **Công nợ** và đối chiếu **Khoản tiền vào** với sao kê.

## 1. Xem việc chờ duyệt ở Trang chủ và «Việc chờ tôi duyệt»

**Mục tiêu:** biết ngay hôm nay có phiếu nào đang chờ riêng bạn.

1. Vào **Trang chủ**: khối «Việc chờ tôi duyệt» liệt kê các việc đến lượt bạn; khối «Công nợ quá hạn» liệt kê phụ huynh nợ quá hạn. Khối nào bạn không có quyền thì không hiện.
2. Bấm «Việc chờ tôi duyệt» ở menu để xem đủ danh sách: các cột «Loại việc», «Mã», «Học sinh / Phụ huynh», «Mã đối tượng», «Nội dung», «Cấp», «Vai trò duyệt», «Người tạo», «Thời gian chờ». Lọc theo «Loại việc» (Đơn hàng, Phiếu thu, Hoàn phí…).
3. Bấm một dòng để mở bản ghi; «Duyệt» và «Từ chối» nằm trong màn của từng loại (không duyệt hàng loạt).

- **Kết quả:** chỉ thấy việc đã đến lượt vai Kế toán (cấp Kế toán).
- **Lỗi thường gặp:** danh sách trống là bình thường khi không còn việc chờ.
- **Ảnh:** [ẢNH: ke-toan-trang-chu], [ẢNH: ke-toan-viec-cho-toi-duyet]

## 2. Đơn hàng và phiếu thu: xem để đối chiếu

**Mục tiêu:** hiểu một khoản thu đi từ đơn hàng tới phiếu thu.

1. **Đơn hàng:** Sale lập đơn, Trưởng cơ sở duyệt, đơn «Đã duyệt» thì Sale lập phiếu thu. Mở đơn để xem «Dòng đơn», điều khoản thanh toán và các đợt.
2. **Phiếu thu:** Sale trình, Trưởng cơ sở duyệt bước quản lý, rồi đến bạn duyệt bước kế toán (mục 3).

- **Kết quả:** bạn nắm đơn nào đã có phiếu thu, đã thu bao nhiêu, còn bao nhiêu.
- **Lỗi thường gặp:** đơn chưa «Đã duyệt» thì chưa lập được phiếu thu.
- **Ảnh:** [ẢNH: ke-toan-don-hang], [ẢNH: ke-toan-phieu-thu-ds]

## 3. Duyệt phiếu thu (bước kế toán)

**Mục tiêu:** xác nhận khoản thu đã vào tài khoản; hệ thống tự sinh khoản tiền vào và ghi danh.

1. Vào **Chờ kế toán duyệt** (hoặc **Phiếu thu**, lọc «Chờ kế toán duyệt»).
2. Mở phiếu. Đối chiếu «Số tiền», «Hình thức», «Ngày nhận», «Mã giao dịch», «Người nhận tiền», «Cơ sở thu tiền», ảnh chứng từ; xem «Chia về các dòng đơn».
3. Khớp sao kê thì bấm **«Duyệt phiếu thu»**.
4. Không khớp thì bấm **«Từ chối phiếu thu»**, ghi lý do; phiếu về Nháp.

- **Kết quả:** phiếu «Đã duyệt»; sinh **khoản tiền vào** và các ghi danh cho đơn đủ điều kiện.
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_KHONG_CO_QUYEN` | tài khoản không phải Kế toán |
| `HMT_CHI_KE_TOAN_DUYET_TIEN` | chỉ vai Kế toán duyệt tiền (Admin và vai khác không duyệt) |
| Người duyệt quản lý trùng người duyệt kế toán | hệ thống chặn; nhờ người khác duyệt |

- **Ảnh:** [ẢNH: phieu-thu-cho-ke-toan], [ẢNH: phieu-thu-duyet], [ẢNH: phieu-thu-tu-choi]

## 4. Khoản tiền vào và hoàn tác khoản

**Mục tiêu:** sổ thu tiền chỉ đọc; sửa sai bằng khoản đảo, không xoá.

1. Vào **Khoản tiền vào**: các cột «Cơ sở», «Phiếu thu», «Đơn hàng», «Phụ huynh», «Số tiền (đ)», «Ngày», «Loại» (Khoản thu, Khoản đảo âm).
2. Khoản sai: bấm **«Hoàn tác»** ở dòng đó; hộp «Hoàn tác khoản tiền» xác nhận.
3. Hệ thống tạo khoản đảo (âm) trỏ về khoản gốc; khoản gốc hiện «Đã hoàn tác».

- **Kết quả:** thông báo «Đã hoàn tác khoản tiền.»; số liệu thu và quỹ giờ điều chỉnh theo.
- **Lỗi thường gặp:** khoản đã hoàn tác không còn nút; thiếu quyền thì không thấy nút.
- **Ảnh:** [ẢNH: khoan-tien-vao-ds], [ẢNH: khoan-tien-hoan-tac]

## 5. Công nợ và thu nợ đầu kỳ

**Mục tiêu:** biết đơn nào còn phải thu, đến hạn hay quá hạn; thu khoản nợ từ trước.

1. Vào **Công nợ**: các cột «Phụ huynh», «Đơn hàng», «Sale», «Đợt», «Hạn đóng», «Phải đóng (đ)», «Đã đóng (đ)», «Còn nợ (đ)», «Tình trạng». Lọc sắp đến hạn hoặc quá hạn; bấm dòng để mở đơn.
2. Thu nợ đầu kỳ: **Phiếu thu** → «Thu nợ đầu kỳ» → chọn «Phụ huynh», nhập «Số tiền», «Hình thức» → «Tạo phiếu nháp».
3. Trình phiếu, rồi duyệt như mục 3.

- **Kết quả:** nợ đầu kỳ của phụ huynh giảm đúng số đã duyệt.
- **Lỗi thường gặp:** `HMT_TINH_NANG_TAT` («Thu nợ đầu kỳ chưa được bật cho cơ sở này»): báo Trưởng cơ sở hoặc Admin bật phân hệ.
- **Ảnh:** [ẢNH: cong-no], [ẢNH: thu-no-dau-ky]

## 6. Duyệt phiếu Hoàn học phí và ghi nhận chi

**Mục tiêu:** chi trả tiền hoàn cho phụ huynh sau khi yêu cầu được duyệt đủ hai cấp (Trưởng cơ sở, rồi Kế toán).

1. Mở phiếu **Hoàn học phí** đang chờ cấp Kế toán (từ «Việc chờ tôi duyệt» hoặc mục Phiếu nghiệp vụ). Kiểm số liệu, bấm **«Duyệt»**.
2. Người tạo phiếu bấm **«Thực hiện»**: hệ thống tính hoàn, trừ giờ và tạo **phiếu chi** (mã `PC-…`) ở «Chờ chi».
3. Vào **Phiếu chi**, mở phiếu: xem «Phụ huynh đã đóng cho ghi danh», «Số tiền hoàn trước phí», «Số tiền hoàn». Sau khi chuyển tiền thật, ghi «Ghi chú chi» rồi bấm **«Ghi nhận đã chi»**. Có bản in «Hoàn học phí cho phụ huynh».

- **Kết quả:** phiếu chi sang «Đã chi»; hồ sơ phụ huynh thấy khoản hoàn.
- **Lỗi thường gặp:**

| Mã | Làm gì |
|---|---|
| `HMT_HOAN_PHI_DANG_MO` | ghi danh đã có yêu cầu hoàn phí chưa xong: xử lý yêu cầu đó trước |
| `HMT_HOAN_PHI_GIO_SAI` | giờ hoàn phải lớn hơn 0 và không quá giờ còn lại (không tính giờ tặng) |
| `HMT_PHIEU_MOT_NGUOI_HAI_CAP` | một người không duyệt hai cấp của cùng một phiếu |
| `HMT_KHONG_CO_QUYEN` | phiếu ở cấp Quản lý cơ sở: Kế toán không duyệt cấp này, chờ Trưởng cơ sở hoặc Admin |

- **Ảnh:** [ẢNH: hoan-hoc-phi-duyet], [ẢNH: phieu-chi-ban-ghi], [ẢNH: phieu-chi-in]

## 7. Số dư khách hàng

**Mục tiêu:** theo dõi tiền phụ huynh còn dư (ví dụ sau dừng học giữ số dư).

1. Vào **Số dư khách hàng**: các cột «Mã phụ huynh», «Số dư (đ)», «Phát sinh gần nhất», «Số dòng sổ».
2. Bấm dòng để xem lịch sử số dư. Số dư dùng để cấn vào đơn khi lập phiếu cho đơn mới.

- **Kết quả:** mọi biến động số dư có dòng sổ, chỉ thêm, không sửa.
- **Lỗi thường gặp:** «Chưa có số dư khách hàng nào» là bình thường lúc chưa có dừng học hoặc thu dư.
- **Ảnh:** [ẢNH: so-du-ds], [ẢNH: so-du-lich-su]

## Khi gặp lỗi

Lỗi từ hệ thống hiện thẳng câu tiếng Việt trên màn. Cần báo: chụp màn hình, ghi mã phiếu và câu lỗi, gửi Trưởng cơ sở. Việc của Trưởng cơ sở xem [bài Trưởng cơ sở](/crm/huong-dan/theo-vai-truong-co-so).
