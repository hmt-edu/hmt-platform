# Rà «Group By» của các danh sách K03 với canvas (Code F, 19/11/2026; thẻ F65)

Nguồn: Tester 2 báo thiếu Group By ở Đơn hàng, Lớp, Ghi danh. Cách làm: (1) đếm mọi cấu hình danh sách `*Config.tsx` có `groupFields` khác rỗng (khuôn ẩn nút Group By khi rỗng, `src/list/ListScreen.tsx`); (2) với mỗi danh sách, tìm nút «Group By» trong các khung canvas cùng mã. Canvas chỉ vẽ **một** khung thả xuống Group By (K1_nhom, Cơ hội: Stage, Sub-stage, Source, Medium, Sale phụ trách, Cơ sở; tối đa hai cấp), mọi danh sách khác chỉ vẽ nút. Cột gợi ý bên dưới là cột dạng danh mục (tình trạng, cơ sở, người phụ trách, hình thức…), **Chat hoặc Design chốt lại** trước khi làm.

## Có Group By trong code (4/22 danh sách)
Lead TS-01, Cơ hội TS-07, Lịch hẹn TS-11, Phiếu kiểm tra TS-16: đúng canvas.

## Canvas CÓ nút Group By, code CHƯA có (lệch, 14 danh sách)
| Màn | Cột gợi ý để nhóm | Lane |
|---|---|---|
| BH-01 Báo giá | Tình trạng, Cơ sở, Người lập, Quá hạn | C |
| BH-06 Đơn hàng | Tình trạng, Cơ sở, Sale, Thu tiền | C |
| TC-01 Phiếu thu, TC-04 Chờ kế toán | Hình thức, Cơ sở, Người lập, Người nhận tiền, Tình trạng | C/D |
| TC-08 Khoản tiền vào | Cơ sở, Ngày | C/D |
| TC-10 Phiếu chi | Hình thức, Cơ sở, Tình trạng | C/D |
| TC-13 Công nợ (cấu hình chung `treasuryConfig`) | Cơ sở, Sale, Đợt, Tình trạng | C/D |
| LOP-01 Lớp | Môn, Khối, Phân loại, Cơ sở, Giáo viên, Tình trạng duyệt, Vận hành | A |
| GD-01 Ghi danh | Hình thức học, Lớp, Tình trạng | A |
| BUOI-01 Buổi học | Ngày, Lớp, Cơ sở, Giáo viên, Loại, Tình trạng | A |
| KH-01 Khách hàng (Phụ huynh) | Tình trạng, Cơ sở tiếp nhận, Đang học tại | B (xong, migration 575; «Đang học tại» chưa làm) |
| TT-01 Tái tục | Giai đoạn, Sub-stage, Campaign, Phụ trách | A/C |
| TT-04 Đối soát tái tục | Cơ sở, Campaign, Lý do chưa có phiếu | A (xong, migration 585; Campaign là tháng đang xem nên một nhóm) |
| CS-01 Ticket | Loại, Nhóm, Mức độ, Trạng thái, Người xử lý, Cơ sở | B (xong, migration 575) |

Còn nhiều danh sách chưa có cấu hình K03 trong `src/` (TS-02..17, GD-06, GD-07, BUOI-10..15, KH-04, LOP-08, LOP-09, TC-09) mà canvas có nút Group By: gom vào cùng việc khi từng màn được chuyển sang khuôn.

## Canvas KHÔNG có nút Group By: đúng thiết kế
CS-05 Phiếu nghiệp vụ, TC-14 Số dư khách hàng, CHUNG-15 Việc chờ tôi duyệt, QT-01 Người dùng, QT-11 Nhật ký thao tác, QT-12 Nhật ký đăng nhập: không khung canvas nào có Group By (hoặc không có khung), nên để trống là đúng.

## Cách làm khi sửa (cho lane nhận)
Nhóm ở máy chủ (đã có mẫu «Group By ở máy chủ», `src/list/khuon-may-chu.test.tsx`): không nhóm trên 50 dòng đã tải, vì kết quả sai khi có nhiều trang. Mỗi danh sách cần hàm đếm theo trường nhóm trong DB (nên có chỉ mục trên cột nhóm) rồi tải dòng khi mở nhóm.

## Đã làm: KH-01 Phụ huynh và CS-01 Ticket (Code B, 20/11/2026, kho #19, migration 575)
| Hàm | Ai gọi | Việc | Luật |
|---|---|---|---|
| `app.parent_group_counts(bộ lọc, trường nhóm)` | Vai có «Phụ huynh · Xem» (security definer, kiểm quyền bên trong) | Đếm phụ huynh theo `status` (Có con đang học / Chưa có con đang học) và `branch` (cơ sở tiếp nhận), tối đa hai cấp khác nhau; bộ lọc giống `list_parents` | R-CRM-27, K1_nhom |
| `app.ticket_group_counts(bộ lọc, trường nhóm)` | Mọi người đăng nhập, dưới RLS ticket (không security definer) | Đếm ticket theo `type`, `group`, `priority`, `status`, `assignee`, `branch`, tối đa hai cấp; bộ lọc giống `list_tickets` | AS-07, K1_nhom |
| `app.ticket_filter_rows(bộ lọc)` | `list_tickets`, `ticket_board`, `ticket_group_counts` | MỘT nơi định nghĩa bộ lọc ticket; thêm khoá `group_code` (nhóm cha của danh mục), `assignee_id`, `no_assignee`; migration 600 thêm `parent_id`, `student_id` (tab Ticket ở hồ sơ phụ huynh KH-02, học sinh KH-05; chỉ mục `ticket_parent_idx`, `ticket_student_idx` có sẵn) | AS-07 |
| `app.ticket_group_label(trường, khoá)` | `ticket_group_counts` | Tên hiển thị nhóm (danh mục, cơ sở, người dùng) | |

