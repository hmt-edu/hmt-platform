# Bàn giao · 6 màn còn thiếu khung (HMT Platform)

Canvas: https://claude.ai/artifact/VLEPAjcSZWAh8yyWjj1dc2 · phiên bản 5 (1794988956-1aab) · 18/11/2026
Anh Trường chốt đóng gói 18/11/2026 15:06.

## Nội dung gói
- `canvas/`: 52 khung `.dc.html` + `canvas.json` (đúng như trên canvas).
- `xem-offline/`: bản trỏ CSS về `../hmt.css` để mở thử; khung cần `support.js` của canvas nên có thể chưa chạy đủ ngoài canvas. Bản gốc xem trên link canvas.
- `hmt.css`: token và lớp hmt-* đã dùng.
- `nhat-ky-design.md`: nhật ký thiết kế theo cụm.

## 6 màn
CHUNG-15 (K03; Trưởng cơ sở, Kế toán, Admin, điện thoại), BC-08, BC-09, CH-05, CH-06, CH-07.

## Luật đã chốt cho đội code
- Dòng việc chờ chỉ để mở bản ghi; Duyệt, Từ chối nằm trong màn từng loại; không duyệt hàng loạt. Admin không duyệt phiếu thu, chỉ Chuyển người duyệt (R-HT-01).
- BC-08 chỉ ghi số liệu (có trợ giảng), tháng theo ngày buổi diễn ra, không tính vi phạm.
- BC-09 chốt cả hệ thống một lần; tháng đã chốt khoá, không Mở lại, hiện "Đã chốt bởi … lúc …"; Trưởng cơ sở không có nút Chốt; không chốt tháng chưa kết thúc.
- CH-05 mã bản kế thêm -v2, -v3; Tạo bản mới sao chép toàn bộ bài từ bản trước; trạng thái chỉ Đang dùng, Ngừng.
- CH-06 chưa khoá khi đã có lớp dùng; không xoá bài; mã bài không đổi khi kéo.
- CH-07 9 tiêu chí, 3 nhóm; mô tả sửa tự do, chỉ áp cho buổi sau; tiêu chí đã dùng chỉ Ngừng.

## Còn mở, không chặn code
- Câu 8 (thời gian chờ tính từ lúc đến lượt cấp hiện tại) và câu 12 (BC-08 tháng theo ngày buổi diễn ra): giữ theo đề xuất.
- Câu 30: mô tả 5 mức và câu mẫu lời nhắn trên CH-07 là chữ mẫu; chờ sheet Rubric từ anh Trường.
- CH-06 "Nhập từ file": chỉ có nút, chưa có hộp thoại vì thiếu khuôn T5 (bước tải file cột cố định, xem trước theo loại, hộp kết quả). Gần nhất K4b, TS04.
- Dữ liệu trên khung là dữ liệu giả.

