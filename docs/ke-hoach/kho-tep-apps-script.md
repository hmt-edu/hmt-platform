# Kho tệp bằng Google Apps Script (thay hướng OAuth/Cloud) · F-23-53

Trạng thái: **đề xuất thiết kế + mã script + hướng dẫn tay**, chưa thử trên Google thật (xem mục 5). Thay `luu-tru-tep-drive.md` phần xác thực (mục 1, 8, 9) và PR #702 nếu anh chọn hướng này. Giữ nguyên: sổ tệp `stored_file` (#692, #700), nén ảnh ở trình duyệt (#693), xoá hẳn sau hạn 60 ngày (F-23-52), hàm kiểm quyền DB.

## 1. So sánh hai hướng

| | OAuth + Google Cloud (đang làm) | Apps Script (đề xuất của anh) |
| --- | --- | --- |
| Việc anh làm tay | ~9 thẻ, dự án Cloud, màn đồng ý, token | ~5 bước, không dự án Cloud |
| Vướng | «Publish app» đòi trang chủ + chính sách riêng tư trên tên miền; để «Thử nghiệm» thì token hết hạn 7 ngày | Không cần xuất bản; script chạy bằng quyền anh |
| Quyền của khoá | `drive.file`: chỉ tệp ứng dụng tạo | **Toàn quyền Drive của tài khoản** (script chạy «Tôi»); giới hạn bằng mã, không bằng Google |
| Tải lên | Trình duyệt tải thẳng lên Drive (tệp không qua Supabase) | Tệp **đi qua Edge Function** rồi tới script (base64, ảnh ≤ ~150 KB nên chấp nhận được) |
| Hạn mức | Drive API: rộng | Apps Script: số lần chạy, tổng giờ chạy/ngày, kích thước thân (xem mục 5, **chưa đo**) |
| Độ trễ | thấp | cao hơn, lần đầu «lạnh» có thể vài giây (**chưa đo**) |

Kết luận tạm: Apps Script gỡ được hai vướng của OAuth nhưng **đổi quyền hẹp sang toàn quyền**; chấp nhận được nếu giữ các ràng buộc ở mục 3. Chốt khi phép thử mục 5 đạt.

## 2. Luồng

