# Nhật ký Claude Code (cập nhật 18/10/2026, 15:30)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang.)

## Đang làm
- Vừa gộp #39 (luật 17/10 vào spec) và #40 (bàn giao 17/10). Không PR mở. Bắt đầu PR 5 Đăng nhập (5a trước; anh OK đề xuất 18/10).

## Đã chốt (chưa vào repo)
- Anh OK 18/10: PR 5 theo đề xuất (giữ trang đặt mật khẩu mới nhưng không dẫn tới; sửa bản đồ CHUNG-04, 05, 08 cho khớp thiết kế); bốn câu P3b2 như em đề xuất (không chặn tạo cơ hội theo C4C; sửa học sinh ở cơ hội = sửa hồ sơ học sinh; phụ huynh khớp SĐT khác tên: dùng hồ sơ cũ không ghi đè tên; học sinh trùng tên khác năm sinh = hai hồ sơ); **bảng quyền phiên bản 4** (17 ô Phụ huynh, Học sinh): nạp trong P3b2a.
- Mục chờ anh quyết, chưa thành luật (ghi chú ở `docs/spec/04` mục 13): R-GD-07, R-GD-13 (một phiếu tái tục mỗi ghi danh), ticket chọn nhiều ghi danh, R-GIO-03/04, spec 02 mục 3, 6, 7, chặn môn theo khối khi tạo lớp.
- Thứ tự: PR 5 (5a, 5b, 5c), PR 5a (Trang chủ), P3b2a (Cơ hội, kèm ma trận v4), P3b2b (Phiếu), P3b3, P3c đến P3f.

## PR 5a (18/10)
- Dựng khung đăng nhập hai cột (cột giới thiệu + thẻ), CHUNG-01/06, hai bước (CHUNG-02), thiết lập 2 bước (CHUNG-03) theo P1 v4. Chữ lỗi lấy theo thiết kế ở giao diện; Edge Function giữ nguyên.
- Thêm ngoài đề xuất: hàm công khai `public.login_branch_names()` (migration 027, chỉ mã và tên cơ sở dạy học đang hoạt động) cho cột giới thiệu.
- Nền động chưa làm (5c); robot đứng yên.

## Đang chờ ai
- **Anh Trường:** ngưỡng dung lượng gói tải (đo: trang đầu CRM 235 KB nén, CI chỉ báo số); hạn xử lý ticket chăm sóc tháng (khi có màn Cấu hình).
- **Claude Chat:** viết đè `docs/nhat-ky/chat.md` (luật 04d–04g đã vào spec).
- **Claude Design:** cụm Lớp trên canvas gốc P5b (xem `docs/nhat-ky/design.md`).

## File và link mới
- Đã gộp: #34 (P3a), #35 (P3b1), #36 (tách gói tải), #37 (nguồn canvas Design), #38 (nền tảng phối hợp), #39 (luật 17/10), #40 (bàn giao 17/10).
- Còn việc nhỏ: kiểm lại TS18, TS19 của P4 (bản chép cũ trong `design/nguon-canvas/p4-hmt-platform/`).
- `scripts/bundle-size.ts` (`npm run size`); bộ seed lớn `supabase/seed-lon.sql` (`npm run db:seed-lon`).
- `main` chưa bắt buộc PR (GitHub Free không cho bật); chỉ do em tuân thủ CLAUDE.md.
