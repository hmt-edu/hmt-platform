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
