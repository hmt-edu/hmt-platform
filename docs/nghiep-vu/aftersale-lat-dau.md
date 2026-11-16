# Aftersale lát đầu (ticket CS): nền dữ liệu và hàm (Đợt 2, PR Draft)

Luật: `docs/spec/de-xuat-luat-aftersale.md` (AS-01 đến AS-13, đã chốt 15/11/2026), R-V2-23, R-V2-26. Migration 156 (cấu hình), 157 (ticket). Phân hệ `AFTERSALE` **tắt mặc định** ở mọi cơ sở; hàm kiểm công tắc.

## Bảng
| Bảng | Việc |
|---|---|
| `app.ticket_category` | Nhóm, nhóm con (94 dòng nạp sẵn theo `v2-aftersale.md`: Đề nghị 6 nhóm 21 nhóm con, Khiếu nại 8 nhóm 25 nhóm con, Ticket giáo viên 9 nhóm 25 nhóm con). Có mức độ mặc định, loại phiếu nghiệp vụ `[NV]`, hạn xử lý riêng, tính chất (Cần hỗ trợ, Phản ánh), bắt buộc học sinh, lớp. Không xoá, chỉ Ngừng. |
| `app.ticket_sla_rule` | Hạn phản hồi đầu và xử lý xong (giờ) theo loại × mức độ (12 dòng). Admin sửa, có nhật ký. |
| `app.ticket` | Ticket. Mã `DN/KN/GV-<CS>-<YYMM>-<STT>` (cấp như chứng từ, liên tục). Hạn chụp lúc tạo. |
| `app.ticket_event` | Nhật ký chỉ thêm dòng: tạo, giao, đổi trạng thái. |
Danh mục mới: `TICKET_STATUS` (7 trạng thái), `TICKET_PRIORITY`, `TICKET_TEAM`; kênh dùng `TICKET_CHANNEL` có sẵn. Tham số: `as_sla_warn_percent` (25), `as_close_wait_days` (3); `complaint_reopen_max_days` (7) có sẵn.

## Hàm (đều qua `rpc`)
| Hàm | Việc | Quyền |
|---|---|---|
| `app.create_ticket(jsonb)` | Tạo ticket, cấp mã, tính hạn. Bắt buộc tiêu đề, mô tả, kênh, nhóm con; đề nghị, khiếu nại cần phụ huynh; nhóm con `[NV]` cần học sinh; "học kém", "nghỉ nhiều" cần học sinh và lớp. Giáo viên chỉ tạo ticket giáo viên | Ticket · Tạo |
| `app.assign_ticket(id, đội, người)` | Giao (Mới → Đã giao); người phụ trách đúng cơ sở | Ticket · Sửa |
| `app.change_ticket_status(id, trạng thái, ghi chú, hài lòng, kết quả)` | Luồng 7 bước; huỷ cần lý do; Đã xử lý cần kết quả; đóng khiếu nại cần hài lòng 1 đến 5; đóng ticket `[NV]` cần ghi chú làm tay (chưa có phiếu); mở lại trong 7 ngày; ra khỏi Chờ thông tin thì dời hạn | Ticket · Sửa |
| `app.list_tickets(bộ lọc, số dòng, bỏ qua)` | Danh sách phân trang ở máy chủ: loại, trạng thái, nhóm con, mức độ, `sla_state` (QUA_HAN, SAP_QUA_HAN, CHO_DONG), `mine`, `q` (mã, tiêu đề) | RLS theo quyền |
| `app.ticket_board(bộ lọc, số dòng mỗi cột)` | Kanban 7 cột một lần gọi | RLS theo quyền |
RLS đọc: phạm vi toàn hệ thống thấy hết; cơ sở thấy ticket cơ sở mình; Được phân công (giáo viên) thấy ticket mình tạo hoặc phụ trách. Ghi chỉ qua hàm.

## Chưa làm (ghi vào PR)
Giao diện CSN01 (danh sách), CSN02 (Kanban), CSN03 (biểu mẫu); phiếu nghiệp vụ (nhóm A đi sau, nhóm tiền chưa); Sale chỉ thấy ticket mình (ma trận hiện cho Sale phạm vi cơ sở, AS-09 muốn chỉ ticket mình tạo, mình phụ trách); giáo viên thấy ticket gắn lớp mình; khung màn cấu hình Admin; tự nâng ticket quá hạn lên quản lý. Kiểm thử: `supabase/tests/database/156_aftersale_lat_dau.test.sql` (67 bài).

## Lát 3a (migration 158): chi tiết và ghi chú
- `app.get_ticket(id)`: chi tiết ticket và dòng thời gian trong một lần gọi; RLS lọc theo phạm vi (AS-09); không thấy thì `HMT_KHONG_TIM_THAY`.
- `app.add_ticket_note(id, nội dung)`: thêm ghi chú (loại sự kiện `GHI_CHU`); cần Ticket · Sửa ở cơ sở của ticket; chặn ghi chú rỗng và ticket đã đóng/huỷ (AS-02).
- `app.list_ticket_assignees(cơ sở)` (migration 159): nhân viên CRM nhận giao ticket; cần Ticket · Sửa ở cơ sở đó (AS-09). Không đụng `app.list_assignable_staff` của Lead.
- `app.get_ticket` có thêm `branch_id` (cho hộp thoại Giao).

## Lát 3c (migration 160): riêng khiếu nại, ticket con, tính chất
- Bốn cột mới của `app.ticket`: `complaint_date`, `customer_wish`, `root_cause`, `compensation_note`. **Bồi hoàn chỉ là ghi chú bằng chữ**, không số tiền, không phiếu chi (chưa có luật riêng; phương án an toàn, Chat xác nhận hoặc đổi sau).
- `app.update_ticket_complaint(id, jsonb)`: sửa phần riêng khiếu nại và người bị khiếu nại (cùng cơ sở); chỉ loại Khiếu nại; khoá khi đã đóng/huỷ; ghi nhật ký `SUA_KHIEU_NAI`.
- `app.get_ticket` có thêm: phần riêng khiếu nại, `nature_code` (ticket giáo viên), `children` (ticket có `related_ticket_id` là ticket này).

## Lát 4 (migration 161): đổi loại, nhóm con, mức độ
- `app.change_ticket_category(id, nhóm con)`, `app.change_ticket_priority(id, mức độ)`, `app.change_ticket_type(id, loại, nhóm con)`; chung lõi `app.reclassify_ticket` (nội bộ, không cấp cho người dùng).
- Hạn tính lại từ lúc tạo theo loại, mức độ, nhóm con mới (AS-07) và **giữ phần dời hạn do Chờ thông tin**. Mã ticket không đổi (AS-01). Đổi loại chỉ giữa Đề nghị và Khiếu nại, chỉ khi Mới hoặc Đã giao (AS-05). Đã đóng, đã huỷ chỉ xem (AS-02). Nhật ký ghi `DOI_NHOM_CON` (kèm chữ «Đổi loại: …» khi đổi loại) hoặc `DOI_MUC_DO`.

## Lát 5 (migration 162): lưu cấu hình SLA
- `app.save_ticket_sla(bảng hạn, hạn riêng)`: lưu một lần bảng loại × mức độ và hạn riêng nhóm con (CSN-09). Cần Quản trị · Sửa (Admin). Số giờ nguyên dương, hạn xử lý ≥ hạn phản hồi; cả lô một giao dịch. Ticket đã tạo giữ hạn đã chụp (AS-07); mọi sửa ghi nhật ký qua trigger audit.