1. Trình duyệt nén ảnh (#693) rồi gọi Edge Function `file-upload` (thay `file-upload-start/done` của #704): gửi các tệp (base64) kèm bài giao.
2. Edge Function gọi hàm DB `file_authorize_upload` (#700) bằng token người gọi (quyền, giới hạn, hạn giữ), ghi dòng `stored_file` CHO_TAI, hỏi script `quota` (chặn mềm khi còn trống dưới `file_storage_min_free_gb`), gọi script `save`, nhận `id` tệp, đổi dòng sang DANG_DUNG. Tên tệp trên Drive là uuid dòng sổ.
3. Xem: Edge Function `file-view` kiểm quyền (`file_authorize_view`), gọi script `read`, trả ảnh cho trình duyệt.
4. Dọn hằng đêm (pg_cron + Edge Function): hạng 1/2/3 như thiết kế cũ, gọi script `remove` (xoá vĩnh viễn) rồi đánh dấu DA_XOA.
5. Phần dùng lại: `file-flow.ts` (kiểm giới hạn, chặn trùng, chặn mềm) chỉ đổi lớp Drive: thay `drive-client.ts` bằng `apps-script-client.ts` (POST JSON, theo chuyển hướng 302, thử lại). Làm sau khi anh chốt hướng và phép thử đạt.

## 3. Bảo mật (rủi ro chính và cách giữ)

- **Script chạy bằng quyền toàn Drive của tài khoản** (có sao lưu đêm và thư). Giữ bằng mã (đã có kiểm thử tự động `scripts/apps-script-kho-tep/code.test.ts`): mọi thao tác đọc/xoá **chỉ trên tệp nằm trong thư mục gốc** `ROOT_FOLDER_ID` (đi ngược các thư mục cha để kiểm); tên thư mục con, tên tệp chỉ gồm chữ không dấu, số, `_ . -`, không bắt đầu bằng dấu chấm; script chỉ có 5 việc cố định, không chạy mã tuỳ ý; xoá dùng xoá vĩnh viễn, không đụng thùng rác.
- **Địa chỉ web app là «Bất kỳ ai có link»**: ai biết URL gọi được. Lớp chặn là **mật khẩu dùng chung** `APPS_SCRIPT_SHARED_SECRET` (dài ≥ 40 ký tự ngẫu nhiên, so sánh không dừng sớm). Sai mật khẩu: từ chối, không tiết lộ gì. URL và mật khẩu chỉ nằm trong Supabase Secrets, không vào repo, log, hay giao diện.
- **Xoay vòng mật khẩu:** đổi giá trị `SECRET` trong «Thuộc tính tập lệnh» của script **và** `APPS_SCRIPT_SHARED_SECRET` ở Supabase Secrets (hai nơi, cùng lúc, khoảng một phút gián đoạn tải lên). Làm khi nghi lộ, khi người có quyền xem Secrets rời đi, hoặc mỗi 6 tháng. Lộ cả URL lẫn mật khẩu thì «Quản lý bản triển khai» > Lưu trữ bản cũ > triển khai mới (đổi URL).
- **Tách staging và chạy thật:** hai script, hai thư mục gốc, hai mật khẩu, không chung giá trị. Chạy thật do anh đăng bằng tài khoản chạy thật, chỉ trên trình duyệt, dán secret ở `hmt-deploy`/Supabase `hmt-prod` trên web. Staging **không** có quyền nào vào script prod (khác URL, khác mật khẩu).
- Tài khoản chủ script bật xác minh 2 bước. Ai sửa được script là sửa được mọi thứ: không chia sẻ dự án script cho ai khác.
- Không lưu dữ liệu thật trong script (không nhật ký nội dung); tên tệp là uuid.
- **BẮT BUỘC (soát 16:11, mức CAO):** script staging chạy bằng **tài khoản Google riêng**, KHÔNG phải tài khoản đang giữ sao lưu đêm prod. Lý do: mật khẩu staging nằm ở Supabase staging (Code, CI đọc được); nếu script cùng tài khoản với sao lưu prod thì lộ mật khẩu staging là chạm được toàn Drive đó. Prod: tài khoản chạy thật, hai script, hai mật khẩu.
- **Trần trong script (soát, mức VỪA):** mỗi tệp ≤ 21 MB (`MAX_BYTES`, từ chối `QUA_LON` trước khi giải mã) và luôn chừa ≥ 1 GB trống (`MIN_FREE_BYTES`, từ chối `HET_CHO`), để người biết URL và mật khẩu cũng không làm đầy Drive. Có kiểm thử.
- **Cách giảm mạnh hơn, CHƯA thử (phép 7, mục 5):** khai `oauthScopes` trong `appsscript.json` chỉ `drive.file` để script chỉ thấy tệp do chính nó tạo (thư mục gốc phải do script tạo, không tạo tay; dung lượng đọc bằng Drive.About.get). Chưa rõ DriveApp và `Drive.Files.remove` có chạy đủ dưới phạm vi này không; đo ở staging rồi mới đổi hướng dẫn.
- Khuyến nghị tách tài khoản kho tệp khỏi tài khoản giữ sao lưu đêm cũng áp cho chạy thật nếu làm được; nếu dùng chung thì ràng buộc thư mục gốc ở trên là lớp chặn duy nhất.

## 4. Hướng dẫn anh làm tay (staging trước, ~5 bước, ~15 phút)

Đăng nhập **tài khoản Google riêng của kho tệp staging (không phải tài khoản giữ sao lưu đêm)** trong cửa sổ ẩn danh. Chữ trong «» là chữ trên màn hình Google (có thể lệch đôi chút; lệch thì chụp màn hình gửi Chat). Không gửi mật khẩu vào chat.

**Bước 0 (một lần).** Mở `drive.google.com` > «+ Mới» > «Thư mục mới», tên `HMT-staging` > «Tạo». Mở thư mục, thanh địa chỉ có `.../folders/XXXX`: chép `XXXX` (đây là `ROOT_FOLDER_ID`, không phải bí mật). Tạo một chuỗi ngẫu nhiên 40 ký tự ở trình quản lý mật khẩu (chữ và số), chép làm `SECRET`.

**Bước 1. Dự án mới.** Vào `script.google.com` > «Dự án mới» (New project). Bấm tên «Dự án không có tiêu đề», đổi thành `HMT kho tệp staging`, «Đổi tên». Kết quả: màn soạn mã có tệp `Code.gs`.

**Bước 2. Dán mã.** Mở tệp `scripts/apps-script-kho-tep/Code.gs` trong repo (Chat gửi nội dung), chọn hết nội dung `Code.gs` trên Google, xoá, dán mã mới, bấm biểu tượng đĩa mềm «Lưu dự án» (Ctrl+S). Cột trái «Dịch vụ» (Services) bấm **«+»**, chọn **Drive API**, phiên bản **v3**, định danh `Drive`, «Thêm» (Add). Kết quả: «Dịch vụ» hiện `Drive`.

**Bước 3. Thuộc tính tập lệnh.** Bấm bánh răng «Cài đặt dự án» (Project Settings), cuối trang mục «Thuộc tính tập lệnh» (Script Properties) > «Chỉnh sửa thuộc tính tập lệnh» > «Thêm thuộc tính tập lệnh»: `SECRET` = chuỗi ở bước 0; thêm tiếp `ROOT_FOLDER_ID` = `XXXX`. «Lưu thuộc tính tập lệnh». Kết quả: hai dòng thuộc tính.

**Bước 4. Triển khai.** Quay lại màn soạn mã (biểu tượng `<>`), góc trên phải «Triển khai» (Deploy) > «Tùy chọn triển khai mới» (New deployment) > bánh răng cạnh «Chọn loại» > **«Ứng dụng web»** (Web app). «Thực thi với tư cách» (Execute as): **Tôi** (email của anh). «Người có quyền truy cập» (Who has access): **Bất kỳ ai** (Anyone). Bấm «Triển khai». Hộp «Cần cấp quyền» > «Cấp quyền truy cập» > chọn tài khoản > «Nâng cao» (Advanced) > «Đi tới HMT kho tệp staging (không an toàn)» > «Cho phép» (Allow). Kết quả: màn «Đã cập nhật bản triển khai» hiện **URL ứng dụng web** kết thúc bằng `/exec`. Bấm «Sao chép».

**Bước 5. Dán vào Supabase.** Vào `supabase.com/dashboard` > dự án `hmt-staging` > «Edge Functions» > «Secrets» > «Add new secret»: `APPS_SCRIPT_URL` = URL bước 4; `APPS_SCRIPT_SHARED_SECRET` = `SECRET` bước 0. «Save». Nếu không đăng nhập được Supabase đó thì dừng, báo Chat (không gửi khoá).

Kết quả cuối: báo Chat «Xong staging Apps Script» (kèm `ROOT_FOLDER_ID` được, không kèm mật khẩu). Chat báo Code chạy phép thử mục 5. **Chạy thật** làm sau, cùng 5 bước, thư mục `HMT-prod`, mật khẩu khác, dự án script khác, bằng tài khoản chạy thật.

## 5. Phép thử (CHƯA làm: cần script đã đăng ở bước 4)

**Chạy các phép thử:** người có URL và mật khẩu (anh, hoặc ai anh giao) chạy `APPS_SCRIPT_URL=… APPS_SCRIPT_SHARED_SECRET=… node scripts/apps-script-kho-tep/phep-thu.mjs` (tuỳ chọn `OUTSIDE_FILE_ID` = id một tệp tạo tay ngoài thư mục gốc). Script chỉ đọc khoá từ biến môi trường, dừng nếu thư mục gốc không có chữ «staging», chỉ lưu tệp giả vào thư mục `PHEP-THU` rồi xoá vĩnh viễn; kết quả dán vào PR. Phép 3 (hạn mức/ngày) và 7 (`drive.file`) làm tay, theo dõi nhiều ngày.

Mã script đã được kiểm bằng Drive giả (7 bài: mật khẩu, thư mục gốc, tên, xoá vĩnh viễn, dung lượng, trần cỡ, chừa dung lượng), **chưa chạy trên Google thật**. Còn phải đo ở staging, mỗi phép ghi kết quả vào PR:

1. POST có thân 200 KB, 500 KB, 1 MB qua Edge Function: có theo chuyển hướng 302 của Apps Script không; trả đúng JSON không.
2. Thời gian phản hồi lần «lạnh» và lần «ấm» (đo 10 lần).
3. Hạn mức tài khoản thường (số lần chạy/ngày, tổng giờ chạy/ngày, độ dài mỗi lần): với 19.500 ảnh/tháng (~650/ngày, mỗi ảnh một lần `save` + thu nhỏ) có nằm trong hạn mức không; nếu không thì đề xuất gộp ảnh đầy + thu nhỏ một lần gọi, hoặc quay lại OAuth.
4. Xoá vĩnh viễn thật: tệp biến mất, `getStorageUsed` giảm, không còn trong thùng rác.
5. Sai mật khẩu: bị từ chối; tệp ngoài thư mục gốc (một tệp thử anh tạo ở nơi khác) không đọc, không xoá được.
6. Edge Function chuyển tiếp xem ảnh: đúng loại, ảnh mở được.
7. Phạm vi hẹp `drive.file`: thêm `oauthScopes` chỉ `drive.file` vào `appsscript.json`, để script tự tạo thư mục gốc; thử `save`, `read`, `remove`, `quota` còn chạy không; thử một tệp tạo tay ngoài kho có bị từ chối không. Đạt thì đổi hướng dẫn bước 0 và 3.
8. Đọc tệp lớn: `read` một PDF 20 MB (base64 ≈ 27 MB) có trả được trong hạn thời gian không; nếu không thì giảm giới hạn tệp hoặc đọc theo đoạn.

Nếu phép 1 hoặc 3 không đạt thì khuyến nghị quay lại OAuth (kèm cách lo trang chính sách riêng tư: một trang tĩnh trên Cloudflare Pages của chính dự án là đủ cho «Publish app»; làm được không cần tên miền riêng, CHƯA CHẮC Google chấp nhận).
