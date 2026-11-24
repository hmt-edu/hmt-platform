# Hướng dẫn anh làm tay: kho tệp Google Drive (F-23-51)

Dành cho anh Trường, làm trên **trình duyệt**, từng thẻ nhỏ. Thiết kế: `luu-tru-tep-drive.md` (mục 6, 8, 9). Không bước nào đặt khoá vào repo. Chữ trong ngoặc «» là chữ Google hiện trên màn hình; Google đổi giao diện thì chữ có thể lệch đôi chút, thấy lệch thì chụp màn hình gửi Chat.

**Nguyên tắc:** tài khoản Google giữ kho tệp là `[email vận hành]` (anh đã cấp quyền). Làm **hai lần**: lần 1 cho **staging**, lần 2 cho **chạy thật**; mỗi lần một dự án Cloud riêng, một thư mục riêng. Dự án, thư mục và khoá của hai môi trường không dùng chung. Nếu Google đòi **thẻ thanh toán** ở bất cứ bước nào: **dừng, báo Chat**.

Chỗ nào ghi «NHÃN» thì thay bằng `staging` hoặc `prod` tuỳ lần làm.

## Thẻ 1. Chuẩn bị tài khoản

1. Mở cửa sổ ẩn danh, vào `accounts.google.com`, đăng nhập `[email vận hành]`.
2. Vào `myaccount.google.com/security`, mục «Xác minh 2 bước»: phải là **Đang bật**. Chưa bật thì bật.
3. Kết quả mong đợi: đăng nhập được, xác minh 2 bước đang bật.

## Thẻ 2. Tạo dự án Cloud

1. Vào `console.cloud.google.com` (cùng cửa sổ, cùng tài khoản). Lần đầu: tích đồng ý điều khoản, bấm «Đồng ý và tiếp tục» (không có chỗ nhập thẻ; nếu có thì dừng).
2. Góc trên trái cạnh chữ «Google Cloud» bấm ô chọn dự án, bấm **«Dự án mới» (New project)**.
3. «Tên dự án»: `hmt-luu-tru-tep-NHÃN`. «Tổ chức»/«Vị trí»: để «Không có tổ chức». Bấm **«Tạo» (Create)**.
4. Chờ chuông thông báo báo xong, bấm «Chọn dự án».
5. Kết quả: thanh trên cùng hiện tên `hmt-luu-tru-tep-NHÃN`.

## Thẻ 3. Bật Google Drive API

1. Menu ☰ > «API và dịch vụ» > **«Thư viện» (Library)**.
2. Ô tìm kiếm gõ `Google Drive API`, bấm kết quả «Google Drive API», bấm **«Bật» (Enable)**.
3. Kết quả: trang «Google Drive API» có chữ «API đã bật» (API enabled).

## Thẻ 4. Màn hình đồng ý OAuth

1. Menu ☰ > «API và dịch vụ» > **«Màn hình đồng ý OAuth» (OAuth consent screen)** (bản mới có thể là «Google Auth platform» > «Branding»). Bấm «Bắt đầu» (Get started) nếu có.
2. «Tên ứng dụng»: `HMT lưu tệp NHÃN`. «Email hỗ trợ người dùng»: chọn `[email vận hành]`. Bấm «Tiếp theo».
3. «Đối tượng» (Audience): chọn **«Bên ngoài» (External)**. Bấm «Tiếp theo».
4. «Thông tin liên hệ»: gõ `[email vận hành]`. Tiếp theo, tích đồng ý chính sách, bấm **«Tạo»**.
5. Mục «Quyền truy cập dữ liệu» (Data Access) > **«Thêm hoặc xoá phạm vi» (Add or remove scopes)**: tìm `drive.file`, tích dòng `.../auth/drive.file` («Xem, chỉnh sửa, tạo và xoá chỉ các tệp Google Drive cụ thể mà bạn dùng với ứng dụng này»). Bấm «Cập nhật», rồi **«Lưu»**. Chỉ một phạm vi này, không thêm phạm vi khác.
6. Mục «Đối tượng» (Audience): bấm **«Xuất bản ứng dụng» (Publish app)**, xác nhận «Xác nhận». Trạng thái phải là **«Đang chạy» (In production)**, không phải «Thử nghiệm» (Testing): ở «Thử nghiệm» token hết hạn sau 7 ngày.
7. Kết quả: trạng thái xuất bản «Đang chạy / In production»; phạm vi liệt kê đúng `drive.file`.

## Thẻ 5. Tạo OAuth client

1. «API và dịch vụ» > **«Thông tin xác thực» (Credentials)** > «+ Tạo thông tin xác thực» > **«ID ứng dụng khách OAuth» (OAuth client ID)**.
2. «Loại ứng dụng»: **«Ứng dụng web» (Web application)**. «Tên»: `hmt-luu-tru-tep-NHÃN-client`.
3. Mục «URI chuyển hướng được phép» (Authorized redirect URIs) > «+ Thêm URI»: dán `https://developers.google.com/oauthplayground`. Bấm **«Tạo»**.
4. Hộp thoại hiện «ID ứng dụng khách» và «Mật khẩu ứng dụng khách» (Client ID, Client secret). **Chưa đóng**: mở một ghi chú riêng trên máy anh (không phải repo, không dán vào chat), chép hai giá trị này vào. Bấm «OK».
5. Kết quả: danh sách «ID ứng dụng khách OAuth 2.0» có một dòng mới.

