# Hàm còn thiếu mô tả, bổ sung sau đối chiếu migration 300–599 (Code B, 19/11/2026, thẻ B20)

Cách đối chiếu: liệt kê mọi hàm `app.*`, `report.*` tạo ở migration 300–349, 400–467, 500–599 rồi tìm tên trong `docs/nghiep-vu/*.md`. Kết quả: 10 hàm chưa có mô tả (các hàm còn lại đã có ở tài liệu lane tương ứng). Mô tả dưới đây rút từ chú thích đầu hàm trong migration; hàm nội bộ đã thu hồi quyền gọi của giao diện (`revoke`) hoặc là trigger.

## 301 (A9, hâm nóng đăng nhập)
- `app.login_warm_tick(p_now timestamptz default now())`: một nhịp hâm nóng Function đăng nhập. Chỉ `pg_cron` (postgres) gọi, lịch `login-warm` mỗi phút; không cấp cho giao diện. Đọc bốn tham số: `login_warm_url`, `login_warm_interval_minutes`, `login_warm_from_minute`, `login_warm_to_minute`. Kết quả (chữ, để thử và đọc nhật ký cron): `TAT` (chưa điền địa chỉ), `DIA_CHI_SAI` (không kết thúc bằng `/functions/v1/login`), `NGOAI_GIO`, `CHUA_DEN_LUOT` (không đúng chu kỳ), `DA_GOI` (đã gọi). Mặc định tắt; không SQL động.

## 302 (GV-07X, xuất nhận xét)
- `app.review_exported_students(p_session_id uuid)`: trả mảng mã học sinh đã đặt cờ Đã xuất của buổi. Ai gọi: người xem được điểm danh của buổi (giáo viên, trợ giảng được phân công; vận hành), cùng phạm vi với `app.set_review_exported`.

## 303 (A25, loại kiểm tra trong yêu cầu buổi)
- `app.session_deducts_hours(p_session app.class_session)`: buổi có trừ giờ không = loại buổi có trừ giờ **và** không đặt `no_charge` (kiểm tra bù không trừ giờ). Thay `app.session_type_deducts_hours(loại)` ở nơi tính giờ theo từng buổi cụ thể.
- `app.set_request_exam(p_request_id, p_enabled, p_scope, p_max_score, p_mode, …)`: đặt hoặc bỏ loại Kiểm tra và cấu hình điểm (phạm vi, điểm tối đa, cách nhập, tối đa ba nhóm điểm) cho yêu cầu buổi **Nháp**. Ai gọi: người có Buổi học · Tạo ở cơ sở của yêu cầu (người tạo yêu cầu). `p_enabled = false` thì xoá cấu hình (về loại theo yêu cầu). Luật như `app.set_exam_config` (R-V2-20).

## 410, 414 (TT, phiếu tái tục)
- `app.upsale_add_event(p_ticket_id, p_type, p_from, p_to, p_note)`: ghi một dòng nhật ký phiếu tái tục (`upsale_ticket_event`). Nội bộ.
- `app.tg_upsale_ticket_event_append_only()`: trigger chặn sửa nhật ký phiếu tái tục; báo `HMT_NHAT_KY_CHI_THEM` («chỉ thêm dòng, không sửa»).
- `app.upsale_target_of_enrollment(p_code text)`: tìm (học sinh, lớp hiện tại) từ mã ghi danh; hàm nội bộ cho hai hàm tạo phiếu tái tục theo ghi danh (migration 414).

## 455 (Q1, Admin không duyệt tiền)
- `app.tg_permission_admin_no_money_approval()`: trigger trên `app.permission` (trước insert, update): ô `ACCOUNTING × DUYET` đang bật chỉ được thuộc vai trò `ACCOUNTANT`; ngược lại lỗi `HMT_CHI_KE_TOAN_DUYET_TIEN`. Chặn mọi đường ghi bảng quyền (hàm lưu ma trận, `set_permission`, SQL). R-HT-01.
- `app.tg_receipt_two_approvers()`, `app.tg_refund_two_approvers()`: trigger chặn một người duyệt cả hai bước (quản lý và kế toán) của phiếu thu, yêu cầu hoàn phí (và yêu cầu dừng học cùng đợt migration). R-TIEN-01. Phiếu thu: bước quản lý có thể không có người (tự duyệt theo tuyến) thì không so.

## Còn lại
- Không tìm thấy hàm nào khác thiếu mô tả trong các dải trên. Dải 1–299 và 350–399 nằm ngoài phạm vi đối chiếu này (hàm lane B 350–399 xem `aftersale-phieu-cs.md`).
