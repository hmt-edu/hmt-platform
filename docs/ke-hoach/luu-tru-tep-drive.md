# Thiết kế lưu ảnh và tệp bài nộp trên Google Drive (HT-04, GV-18)

Trạng thái: **BẢN THIẾT KẾ, CHƯA CODE**, chờ Chat duyệt (thẻ F-23-45, anh chốt 24/11/2026 14:11). Soạn bởi Code F.
Quyết định của anh: lưu trên **Google Drive của tài khoản vận hành** (15 GB miễn phí, không gắn thẻ), qua Edge Function; không dùng R2 hay Firebase.
Giới hạn đã chốt: 20 MB mỗi tệp, 10 tệp mỗi lần, 50 MB tổng mỗi lần; nhận JPG, PNG, HEIC, PDF.

**Chỗ em chưa chắc** ghi «CHƯA CHẮC» và đều nên thử bằng một tệp thật trước khi dựng. Em không đọc được `luu-tru-tep-r2-23-11.md` (không có trong repo hay hộp thư em thấy): mục 6 dựa vào mô tả trong thẻ, xin Chat gửi lại nội dung hạng 1/2/3.

## 1. Xác thực Drive

| Cách | Chạy được trên gói miễn phí? | Ghi chú |
|---|---|---|
| Tài khoản dịch vụ ghi vào Drive cá nhân | **Không nên** (CHƯA CHẮC, hay gặp lỗi hết dung lượng) | Tài khoản dịch vụ thường không có dung lượng riêng; thư mục chia sẻ cho nó thường vẫn bị từ chối khi ghi tệp mới. Ổ chia sẻ (Shared Drive) cần Google Workspace trả phí. |
| **OAuth, refresh token của tài khoản vận hành** | **Có** (đề xuất) | Edge Function đổi refresh token lấy access token, ghi tệp **dưới tên tài khoản vận hành**, tính vào 15 GB của tài khoản này. |

Đề xuất: OAuth một lần, quyền (scope) **`drive.file`** (chỉ thấy tệp ứng dụng này tạo, không đọc được phần Drive còn lại; thuộc nhóm quyền không nhạy cảm nên khỏi gửi Google xét duyệt). Ba điều cần giữ:

1. Dự án Google Cloud để chế độ **«Đang chạy» (In production)**, không để «Thử nghiệm» (Testing): ở chế độ thử nghiệm refresh token **hết hạn sau 7 ngày** (theo tài liệu Google; CHƯA CHẮC còn đúng, kiểm lại lúc dựng). Ứng dụng chưa xét duyệt có màn cảnh báo «chưa xác minh» lúc anh cấp quyền, chỉ anh thấy, bỏ qua được.
2. Refresh token bị thu hồi nếu anh đổi mật khẩu Google hoặc thu hồi quyền; Google cũng huỷ token không dùng trong 6 tháng. Edge Function gặp lỗi `invalid_grant` thì báo Admin trên màn Quản trị.
3. Chỉ tài khoản vận hành, bật xác thực hai bước; không dùng tài khoản cá nhân của ai.

## 2. Luồng tải lên

1. Trình duyệt **nén ảnh** (WebP hoặc JPEG khoảng 70%, cạnh dài 1600 px); PDF giữ nguyên; HEIC đổi sang JPEG ở trình duyệt nếu thiết bị làm được, không thì gửi nguyên HEIC.
2. Trình duyệt gọi Edge Function `file-upload` (gửi kèm phiên đăng nhập; không có khoá nào ở giao diện).
3. Edge Function kiểm: quyền (học sinh nộp bài của chính mình; giáo viên của lớp đính kèm buổi; bằng hàm DB kiểu `app.assert_*`), cỡ và loại tệp (đọc phần đầu tệp, không tin đuôi tên), 10 tệp và 50 MB, công tắc tính năng theo cơ sở, chống gửi dồn (đếm theo người).
4. Ghi lên Drive (multipart cho tệp nhỏ, tải từng đợt cho tệp lớn); xong ghi một dòng bảng `stored_file` (mục 5), trả `file_id` nội bộ.
5. Lỗi giữa chừng: không ghi dòng DB, xoá tệp dở trên Drive; giao diện cho thử lại.

Giới hạn Edge Function gói Free (bộ nhớ, thời gian xử lý, thời gian chờ): **đối chiếu tài liệu Supabase lúc dựng**; em nhớ khoảng 256 MB bộ nhớ và vài giây CPU, nên **không giữ cả tệp trong bộ nhớ**, chuyển tiếp dòng dữ liệu (stream). Ảnh sau nén thường dưới 1 MB nên nhẹ; PDF 20 MB là ca nặng nhất, cần thử.

## 3. Luồng xem

Ảnh **không công khai**, không dùng đường dẫn chia sẻ của Drive. Giao diện gọi Edge Function `file-view`: kiểm quyền (giáo viên của lớp, phụ huynh của em, chính em, quản lý cơ sở theo phạm vi) rồi trả nội dung từ Drive.

Băng thông Supabase gói Free là **5 GB/tháng tải ra**, ảnh xem đi qua Edge Function nên tính vào đó. Ví dụ: ảnh 500 KB × 10.000 lượt xem = 5 GB, bằng cả hạn mức. Cách giảm:

