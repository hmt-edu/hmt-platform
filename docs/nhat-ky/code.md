# Nhật ký Claude Code (cập nhật 18/10/2026, 17:00)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang.)

## Đang làm
- Vừa gộp #41 đến #49 (#48, #49: chốt giờ test, dung lượng, R-CRM-36, CLAUDE.md). PR docs R-CRM-37 + chốt P3b3 chờ OK; kế hoạch P3b3 gửi anh duyệt trước khi code.

## Đã chốt (chưa vào repo)
- Anh OK 18/10: PR 5 theo đề xuất (giữ trang đặt mật khẩu mới nhưng không dẫn tới; sửa bản đồ CHUNG-04, 05, 08 cho khớp thiết kế); bốn câu P3b2 như em đề xuất (không chặn tạo cơ hội theo C4C; sửa học sinh ở cơ hội = sửa hồ sơ học sinh; phụ huynh khớp SĐT khác tên: dùng hồ sơ cũ không ghi đè tên; học sinh trùng tên khác năm sinh = hai hồ sơ); **bảng quyền phiên bản 4** (17 ô Phụ huynh, Học sinh): nạp trong P3b2a.
- Mục chờ anh quyết, chưa thành luật (ghi chú ở `docs/spec/04` mục 13): R-GD-07, R-GD-13 (một phiếu tái tục mỗi ghi danh), ticket chọn nhiều ghi danh, R-GIO-03/04, spec 02 mục 3, 6, 7, chặn môn theo khối khi tạo lớp.
- Thứ tự: PR 5 (5a, 5b, 5c), PR 5a (Trang chủ), P3b2a (Cơ hội, kèm ma trận v4), P3b2b (Phiếu), P3b3, P3c đến P3f.

## PR 5a (18/10, đã gộp #41)
- Dựng khung đăng nhập hai cột (cột giới thiệu + thẻ), CHUNG-01/06, hai bước (CHUNG-02), thiết lập 2 bước (CHUNG-03) theo P1 v4. Chữ lỗi lấy theo thiết kế ở giao diện; Edge Function giữ nguyên.
- Thêm ngoài đề xuất: hàm công khai `public.login_branch_names()` (migration 027, chỉ mã và tên cơ sở dạy học đang hoạt động) cho cột giới thiệu.
- Nền động chưa làm (5c); robot đứng yên.

## PR 5b (18/10)
- CHUNG-04 chỉ còn hướng dẫn liên hệ quản trị viên, không gửi email (anh OK 18/10). CHUNG-05 giữ trang, không dẫn tới. CHUNG-07, 08, 09, 25 theo P1 v4.
- Hết phiên (DN09): số thời gian lấy từ tham số có sẵn `staff_idle_logout_minutes` (60), `teacher_idle_logout_minutes`, `student_idle_logout_minutes` (10080), theo `idleGroup`; hiện phút, giờ hoặc ngày. Số phút lưu cùng lúc bị đăng xuất (`sessionEnd.ts`), không tạo tham số mới.
- Sửa lỗi của 5a: nền cam cột giới thiệu không hiện (khai báo `background-image` lẫn màu nên trình duyệt bỏ cả dòng); có bài kiểm tái hiện.

## PR Trang chủ theo vai trò (18/10)
- `src/pages/home/`: `CrmHome` (khung K09b), `homeBlocks` (khối khai báo theo module, quyền, công tắc tính năng; thêm phân hệ mới = thêm một dòng), `useAppointmentsToday` (hai lần gọi: `list_appointments` và `appointment_overdue_count`, không thêm migration).
- "Hôm nay" tính theo Asia/Ho_Chi_Minh (`src/lib/vnDay.ts`), không theo múi giờ trình duyệt. Thẻ QUÁ HẠN dùng mốc đầu ngày hôm nay; hàm đó chỉ có tham số "của tôi", nên thẻ này không theo ô chọn cơ sở.
- Xem thử vai trò: chỉ người có quyền Quản trị; đổi khối nào hiện, số liệu vẫn theo quyền thật.
- Ngoài ra: bỏ đuôi `?ly-do=tam-chan`; bài so sánh ảnh mặc định không ghi đè `docs/so-sanh` (đặt `SO_SANH_GHI_VAO_REPO=1` mới ghi).

