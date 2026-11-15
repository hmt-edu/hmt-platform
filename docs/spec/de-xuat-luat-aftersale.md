# ĐỀ XUẤT luật Aftersale (ticket CS) chờ Chat chốt

Code B soạn 15/11/2026 từ `v2-aftersale.md` (BA 30/10/2026, anh Trường duyệt; file nằm trong `_inbox/`, không commit) và đối chiếu với `docs/spec/04` (R-CS-01 đến R-CS-14, R-V2-23 đến R-V2-26). **Đây là đề xuất, chưa phải luật**: không sửa `docs/spec/04`. Chat chốt từng dòng rồi mới đưa vào luật. Chưa làm code Aftersale cho đến khi chốt.

## 1. Đã có trong luật (không cần đề xuất lại)
R-V2-23 (lõi ticket, 3 loại, hai cấp nhóm, đổi loại khi tiếp nhận, khiếu nại sinh đề nghị con), R-V2-24 (đề nghị có nghiệp vụ thật, duyệt ở bản ghi nghiệp vụ, "làm tay"), R-V2-25 (tái tục là một dạng Đề nghị), R-V2-26 (mức độ, hạn là tham số, vàng dưới 25%), R-CS-02, R-CS-08, R-CS-09, R-CS-11, R-CS-14 (hài lòng 5 mức), tham số `sla_*`.

## 2. Đề xuất bổ sung (chưa có trong luật)
| # | Đề xuất | Nguồn `v2-aftersale.md` |
|---|---|---|
| AS-01 | **Mã ticket:** `DN-<CS>-<YYMM>-<STT>`, `KN-…`, `GV-…`, cấp bằng bảng đếm khoá dòng, liên tục theo cơ sở và tháng, không sửa. | Loại ticket |
| AS-02 | **Luồng trạng thái chung 7 bước** cho cả 3 loại: Mới → Đã giao → Đang xử lý ↔ Chờ thông tin → Đã xử lý → Đã đóng; nhánh Đã huỷ (bắt buộc lý do). Tên 7 bước ở đây là suy ra từ lời văn của tài liệu (sơ đồ gốc không có trong phần chữ): **Chat xác nhận tên**. Không xoá ticket. | Trạng thái |
| AS-03 | **Ticket không tự đóng.** Người phụ trách đóng sau khi xác nhận với người gửi. Ticket [NV] tự sang Đã xử lý khi phiếu nghiệp vụ Đã thực hiện hoặc Từ chối, rồi người phụ trách đóng. Đã xử lý quá 3 ngày chưa đóng: bộ lọc "Chờ đóng" (tham số). Mở lại trong 7 ngày sau khi đóng (`complaint_reopen_max_days`). | Trạng thái |
| AS-04 | **Đóng khiếu nại bắt buộc ghi mức hài lòng 1 đến 5.** | Trường thông tin |
| AS-05 | **Ticket giáo viên:** giáo viên chọn nhóm và nhóm con; **tính chất Hỗ trợ hoặc Phản ánh gắn sẵn theo nhóm con** (giáo viên không chọn); CSKH được đổi nhóm con khi tiếp nhận (tính chất đổi theo, có nhật ký). Ticket "học kém", "nghỉ nhiều" bắt buộc gắn học sinh và lớp. Tự tạo ticket khi vắng liên tiếp: để đợt sau. *Lệch chữ:* R-V2-23 viết "Cần hỗ trợ", tài liệu BA viết "Hỗ trợ": Chat chọn một. | Ticket giáo viên |
| AS-06 | **Nhóm con có nghiệp vụ [NV]:** đổi tên được, không Ngừng được, không đổi loại phiếu; xoá hẳn chỉ khi chưa ticket nào dùng. Mọi loại, nhóm, nhóm con, kênh, mức độ là danh mục có màn cấu hình (Admin). | Loại ticket, danh mục |
| AS-07 | **Bảng SLA mặc định** theo loại × mức độ (phản hồi đầu / xử lý xong) và hạn riêng theo nhóm con (Hoàn học phí 7 ngày; Chuyển phí, Dừng học 5 ngày; Bảo lưu, Tiếp tục học, Chuyển lớp, Chuyển cơ sở 2 ngày; Cập nhật hồ sơ 1 ngày). Hạn tính từ lúc tạo, trừ thời gian Chờ thông tin; đổi mức độ thì tính lại từ lúc tạo; ticket cũ giữ hạn đã chụp; mọi số là tham số có nhật ký. Cần thêm các khoá `sla_*` cho Đề nghị theo mức Khẩn, Cao, Thấp và cho Ticket giáo viên (luật `docs/spec/06` mới có số của v1). | SLA |
| AS-08 | **Mức độ mặc định theo nhóm con:** Khẩn cho bắt nạt, đưa đón an toàn, học sinh có dấu hiệu tâm lý, sức khoẻ; Cao cho khiếu nại giáo viên, khiếu nại học phí, lịch dạy đổi đột xuất; còn lại Thường. | SLA |
| AS-09 | **Phân quyền:** dùng ma trận quyền chung, không vai riêng, không cờ Hạn chế. CSKH và Quản lý cơ sở xem và xử lý ticket cơ sở mình; Sale xem ticket mình tạo, mình phụ trách; Kế toán xem ticket có phiếu tiền và duyệt bước Kế toán; Giáo viên xem ticket mình tạo và ticket gắn lớp mình, **không thấy ghi chú nội bộ và tiền trên phiếu**, chỉ tạo và trả lời; Admin tất cả. | Phân quyền |
| AS-10 | **7 phiếu nghiệp vụ** (Cập nhật hồ sơ, Đổi lịch/học bù, Chuyển lớp cùng môn/chuyển cơ sở, Bảo lưu/Tiếp tục học, Dừng học, Hoàn học phí, Chuyển phí), thứ tự làm A (1 đến 4, không đụng tiền) → B (Dừng học, Chuyển phí, cần sổ số dư) → C (Hoàn học phí, cần phiếu chi). Phiếu: Nháp → Chờ duyệt → Đã duyệt → Đã thực hiện; nhánh Từ chối có lý do; database chặn thao tác không qua phiếu (R-CS-02). Người duyệt theo bảng ở tài liệu BA (như R-CS-07). | Đề nghị có nghiệp vụ thật |
| AS-11 | **Luồng Bảo lưu → Tiếp tục học** theo ghi danh: điều kiện, nhả chỗ lớp, bỏ khỏi buổi chưa điểm danh, không tính vào "đang học", gia hạn không giới hạn số lần, tối đa theo `reservation_max_months` (6 tháng) mỗi lần, bộ lọc "Sắp hết bảo lưu" 7 ngày (tham số), quá hạn không tự dừng. Tiếp tục học: lớp mặc định là lớp trước bảo lưu, về lớp cũ không cần duyệt. | Luồng Bảo lưu |
| AS-12 | **Luồng Chuyển phí** qua sổ số dư khách hàng (đã có bảng ở PR Số dư tiền Draft): giá trị chuyển = đã đóng − giờ mua đã học × giá sau chiết khấu (giá chụp trên đơn); không trừ phí; giờ tặng huỷ; âm thì chặn; sang em khác phụ huynh được kèm xác nhận; tiền dư luôn giữ số dư, rút tiền mặt thì Hoàn học phí trừ phí 10%. | Luồng Chuyển phí |
| AS-13 | **Báo cáo:** tháng đầu chỉ danh sách có Group By; dashboard để sau (R-CS-12 hoãn). | Tóm tắt |

