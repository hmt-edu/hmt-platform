# Tổng hợp: hàm, bảng, cờ của Code D (migration 210 đến 233)

Code D, 16/11/2026. Mỗi cụm có tài liệu riêng (cột «Chi tiết»). Mọi cờ **mặc định TẮT** (không có dòng = tắt); Chat bật khi Tester ĐẠT. Chưa có giao diện cho cụm nào.

| Mig | Cụm | Cờ | Bảng / view | Hàm giao diện được gọi | Chi tiết |
| --- | --- | --- | --- | --- | --- |
| 210 | Chuyển lớp, chuyển cơ sở | `CHUYEN_LOP` | `class_transfer` | `create/submit/approve/reject/cancel/execute_class_transfer` | `chuyen-lop.md` |
| 211 | Báo cáo tổng quan BC-01 | (quyền Báo cáo · Xem) | không | `report_overview(từ, đến, cơ sở)` | `bao-cao-tong-quan.md` |
| 212 | Tính hoàn phí | không | không | `compute_refund` (nội bộ) | `hoan-phi.md` |
| 213 | Cảnh báo xếp lớp từ đơn (Q1) | không | cột `enrollment.placement_warning_code`, sự kiện đơn `CANH_BAO_XEP_LOP` | `create_enrollments_for_order` (thay bản 101) | `canh-bao-xep-lop-don.md` |
| 214 | View báo cáo BC-02, 03, 04, 06 | không | view `report.lead_funnel`, `revenue_by_session`, `hours_fund`, `class_attendance`, `enrollment_unit_price` | đọc view | `bao-cao-view.md` |
| 215 | Bảo lưu | `BAO_LUU` | `enrollment_hold` | `create/submit/approve/reject/cancel/end_enrollment_hold` | `bao-luu.md` |
| 230 | View BC-10 ticket | không | view `report.ticket_summary` | đọc view | `bao-cao-view.md` |
| 231 | Hoàn phí, phiếu chi PC | `HOAN_PHI` | `refund_request`, `payment_voucher` | `create/submit/cancel/reject_refund_request`, `approve_refund_manager`, `approve_refund_accountant`, `pay_payment_voucher` | `hoan-phi-ban-ghi.md` |
| 232 | Dừng học giữ số dư | `DUNG_HOC` | `enrollment_stop`; mở rộng `customer_balance_entry` (bảng của migration 217) | `create/submit/cancel/reject_enrollment_stop`, `approve_stop_manager`, `approve_stop_accountant`, `customer_balance` | `dung-hoc-so-du.md` |
| 233 | View BC-07 BTVN | không | view `report.homework_summary` | đọc view | `bao-cao-view.md` |

## Chỗ cần chốt (chưa làm)

1. **Nối với phiếu nghiệp vụ Aftersale (Code B, migration 226 `ticket_task`).** Phiếu của B đã có cấp duyệt theo loại (quản lý cơ sở; Dừng học, Hoàn phí, Chuyển phí thêm kế toán) và hàm `execute_ticket_task` chưa thực hiện được các loại Chuyển lớp, Bảo lưu, Dừng học, Hoàn phí. Bản ghi của D cũng có bước duyệt riêng (R-V2-24: «việc duyệt nằm ở bản ghi nghiệp vụ»). Nếu dùng cả hai thì duyệt hai lần. Đề xuất: khi phiếu của B đã duyệt đủ cấp, `execute_ticket_task` gọi một hàm «áp dụng» của D (tạo bản ghi ở trạng thái đã duyệt, chạy phần ghi sổ giờ, số dư, phiếu chi) và **bỏ bước duyệt thứ hai**; bản ghi của D khi tạo thẳng (không qua ticket) vẫn giữ duyệt riêng cho vận hành nội bộ hoặc bị chặn theo R-CS-02. Cần Chat và Code B chốt.
2. **«Dùng số dư» cho đơn mới (TC-16):** `money_in.receipt_id` bắt buộc nên phải đổi bảng lõi tiền; xem đề xuất trong thư Code D.
3. **Dừng sinh phiếu tái tục khi bảo lưu (R-GD-13)** và đóng phiếu khi dừng, chuyển phiếu theo lớp mới: chờ bảng phiếu tái tục.
4. **Lịch pg_cron** cho `end_expired_enrollment_holds` (bảo lưu hết hạn): chưa đăng ký, chờ anh duyệt.
5. **Giao diện** cho mọi cụm: chờ khuôn.

## Bổ sung (migration 234): hàm áp dụng cho phiếu nghiệp vụ Aftersale

`apply_enrollment_hold(...)` và `apply_class_transfer(...)`: tạo bản ghi bảo lưu hoặc chuyển lớp ở trạng thái **đã duyệt** và thực hiện ngay trong một giao dịch, dùng đúng luật của bản tạo thường (R-GD-09, R-GD-10, cờ `BAO_LUU`, `CHUYEN_LOP`). **Nội bộ** (không cấp cho giao diện), **chưa nối** vào `execute_ticket_task` của Code B: chờ Chat và Code B chốt mục «Chỗ cần chốt» số 1 (phiếu đã duyệt đủ cấp thì không duyệt lần hai ở bản ghi). Hoàn phí và dừng học làm tương tự ở bước sau khi có chốt, vì còn kế toán duyệt và phiếu chi.