Lỗi: `HMT_NHOM_SAI` (trường lạ, trùng hai cấp, quá hai cấp, không chọn), `HMT_KHONG_CO_QUYEN` (phụ huynh, người không có quyền xem). Mở một nhóm thì giao diện gọi `list_parents` (`status`, `branch_id`) hoặc `list_tickets` (`ticket_type`, `group_code`, `priority_code`, `status_code`, `assignee_id` hoặc `no_assignee`, `branch_id`) với bộ lọc của nhóm. Nhóm «Người xử lý» chưa giao: khoá rỗng, nhãn «Chưa có».

Chỗ chưa làm, chờ Chat chốt: «Đang học tại» của KH-01 (một phụ huynh học ở nhiều cơ sở cùng lúc nên lọt nhiều nhóm, tổng đếm sai). Không thêm chỉ mục mới (cột nhóm đã có chỉ mục).

## Rà lại Group By của Thu chi, Bán hàng với canvas 9933 (Code C, 21/11/2026, thư Chat 02:07)

Cách rà: lấy `gfields` trong cấu hình của từng khung canvas (`BH01`, `BH06`, `TC01`, `TC04`, `TC08`, `TC10`, `TC13`, `TT01`, `TT04`) và so với `groupFields` của `*Config.tsx`.

| Màn | Canvas (nhóm được) | Code | Kết quả |
|---|---|---|---|
| BH-01 Báo giá | Tình trạng, Cơ sở, **Người lập** | Tình trạng, Cơ sở | **Thiếu «Người lập»** |
| BH-06 Đơn hàng | Tình trạng, Cơ sở, **Sale** | Tình trạng, Cơ sở | **Thiếu «Sale»** (người lập đơn) |
| TC-01 Phiếu thu | Tình trạng, Hình thức, Cơ sở | đủ ba | Đúng |
| TC-04 Chờ kế toán | Tình trạng, Cơ sở, Hình thức, Sao kê | đủ bốn (Sao kê: #434, migration 579) | Đúng |
| TC-08 Khoản tiền vào | Cơ sở, **Ngày** | Cơ sở | **Thiếu nhóm «Ngày»** |
| TC-10 Phiếu chi | Tình trạng, Cơ sở, **Hình thức** | Tình trạng, Cơ sở | **Thiếu «Hình thức»** (cột đã có từ migration 564) |
| TC-13 Công nợ | Cơ sở, **Sale**, **Tình trạng** | Cơ sở | **Thiếu «Sale», «Tình trạng»** |
| TT-01 Tái tục | Campaign, Giai đoạn, Phụ trách | Giai đoạn, Sub-stage, Campaign, Phụ trách, Cơ sở | Đúng (code nhiều hơn canvas) |
| TT-04 Đối soát tái tục | Cơ sở, Lý do chưa có phiếu | đã làm ở migration 585 | Đúng |

Mỗi chỗ thiếu cần sửa hàm đếm nhóm của màn (trường nhóm mới, nhãn, giữ phạm vi cơ sở) nên là **migration, mức CAO theo quy ước** (hàm danh sách tiền). Đề xuất gom hai PR, mỗi PR một migration, pgTAP đúng và bị chặn: (a) Bán hàng: `quotation_group_counts` thêm `creator`, `order_group_counts` thêm `sale`; (b) Thu chi: `voucher_group_counts` thêm `method`, `money_in_group_counts` thêm `day`, `receivable_group_counts` thêm `sale`, `status`. **Xin Chat cấp hai số migration** (từ 594 trở đi) và duyệt làm.

### So canvas TC chưa kiểm (TC-08, TC-09, TC-13, TC-15)
Chữ nhãn của các khung khớp code, trừ hai chỗ: (1) **khung «không có quyền» của TC-08 và TC-13** (`TC08_khong_quyen`, `TC13_khong_quyen`) vẽ tiêu đề «Bạn không có quyền xem khoản tiền vào» / «…khoản công nợ», câu «Vai trò … chưa được cấp quyền xem phân hệ Bán hàng và thu chi. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.» và nút «Về trang chủ»; code hiện «Không tải được danh sách» kèm câu lỗi của máy chủ. Nguyên nhân chung ở khuôn danh sách (`src/list/ListScreen.tsx` nhận lỗi dạng chữ, không phân biệt mã `HMT_KHONG_CO_QUYEN`), nên sửa một lần cho mọi danh sách K03: **xin Chat duyệt**; (2) «Lọc thông minh» ở thanh công cụ của khung mẫu: không có trong bản đồ màn hình, Tester so ảnh. TC-09 và TC-15: đúng nhãn, các tên người và số liệu là minh hoạ.
