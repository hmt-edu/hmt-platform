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

## TT-D1 (migration 416): bản ghi TT-02

`app.get_upsale_ticket(phiếu)` trả một lần: phiếu, phụ huynh, học sinh, lớp và giáo viên lớp, ghi danh liên quan kèm giờ còn, giờ đã mua và đã học, số buổi vắng trong `absence_risk_window_days` ngày, sự kiện, và `actions` (giao, doi_giai_doan, sua_ghi_chu theo quyền người gọi). Màn `/crm/tai-tuc/:id` (K06): thanh giai đoạn chỉ đọc, nút «Chuyển giai đoạn» (L5 bắt buộc lý do), «Giao», hai ô tự do + Lưu, tab Giờ học, Báo giá và đơn (chưa có), Tình hình học tập (chưa dùng).

**Chưa làm, cần Chat/anh quyết (ghi ở PR):**
1. **Email, Zalo phụ huynh**: spec nói lấy từ hồ sơ phụ huynh nhưng bảng `app.parent` chưa có cột email, Zalo: màn hiện «—». Cần quyết thêm cột ở hồ sơ phụ huynh (việc của Khách hàng).
2. **Deadline, Stage Deadline, Next Activity, Assign Date, Nhân sự hỗ trợ, Lần liên hệ gần nhất** (khối «Xem thêm (6 trường)» của canvas): chưa có luật và cột; không làm.
3. **Ghi chú tự do (Chatter) và lịch hẹn của phiếu**: cần đăng ký loại ghi chú `UPSALE` ở `note_target` và sửa `can_see_note_target` (hàm dùng chung nhiều PR); dòng thời gian hiện chỉ có sự kiện nghiệp vụ. Nút «Thêm lịch hẹn» chưa có.
4. **TT-D2 (đề xuất, chưa làm, dính tiền):** «Tạo báo giá», «Tạo đơn» từ phiếu ở L6, L7A, L7B, L8A. Bảng `app.quotation` đã có `renewal_ticket_id`, nhưng `sales_order` và hàm tính dòng (`order_write_priced_lines`) đang lấy học sinh từ cơ hội (`prospect_student`); đơn từ phiếu cần dòng gắn `student_id`, lớp và hình thức học giữ như ghi danh cũ (R-GD-13), cùng móc đơn đóng đủ thì phiếu sang L8A. Xin Chat duyệt thiết kế trước khi viết.

## TT-D2a (migration 417): tạo đơn từ phiếu tái tục

- `app.create_order_from_upsale_ticket(phiếu, dòng, điều khoản, ngày vào lớp)`: cần **cả hai** quyền Đơn hàng · Tạo và Phiếu tái tục · Sửa (Chat 13:20, mỗi bước kiểm riêng), một giao dịch: đơn Nháp (gốc là phiếu, không cơ hội), dòng gắn học sinh và lớp CỦA PHIẾU (không nhận từ đầu vào), hình thức học giữ như ghi danh cũ, giá `price_line` như đơn thường, điều khoản, phiếu L6 → L7B. Chặn: phiếu chưa L6 (`HMT_PHIEU_CHUA_DONG_Y`), đã có đơn đang sống (`HMT_PHIEU_DA_CO_DON`), học sinh không còn học ở lớp (`HMT_HOC_SINH_KHONG_O_LOP`), ngày vào lớp không phải buổi của lớp (`HMT_NGAY_VAO_LOP_SAI`; mặc định lấy buổi sắp tới gần nhất).
- `app.list_upsale_orders(phiếu)`: đơn của phiếu cho tab «Báo giá và đơn».
- `app.reconcile_upsale_orders()`: đơn Đã duyệt đã thu đủ thì phiếu sang L8A; mọi đơn Huỷ thì về L6. Chạy cùng lịch đêm (`sync_upsale_cron` nay lên lịch cả hai việc; vẫn chờ anh duyệt đăng ký).
- Ghi danh mới: hàm sẵn có `create_enrollments_for_order` đã xếp thẳng vào lớp của phiếu (pgTAP chứng minh), không vào hàng chờ xếp lớp.
- **Chưa làm:** hộp «Tạo đơn» trên màn TT-02 (chọn gói), báo giá từ phiếu (bảng báo giá còn bắt buộc cơ hội), sửa đơn Nháp từ phiếu bằng `save_order`.
