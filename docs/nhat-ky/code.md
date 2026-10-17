# Nhật ký Claude Code (cập nhật 17/10/2026, 22:30)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang.)

## Đang làm
- Vừa gộp #38 (nền tảng phối hợp) và #36 (tách gói tải). Không có PR nào đang mở. Việc kế: PR riêng "Đưa luật 17/10 (04d–04g) vào spec".

## Đã chốt (chưa vào repo)
- Luật `04d`–`04g` chờ đưa vào spec: nằm ở `docs/phoi-hop/luat-cho-dua-vao-spec/`; bản nháp phần sửa spec ở nhánh `docs/luat-17-10-ban-nhap`. Mục [CHỜ] (chặn môn theo khối khi tạo lớp; một phiếu tái tục cho mỗi ghi danh; R-GD-07) không đưa vào spec.
- Thứ tự tiếp theo: PR luật 17/10, PR 5 (Đăng nhập), PR 5a (Trang chủ), P3b2a (Cơ hội), P3b2b (Phiếu kiểm tra), P3b3, P3c đến P3f.

## Đang chờ ai
- **Anh Trường:** ngưỡng dung lượng gói tải (đo: trang đầu CRM 235 KB nén; CI hiện chỉ báo số); 4 câu hỏi P3b2; OK bảng quyền phiên bản 4 (17 ô, Phụ huynh, Học sinh); cài hạn xử lý ticket chăm sóc tháng.
- **Claude Code:** làm theo thứ tự trên.

## File và link mới
- Đã gộp: #34 (P3a), #35 (P3b1), #36 (tách gói tải), #37 (nguồn canvas Design), #38 (nền tảng phối hợp).
- `scripts/bundle-size.ts` (`npm run size`); bộ seed lớn `supabase/seed-lon.sql` (`npm run db:seed-lon`).
- `main` chưa bắt buộc PR (GitHub Free không cho bật); chỉ do em tuân thủ CLAUDE.md.
