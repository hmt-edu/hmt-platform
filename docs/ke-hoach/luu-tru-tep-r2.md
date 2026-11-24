# Thiết kế lưu ảnh và tệp bài nộp trên Cloudflare R2 (HT-04, GV-18)

Trạng thái: **BẢN THIẾT KẾ, CHƯA CODE**, chờ Chat duyệt (thẻ F-23-45c, anh chốt lại 24/11/2026 14:17: giữ R2 như chốt 23/11, không dùng Drive hay Firebase vì R2 còn dùng cho việc khác). Soạn bởi Code F. Thay bản Drive (F-23-45, PR #690, sẽ đóng).
Giới hạn đã chốt: 20 MB mỗi tệp, 10 tệp mỗi lần, 50 MB tổng mỗi lần; nhận JPG, PNG, HEIC, PDF.
R2 gói Free (spec 01): 10 GB lưu mỗi tháng, tải ra miễn phí; dung lượng vượt tính 0,015 USD/GB-tháng (**không tự vượt**, xem mục 6).

**Chỗ chưa chắc** ghi «CHƯA CHẮC», nên thử bằng tệp giả trước khi dựng. Em không đọc được `luu-tru-tep-r2-23-11.md` (không có trong repo hay hộp thư em thấy): mục 6 dựa vào mô tả trong thẻ, xin Chat gửi lại nội dung hạng 1/2/3.

## 0. Bước đầu tiên: anh kiểm R2 có đòi thẻ không

R2 **có thể đòi gắn thẻ** lúc bật (CHƯA CHẮC). Trước mọi việc khác:

1. Anh vào Cloudflare **thử nghiệm** (tài khoản `[email vận hành]+staging`), mục R2 Object Storage, bấm bật.
2. Nếu hiện màn đòi thẻ hoặc phương thức thanh toán: **DỪNG, không gắn thẻ**, báo Chat để hỏi anh (CLAUDE.md: không phát sinh tiền khi chưa hỏi). Em không tự gắn.
3. Nếu không đòi: tạo bucket (mục 8) và đi tiếp.

## 1. Kho và quyền truy cập

- Một bucket **riêng tư** cho mỗi môi trường: `hmt-files-staging`, `hmt-files-prod` (prod tạo trên tài khoản Cloudflare chạy thật, trên trình duyệt, qua `hmt-deploy`). Không bật địa chỉ công khai, không tên miền công khai.
- Edge Function giữ khoá R2 (Access Key ID, Secret) và **ký địa chỉ có hạn** (presigned URL, giao thức S3). Giao diện không có khoá nào.
- Khoá R2 giới hạn quyền **Object Read & Write chỉ trên bucket này**, không dùng khoá toàn tài khoản.
- Cấu hình CORS của bucket cho phép `PUT` và `GET` từ tên miền ứng dụng (staging, chạy thật).

## 2. Luồng tải lên

1. Trình duyệt **nén ảnh** (mục 5), tính **mã băm SHA-256**, tạo ảnh thu nhỏ.
2. Trình duyệt gọi Edge Function `file-upload-url` với danh sách tệp (loại, cỡ, mã băm, buổi hoặc bài nộp đích) kèm phiên đăng nhập.
3. Edge Function kiểm: quyền (học sinh nộp bài của chính mình; giáo viên của lớp đính kèm buổi; bằng hàm DB kiểu `app.assert_*`), loại và cỡ theo giới hạn trên (đọc từ tham số cài đặt, không viết cứng), công tắc tính năng theo cơ sở, chống gửi dồn (đếm theo người), **trùng mã băm** (mục 5).
4. Edge Function cấp **địa chỉ ký để `PUT` thẳng lên R2, hạn 5 phút**, một địa chỉ cho mỗi tệp và mỗi ảnh thu nhỏ; ghi dòng `stored_file` trạng thái `CHO_TAI` (mục 7).
5. Trình duyệt tải thẳng lên R2: **tệp không đi qua Supabase**, nên không tốn băng thông 5 GB/tháng của Supabase và không vướng giới hạn bộ nhớ Edge Function.
6. Trình duyệt gọi `file-upload-done`; Edge Function hỏi R2 (HEAD) xác nhận có tệp, đúng cỡ, rồi đổi `DANG_DUNG`. Tệp không xác nhận sau 1 giờ: việc dọn đánh `DA_XOA` và xoá khỏi R2.
7. Lỗi giữa chừng: giao diện cho thử lại, trình duyệt giữ tệp.

## 3. Luồng xem

Ảnh **không công khai**. Giao diện gọi Edge Function `file-view-url`: kiểm quyền (giáo viên của lớp, phụ huynh của em, chính em, quản lý cơ sở theo phạm vi) rồi trả **địa chỉ ký để `GET`, hạn vài phút**; trình duyệt tải thẳng từ R2. R2 **không tính phí tải ra**, và lượt xem không đi qua Supabase, nên băng thông 5 GB/tháng của Supabase gần như không bị ảnh hưởng (chỉ lời gọi nhỏ xin địa chỉ).

Danh sách chỉ tải **ảnh thu nhỏ**; ảnh đầy chỉ tải khi bấm xem to (giảm thời gian chờ trên 4G). Không dùng `Cache-Control` dài trên địa chỉ ký (địa chỉ đổi mỗi lần); giao diện giữ ảnh thu nhỏ trong bộ nhớ phiên.

## 4. Hạn mức và lỗi

R2 có hạn mức số thao tác miễn phí mỗi tháng (con số **đối chiếu tài liệu Cloudflare lúc dựng**; với vài trăm em là rất dư, CHƯA CHẮC con số hiện hành). Gặp lỗi 429 hoặc 5xx từ R2 thì trình duyệt thử lại tối đa 3 lần, chờ tăng dần; vẫn lỗi thì báo «Tải lên chưa được, thử lại sau» và ghi nhật ký. Lỗi vượt dung lượng: chặn tải mới và báo Admin (mục 6).

## 5. Nén ảnh và chặn trùng (ở trình duyệt)

- Ảnh: **thang xám + tăng tương phản + WebP chất lượng khoảng 60–65, cạnh dài khoảng 1280 px**, mục tiêu **120–180 KB mỗi ảnh**. Không dùng AVIF (iPhone cũ không mở được). HEIC đổi sang WebP ở trình duyệt nếu thiết bị làm được, không thì gửi nguyên HEIC (CHƯA CHẮC mọi thiết bị).
- **Thang xám có thể mất thông tin** nếu bài có màu (bút đỏ chấm của giáo viên, hình tô màu): đề xuất giáo viên đính kèm ảnh màu thì giữ màu (cờ theo loại tệp), chỉ bài nộp của học sinh dùng thang xám; xin Chat chốt.
- **Thử mức nén trên ảnh vở GIẢ** (tự tạo, chữ viết tay giả, không dùng ảnh thật của học sinh) trước khi chốt số: chữ vẫn đọc rõ khi phóng to. Kết quả thử ghi vào PR dựng HT-04.
- PDF giữ nguyên.
- **Ảnh thu nhỏ** 20–30 KB (cạnh dài khoảng 400 px) tạo ở trình duyệt, lưu cạnh ảnh đầy.
- **Chặn nộp trùng bằng mã băm**: cùng học sinh, cùng bài, cùng SHA-256 thì Edge Function trả «Tệp này đã nộp» và không cấp địa chỉ tải lên.

## 6. Dung lượng, dọn dẹp, hạn giữ

Luật hạng 1/2/3 và «30 ngày sau Dừng học» giữ như tài liệu R2 23/11 (em chưa đọc được, xin Chat gửi). **Bước «xuất sang Drive» cho hạng 3 giữ như chốt 23/11.** Việc dọn hằng đêm (pg_cron gọi Edge Function, hoặc GitHub Actions) xoá tệp có `delete_after` đã qua, xoá khỏi R2 và đổi `DA_XOA`.

Ước dung lượng ổn định theo hạn giữ (giả định, không phải số đo): 500 em, 19.500 ảnh mỗi tháng.

| Cỡ mỗi ảnh | Hạn giữ | Dung lượng ổn định |
|---|---|---|
| 150 KB | 90 ngày | khoảng 8,8 GB (trong 10 GB) |
| 300 KB | 90 ngày | khoảng 17,5 GB (vượt, khoảng 0,11 USD/tháng phần vượt 7,5 GB) |

Cộng thêm ảnh thu nhỏ (~25 KB mỗi ảnh, thêm khoảng 15%). Đề xuất: **hạn giữ mặc định 90 ngày nếu nén đạt ≤ 150 KB**, rút còn 60 ngày nếu thử nén ra lớn hơn. Hạn giữ là **tham số cài đặt** (không viết cứng). **Chặn mềm khi tổng dung lượng chạm 80% hạn mức miễn phí** và báo Admin, để không tự phát sinh tiền; vượt mức miễn phí chỉ khi anh đồng ý.

## 7. Bảng DB và RLS

- Bảng `stored_file` (migration riêng, sau khi được duyệt): `id uuid`, `r2_key`, `thumb_r2_key`, `sha256`, `branch_id`, `class_id`, khoá ngoại tới nơi dùng (bài nộp, buổi), `mime`, `size_bytes`, `owner_user_id`, `retention_class`, `delete_after` (date), `status` (`CHO_TAI`, `DANG_DUNG`, `DA_XOA`) và cột chuẩn của bảng nghiệp vụ. **Chỉ lưu khoá tệp và cờ, không lưu nội dung** (CLAUDE.md: không dùng Supabase Storage).
- Khoá R2 dạng `{môi trường}/{cơ sở}/{lớp}/{năm-tháng}/{uuid}`: không chứa tên học sinh hay số điện thoại.
- RLS bật: đọc theo quyền xem bài, buổi, lớp của người gọi qua hàm quyền; **không ai ghi trực tiếp** (chỉ Edge Function bằng khoá dịch vụ).
- Chỉ mục (ghi lý do trong migration): `(class_id, created_at)` cho danh sách theo lớp; khoá ngoại tới bài nộp; `(owner_user_id, sha256)` cho chặn trùng; `(delete_after) where status = 'DANG_DUNG'` cho việc dọn hằng đêm.
- Xoá là đổi trạng thái; tệp xoá thật khỏi R2 bởi việc dọn, có nhật ký.

## 8. Khoá và môi trường

- Khoá R2 **chỉ ở secret của Edge Function**, không vào repo, không vào `VITE_*`.
- Staging: bucket và khoá trên Cloudflare **thử nghiệm**, anh dán vào secret của dự án Supabase staging (trên web). Bản chạy thật: bucket và khoá trên Cloudflare chạy thật, dán ở `hmt-deploy` trên web.
- **Không khoá chạy thật trên máy Mac** (CLAUDE.md): Claude Code chỉ dựng với bucket và khoá staging do anh dán.

## 9. Việc anh làm tay (trên trình duyệt)

1. Bước 0: vào Cloudflare **thử nghiệm**, bật R2; **nếu đòi thẻ thì dừng và báo** (không gắn).
2. Tạo bucket `hmt-files-staging`, **riêng tư** (mặc định).
3. «Manage R2 API Tokens», tạo token loại **Object Read & Write**, chỉ áp cho bucket này; ghi `Access Key ID`, `Secret Access Key`, `Account ID` (hiện một lần).
4. Cấu hình CORS bucket: nguồn là tên miền staging của ứng dụng, phương thức `PUT`, `GET`, `HEAD`; Code cung cấp đoạn JSON lúc dựng.
5. Dán `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` vào secret của Edge Function trên Supabase staging (trên web).
6. Báo Code, thử một tệp giả. Bản chạy thật làm lại các bước 1–5 trên tài khoản chạy thật khi tới lúc đưa lên.

## Câu hỏi cho Chat và anh

1. Hạn giữ mặc định 90 ngày (nếu nén ≤ 150 KB) có hợp với luật hạng 1/2/3 không? Xin gửi lại nội dung `luu-tru-tep-r2-23-11.md`.
2. Thang xám cho mọi ảnh, hay giữ màu cho ảnh giáo viên đính kèm (mục 5)?
3. Chặn mềm ở 80% hạn mức miễn phí (mục 6) có đúng ý anh không?
4. Có tạo ảnh thu nhỏ ngay từ đầu không (khuyến nghị: có)?
