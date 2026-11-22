# Rà UI nhóm Bán hàng, Thu chi, Ghi danh với canvas (Code F, 19/11/2026; thẻ F64)

Cách làm: (1) danh sách: so tiêu đề cột `<th>` của khung canvas 9933/abea với cấu hình cột trong code; (2) bản ghi và hộp thoại: lấy mọi chữ hiện trong khung canvas (`BH05*`, `TC02*`, `GD02*`, `GD03*`, `BH07*`, `BH08*`), tìm trong `src/`; chữ không thấy được xét tay (tên người mẫu, số liệu minh hoạ và mục danh mục lấy từ DB không tính là lệch). Chưa so bằng ảnh chụp bản dựng: Tester nên xem lại các dòng «Gần đúng».

| Màn | Canvas | Code | Kết quả |
|---|---|---|---|
| TC-01 Phiếu thu (danh sách) | Mã, Đơn hàng, Phụ huynh, Số tiền, Hình thức, Ngày nhận, Cơ sở, Người lập, Người nhận tiền, **Người duyệt**, Tình trạng (abea) | không có cột Người duyệt; thừa cột «Cơ sở đơn» (canvas không có) | **Đã sửa** (#327, #300, #262): có «Người duyệt», «Cơ sở đơn» ẩn mặc định. Cập nhật 23/11 sau rà code (thẻ C-23-01) |
| TC-04 Hàng chờ kế toán duyệt | Mã, Đơn hàng, Phụ huynh, Cơ sở, Người lập, Người nhận tiền, Số tiền, Hình thức, **Mã giao dịch**, Ngày nhận, Tình trạng, **Sao kê** (Đã khớp/Chưa khớp), **Xử lý** (nút Duyệt, Từ chối ngay trên dòng) | dùng lại bảng TC-01 (không có Mã giao dịch, Sao kê, Xử lý) | **Đã sửa** phần cột: «Mã giao dịch» (#327), «Sao kê» (#404, TC-15 đã có). **Còn chờ anh chốt luật**: cột «Xử lý» (nút Duyệt, Từ chối ngay trên dòng) — chưa làm (thẻ C-23-01 bỏ qua) |
| TC-08 Khoản tiền vào | Mã, Phiếu thu, Đơn hàng, Phụ huynh, Số tiền, Ngày, Cơ sở, Ghi chú, Hoàn tác | giống hệt | khớp |
| TC-13 Công nợ | Đơn hàng, Phụ huynh, Cơ sở, Sale, Đợt, Hạn đóng, Phải đóng, Đã đóng, Còn nợ, Tình trạng | giống hệt | khớp |
| TC-02 Phiếu thu (bản ghi) | thêm chữ «Duyệt bởi», «Dồn trước», cột «Thành tiền» ở bảng chia tiền về dòng | không thấy ba chữ này | **gần đúng**: bố cục khớp, thiếu ba nhãn; Tester so ảnh |
| TC-05 Kế toán duyệt, từ chối phiếu thu | khung TC02_cho_kt, TC02_duyet | cùng trang bản ghi | **gần đúng** (như TC-02) |
| BH-05 Đơn hàng (bản ghi) | khối «Người xử lý và cơ sở», lịch đợt «tự tính, chỉ đọc», «Đã duyệt · khoá» | có lịch đợt và mục «Người duyệt»; không có tiêu đề khối «Người xử lý và cơ sở» | **gần đúng**: khác tiêu đề khối |
| BH-07 Duyệt, từ chối đơn | «Đồng ý chiết khấu vượt trần», lý do từ chối (danh mục), «Khác» bắt buộc ghi chú | có đủ; lý do lấy từ danh mục | khớp |
| BH-08 Chọn lớp và ngày vào lớp | chọn lớp, ngày vào lớp, chưa có buổi | có `ClassPicker`; chữ khớp | khớp |
| GD-02 Ghi danh (bản ghi) | khối «Quỹ giờ và lớp», nút «Mở sổ giờ đầy đủ», khối «Nhóm đề nghị», cột «Trừ buổi», nhãn «Đã rời lớp» | có «Quỹ giờ», nút «Sổ giờ»; không thấy «Nhóm đề nghị», «Trừ buổi», «Đã rời lớp» | **lệch**: bốn chỗ thiếu hoặc khác tên; Code A sửa (cần Chat chuyển) |
| GD-03 Xếp lớp theo nhóm, theo lớp | khung GD03_nhom, GD03_le, GD03_trung_gio | chữ khớp (chỉ khác tên mẫu) | khớp |

## Chưa rà được
CS-04, CS-08, CS-13: khung canvas của nhóm này mang mã CSN01..09 (gói 9189), một khung gộp nhiều bước; so chữ ra nhiều chỗ lẫn tên mẫu, chưa kết luận chắc. Cần ảnh chụp bản dựng của Tester (CS-04: `CSN03_de_nghi`, CS-08: `CSN06_*`, CS-13: `CSN04_dong_khieu_nai`, `CSN04_mo_lai`). BH-09, BH-10, BH-11, TC-03, TC-06, TC-07, TC-09 và GD-05 chưa so (ưu tiên sau).
