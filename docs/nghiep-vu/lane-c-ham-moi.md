# Hàm Postgres mới của lane C (thu chi, tái tục): mục lục theo luật

Cập nhật 18/11/2026 (thẻ C12; CLAUDE.md mục «Quy ước viết nghiệp vụ bằng SQL» số 8). Chi tiết từng luồng nằm ở các tệp riêng trong thư mục này; bảng dưới là mục lục để tra nhanh. Mọi hàm kiểm quyền bên trong (`assert_can`), kiểm công tắc Bán hàng, một giao dịch.

## R-V2-44 «Chuyển người duyệt» (migration 400, PR #82; cờ `approver_reassign_enabled` TẮT mặc định)

| Hàm                                                                  | Ai gọi                                 | Việc                                                                                                                                                                                                                                                                                                                       |
| -------------------------------------------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app.reassign_approver(loại, id, người nhận, mã lý do, ghi chú)`     | Admin đã xác thực hai bước             | Đổi `assigned_approver_id` của đơn `DA_TRINH` hoặc phiếu thu `DA_GUI` route `QUAN_LY`. Không duyệt, không từ chối thay (R-HT-01). Chỉ khi người đã chốt bị khoá, mất quyền Duyệt hoặc quá `approver_reassign_after_hours` (48). Lý do từ `REASSIGN_REASON`, «Khác» cần ghi chú. Lỗi có mã `HMT_...` và câu tiếng Việt. |
| `app.list_approver_candidates(loại, id)`                             | Admin                                  | Tối đa 50 người nhận hợp lệ cho hộp chọn.                                                                                                                                                                                                                                                                                 |
| `app.get_reassign_state(loại, id)`                                   | Admin                                  | Hiện nút hay không và vì sao người đã chốt không duyệt được.                                                                                                                                                                                                                                                               |
| `app.approver_candidate_problem`, `app.approver_unavailable_reason`  | Nội bộ (đã thu hồi quyền người dùng)   | Điều kiện người nhận; tình trạng người đã chốt.                                                                                                                                                                                                                                                                            |

## R-V2-15, R-TIEN-26 Thu nợ đầu kỳ (migration 251, 252, 253; cờ `opening_debt_receipt_enabled` TẮT mặc định)

`create_opening_debt_receipt`, `save_opening_debt_receipt`, `submit_opening_debt_receipt`, `approve_opening_debt_receipt` (Kế toán duyệt, không qua quản lý), `opening_debt_remaining` (theo phụ huynh), `opening_student_debt_remaining` (nội bộ, theo từng em), `opening_debt_by_student` (nợ từng em cho màn), trigger trần theo em; `reverse_money_in` và `list_money_in` xử lý khoản không đơn. Chi tiết: `bang-nhom-b-ban-hang-thu-chi.md`.

## R-GD-13 Phiếu tái tục (giữ lại theo R-V2-25 chốt lại 18/11), migration 410 đến 419

| Nhóm                                                                   | Hàm                                                                                                                                                                                                  |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Thao tác tay (410)                                                     | `create_upsale_ticket`, `assign_upsale_ticket`, `change_upsale_stage`, `update_upsale_notes`, `issue_upsale_code` (nội bộ)                                                                            |
| Đọc (414, 416, 419)                                                    | `list_upsale_tickets`, `upsale_board`, `upsale_filtered`, `upsale_ticket_row`, `get_upsale_ticket`, `list_upsale_assignees`, `preview_upsale_enrollment`, `create_upsale_ticket_from_enrollment`    |
| Tự sinh, đối soát (415; cờ `upsale_auto_generate_enabled` TẮT, cron chưa đăng ký) | `upsale_candidates` (nội bộ), `generate_upsale_tickets`, `sync_upsale_cron`                                                                                                              |
| Đơn từ phiếu (417, 418)                                                | `create_order_from_upsale_ticket`, `list_upsale_orders`, `reconcile_upsale_orders`, `list_upsale_order_options`                                                                                       |

Báo giá từ phiếu chưa làm: xem `bao-gia-tu-phieu-tai-tuc-de-xuat.md` (PR #107). Chi tiết luồng tái tục: `tt-a-phieu-tai-tuc.md` (có khi các PR TT vào main).

## Đang chờ gộp (cập nhật 19/11)
| PR | Hàm / việc |
|---|---|
| #82 | R-V2-44 (xem `chuyen-nguoi-duyet.md`) |
| #100, #102, #104 | tự sinh và đối soát (415), bản ghi TT-02 (416), đơn từ phiếu (417, 418), Kanban một lượt (419) |
| #155 | `receipt_expected_approver(phiếu)` (migration 420): người duyệt dự kiến và lý do chặn trình của phiếu thu Nháp (cùng cách `get_order.expected_*`); giao diện dòng chặn trình phiếu thu |
| #103 | giao diện Thu nợ đầu kỳ (không có hàm DB mới) |
