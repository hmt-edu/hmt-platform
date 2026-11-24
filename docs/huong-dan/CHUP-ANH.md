# Chụp ảnh tự động cho hướng dẫn người dùng (E32)

Mục đích: tạo ảnh cho chỗ `[ẢNH: ten]` trong `docs/huong-dan/*.md` bằng Playwright, chạy trên **Supabase local với dữ liệu giả**, không cần staging, không cần mật khẩu staging.

## Chạy
```
npm run chup-anh
```
Lệnh làm lần lượt: bật Supabase local (nếu chưa), dựng lại DB từ migration và seed, tạo tài khoản giả với mật khẩu ngẫu nhiên (không lưu), rồi chạy `e2e/chup-anh.spec.ts`. Xong thì tắt DB: `npm run db:stop`.

- Cần Docker Desktop và `npx playwright install chromium` (một lần).
- Chạy **lần lượt** với lane khác: ghi một dòng vào `HOP-THU/LUOT-DB.txt` trước khi chạy, xoá sau khi tắt DB.
- Cổng xem trước mặc định 4173; hai thư mục làm việc chạy song song thì đặt `E2E_PREVIEW_PORT` khác nhau.

## Kết quả
Ảnh lưu **ngoài repo**: `~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/<vai>/<ten>.png` (đổi thư mục gốc bằng biến `ANH_OUT`). Không commit ảnh. Máy tính rộng 1280 px; cổng Giáo viên cỡ iPhone 390 × 844.

Vai và tài khoản giả (xem `scripts/seed-users.ts`): `sale` (sale.cs5), `cskh` (cskh.cs5), `ke-toan` (ketoan.cs5, có bước hai bước giả), `truong-co-so` (truongcs.cs5), `giao-vien` (gv.cs5), `quan-tri` (quantri.cs5).

Mỗi thư mục vai có `BAO-CAO.txt`: **ĐÃ CHỤP** (đúng màn), **XẤP XỈ** (chụp màn gần nhất, thường là danh sách hoặc bản ghi, vì hộp thoại hoặc bước cần dữ liệu riêng chưa mở tự động) và **LỖI** (không mở được màn). Chỗ xấp xỉ cần chụp tay hoặc bổ sung bước trong `e2e/chup-anh-ban-do.ts`.

## Thêm hoặc sửa ảnh
Sửa bảng `ROLES` ở `e2e/chup-anh-ban-do.ts`: mỗi ảnh có `name` (đúng tên trong `[ẢNH: ten]`), `route`, `row` (bấm dòng đầu của bảng), `view` (chọn kiểu xem). Dữ liệu trong ảnh là dữ liệu giả của seed; đừng chụp trên bản có dữ liệu thật.

## Giới hạn hiện tại (đã chạy thử 19/11)
- Bản chạy thử đầu tiên dùng DB seed thường: 6 vai chạy xong, không lỗi, nhưng DB giả **chưa có dữ liệu mẫu** (lead, đơn, phiếu thu, lớp, ticket… trống) nên nhiều ảnh «bản ghi» chỉ là danh sách trống: `BAO-CAO.txt` ghi XẤP XỈ kèm lý do. Muốn ảnh đẹp cần bước dựng dữ liệu mẫu nhỏ (lead, cơ hội, đơn, phiếu thu, lớp, buổi, ticket) trước khi chụp: việc tiếp theo, chưa làm.
- Hộp thoại chưa mở tự động (đánh dấu XẤP XỈ trong bảng ánh xạ).
- Từ bước 2 lệnh `npm run chup-anh` nạp thêm bộ seed giả lớn có sẵn (lead, cơ hội, đơn, phiếu thu, lớp, buổi, ghi danh) trước khi chụp để ảnh «bản ghi» có dòng thật; tắt bằng `CHUP_ANH_DU_LIEU=0`. Ticket, phiếu nghiệp vụ, khoản tiền chưa có seed nên ảnh liên quan vẫn là xấp xỉ.
- **E36:** `npm run chup-anh` còn nạp `supabase/seed-anh-huong-dan.sql` (một lớp ở CS5 do giáo viên giả gv.cs5 dạy, có buổi HÔM NAY đã chốt danh sách, ba em đang học): bảy ảnh cổng Giáo viên (điểm danh, nội dung buổi, chấm nhận xét, BTVN, hoàn tất…) chụp được. Chạy thử: Giáo viên 8 ảnh đúng màn (trước 3), CSKH 10 (trước 7), Trưởng cơ sở 5 (trước 4); còn xấp xỉ chủ yếu là hộp thoại và ticket, phiếu nghiệp vụ, khoản tiền chưa có seed.

## QUY ƯỚC TÊN ẢNH (MỘT quy ước, thống nhất 24/11)
Trong tài liệu viết `[ẢNH: tên]` (và `[VIDEO: tên]`), KHÔNG viết `![tên](đường-dẫn)`. Trang Hướng dẫn trong ứng dụng chỉ hiểu dạng này và đọc ảnh ở `public/huong-dan/anh/<tên>.png`. Kịch bản `scripts/huong-dan/*.mjs` xuất thẳng vào thư mục đó. Thêm ảnh mới: chụp vào `public/huong-dan/anh/`, giữ nguyên `[ẢNH: tên]` trong tài liệu.

## Hướng dẫn có khung đánh dấu và video
Xem `scripts/huong-dan/README.md` (chạy trên bản thử nghiệm, ba bài mẫu).

## F63 (19/11): dữ liệu mẫu là bộ seed của bản thử nghiệm
`npm run chup-anh` nay nạp `supabase/seed-staging.sql` (`npm run db:seed-staging`) thay cho bộ seed giả lớn: cùng dữ liệu với bản thử nghiệm (lead 60, cơ hội 40, báo giá 16, đơn 24, phiếu thu 16, khoản tiền vào 12, ghi danh 28, lớp 5, buổi 40, ticket 16, phiếu nghiệp vụ 4, tái tục 4; có buổi hôm nay của gv.cs5), nên ảnh chụp ở máy khớp ảnh chụp trên staging. Ticket, phiếu nghiệp vụ, khoản tiền vào giờ đã có dòng thật: các ảnh liên quan không còn bắt buộc XẤP XỈ vì thiếu dữ liệu; còn lại XẤP XỈ chỉ vì **hộp thoại chưa mở tự động** (bổ sung `clicks` trong `e2e/chup-anh-ban-do.ts` khi biết đúng tên nút).
Chụp trực tiếp trên staging (khi anh Trường cho phép và đã nạp seed-staging): chạy cùng kịch bản với địa chỉ và mật khẩu tài khoản giả của staging trong biến môi trường, KHÔNG ghi mật khẩu vào file; việc này cần chỉnh cấu hình Playwright (hiện chỉ chạy trên máy chủ xem trước local), nên **chưa làm**: ghi để Chat quyết.
