# Ghi chú cho Code · canvas HMT Quản trị và Nạp dữ liệu · bổ sung

Chỉ gồm ghi chú cho Code. Chỗ ghi **[Code chốt]** là chỗ khung chỉ minh hoạ.

## 1. QT-18 Nhập dữ liệu: ngoại lệ của R-CRM-27
- R-CRM-27 cấm Tạo tay Phụ huynh, Học sinh. Anh Trường cho **ngoại lệ**: màn Nhập (QT-18) chỉ **Admin** dùng, gọi **hàm nạp riêng**, không phải thao tác Tạo tay.
- Code ghi ngoại lệ này vào luật (`docs/spec/04`) và ghi chú vênh trong PR.
- Nạp chỉ dùng cho đợt chuyển dữ liệu CS5 Mỹ Đình. Mọi lần nạp ghi nhật ký. Mật khẩu hệ thống cũ không mang sang.

## 2. Mục menu mới
- Thêm mục **Nhập dữ liệu** ở **cuối nhóm Quản trị** (sau Nhật ký). QT-18 là mã màn mới, bản đồ màn hình chưa có dòng này: Code thêm.

## 3. Loại nạp, cột, giới hạn
- 8 loại theo thứ tự gợi ý: Người dùng, Lớp, Phụ huynh, Học sinh, Ghi danh, Số dư, Cơ hội, Phiếu test. **Lớp, Ghi danh, Số dư** hiện ghi **Sắp có**, nút Nhập khoá.
- Tên cột, cột bắt buộc của Phụ huynh (khung ghi ma_cu, ho_ten, sdt, co_so), Ghi danh, Số dư: **[Code chốt]** theo hàm nạp. Khung chỉ minh hoạ.
- Giới hạn số dòng mỗi file: **[giới hạn do Code chốt]**.
- Cột **Cảnh báo** ở bước xem trước chỉ hiện khi hàm nạp của Code có cảnh báo cho dòng đó. Khung để trống, không thêm hành vi nào.
- Cột lạ trong file bị bỏ qua và có báo; thiếu cột bắt buộc thì không xem trước được.

## 4. Báo lỗi không in tên đầy đủ
- Dòng lỗi, trùng chỉ ghi: **số dòng, chữ cái đầu tên (vd N.T.L), tên cột lỗi**. Không in tên đầy đủ, cả trên màn lẫn file tải về.
- **Ghi danh và Số dư**: một dòng lỗi thì **không nạp cả loại** (nút Nạp thật khoá). Các loại khác: dòng lỗi và trùng bị bỏ qua, nạp dòng hợp lệ.

## 5. Mật khẩu tạm hàng loạt (loại Người dùng)
- Hộp kiểu K4g nhưng cho nhiều người: **chỉ tóm tắt số người theo loại** (Giáo viên gồm trợ giảng, Nhân viên văn phòng), không liệt kê từng người, nên hộp không dài ra (ví dụ 112 tài khoản = 88 giáo viên, trong đó 23 trợ giảng, + 24 nhân viên văn phòng; **số minh hoạ, số thật theo file nạp**).
- Mật khẩu chỉ nằm trong **file tải một lần**; cảnh báo "tải một lần, xoá file sau khi gửi". Nút **Đóng khoá** tới khi tải file (hoặc tick xác nhận) như K4g.
- Mỗi người đổi mật khẩu ở lần đăng nhập đầu (CHUNG-07).
- Lối thoát khi mất file: **Đặt lại mật khẩu từng người ở QT-02**.
- Điện thoại: K4e4 cho một mật khẩu; khung `QT18_mat_khau_hang_loat_dt` vẽ bản 12 người; bản 112 người (`QT18_mat_khau_hang_loat_112`) cùng cách.

## 6. QT-02 Người dùng (bản ghi K06)
- Dùng khuôn K06 có sẵn. **Chỉ thêm mục vào menu Hành động**: Sửa email (mới). Các mục Sửa vai trò, Đổi cơ sở, Khoá, Đặt lại mật khẩu, Đặt lại hai bước, Thu hồi phiên đã có theo bản đồ màn hình.
- Đặt lại mật khẩu: hộp xác nhận ("mật khẩu cũ hết hiệu lực, mọi phiên đăng nhập bị thu hồi"), rồi mở **K4g** (máy tính) hoặc **K4e4** (điện thoại) của HMT Platform; không vẽ lại.

## 7. QT-03 Tạo người dùng, Sửa email
- Form có **cả tên đăng nhập** (hệ thống gợi ý, sửa được, không đổi sau khi tạo) **và email**. Mã nhân sự tự cấp, không sửa.
- Tên đăng nhập trùng, email trùng: báo ngay ở ô, không tạo.
- Email mẫu trong khung là `@example.test` (giả). **Email quy ước thật là `<tên đăng nhập>@nv.hmt.invalid`.**

## 8. QT-07 Danh mục
- Thêm mục, đổi tên hiển thị, đổi thứ tự, Ngừng. Mã không đổi, không xoá. Danh mục nhiều cấp (vd nguồn → kênh) làm theo từng cấp.
- Nút **Dùng lại** (mục đang Ngừng) **chưa có trong spec** (spec ghi Thêm, đổi tên, đổi thứ tự, Ngừng). Anh Trường đã duyệt giữ nút này: Code ghi vào spec.

## 9. CH-03 Bảng giá, ô trống
- Giá trống nghĩa là **chưa bán được hình thức đó** (R-TIEN-10).
- Khung `CH03_danh_sach_gia_trong` phân biệt hai trạng thái, hai chip khác màu, hai chú thích khác nhau:
  - **Chưa có giá** (chip hổ phách): "Chờ cập nhật, không phải ngừng bán" (R-TIEN-10). Hai sản phẩm chưa có giá online là chờ anh Trường cập nhật.
  - **Không bán** (chip xám): "Gói không bán hình thức này" (R-TIEN-15).
- **Tên sản phẩm và số liệu trong khung (VIP Môn khác, KR, mọi con số giá) chỉ là ví dụ; giá thật nhập trên hệ thống.**
- Khung `CH03_gia_trong`: hộp Thêm bảng giá mới có ô để trống. Không có nhãn "Chưa cấu hình" riêng.

## 10. CH-01 Gói bán
- Mã gói theo `Loại-Môn-Khối` (hoặc `Loại-Môn-KhốiđầuKhốicuối`), **không chứa hình thức** (chốt 12/10). Giá ở Bảng giá, không đặt trong gói.
- **Gói chưa có cột số giờ** (anh Trường chốt 05/11): số giờ nhập khi lập dòng đơn. Mọi khung CH01 không có ô số giờ.
- Sửa gói đổi được **tên** và **mã cũ** (`legacy_ref`, ô "Mã cũ (Sheet)"). Mã gói luôn khoá. Tên gói trong khung là số mẫu.
- Ngừng bán: gói không hiện ở ô chọn mới, đơn đã tạo giữ nguyên. Nút **Dùng lại** (danh mục, gói, phòng): anh Trường duyệt, giữ.

## 11. QT-08 Cơ sở và phòng học
- Cơ sở là danh mục khoá: **không thêm, không ngừng** ở giao diện (cơ sở mới qua migration). Chỉ sửa **tên hiển thị và địa chỉ**.
- CS3 Hội sở là văn phòng, không có phòng học. Phòng: thêm, sửa tên và sức chứa, Ngừng. Tên, địa chỉ, sức chứa trong khung là số mẫu. Nút Dùng lại phòng: như mục 8, đã duyệt.
