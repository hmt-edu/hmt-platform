# Thiết kế lưu ảnh và tệp bài nộp trên Google Drive (HT-04, GV-18)

Trạng thái: **BẢN THIẾT KẾ, CHƯA CODE**, chờ Chat duyệt (thẻ F-23-47). Soạn bởi Code F.
**Thay bản R2** (`luu-tru-tep-r2.md`, #691, đã gộp, nay đổi tên thành file này): anh chốt lại 24/11/2026 14:33 dùng **Google Drive của tài khoản vận hành** (15 GB miễn phí, không thẻ) vì R2 đòi gắn thẻ (màn «Add R2 subscription»). Không dùng R2 hay Firebase.
Giới hạn đã chốt: 20 MB mỗi tệp, 10 tệp mỗi lần, 50 MB tổng mỗi lần; nhận JPG, PNG, HEIC, PDF.

**Chỗ chưa chắc** ghi «CHƯA CHẮC»; mỗi chỗ có cách thử bằng tệp giả trước khi dựng (mục 10).

## Phần dùng chung với bản R2 (giữ nguyên)

- Giới hạn tệp ở trên, đọc từ tham số cài đặt (đã có trong migration 664 ở #692), không viết cứng.
- Nén ở trình duyệt: ảnh học sinh **thang xám + tăng tương phản + WebP chất lượng ~60–65, cạnh dài ~1280 px, mục tiêu 120–180 KB**; ảnh giáo viên đính kèm **giữ màu**; PDF giữ nguyên; không AVIF. Thử trên ảnh vở GIẢ trước khi chốt số. Đã làm ở #693 (chưa thử ảnh giả).
- **Ảnh thu nhỏ** 20–30 KB tạo ở trình duyệt; danh sách chỉ tải ảnh thu nhỏ.
- **Chặn nộp trùng** bằng SHA-256 (chỉ mục duy nhất ở bảng `stored_file`).
- Bảng `stored_file` + RLS + chỉ mục (#692): cột `storage_key` giờ là **id tệp Drive**, `thumb_storage_key` là id ảnh thu nhỏ.
- Luật dọn hạng 1/2/3 (anh duyệt 23/11): Hạng 1 = ảnh của học sinh đã Dừng học sau 30 ngày chờ; Hạng 2 = học sinh mọi ghi danh đã kết thúc, không còn lớp đang học hay bảo lưu; Hạng 3 = ảnh quá hạn giữ của học sinh đang học. Bảo lưu và Tạm nghỉ không vào hạng 1, 2; quay lại trong 30 ngày thì thoát hạng 1; không bao giờ xoá ảnh của học sinh còn ghi danh hoạt động. Chỉ tệp bài làm; điểm, nhận xét, trạng thái nộp ở lại Postgres; sau xoá màn hiện «Ảnh đã được dọn theo quy định lưu trữ». Chạy hằng đêm, theo lô, **có chế độ chạy thử** (`file_cleanup_dry_run` bật lúc đầu), chỉ Admin đổi tham số hay bấm xoá tay; ghi nhật ký (lớp, tháng, số tệp, người, thời điểm).
- Chặn mềm ở 80% hạn mức và báo Admin; khoá chỉ trong secret của Edge Function; staging dùng thư mục Drive riêng; không khoá chạy thật trên máy Mac.

## 1. Xác thực Drive

| Cách                                                   | Chạy được trên gói miễn phí?                          | Ghi chú                                                                                                                                                         |
| ------------------------------------------------------ | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tài khoản dịch vụ ghi vào Drive cá nhân                | **Không nên** (CHƯA CHẮC; hay gặp lỗi hết dung lượng) | Tài khoản dịch vụ không có dung lượng riêng; thư mục chia sẻ cho nó thường vẫn bị từ chối khi ghi tệp mới. Ổ chia sẻ (Shared Drive) cần Google Workspace trả phí. |
| **OAuth, refresh token của tài khoản vận hành** (chọn) | **Có**                                                | Edge Function đổi refresh token lấy access token, ghi tệp **dưới tên tài khoản vận hành**, tính vào 15 GB của tài khoản này.                                    |

Quyền (scope) **`drive.file`**: ứng dụng chỉ thấy tệp do chính nó tạo, không đọc được phần Drive còn lại; thuộc nhóm không nhạy cảm nên khỏi gửi Google xét duyệt (CHƯA CHẮC mọi trường hợp; nếu `drive.file` không đủ thì nói lại với anh trước khi xin quyền rộng hơn). Ba điều giữ:

1. Dự án Google Cloud để **«Đang chạy» (In production)**, không để «Thử nghiệm»: ở chế độ thử nghiệm refresh token **hết hạn sau 7 ngày** (theo tài liệu Google, CHƯA CHẮC còn đúng, kiểm lại lúc dựng). Ứng dụng chưa xét duyệt có màn «chưa xác minh» lúc anh cấp quyền, chỉ anh thấy, bỏ qua được.
2. Refresh token bị thu hồi nếu anh đổi mật khẩu Google hoặc thu hồi quyền; Google cũng huỷ token không dùng 6 tháng. Edge Function gặp `invalid_grant` thì báo Admin trên màn Quản trị.
3. Chỉ dùng tài khoản vận hành, bật xác thực hai bước.

## 2. Luồng tải lên

Drive **không có URL ký kiểu R2/S3**. Có hai cách, thử cách A trước:

- **A. Phiên tải tiếp được (resumable upload) do Edge Function khởi tạo, trình duyệt tải thẳng lên Drive.** Edge Function kiểm quyền rồi gọi Drive tạo phiên, nhận địa chỉ phiên và trả cho trình duyệt; trình duyệt `PUT` thẳng, **không tốn băng thông Supabase**. **CHƯA CHẮC** hai chỗ: (i) Drive có cho trình duyệt gọi địa chỉ phiên từ tên miền khác (CORS) không, và phải truyền `Origin` đúng lúc khởi tạo; (ii) đọc được id tệp từ phản hồi cuối hay không. Nếu một trong hai không được thì dùng B.
- **B. Qua Edge Function** (trình duyệt gửi tệp lên Edge Function, Edge Function chuyển tiếp dòng dữ liệu sang Drive, không giữ cả tệp trong bộ nhớ). Tốn băng thông Supabase 5 GB/tháng và vướng giới hạn bộ nhớ, thời gian của Edge Function gói Free (đối chiếu tài liệu Supabase lúc dựng). Ảnh sau nén ~150 KB nên nhẹ: 19.500 ảnh/tháng ≈ 3 GB lên, cộng lượt xem thì sát hạn mức; cần đo.

Luồng chung:

1. Trình duyệt nén ảnh, tính SHA-256, tạo ảnh thu nhỏ.
2. Gọi Edge Function `file-upload-start` với danh sách tệp (loại, cỡ, mã băm, buổi hoặc bài nộp đích) và phiên đăng nhập.
3. Edge Function kiểm: quyền (học sinh nộp bài của chính mình; giáo viên của lớp đính kèm; bằng hàm DB kiểu `app.assert_*`), loại và cỡ theo tham số, công tắc tính năng theo cơ sở, chống gửi dồn, **trùng mã băm**, **chặn mềm 80% dung lượng**.
4. Cách A: trả địa chỉ phiên cho từng tệp và ảnh thu nhỏ; cách B: nhận tệp. Ghi dòng `stored_file` trạng thái `CHO_TAI`.
5. Xong: gọi `file-upload-done` kèm id tệp Drive; Edge Function hỏi Drive (metadata) xác nhận đúng cỡ rồi đổi `DANG_DUNG`. Tệp `CHO_TAI` quá 1 giờ: việc dọn xoá vĩnh viễn khỏi Drive và đánh `DA_XOA`.
6. Lỗi giữa chừng: giao diện cho thử lại; trình duyệt giữ tệp.

## 3. Luồng xem

Ảnh **không công khai**, không dùng đường dẫn chia sẻ của Drive. Giao diện gọi Edge Function `file-view`: kiểm quyền (giáo viên của lớp, phụ huynh của em, chính em, quản lý cơ sở theo phạm vi) rồi **trả byte từ Drive làm trung gian**. Đây là chỗ tốn băng thông Supabase (5 GB/tháng tải ra).

Ước tính (giả định 500 em, 19.500 ảnh/tháng): mỗi ảnh xem đầy một lần ở 150 KB ≈ 3 GB; thêm ảnh thu nhỏ ~25 KB mỗi lần mở danh sách. Gần hạn mức nếu xem lại nhiều. Cách giảm:

- Danh sách chỉ tải **ảnh thu nhỏ**; ảnh đầy chỉ tải khi bấm xem to.
- `Cache-Control: private, max-age` cho phản hồi, trình duyệt giữ; xem lại không tốn.
- Đo lượng tải ra thật sau 2 tuần thử; **báo anh trước khi vượt 70%**.
- Dự phòng: kiểm tra Drive có cấp được địa chỉ tải ngắn hạn cho tệp riêng mà không công khai (CHƯA CHẮC; nhiều khả năng không) để trình duyệt tải thẳng.

## 4. Xoá vĩnh viễn

Tệp bỏ vào **thùng rác Drive vẫn tính dung lượng 15 GB**. Việc dọn phải gọi **xoá vĩnh viễn** (`files.delete`, không phải đánh dấu `trashed`) rồi kiểm lại không còn. Với `drive.file`, ứng dụng chỉ xoá được tệp do chính nó tạo (đúng ý). **Bỏ bước «xuất Drive rồi xoá» của hạng 3** (ảnh đã ở Drive): hạng 3 xoá thẳng sau hạn giữ.

## 5. Hạn mức Drive API và lỗi

Drive API có hạn mức số lời gọi mỗi phút theo dự án và theo người dùng (con số **xem trong Google Cloud Console lúc dựng**; vài trăm em là rất dư). Lỗi 403 `rateLimitExceeded`, 429 hoặc 5xx: thử lại tối đa 3 lần, chờ tăng dần có độ lệch ngẫu nhiên; vẫn lỗi thì báo «Tải lên chưa được, thử lại sau» và ghi nhật ký. Lỗi hết dung lượng Drive (`storageQuotaExceeded`): chặn tải mới và báo Admin.

## 6. Dung lượng và hạn giữ

Giả định 500 em, 19.500 ảnh/tháng (không phải số đo):

| Cỡ mỗi ảnh | Hạn giữ | Dung lượng ổn định (chưa kể ảnh thu nhỏ ~15%) |
| ---------- | ------- | --------------------------------------------- |
| 150 KB     | 90 ngày | khoảng 8,8 GB (trong 15 GB)                   |
| 300 KB     | 90 ngày | khoảng 17,5 GB (**vượt** 15 GB)               |

Đề xuất: **hạn giữ mặc định 90 ngày nếu nén ≤ 150 KB, rút còn 60 ngày nếu thử nén ra lớn hơn** (anh chưa chốt hạn giữ; là **tham số** `file_retention_days`). 15 GB tính **chung cả tài khoản Google** (Gmail, Drive khác): **quyết định: kho tệp dùng TÀI KHOẢN GOOGLE RIÊNG** (không chung với sao lưu đêm và hộp thư vận hành; mỗi môi trường một tài khoản, xem mục 8). Không còn là câu hỏi mở. Chặn mềm khi tổng dung lượng chạm 80% (`file_storage_soft_limit_percent`, hạn mức `file_storage_free_gb` = 15) và báo Admin; Edge Function hỏi dung lượng còn lại của Drive (`about.get`).

## 7. Thư mục và bảng DB

- Cây thư mục: `HMT / {môi trường} / {cơ sở} / {lớp} / {năm-tháng}/`, tạo khi cần; Edge Function nhớ id thư mục. Không tên học sinh hay số điện thoại trong tên thư mục hay tên tệp (tên tệp = uuid).
- Bảng `stored_file` (#692): chỉ lưu id tệp và cờ, không lưu nội dung; RLS bật, đọc theo quyền xem bài giao, không ai ghi trực tiếp (chỉ Edge Function bằng khoá dịch vụ).
- Xoá là đổi trạng thái; tệp xoá thật bởi việc dọn, có nhật ký.

## 8. Khoá và môi trường

- **Staging và chạy thật dùng HAI dự án Google Cloud khác nhau**, mỗi dự án có OAuth client và refresh token riêng, mỗi môi trường một thư mục gốc Drive riêng (quyết định, không còn «tốt nhất»). Lý do: khoá staging nằm trong tay Claude Code và CI; nếu chung dự án hay chung token thì khoá staging đọc, xoá được ảnh thật của học sinh.
  - Staging: dự án `hmt-luu-tru-tep-staging`, tài khoản Google kho tệp staging, thư mục `HMT-staging`; secret dán vào Edge Function của Supabase `hmt-staging` (và Secrets của `hmt-platform` nếu CI cần).
  - Chạy thật: dự án `hmt-luu-tru-tep-prod`, tài khoản Google kho tệp chạy thật (đăng ký bằng email chạy thật, xác thực hai bước, chỉ dùng trên trình duyệt), thư mục `HMT-prod`; secret chỉ dán ở `hmt-deploy` và Edge Function của `hmt-prod` trên web.
  - Hai bộ secret khác tên môi trường, không dùng chung giá trị nào. Kiểm tra: dùng token staging thử đọc thư mục prod, phải bị từ chối (làm một lần khi cài, ghi kết quả).
- Client ID, client secret, refresh token **chỉ ở secret của Edge Function**, không vào repo, không vào `VITE_*`.
- **Không khoá chạy thật trên máy Mac** (CLAUDE.md): Claude Code chỉ dựng với thư mục và token staging do anh dán.

## 9. Việc anh làm tay (trên trình duyệt)

Làm **hai lần**, một cho staging, một cho chạy thật (khác tài khoản Google, khác dự án, khác thư mục):

1. Tạo tài khoản Google riêng cho kho tệp của môi trường đó (không dùng tài khoản đang giữ sao lưu đêm hay hộp thư vận hành).
2. Vào console.cloud.google.com bằng tài khoản đó, tạo dự án mới (`hmt-luu-tru-tep-staging` hoặc `hmt-luu-tru-tep-prod`); không bật thanh toán; nếu Google đòi thẻ ở bước nào thì **dừng và báo**.
3. «APIs & Services»: bật **Google Drive API**.
4. «OAuth consent screen»: loại **External**, tên «HMT lưu tệp», email hỗ trợ là email vận hành; thêm scope `drive.file`; bấm **Publish app** để chuyển sang «In production».
5. «Credentials»: tạo OAuth client ID loại **Web application**; redirect URI do Code cung cấp lúc dựng (hoặc dùng OAuth Playground lấy token một lần, Code viết từng bước lúc đó).
6. Cấp quyền bằng tài khoản kho tệp, nhận **refresh token** (lần đầu chọn `access_type=offline` và `prompt=consent`).
7. Tạo thư mục Drive gốc (`HMT-staging` hoặc `HMT-prod`); đưa id thư mục cho Code (staging) hoặc dán thẳng vào secret (chạy thật).
8. Dán `client_id`, `client_secret`, `refresh_token`, `folder_id` vào secret của Edge Function: staging trên Supabase `hmt-staging`; chạy thật ở `hmt-deploy` và Supabase `hmt-prod`, đều trên web.
9. Báo Code, thử một tệp giả ở staging. Thử đọc thư mục prod bằng token staging: phải bị từ chối.

## Câu hỏi cho Chat và anh

1. Đồng ý OAuth refresh token + scope `drive.file` + «In production»?
2. Thử cách A (tải thẳng lên Drive) trước, rơi về B nếu CORS không qua?
3. ~~Tài khoản Google riêng cho kho tệp?~~ Đã chốt: riêng, mỗi môi trường một tài khoản (mục 6, 8).
4. Hạn giữ 90 ngày (nén ≤ 150 KB) / 60 ngày (nếu lớn hơn) làm mặc định?

5. Hạng 3 «xoá thẳng sau hạn» khác luật 23/11 (lưu trữ rồi xoá): chờ anh xác nhận; đề xuất xoá hẳn sau hạn.
6. Ảnh HEIC không gửi nguyên: trình duyệt đổi sang WebP; không đổi được thì báo trước khi nộp (#693).
