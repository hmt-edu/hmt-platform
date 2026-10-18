# Nhật ký Claude Code (cập nhật 17/10/2026, 23:30)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang.)

## Đang làm
- PR "Đưa luật 17/10 (04d–04g) vào spec" (nhánh `docs/dua-luat-17-10-vao-spec`, chỉ tài liệu): chờ anh gửi Claude Chat soát rồi comment OK.

## Đã chốt (chưa vào repo)
- Mục chờ anh quyết, **chưa thành luật** (ghi chú ở `docs/spec/04` mục 13): R-GD-07, R-GD-13 (một phiếu tái tục mỗi ghi danh), ticket chọn nhiều ghi danh, R-GIO-03/04, spec 02 mục 3, 6, 7, chặn môn theo khối khi tạo lớp.
- Thứ tự tiếp theo: PR 5 (Đăng nhập), PR 5a (Trang chủ), P3b2a (Cơ hội, kèm ma trận quyền phiên bản 4), P3b2b (Phiếu kiểm tra), P3b3, P3c đến P3f.

## Đang chờ ai
- **Anh Trường:** ngưỡng dung lượng gói tải (đo: trang đầu CRM 235 KB nén; CI hiện chỉ báo số); 4 câu hỏi P3b2; OK bảng quyền phiên bản 4 (17 ô, Phụ huynh, Học sinh); cài hạn xử lý ticket chăm sóc tháng.
- **Claude Code:** làm theo thứ tự trên.

## File và link mới
- Đã gộp: #34 (P3a), #35 (P3b1), #36 (tách gói tải), #37 (nguồn canvas Design), #38 (nền tảng phối hợp).
- Luật 04d–04g đã vào spec trong PR đang mở; thư mục `docs/phoi-hop/luat-cho-dua-vao-spec/` đã xoá trong PR đó.
- `scripts/bundle-size.ts` (`npm run size`); bộ seed lớn `supabase/seed-lon.sql` (`npm run db:seed-lon`).
- `main` chưa bắt buộc PR (GitHub Free không cho bật); chỉ do em tuân thủ CLAUDE.md.
