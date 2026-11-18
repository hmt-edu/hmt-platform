# TT-A Phiếu tái tục: nền dữ liệu và thao tác tay (migration 410)

Luật: R-GD-13 (spec 04), R-V2-25 chốt lại 18/11. Đề xuất chia PR: `tt-phieu-tai-tuc-de-xuat.md`.

| Hàm | Ai gọi | Việc |
|---|---|---|
| `app.create_upsale_ticket(student, class, note)` | Quyền UPSALE · Tạo ở cơ sở của lớp | Tạo phiếu tay (TT-03), L1B; học sinh phải đang học ở lớp; tối đa một phiếu đang mở cho mỗi (học sinh, lớp). Lỗi: `HMT_HOC_SINH_KHONG_O_LOP`, `HMT_DA_CO_PHIEU_TAI_TUC` |
| `app.assign_upsale_ticket(id, owner)` | UPSALE · Giao việc | Giao người phụ trách (cùng cơ sở); phiếu L5, L8 không giao |
| `app.change_upsale_stage(id, to, reason, note)` | UPSALE · Sửa | Đổi tay giữa L1..L4, sang L6 hoặc L5 (bắt buộc lý do `RENEWAL_LOST_REASON`, «Khác» cần ghi chú). L7, L8 do hàm báo giá, đơn (TT-D). Lỗi: `HMT_GIAI_DOAN_KHONG_HOP_LE`, `HMT_PHIEU_KHONG_DOI_TAY`, `HMT_LY_DO_THIEU` |
| `app.update_upsale_notes(id, goal, roadmap)` | UPSALE · Sửa | Sửa hai ô tự do, nhật ký ghi tên ô đổi |
| `app.issue_upsale_code()` | Nội bộ | Cấp mã `TT` + 6 số (không mở cho người dùng) |

Bảng: `app.upsale_ticket`, `app.upsale_ticket_event` (chỉ thêm). RLS đọc theo quyền UPSALE · Xem (toàn hệ thống hoặc cơ sở của người xem). Ghi chỉ qua hàm. Chưa có: tự sinh theo ngưỡng (TT-B), danh sách, Kanban, bản ghi (TT-C, TT-D), đối chiếu (TT-E).

## TT-C (migration 414): đọc danh sách, Kanban, tạo theo mã ghi danh

| Hàm | Ai gọi | Việc |
|---|---|---|
| `app.list_upsale_tickets(bộ lọc, số dòng, bỏ qua)` | Người có quyền UPSALE · Xem (RLS lọc) | Danh sách phân trang ở máy chủ. Lọc: `stage_code`, `branch_id`, `owner` (mine, unassigned), `campaign_month` (YYYY-MM theo ngày hết giờ dự kiến), `risk`, `q` |
| `app.upsale_board(bộ lọc, số dòng mỗi cột)` | như trên | Kanban L1..L8 một lần gọi |
| `app.preview_upsale_enrollment(mã ghi danh)` | UPSALE · Tạo | Xem học sinh, lớp, số ghi danh, phiếu đang mở trước khi tạo |
| `app.create_upsale_ticket_from_enrollment(mã ghi danh, ghi chú)` | UPSALE · Tạo | Hộp «Tạo phiếu tái tục thủ công» (TT-03): tìm (học sinh, lớp) từ ghi danh rồi dùng `create_upsale_ticket` |
| `app.list_upsale_assignees(phiếu)` | UPSALE · Giao việc | Người nhận giao của cơ sở phiếu |

Nhãn «Tái tục MM/YYYY» tính từ ngày hết giờ dự kiến, không có bản ghi chiến dịch. Giao diện: `src/pages/tai-tuc/` (danh sách, Kanban, hộp Tạo, hộp Giao); bản ghi TT-02 làm ở TT-D.

## TT-B (migration 415): tự sinh và đối soát

- `app.upsale_candidates()` (nội bộ, KHÔNG mở cho người dùng): mỗi (học sinh, lớp) có ghi danh còn hiệu lực (Đã xếp lớp, Đang học) kèm giờ còn, `expected_end_date`, `risk_flag`. Cùng cách tính với GD-07: hết giờ dự kiến = hôm nay + giờ còn / giờ học mỗi tuần của lớp × 7 ngày. **Báo cáo TT-04 (Code F) gọi hàm này từ hàm security definer của mình** để lấy «ngày hết giờ dự kiến».
- `app.generate_upsale_tickets()`: cron hoặc Admin (hai bước). Chỉ cơ sở bật `upsale_auto_generate_enabled` (tắt mặc định) và công tắc Bán hàng. Đối soát: dừng học đóng phiếu (L5, lý do `DUNG_HOC`), chuyển lớp chuyển phiếu; cập nhật giờ còn, ngày hết giờ, cờ rủi ro của phiếu mở L1..L4; sinh phiếu L1A cho cặp chạm ngưỡng giờ hoặc ngày, chưa có phiếu mở, chưa từng L5 (R-GD-13). Bảo lưu: không sinh.
- `app.sync_upsale_cron()`: đăng ký lịch 02:00 giờ Việt Nam. **Không tự chạy trong migration; chờ anh duyệt đăng ký.**
- Tham số mới: `upsale_auto_generate_enabled` (tắt), `absence_risk_window_days` (30).
- Sửa theo nhắc của Chat 12:25, 12:35: `create_upsale_ticket` kiểm học sinh cùng cơ sở với lớp (`HMT_HOC_SINH_KHAC_CO_SO`); `preview_upsale_enrollment` kiểm quyền trước, mã ở cơ sở ngoài phạm vi báo như mã không có.
