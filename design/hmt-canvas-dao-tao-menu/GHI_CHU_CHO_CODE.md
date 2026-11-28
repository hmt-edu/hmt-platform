# HMT Đào tạo: menu và điểm danh (canvas riêng, nhập 27/11/2026)

Chỉ thiết kế; chưa dựng. Chỗ vênh luật thì làm theo luật và ghi vào PR. Tên, số điện thoại, số trong khung là dữ liệu giả, số minh hoạ, không chép vào code hay test.

## Danh sách màn
| Khung | Nội dung |
|---|---|
| Menu | Menu trái, vẽ lại một lần, áp cho mọi màn |
| MenuMobile | Menu điện thoại: thanh dưới và ngăn kéo |
| Main | Điểm danh, một bảng (máy tính) |
| DiemDanhMobile | Điểm danh, điện thoại |
| DiemDanh7Ngay | Điểm danh, 7 ngày qua, nhóm theo ngày rồi theo lớp, lọc Chưa điểm danh |
| DiemDanhMobile7Ngay | Điểm danh, điện thoại, 7 ngày |
| GhiDanh | Ghi danh, tab Chờ xếp lớp |
| BuoiHoc | Buổi học, danh sách |
| BuoiHocTuan | Buổi học, lịch tuần |
| BuoiHocMobile | Buổi học, lịch tuần (điện thoại) |
| ManPhu | Chi tiết buổi, Done hàng loạt, Nhập thay giáo viên |
| NhatKy | Quản trị, Nhật ký (hai tab) |

## Ghi chú trên canvas
- Menu: Lịch hẹn bỏ khỏi Tuyển sinh. Đào tạo có 5 mục. CSKH thêm Sắp hết giờ. Cấu hình và Quản trị có nhóm con. Quản trị: mục «Nhật ký» riêng, bên trong hai tab (hệ thống, nghiệp vụ).
- Điểm danh (**bản 28/11/2026, anh Trường OK 09:12; thay bản có hai tab**): một màn, một bảng khuôn K03, **mỗi dòng một học sinh trong một buổi**. Bỏ tab «Cần gọi» (khung CanGoi đã xoá).
  - Cột: Giờ (kèm ngày) · Lớp (tên rút gọn, dòng dưới là mã) · Học sinh (tên, mã) · Phụ huynh · SĐT (bấm gọi) · Giáo viên · GV điểm danh (chỉ xem, kèm giờ tích) · Vận hành (Có, Muộn, VP = vắng có phép, KP = vắng không phép; bấm là lưu, không xoá về trống) · Lệch (tô cam) · Liên hệ phụ huynh (lý do và ghi chú ngay trên dòng) · Phụ trách.
  - Lọc nhanh (chọn nhiều là HOẶC): Chưa vào lớp, Vắng, Đi muộn, Chưa điểm danh, Lệch. Lọc: ngày, cơ sở, lớp, giáo viên, phụ trách.
  - Nhóm mặc định ngày rồi lớp, đổi được (Ngày, Lớp, Giáo viên, Không nhóm). Chọn nhiều dòng để «Gán cùng lúc». Buổi Done khoá cột Vận hành. Phân trang máy chủ 50 dòng.
  - Điện thoại: mỗi dòng thành một thẻ cùng đủ thông tin; cơ sở, lớp, giáo viên, phụ trách, nhóm theo nằm trong tấm «Lọc».
  - **Chỗ canvas tự đặt, cần Chat hoặc anh xác nhận trước khi dựng:** trạng thái dùng để đếm và lọc lấy ô giáo viên, trống thì lấy ô vận hành (R-DD-02, danh sách gọi nhắc); «Chưa vào lớp» = chưa được ghi Có mặt, Đi muộn hay Vắng có phép; «Chưa điểm danh» = cả hai ô đều trống.