## Thẻ 6. Lấy refresh token (OAuth Playground)

1. Vào `developers.google.com/oauthplayground` (cùng tài khoản).
2. Bánh răng ⚙ góc trên phải (OAuth 2.0 configuration): tích **«Use your own OAuth credentials»**, dán Client ID và Client secret của thẻ 5. Bấm «Close».
3. Cột trái «Step 1»: ô «Input your own scopes» gõ `https://www.googleapis.com/auth/drive.file`, bấm **«Authorize APIs»**.
4. Chọn `[email vận hành]`. Màn «Google hasn't verified this app» (chưa xác minh) là bình thường (chỉ anh thấy): bấm «Nâng cao» (Advanced) > «Đi tới HMT lưu tệp NHÃN (không an toàn)». Bấm «Tiếp tục» để cấp quyền (chỉ quyền với tệp ứng dụng tạo).
5. Quay lại Playground, «Step 2»: bấm **«Exchange authorization code for tokens»**.
6. Ô «Refresh token» hiện chuỗi bắt đầu bằng `1//`. Chép vào ghi chú riêng cạnh hai giá trị trước. (Không thấy `Refresh token`: bấm ⚙, tích «Access type: Offline», làm lại từ bước 3.)
7. Kết quả: ba giá trị trong ghi chú riêng: `client_id`, `client_secret`, `refresh_token`.

## Thẻ 7. Tạo thư mục gốc

1. Vào `drive.google.com` (cùng tài khoản) > «+ Mới» > «Thư mục mới», tên `HMT-NHÃN` (`HMT-staging` hoặc `HMT-prod`), «Tạo».
2. Mở thư mục, nhìn thanh địa chỉ: `drive.google.com/drive/folders/XXXXXXXX`. Phần `XXXXXXXX` là `folder_id`; chép vào ghi chú riêng.
3. Lưu ý: với phạm vi `drive.file`, ứng dụng chỉ thấy thư mục nó tạo hoặc anh mở bằng ứng dụng. Nếu thử một tệp giả mà báo không thấy thư mục: **báo Chat**, Code sẽ cho Edge Function tự tạo thư mục gốc (đã nằm trong danh sách «CHƯA CHẮC» của thiết kế, mục 10).
4. Kết quả: thư mục tồn tại, có `folder_id`.

## Thẻ 8. Dán bí mật

Bốn giá trị: `client_id`, `client_secret`, `refresh_token`, `folder_id`. Tên bí mật (Code chốt khi dựng Edge Function, dự kiến): `DRIVE_CLIENT_ID`, `DRIVE_CLIENT_SECRET`, `DRIVE_REFRESH_TOKEN`, `DRIVE_ROOT_FOLDER_ID`.

**Staging** (lần 1): vào `supabase.com/dashboard` (tài khoản GitHub của TÀI KHOẢN CHỦ DỰ ÁN, organization HMT) > dự án `hmt-staging` > «Edge Functions» > «Secrets» (hoặc «Project Settings > Edge Functions») > «Add new secret», dán từng cặp tên và giá trị, bấm «Save». Nếu tài khoản này không phải của anh, nhờ Chat sắp xếp.

**Chạy thật** (lần 2): chỉ làm trên trình duyệt, bằng tài khoản Supabase `[email chạy thật]` (organization HMT Prod) > dự án `hmt-prod` > Edge Functions > Secrets, dán bốn cặp. Bản sao thứ hai nếu quy trình deploy cần: GitHub `hmt-deploy` > «Settings» > «Secrets and variables» > «Actions» > «New repository secret», cùng bốn tên. Không dán ở đâu khác.

Kết quả: danh sách Secrets hiện bốn tên (không hiện giá trị).

## Thẻ 9. Dọn và báo

1. Xoá ghi chú riêng chứa khoá khi đã dán xong (hoặc giữ ở trình quản lý mật khẩu, không để file thường).
2. Báo Chat: «Xong staging» hoặc «Xong prod». Chat báo Code chạy **4 phép thử điểm chưa chắc** (thiết kế mục 10) bằng một tệp giả ở staging, kèm phép thử token staging không đọc được thư mục prod.
3. Sau khi làm lần 2, cũng chạy phép thử: dùng token staging thử mở `HMT-prod`, phải bị từ chối.

## Về video hướng dẫn

Sau khi staging chạy, Code làm một lệnh (script, không kéo thả tay) tải mp4 lên thư mục video của Drive và in ra `id`, để ghi vào `video-manifest.json`. Việc này dùng cùng bộ khoá ở thẻ 8, không cần bước tay mới.
