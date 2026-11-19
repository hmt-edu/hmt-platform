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