- Khi tải lên tạo luôn **ảnh thu nhỏ** (cạnh dài khoảng 400 px, khoảng 30 KB) lưu cạnh ảnh gốc; danh sách chỉ tải ảnh thu nhỏ, ảnh gốc chỉ tải khi bấm xem to.
- Đặt `Cache-Control: private, max-age` để trình duyệt giữ, xem lại không tốn.
- Đo lượng tải ra thật sau 2 tuần thử, báo anh trước khi vượt 70%.
- Dự phòng nếu vẫn vượt: Edge Function trả đường dẫn tải có hạn vài phút thay vì chuyển tiếp nội dung (CHƯA CHẮC Drive làm được cho tệp riêng mà không công khai; cần thử).

## 4. Hạn mức Drive API và lỗi

Drive API có hạn mức số lời gọi mỗi phút theo dự án và theo người dùng (con số cụ thể **xem trong Google Cloud Console lúc dựng**; với vài trăm em là rất dư). Gặp lỗi 429 hoặc 5xx thì thử lại tối đa 3 lần, chờ tăng dần; vẫn lỗi thì báo «Tải lên chưa được, thử lại sau» và ghi nhật ký. Trình duyệt giữ tệp trong lúc thử lại. Lỗi hết dung lượng Drive: báo Admin, chặn tải lên mới (mục 6).

## 5. Thư mục và bảng DB

- Cây thư mục: `HMT / {môi trường} / {cơ sở} / {lớp} / {năm-tháng}/`, tạo khi cần; Edge Function nhớ id thư mục để khỏi tìm lại.
- Bảng `stored_file` (migration riêng, sau khi được duyệt): `id uuid`, `drive_file_id`, `thumb_drive_file_id`, `branch_id`, `class_id`, khoá ngoại tới nơi dùng (bài nộp, buổi), `mime`, `size_bytes`, `owner_user_id`, `retention_class` (hạng giữ), `delete_after` (date), `status` (`DANG_DUNG`, `DA_XOA`) và cột chuẩn của bảng nghiệp vụ. **Chỉ lưu id tệp và cờ, không lưu nội dung.**
- RLS bật: đọc theo quyền xem bài, buổi, lớp của người gọi qua hàm quyền; **không ai ghi trực tiếp** (chỉ Edge Function bằng khoá dịch vụ).
- Chỉ mục (ghi lý do trong migration): `(class_id, created_at)` cho danh sách theo lớp; khoá ngoại tới bài nộp; `(delete_after) where status = 'DANG_DUNG'` cho việc dọn hằng đêm.
- Xoá là đổi trạng thái; tệp trên Drive xoá thật bởi việc dọn (mục 6), có nhật ký.

## 6. Dọn dẹp và hạn giữ

Luật hạng 1/2/3 và «30 ngày sau Dừng học» giữ như tài liệu R2 (em chưa đọc được, xin Chat gửi), nhưng **chạy trực tiếp trên Drive, bỏ bước «xuất rồi xoá»**: việc dọn hằng đêm (pg_cron gọi Edge Function, hoặc GitHub Actions) xoá tệp có `delete_after` đã qua và dọn thùng rác Drive.

Dung lượng, giả định 500 em, mỗi em nộp 2 buổi/tuần, mỗi lần 2 ảnh khoảng 500 KB: khoảng 4 GB mỗi tháng, **15 GB đầy sau khoảng 3,5 tháng** (thẻ ghi 2,5 tháng theo giả định nặng hơn). Đề xuất **hạn giữ mặc định 45 ngày** cho bài nộp thường và 30 ngày sau Dừng học; hạn giữ là **tham số cài đặt** (không viết cứng); có chặn mềm khi Drive còn dưới 10% và báo Admin (Edge Function hỏi dung lượng còn lại của Drive).

## 7. Khoá và môi trường

- Client ID, client secret, refresh token **chỉ ở secret của Edge Function**, không vào repo, không vào `VITE_*`.
- **Staging dùng thư mục Drive RIÊNG** (tốt nhất refresh token riêng); bản chạy thật dùng thư mục gốc khác, secret dán từ `hmt-deploy` trên web.
- **Không khoá chạy thật trên máy Mac** (CLAUDE.md): Claude Code chỉ dựng với thư mục và token staging do anh dán vào secret của dự án staging.

## 8. Việc anh làm tay (trên trình duyệt, đăng nhập tài khoản vận hành)

1. Vào console.cloud.google.com, tạo dự án mới `hmt-luu-tru-tep` (không cần bật thanh toán).
2. «APIs & Services»: bật **Google Drive API**.
3. «OAuth consent screen»: loại **External**, tên «HMT lưu tệp», email hỗ trợ là email vận hành; thêm scope `drive.file`; bấm **Publish app** để chuyển sang «In production» (mục 1).
4. «Credentials»: Create OAuth client ID loại **Web application**; redirect URI do Code cung cấp lúc dựng (hoặc dùng OAuth Playground của Google lấy token một lần, Code sẽ viết từng bước lúc đó).
5. Cấp quyền bằng tài khoản vận hành, nhận **refresh token** (lần đầu chọn `access_type=offline` và `prompt=consent`).
6. Tạo hai thư mục Drive `HMT-staging` và `HMT-prod`; đưa id thư mục cho Code.
7. Dán `client_id`, `client_secret`, `refresh_token`, `folder_id` vào secret của Edge Function trên Supabase staging (trên web); bản chạy thật dán ở `hmt-deploy`.
8. Báo Code, thử một tệp thật.

## Câu hỏi cho Chat và anh

1. Đồng ý OAuth refresh token + scope `drive.file` + «In production»? (khuyến nghị)
2. Hạn giữ mặc định 45 ngày có hợp với luật hạng 1/2/3 không? Xin gửi lại nội dung tài liệu R2.
3. Tạo ảnh thu nhỏ ngay từ đầu (khuyến nghị) hay làm sau khi đo băng thông?