## Danh sách khung
- `Main` · Mục lục · 6 màn còn thiếu khung
- `CAU_HOI_TREO` · Câu hỏi treo (còn chờ anh)
- `DA_TRA_LOI` · Câu hỏi đã được Chat trả lời
- `MAN_DUNG` · Màn dừng và chỗ thiếu
- `CHUNG15_pc` · CHUNG-15 · Hàng việc chờ tôi duyệt · Trưởng cơ sở (máy tính)
- `CHUNG15_kt_pc` · CHUNG-15 · Kế toán, nhiều cơ sở (máy tính)
- `CHUNG15_ad_pc` · CHUNG-15 · Admin, mọi cơ sở, không duyệt tiền (máy tính)
- `CHUNG15_loc_pc` · CHUNG-15 · Lọc theo loại việc, khung thả xuống (máy tính)
- `CHUNG15_da_loc_pc` · CHUNG-15 · Đã lọc: Đơn hàng, Phiếu thu (máy tính)
- `CHUNG15_trong_pc` · CHUNG-15 · Trống: không có việc chờ duyệt (máy tính)
- `CHUNG15_trong_loc_pc` · CHUNG-15 · Trống: bộ lọc không khớp việc nào (máy tính)
- `CHUNG15_tai_pc` · CHUNG-15 · Đang tải (máy tính)
- `CHUNG15_loi_pc` · CHUNG-15 · Lỗi tải danh sách (máy tính)
- `CHUNG15_quyen_pc` · CHUNG-15 · Không có quyền (máy tính)
- `CHUNG15_dt` · CHUNG-15 · Hàng việc chờ tôi duyệt (điện thoại)
- `CHUNG15_loc_dt` · CHUNG-15 · Lọc theo loại việc, bảng chọn dưới (điện thoại)
- `CHUNG15_trong_dt` · CHUNG-15 · Trống (điện thoại)
- `CHUNG15_tai_dt` · CHUNG-15 · Đang tải (điện thoại)
- `BC08_pc` · BC-08 · Giáo viên trễ hạn hằng tháng · Admin (máy tính)
- `BC08_khong_xuat_pc` · BC-08 · Trưởng cơ sở, cơ sở khoá, không có quyền Xuất (máy tính)
- `BC08_trong_pc` · BC-08 · Trống: không có buổi trễ hạn trong tháng (máy tính)
- `BC08_tai_pc` · BC-08 · Đang tải (máy tính)
- `BC08_quyen_pc` · BC-08 · Không có quyền (máy tính)
- `BC09_pc` · BC-09 · Giờ dạy giáo viên · tháng chưa chốt · Kế toán (máy tính)
- `BC09_da_chot_pc` · BC-09 · Tháng đã chốt, khoá sửa (máy tính)
- `BC09_chot_pc` · BC-09 · Hộp thoại Chốt tháng (máy tính)
- `BC09_chot_loc_pc` · BC-09 · Đang lọc một cơ sở, hộp thoại Chốt vẫn ghi Tất cả cơ sở (máy tính)
- `BC09_bm_pc` · BC-09 · Trưởng cơ sở: cơ sở khoá, không có nút Chốt tháng (máy tính)
- `BC09_trong_pc` · BC-09 · Trống: tháng chưa có buổi hoàn tất (máy tính)
- `BC09_tai_pc` · BC-09 · Đang tải (máy tính)
- `BC09_quyen_pc` · BC-09 · Không có quyền (máy tính)
- `CH05_pc` · CH-05 · Khung chương trình, danh sách phiên bản · Admin (máy tính)
- `CH05_bm_pc` · CH-05 · Trưởng cơ sở chỉ xem: không có Tạo bản mới, Ngừng (máy tính)
- `CH05_tao_pc` · CH-05 · Hộp thoại Tạo bản mới (máy tính)
- `CH05_ngung_pc` · CH-05 · Hộp thoại xác nhận Ngừng (máy tính)
- `CH05_trong_pc` · CH-05 · Trống: chưa có khung chương trình (máy tính)
- `CH05_tai_pc` · CH-05 · Đang tải (máy tính)
- `CH05_quyen_pc` · CH-05 · Không có quyền (máy tính)
- `CH06_pc` · CH-06 · Danh sách bài học · chưa có lớp dùng, sửa được · Admin (máy tính)
- `CH06_sua_pc` · CH-06 · Sửa một bài tại dòng (máy tính)
- `CH06_them_pc` · CH-06 · Hộp thoại Thêm bài (máy tính)
- `CH06_bm_pc` · CH-06 · Trưởng cơ sở chỉ xem (máy tính)
- `CH06_trong_pc` · CH-06 · Trống: khung chưa có bài (máy tính)
- `CH06_tai_pc` · CH-06 · Đang tải (máy tính)
- `CH06_quyen_pc` · CH-06 · Không có quyền (máy tính)
- `CH07_pc` · CH-07 · Rubric nhận xét · bộ Toán, mô tả mức (máy tính)
- `CH07_cau_mau_pc` · CH-07 · Rubric Toán · câu mẫu lời nhắn phụ huynh theo mức (máy tính)
- `CH07_phu_pc` · CH-07 · Rubric bộ môn phụ, mẫu Vật lý (máy tính)
- `CH07_sua_pc` · CH-07 · Đang sửa mô tả mức (máy tính)
- `CH07_tao_pb_pc` · CH-07 · Hộp thoại Tạo phiên bản (máy tính)
- `CH07_tai_pc` · CH-07 · Đang tải (máy tính)
- `CH07_quyen_pc` · CH-07 · Không có quyền (chỉ Admin) (máy tính)
