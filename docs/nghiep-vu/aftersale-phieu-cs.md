# Aftersale: phiếu nghiệp vụ và ticket, bổ sung sau lát A1 (Code B, 18/11/2026)

Bổ sung cho `aftersale-lat-dau.md` (ticket) và `aftersale-phieu-a1.md` (phiếu, migration 226). Hàm nào ở PR chưa gộp thì ghi rõ «chưa vào main». Luật: AS-03, AS-10, AS-13 (`docs/spec/de-xuat-luat-aftersale.md`), R-V2-23, R-V2-24, R-CS-02, R-CS-07, R-HT-01, R-TIEN-01.

## Danh sách và chi tiết phiếu (migration 260, 355)
- `app.list_ticket_tasks(bộ lọc, limit, offset)`: danh sách phiếu cho CSN-05, phân trang ở máy chủ (50 mặc định, 100 tối đa). Bộ lọc: `q` (mã phiếu hoặc mã ticket), `status_code`, `task_type`, `branch_id`, `cho_toi` (phiếu chờ người gọi duyệt, không phải người tạo), `cho_ke_toan`. Mỗi dòng: mã, loại, trạng thái, cấp hiện tại/tổng, vai duyệt kế tiếp, mã ticket gốc, học sinh, cơ sở, ngày tạo, **hạn xử lý của ticket gốc `due_at` (migration 355)**. Từ 355, hàng «Chờ tôi duyệt» ở cấp kế toán chỉ tính vai **Kế toán** (Admin không duyệt tiền, R-HT-01). RLS lọc theo phạm vi cơ sở.
- `app.get_ticket_task(id)`: chi tiết phiếu, nhật ký, ticket gốc; không thấy thì `HMT_KHONG_TIM_THAY`.

## Ticket: các khoá trả về (migration 351, 352, 261)
- `app.ticket_row(ticket)` (nội bộ, dùng chung danh sách và chi tiết): thêm `group_name` (nhóm của nhóm con) và `student_name` (migration 351) cho cột «Nhóm · Nhóm con», «Học sinh» của CSN-01.
- `app.get_ticket(id)`: thêm `class_code`, `enrollment_code`, `related_ticket_code` (migration 352) cho khung Liên kết của CSN-03; từ 261 trả `business_type` (loại phiếu của nhóm con) và danh sách phiếu của ticket. Không `security definer`: RLS áp dụng, không thấy thì `HMT_KHONG_TIM_THAY`.

## Hàm nội bộ (không cấp cho giao diện)
- `app.ticket_task_log(phiếu, loại sự kiện, từ, đến, ghi chú)`: ghi một dòng nhật ký phiếu (`ticket_task_event`, chỉ thêm).
- `app.ticket_task_finish_ticket(ticket, kết quả)`: phiếu Đã thực hiện hoặc Từ chối thì ticket có nghiệp vụ sang Đã xử lý, người phụ trách đóng tay (AS-03).
- `app.ticket_resolve_hours(loại, mức độ, nhóm con)`: hạn xử lý (giờ): hạn riêng của nhóm con nếu có, không thì bảng loại × mức độ (AS-07).
- `app.tg_ticket_event_append_only()`: trigger chặn sửa và xoá nhật ký ticket.

## Chưa vào main lúc viết (PR #81, nhánh `code-b/phieu-bao-luu-chuyen-lop`)
- `app.get_task_form_options(ticket)` (migration 350): tuỳ chọn cho biểu mẫu tạo phiếu Bảo lưu, Chuyển lớp: ghi danh của học sinh gắn ticket (kèm lớp hiện tại, giờ còn lại), lý do bảo lưu (`HOLD_REASON`), lý do và loại chuyển lớp (`TRANSFER_REASON`), lớp đã duyệt cùng cơ sở. Chỉ đọc; kiểm AFTERSALE và Ticket · Sửa.
- `app.create_ticket_task`, `app.execute_ticket_task` (migration 262): phiếu **Bảo lưu** và **Chuyển lớp** kiểm dữ liệu lúc tạo (ghi danh của học sinh ticket, cùng cơ sở, lý do; Bảo lưu số tháng từ 1; Chuyển lớp cần lớp mới, ngày, loại) và thực hiện thẳng bằng `app.apply_enrollment_hold`, `app.apply_class_transfer` (Code D, migration 234), không duyệt lần hai (R-V2-24). Chuyển cơ sở chặn lúc tạo (`HMT_PHIEU_CHUA_LAM`, cần quản lý hai cơ sở, R-CS-07).
- Migration 353: phiếu **Hoàn học phí** thực hiện thẳng bằng `app.apply_refund_request` (migration 235): `execute_ticket_task` kiểm dữ liệu phiếu lúc thực hiện (ghi danh, lý do, hình thức TOAN_BO/MOT_PHAN, MOT_PHAN cần số giờ > 0), gắn mã ticket, ghi người duyệt cấp 1 và cấp 2 lấy từ nhật ký phiếu vào yêu cầu hoàn phí (`manager_by`, `accountant_by`). `apply_refund_request` thêm hai tham số `p_manager_by`, `p_accountant_by` (mặc định null). **Siết cấp duyệt** ở `approve_ticket_task`: cấp kế toán chỉ vai ACCOUNTANT; cấp quản lý của phiếu có cấp kế toán chỉ BRANCH_MANAGER; một người không duyệt hai cấp của cùng một phiếu (`HMT_PHIEU_MOT_NGUOI_HAI_CAP`). Kiểm thử: `354_phieu_hoan_phi.test.sql`.

## Còn lại
- Chưa nối vào phiếu: Dừng học (`apply_enrollment_stop`, cùng luật cấp duyệt như Hoàn học phí), Chuyển phí, Đổi lịch học bù, Chuyển cơ sở.
- Giao diện tạo phiếu Hoàn học phí và gia hạn bảo lưu từ ticket chưa làm (cần `REFUND_REASON` trong `get_task_form_options`).
