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
- **Mọi câu lỗi và câu mô tả trong khung QT-07 do Design viết là câu tạm: Code đổi theo câu thật của hệ thống.**
- Danh mục "Nguồn lead" chỉ vẽ ở khung nhiều cấp `QT07_nhieu_cap` (3 nguồn, 4 kênh trong đó 1 kênh Ngừng). Các khung danh mục phẳng (Thêm mục, Đổi tên, Ngừng, Lỗi nhập) dùng "Loại hoạt động" (6 mục, spec 06 dòng 16). Mã trong khung là số mẫu.
- Thêm mục, đổi tên hiển thị, đổi thứ tự, Ngừng. Mã không đổi, không xoá. Danh mục nhiều cấp (vd nguồn → kênh) làm theo từng cấp.
- Nút **Dùng lại** (mục đang Ngừng) **chưa có trong spec** (spec ghi Thêm, đổi tên, đổi thứ tự, Ngừng). Anh Trường đã duyệt giữ nút này: Code ghi vào spec.
- **Đổi thứ tự bằng nút ▲▼** trên từng dòng (đổi chỗ với dòng kề, không kéo thả). ▲ mờ ở dòng đầu, ▼ mờ ở dòng cuối. Danh mục nhiều cấp: đổi chỗ trong cùng cấp, cùng cha. Ô "Thứ tự" trong hộp Thêm mục giữ như cũ (mục mới đặt cuối); nếu thấy trùng với ▲▼ thì báo lại, Design không tự bỏ.
- Cột trái có ô **Tìm danh mục** (tìm theo tên). Khung chỉ vẽ 5 danh mục mẫu; **thật có 34 danh mục**.
- Nút **Lịch sử thay đổi** ở đầu trang QT-07 vẽ **mờ**: Nhật ký (QT-11) chưa dựng. Ở QT-08 **bỏ nút** (Q-111).
- `QT07_khoa_chi_doi_ten`: danh mục khoá (vd Giai đoạn cơ hội) chỉ có **Đổi tên**, không Thêm mục, Ngừng, Dùng lại, không ▲▼. Vẽ đủ 8 giai đoạn (L1 đến L8) và **62 nhóm con** (60 đang dùng, 2 Ngừng: L5P, L5Q) theo spec 06 mục 1.3 bản 04/11, mỗi dòng chỉ có nút Đổi tên (dòng Ngừng cũng chỉ Đổi tên). Khung cao hơn 1000 vì có 70 dòng. **Tên tạm, chờ Config mới:** L6C đến L6G (spec viết tắt '… học xuất sắc/tốt/khá/trung bình/yếu', Design viết đủ theo mẫu L6B) và L7N đến L7Q (spec viết tắt '… về chương trình học/thời gian học/hình thức học/địa điểm học', viết đủ theo mẫu L7M). Câu cuối trang 'chỉ đổi tên' tạm giữ, chờ kết quả Q-122.
- `QT07_them_kenh`: hộp Thêm kênh có "Thuộc nguồn" (ô chọn), Mã, Tên hiển thị. Mục cha và mục con (kênh) đều có Ngừng và Dùng lại. Chưa vẽ trường hợp Ngừng mục cha đang có kênh con còn dùng: luật chưa có, Code cho biết.
- `QT07_tinh_phuong_xem`: Tỉnh, phường chỉ xem, "Nạp từ file chuẩn, chỉ xem", không Thêm, Đổi tên, Ngừng. Nhãn "Chỉ xem" (Q-110, áp mọi khung QT-07). **Vênh:** spec 06 ghi danh mục 29 là "Mở"; Code làm theo luật. Mã và tên trong khung là số mẫu.
- `QT07_loi_nhap`: hộp Thêm mục có lỗi (mã sai dạng, tên trống; ví dụ 2: mã trùng). **Câu lỗi do Design viết, Code đổi theo câu thật.**
- `QT07_danh_muc_rong`: danh mục chưa có mục nào, câu hướng dẫn và nút Thêm mục.

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
- **Mọi câu lỗi và câu mô tả trong khung QT-08 do Design viết là câu tạm: Code đổi theo câu thật của hệ thống.**
- Cơ sở là danh mục khoá: **không thêm, không ngừng** ở giao diện (cơ sở mới qua migration). Chỉ sửa **tên hiển thị và địa chỉ**.
- **Sửa theo R-V2-10 (anh Trường chốt 04/11): CS3 là cơ sở dạy học thường, có lớp, phòng, học sinh.** Khung cũ vẽ CS3 là văn phòng, không có phòng học: đã sửa, CS3 vẽ như mọi cơ sở khác (có bảng Phòng, nút Thêm phòng). Tên hiển thị "CS3 Hội sở" giữ như khung cũ, Code gửi tên thật.
- Phòng: thêm, sửa tên và sức chứa, Ngừng. Tên, địa chỉ, sức chứa trong khung là số mẫu. Nút Dùng lại phòng: như mục 8, đã duyệt.
- **Mã phòng**: bắt buộc, chữ viết hoa, số, dấu gạch dưới, không trùng trong cơ sở, không đổi sau khi tạo (Sửa phòng: ô chỉ đọc có biểu tượng khoá). Bảng phòng có thêm cột Mã phòng. Ô Mã ở Sửa cơ sở và Đổi tên mục cũng vẽ chỉ đọc có khoá.
- **Địa chỉ cơ sở**: một dòng, tối đa 200 ký tự.
- `QT08_co_so_chua_phong`: cơ sở chưa có phòng, hiện câu hướng dẫn và nút Thêm phòng.
- `QT08_loi_phong`: lỗi khi thêm phòng (tên trùng, mã trùng, mã sai dạng, sức chứa trống hoặc ≤ 0). **Câu lỗi do Design viết, Code đổi theo câu thật.**
- Lỗi mạng khi Lưu và người không phải Admin: dùng khung chung CHUNG-17 và CHUNG-16 của canvas HMT Platform (`CHUNG_trang_thai`), không vẽ lại. CHUNG-17 là khung trang "Không tìm thấy / lỗi hệ thống", chưa chắc đủ cho lỗi mạng lúc Lưu trong hộp.
- Chưa vẽ hộp chặn "Ngừng phòng có lớp hoặc buổi sắp tới": làm cùng đợt Lớp.

