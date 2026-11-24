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

## Bổ sung 18/11/2026 (migration 235 đến 459): hàm, bảng, cờ mới và các bản sửa của Soát

Mọi PR dưới đây là PR của Code D; cột «PR» ghi số PR. Cờ mặc định TẮT.

| Mig | PR | Việc | Cờ | Bảng, hàm | Chi tiết |
| --- | --- | --- | --- | --- | --- |
| 235 | #86 | Hàm áp dụng hoàn phí, dừng học cho phiếu Aftersale (nội bộ) | `HOAN_PHI`, `DUNG_HOC` (kiểm trong hàm) | `apply_refund_request`, `apply_enrollment_stop`; lõi `finish_refund_request`, `finish_enrollment_stop` | `ap-dung-phieu-cho-code-b.md` |
| 450 | #89 | Sửa T1, T2: hoàn toàn bộ trừ tiền đã hoàn; giờ tặng không hoàn | không | `compute_refund` (đổi thân) | `hoan-phi.md` |
| 451 | #91 | Sửa T3, T4: chặn huỷ đơn còn ghi danh; không cấp lại giờ ghi danh đã Dừng, Hoàn phí | không | `cancel_order`, `sync_enrollment_hours` (đổi thân) | `hoan-phi.md` |
| 452 | #95, #101 | Đọc phiếu chi TC-10, TC-11, bản in TC-12 | quyền Phiếu thu · Xem | `list_payment_vouchers`, `get_payment_voucher` | `hoan-phi-ban-ghi.md` |
| 453 | #101 | Đọc số dư khách hàng TC-14 | quyền Phiếu thu · Xem | `list_customer_balances`, `get_customer_balance_history` | `hoan-phi-ban-ghi.md` |
| 454 | #110 | Cấn số dư vào đơn TC-16 | `customer_balance_apply_enabled` | `apply_customer_balance_to_order`; cột `money_in.balance_entry_id`; sửa `reverse_money_in`, `order_has_receipt` | `hoan-phi-ban-ghi.md` |
| 455 | #113 | Sửa Q1, Q1b: chỉ Kế toán có Kế toán · Duyệt; cùng người không duyệt hai bước | không | trigger trên `permission`, `receipt`, `refund_request`, `enrollment_stop` | `phan-quyen.md` |
| 456 | #117 | Sửa T5: dừng học trừ giờ đã hoàn một phần, giờ tặng không thành tiền | không | `compute_stop_balance` (đổi thân) | `dung-hoc-so-du.md` |
| 457 | #123 | Sửa P1 (phần chính sách RLS): bọc `(select auth.uid())` | không | bốn chính sách: `user_account_read`, `user_role_read`, `notification_read_own`, `saved_filter_read` | `phan-quyen.md` |
| 458 | #130 | Sửa T8: người tạo, kể cả Admin, không tự duyệt bước quản lý | không | `approve_refund_manager`, `approve_stop_manager` (đổi thân) | `hoan-phi.md` |
| 459 | #135 | Sửa T6: hoàn phí, dừng học bắt buộc qua ticket (R-V2-24A) | `refund_direct_without_ticket_enabled` | `assert_refund_ticket`; `create_refund_request`, `create_enrollment_stop` (thêm một lệnh kiểm) | `hoan-phi.md` |
| 663 | D-23-49 | Ghi danh «Chờ xếp lớp» được hoàn phí và dừng học (anh chốt 24/11, phương án A): thêm `CHO_XEP_LOP` vào danh sách tình trạng cho phép ở `create_refund_request`, `apply_refund_request`, `finish_refund_request`, `create_enrollment_stop`, `apply_enrollment_stop`, `finish_enrollment_stop`, `create_ticket_task`, trigger `ticket_task_check_scope`, `get_task_form_options`. Không đổi công thức tiền (giờ đã học = 0 nên hoàn = tiền đã đóng − phí xử lý); chặn «đã có hoàn dở» (659, 662) giữ nguyên; ghi danh đã Dừng, Hoàn phí, Kết thúc, Huỷ vẫn bị chặn | `HOAN_PHI`, `DUNG_HOC` | `HMT_HOAN_PHI_GHI_DANH_SAI`, `HMT_DUNG_HOC_GHI_DANH_SAI` |
| 460–463 | #163–#166 | Sửa R1 của Soát: chính sách đọc dùng phạm vi `CO_SO` thay «khác rỗng» (phạm vi hẹp không đọc cả cơ sở); 460 phiếu thu, tiền vào · 461 đơn hàng · 462 báo giá, tái tục · 463 lead, cơ hội, lịch hẹn | không | 18 chính sách đọc (`alter policy`); không đổi hàm | `phan-quyen.md` |
| 464 | #171 | Ba hàm danh sách đọc cỡ trang và trần từ tham số `list_page_size_*` thay vì ghi cứng 50 và 100 | không | `list_expiring_enrollments`, `session_day_attendance`, `list_curriculum_frames` (đổi một dòng) | không |
| (bài kiểm) | #158, #179 | Bổ sung ca bị chặn cho hàm tiền ra: quyền xem, ghi nhận chi, cơ sở khác, hàm nội bộ (461); thêm ticket giả và ca chặn T6 | không | bài `461_bao_phu_ham_tien_ra_bi_chan` | không |
| (tài liệu) | #137, #146, #159, #168 | Bảng hàm này; CI tách job (`docs/van-hanh/ci-tach-job.md`); mã lỗi `HMT_*` lane D (`ma-loi-hmt-lane-d.md`); đề xuất R2 Học sinh đọc cấu hình (`docs/de-xuat/r2-hoc-sinh-doc-cau-hinh.md`, chờ duyệt) | không | không | các tệp kể trên |
| (không migration) | #127 | Sửa P2: cache lâu `/assets/*` | không | tệp `public/_headers` | không |
| (không migration) | #122 | Đề xuất lịch kết thúc bảo lưu đã tới hạn (chờ anh duyệt) | chưa | không | `de-xuat/lich-ket-thuc-bao-luu.md` |

**Đã gộp vào `main` (18/11):** #86 (235), #89 (450), #91 (451), #101 (452, 453), #113 (455), #117 (456), #130 (458), #135 (459), #123 (457), #127, #122, #158, #179. **Còn mở:** #110 (454), #137, #146, #159, #163–#166, #168, #171. Lưu ý đã xảy ra: #135 (bắt buộc ticket) làm bài pgTAP gọi `create_refund_request`, `create_enrollment_stop` phải có ticket giả (đã sửa ở 450, 452, 456, 458, 461); #113 (hai người duyệt khác nhau) buộc hàm áp dụng của #86 không ghi `manager_by`.