## 3. Chỗ lệch cần Chat chốt
1. **Đóng ticket:** R-V2-24 viết "ticket chỉ đóng khi nghiệp vụ xong"; tài liệu BA: ticket [NV] sang Đã xử lý khi phiếu xong rồi người phụ trách đóng tay. Đề xuất theo tài liệu BA (AS-03).
2. **Tên tính chất ticket giáo viên:** "Cần hỗ trợ" (R-V2-23) hay "Hỗ trợ" (BA). Canvas 9189 dùng «Cần hỗ trợ», «Phản ánh».
3. **Tên 7 trạng thái** (AS-02), vì sơ đồ gốc không đọc được.
4. **Khung canvas:** 9189 có CSN01 đến CSN09 (khoảng 90 khung); tài liệu BA nói 14 khung CRM và 2 khung cổng giáo viên. Chưa đối chiếu từng khung với danh sách này; sẽ làm khi Chat chốt phạm vi lát đầu.

## 4. Lát đầu đề xuất khi luật chốt (làm sau go-live, PR Draft)
Bảng ticket (3 loại), mã, luồng trạng thái chung và nhật ký, hạn SLA từ tham số, RLS theo ma trận quyền, hàm danh sách phân trang cho CSN01 và Kanban CSN02, biểu mẫu CSN03. Chưa làm phiếu nghiệp vụ có tiền (nhóm B, C) cho đến khi có sổ số dư và phiếu chi được duyệt.
