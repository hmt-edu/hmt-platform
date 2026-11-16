# Aftersale: phiếu nghiệp vụ, lát A1 (Code B, 16/11/2026, migration 226)

Luật: `docs/spec/de-xuat-luat-aftersale.md` AS-03, AS-10, AS-13; R-V2-24, R-CS-07. Giao diện (CSN-05, CSN-06) chưa làm: lát này chỉ có DB và hàm.

## Bảng
| Bảng | Việc |
|---|---|
| `app.ticket_task` | Phiếu nghiệp vụ gắn ticket: mã `PNV-<CS>-<YYMM>-<STT>`, loại, trạng thái (Nháp, Chờ duyệt, Đã duyệt, Đã thực hiện, Từ chối, Đã huỷ), lý do, dữ liệu, kết quả, các cấp duyệt chụp lúc tạo. Mỗi ticket một phiếu đang mở (chỉ mục duy nhất). |
| `app.ticket_task_event` | Nhật ký phiếu, chỉ thêm dòng. |
| `app.ticket_task_rule` | Cấu hình: số cấp duyệt từng loại phiếu (R-CS-07): bốn loại không tiền một cấp quản lý cơ sở; Dừng học, Hoàn học phí, Chuyển phí thêm cấp kế toán. |
| `app.ticket_task_field` | Cấu hình: trường hồ sơ sửa được bằng phiếu Cập nhật hồ sơ (phụ huynh: họ tên, địa chỉ, người thân; học sinh: trường, loại trường, khối, mục tiêu, giới tính). SĐT, mã, cơ sở tiếp nhận không nằm ở đây (danh tính hồ sơ, R-CRM-28). |

## Hàm (đều kiểm công tắc AFTERSALE, đang tắt mặc định)
- `app.create_ticket_task(ticket, loại, lý do, dữ liệu)`: Ticket · Sửa; nhóm con của ticket phải dùng đúng loại phiếu (R-V2-24); kiểm sớm dữ liệu Cập nhật hồ sơ.
- `app.submit_ticket_task(id)`: Nháp → Chờ duyệt (cấp 1).
- `app.approve_ticket_task(id, ghi chú)`: duyệt một cấp; hết cấp thì Đã duyệt. Cấp quản lý cơ sở: Ticket · Duyệt ở cơ sở; cấp kế toán: vai trò kế toán. **Người tạo không tự duyệt** (kể cả Admin).
- `app.reject_ticket_task(id, lý do)`: Chờ duyệt → Từ chối, bắt buộc lý do.
- `app.execute_ticket_task(id)`: Đã duyệt → Đã thực hiện. **Lát này chỉ thực hiện được Cập nhật hồ sơ**; sáu loại còn lại báo `HMT_PHIEU_CHUA_LAM`. Giá trị trước và sau ghi vào kết quả phiếu.
- `app.cancel_ticket_task(id, lý do)`: huỷ phiếu chưa thực hiện, bắt buộc lý do.
- Phiếu Đã thực hiện hoặc Từ chối thì **ticket có nghiệp vụ tự sang Đã xử lý** (AS-03); người phụ trách đóng tay. Huỷ phiếu không đổi trạng thái ticket.

## Quyết định tự chọn (phương án an toàn; Chat xác nhận hoặc đổi)
1. Người tạo phiếu không tự duyệt phiếu của mình (kể cả Admin).
2. Cập nhật hồ sơ: duyệt một cấp, quản lý cơ sở.
3. Danh sách trường sửa được là cấu hình (bảng), mặc định như trên; không có SĐT.
4. Chưa có: phiếu Chuyển cơ sở (cả hai quản lý), giao diện CSN-05/06, các loại phiếu khác (chờ luật và bản ghi của cụm Ghi danh: PR chuyển lớp, bảo lưu của Code D).