## PR P3b2a Cơ hội (18/10)
- Migration `20261018000028` (bảng cơ hội, lịch hẹn gắn cơ hội, hàm tạo, sửa, đổi giai đoạn, danh sách, Kanban; tìm hoặc tạo phụ huynh, học sinh). Migration `029` (ma trận v4) CHƯA viết vào repo, chờ OK riêng.
- Điểm nối với phiếu: `opportunity_test_state`, `opportunity_l5_substage` (thân tạm); P3b2b thay thân. Hoãn: R-CRM-16 (chặn tạo đơn), 17, 18.
- Phát hiện khi đo: CTE dùng hai lần bị Postgres cho "materialized" làm danh sách quét cả bảng; đã sửa `list_leads`, `list_appointments`, `list_opportunities` bằng `not materialized`.

## PR Ma trận quyền phiên bản 4 (18/10)
- Migration `20261018000029`: 17 ô Phụ huynh, Học sinh (bỏ Tạo 8, bỏ Xuất Trưởng cơ sở 2, Xem toàn hệ thống 6, Kế toán Xem Phụ huynh 1). Bài pgTAP 021; chỉnh 017 (phụ huynh cơ sở khác nay đọc được), 018 (đếm quyền, số phiên bản).

## PR P3b2b Phiếu kiểm tra (18/10)
- Migration `20261018000030`: bảng `student_test`, lịch hẹn gắn phiếu (`student_test_id`, `is_auto_reminder`, `auto_scheduled_at`), hàm tạo, đổi lịch, sửa, bắt đầu, nộp bài, nhập kết quả, hoàn thành, lùi bước, huỷ, mở lại; danh sách, Kanban; thay thân `opportunity_test_state`, `opportunity_l5_substage`.
- Quyền theo phạm vi của phiếu (`test_scope_ok`): toàn hệ thống, cơ sở của cơ hội, được phân công (giáo viên chấm, người phụ trách). Lỗi bắt được nhờ bài kiểm: so với null cho null chứ không false, nên giáo viên chưa phân công lọt qua kiểm quyền.
- Kiểm bản vẽ TS15: Khối chọn được (không khoá). Đã sửa bản đồ TS-15 và dòng tương ứng ở `dac-ta/P3-tuyen-sinh.md`.

## R-CRM-36 đối chiếu (18/10)
- R-CRM-36 (cơ hội mới luôn bắt đầu ở L1) đã vào spec. `create_opportunity` (migration 028) khớp: câu `insert` ghi cứng `stage_code = 'L1'`, `substage_code` trống; `p_data` không có đường nào đặt giai đoạn (chỉ đọc nhu cầu, học sinh, người phụ trách, người hỗ trợ). Thêm bài pgTAP: truyền giai đoạn, nhóm con, lý do bỏ qua trong `p_data` vẫn ra L1.
- **Màn tạo cơ hội:** chưa dựng (P3d); bản vẽ TS-06 chỉ có hộp cảnh báo "lead đã có cơ hội", không có ô giai đoạn. Khi dựng màn tạo, không đặt ô chọn giai đoạn.

## Đang chờ ai
- **Anh Trường:** ngưỡng dung lượng gói tải (đo: trang đầu CRM 235 KB nén, CI chỉ báo số); hạn xử lý ticket chăm sóc tháng (khi có màn Cấu hình).
- **Claude Chat:** viết đè `docs/nhat-ky/chat.md` (luật 04d–04g đã vào spec).
- **Claude Design:** cụm Lớp trên canvas gốc P5b (xem `docs/nhat-ky/design.md`).

## File và link mới
- Đã gộp: #47, #46, #45, #44, #43, #42, #41 (PR 5a), #34 (P3a), #35 (P3b1), #36 (tách gói tải), #37 (nguồn canvas Design), #38 (nền tảng phối hợp), #39 (luật 17/10), #40 (bàn giao 17/10).
- Còn việc nhỏ: kiểm lại TS18, TS19 của P4 (bản chép cũ trong `design/nguon-canvas/p4-hmt-platform/`).
- `scripts/bundle-size.ts` (`npm run size`); bộ seed lớn `supabase/seed-lon.sql` (`npm run db:seed-lon`).
- `main` chưa bắt buộc PR (GitHub Free không cho bật); chỉ do em tuân thủ CLAUDE.md.
