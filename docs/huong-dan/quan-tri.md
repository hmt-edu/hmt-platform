# Hướng dẫn cho Quản trị (Admin)

Vai: Admin hệ thống. Admin cần **thiết lập hai bước** khi đăng nhập (xem `chung.md`). Admin xem được mọi cơ sở, nhưng **không duyệt tiền** (phiếu thu, hoàn phí, phiếu chi do Kế toán duyệt). Menu **Quản trị** và **Cấu hình**. Xem `README.md` về cách đọc.

## 1. Tạo người dùng
- **Mục đích:** cấp tài khoản cho nhân viên, giáo viên, trợ giảng.
- **Ai làm:** Admin.
- **Các bước:** 1) **Người dùng** (`/crm/quan-tri/nguoi-dung`) → **«Tạo người dùng»**. 2) Mục «Tài khoản nhân viên»: nhập «Tên hiển thị», «Tên đăng nhập», «Email», chọn «Cơ sở», «Loại nhân sự» (Nhân viên, Giáo viên, Trợ giảng), «Mã nhân sự». 3) Bấm tạo; màn «Tạo xong» hiện **«Mật khẩu tạm»** (một lần duy nhất). Có nút chép; nếu «Không chép được vào bộ nhớ tạm» thì bôi đen và chép tay. Giao mật khẩu cho người đó qua kênh an toàn.
- **Kết quả mong đợi:** người dùng đăng nhập bằng mật khẩu tạm và bị yêu cầu đổi mật khẩu lần đầu.
- **Lỗi thường gặp:** «Chưa tạo được.» kèm câu lý do (trùng tên đăng nhập hoặc mã nhân sự, thiếu trường); mất mật khẩu tạm → dùng «Đặt lại mật khẩu» (mục 2). **Ảnh:** [ẢNH: nguoi-dung-tao], [ẢNH: nguoi-dung-mat-khau-tam]

## 2. Quản lý tài khoản
- **Các bước:** mở một người ở danh sách. Menu **«Hành động»**: «Sửa vai trò», «Đổi cơ sở», «Quản lý trực tiếp» (người duyệt đơn cho Sale/CSKH), «Sửa email», «Khoá» (hộp «Khoá tài khoản» xác nhận) hoặc «Mở khoá», «Thu hồi phiên» (đăng xuất mọi máy), «Đặt lại mật khẩu» (cấp mật khẩu tạm mới), «Đặt lại hai bước» (cho Admin hoặc Kế toán mất thiết bị). Cuối trang có «Lịch sử đăng nhập».
- **Kết quả mong đợi:** thay đổi ghi vào nhật ký (ai, lúc nào, trường nào đổi).
- **Lỗi thường gặp:** không khoá được người cuối cùng giữ quyền Admin (câu lý do trên màn); gán vai Kế toán cho người cụ thể là cách duy nhất để người đó duyệt tiền. **Ảnh:** [ẢNH: nguoi-dung-ban-ghi], [ẢNH: nguoi-dung-hanh-dong]

## 3. Danh mục
- **Mục đích:** chỉnh các danh sách chọn dùng khắp hệ thống (môn, khối, lý do…).
- **Ai làm:** Admin (một số danh mục chỉ xem).
- **Các bước:** **Danh mục** (`/crm/quan-tri/danh-muc`): cột trái là «Danh sách danh mục» (ô «Tìm danh mục»), phải là «Các mục của danh mục». Thêm hoặc sửa tên mục; mục **không xoá**, chỉ bấm **«Ngừng»** (mục ngừng không hiện ở ô chọn mới, dữ liệu cũ giữ nguyên) và «Đang dùng» để dùng lại. Mục có chữ «Khoá: chỉ đổi tên hiển thị.» là mục luật bám vào: đổi tên được, không ngừng được. «Nạp từ file chuẩn» để nạp nhiều mục từ tệp mẫu.
- **Kết quả mong đợi:** ô chọn ở các màn khác đổi theo; mọi sửa có nhật ký.
- **Lỗi thường gặp:** mã không đổi được sau khi tạo; trùng mã báo ngay tại ô. **Ảnh:** [ẢNH: danh-muc-ds], [ẢNH: danh-muc-ngung]