## 12. QT-09 Cài đặt tham số nghiệp vụ
- Chỉ Admin. Màn dùng khuôn K10 (danh sách nhóm bên trái, bảng tham số bên phải); không sửa khung cũ ở gói P2, khung này vẽ lại theo kiểu khung hiện hành.
- Danh sách theo `docs/spec/06` mục 2: **25 tham số, 8 nhóm** (Bán hàng, Ghi danh, Tái tục, Buổi học, Lớp, Giáo viên, CSKH, Đăng nhập). Nhóm **Lớp** có trong spec nhưng không có trong danh sách nhóm anh Trường nêu; khung vẽ đủ 8 nhóm theo spec.
- **Khoảng cho phép theo spec** (luật thắng ví dụ): Ngưỡng giờ còn **0–100** (ví dụ anh nêu 0–50), Số lần sai trước khi tạm khoá **3–50** (ví dụ anh nêu 3–20). Nếu muốn đổi khoảng, sửa spec 06 trước.
- Tham số tiền, giá, chiết khấu, đăng nhập **không có** nút Ghi đè cơ sở. Chỉ tham số "Có" ở cột Ghi đè mới có nút. Tham số có ghi đè hiện **giá trị chung** và **danh sách cơ sở đang ghi đè**.
- Giải thích ngắn của từng tham số trong khung là **câu ví dụ**, **[Code chốt]** câu thật.
- Nhập ngoài khoảng: báo lỗi ngay dưới ô, nút Lưu khoá. Sửa xong bấm Lưu thì có hộp xác nhận nêu giá trị cũ → mới. Mọi lần sửa ghi nhật ký (ai sửa, lúc nào, giá trị cũ, giá trị mới), lịch sử chỉ đọc.
- Tham số "Tự đăng xuất giáo viên, trợ giảng" và "học sinh": hiện theo ngày, lưu bằng phút.
- Không có quyền: dùng khuôn CHUNG-16 (Bạn không có quyền xem …, nút Về trang chủ). Chỉ máy tính, không có bản điện thoại.
- Trần chiết khấu tổng: giải thích ghi rõ gồm chính sách %, ưu đãi linh hoạt và giờ tặng (giờ tặng quy ra %), giá trị 20%, khoảng 0–100%, không ghi đè theo cơ sở.