## 4. Tham số nghiệp vụ
- **Mục đích:** chỉnh các con số vận hành (hạn, ngưỡng, số dòng tối đa…) không phải sửa code.
- **Ai làm:** Admin.
- **Các bước:** **Cài đặt tham số nghiệp vụ** (`/crm/quan-tri/tham-so`): chọn «Nhóm tham số», tìm bằng ô «Tìm tham số». Mỗi tham số có «Giá trị» chung và có thể **ghi đè theo «Cơ sở»**. Sửa rồi bấm **«Lưu thay đổi tham số»**; hộp xác nhận cho xem «Giá trị cũ» và «Giá trị mới» trước khi **«Lưu»**. Tham số kiểu bật/tắt có «Bật», «Tắt».
- **Kết quả mong đợi:** hàm nghiệp vụ đọc giá trị mới ngay; bản ghi đã tạo giữ giá trị lúc tạo (không tính lại).
- **Lỗi thường gặp:** giá trị ngoài khoảng cho phép (nhỏ nhất, lớn nhất ghi ở mô tả tham số) bị chặn tại ô; ghi đè sai cơ sở → xoá ghi đè để về giá trị chung. **Ảnh:** [ẢNH: tham-so-nhom], [ẢNH: tham-so-luu]

## 5. Công tắc tính năng theo cơ sở
- **Mục đích:** bật hoặc tắt một phân hệ (Vận hành lớp, Aftersale, Bảo lưu, Chuyển lớp, Hoàn phí, Thu nợ đầu kỳ…) cho từng cơ sở.
- **Ai làm:** Admin.
- **Các bước:** **Công tắc tính năng** (`/crm/quan-tri/cong-tac`): bảng «Phân hệ» × «Cơ sở»; bấm ô để đổi sang «Bật» hoặc «Tắt» (cột «Trạng thái mới» cho biết sẽ thành gì); xác nhận.
- **Kết quả mong đợi:** phân hệ hiện hoặc ẩn khỏi menu của cơ sở đó; hàm nghiệp vụ cũng kiểm công tắc.
- **Lỗi thường gặp:** màn nghiệp vụ báo `HMT_TINH_NANG_TAT` nghĩa là phân hệ chưa bật cho cơ sở đó: vào đây bật. Bật công tắc không tự tạo dữ liệu. **Ảnh:** [ẢNH: cong-tac-bang]

## 6. Vai trò và ma trận quyền (xem, không đổi trong lúc vận hành)
- **Các bước:** **Vai trò** (`/crm/quan-tri/vai-tro`, ô «Tìm vai trò») và **Ma trận quyền** (`/crm/quan-tri/ma-tran-quyen`). Mỗi lần lưu ma trận là một phiên bản, hiệu lực ngay; không đổi cấu trúc quyền trong cơ sở dữ liệu. Chỉ vai Kế toán được có quyền «Kế toán · Duyệt» (hệ thống chặn nếu gán cho vai khác, `HMT_CHI_KE_TOAN_DUYET_TIEN`).
- **Lỗi thường gặp:** Admin không tự duyệt tiền dù có mọi quyền khác. **Ảnh:** [ẢNH: vai-tro-ds], [ẢNH: ma-tran-quyen]

## 7. Nhật ký
- **Các bước:** **Nhật ký thao tác** (`/crm/quan-tri/nhat-ky`) cho mọi sửa cấu hình và dữ liệu (chỉ thêm, không sửa); **Nhật ký đăng nhập** (`/crm/quan-tri/nhat-ky-dang-nhap`) cho lần đăng nhập, có xuất file; mở khoá tạm khi người dùng bị khoá do nhập sai.
- **Kết quả mong đợi:** tra được ai làm gì lúc nào. **Ảnh:** [ẢNH: nhat-ky-thao-tac], [ẢNH: nhat-ky-dang-nhap]
