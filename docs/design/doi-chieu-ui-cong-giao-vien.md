# Đối chiếu giao diện cổng Giáo viên (/gv) với canvas 9189 (Code C, 19/11/2026)

Cách rà: lấy chữ nhãn của từng khung điện thoại (`GVxx_dt`) trong `design/hmt-canvas-9189/`, so với chữ trong mã giao diện; khung lệch thì mở mã đọc tiếp. Bỏ qua tên người, số liệu minh hoạ và các khung nháp `GV07b_*`, `GV08b_*` (chưa làm, theo `CLAUDE.md`). Phạm vi: nhãn, khối, nút; chưa chụp màn hình so từng điểm ảnh.

| Màn | Kết quả | Ghi chú |
| --- | --- | --- |
| GV-01 Tài khoản, GV-03 Lịch dạy, GV-12 Cần làm, GV-13 | Đúng | Mọi nhãn canvas có trong mã |
| GV-02 Hôm nay | Lệch → **đã sửa (#281)** | Thẻ buổi không bấm được (T2-23); nay bấm mở `/gv/buoi/:id` |
| GV-04 Buổi dạy (các bước) | Lệch → **đã sửa (#281)** | «Tiến độ 0/3 bước» đi cùng chữ «đủ bốn bước»; nay dùng số bước thật |
| GV-05 Điểm danh | Đúng | Nhãn «Vận hành: …» ghép từ trạng thái vận hành lúc chạy |
| GV-06 Nội dung buổi, BTVN | Đúng | |
| GV-07 Chấm nhận xét | Lệch → **đã sửa (#282)** | Thiếu «Lưu và em tiếp theo», tiêu đề «[HS 2/4]» thô |
| GV-07K Chấm kiểm tra (điện thoại) | **Lệch cấu trúc, chưa sửa** | Canvas chấm **từng em một** (Em 2/4, Lưu và em tiếp theo); mã là **bảng cả lớp** («Lưu (cả lớp)»). Cần Chat quyết: dựng thẻ từng em cho điện thoại, giữ bảng cả lớp cho máy tính |
| GV-08 Chấm BTVN | Đúng (khung nháp `GV08b_*` chưa làm) | |
| GV-09 Hoàn tất buổi | Gần đúng | Canvas «Chưa đủ bốn bước.»; mã «Chưa đủ các bước.» (số bước đổi theo bước Bỏ qua, đúng luật R-V2-35) |
| GV-10 Lớp của tôi | Đúng | |
| GV-11 Lớp chi tiết | **Lệch cấu trúc, chưa sửa** | Canvas: một trang cuộn các khối (thông tin, Học sinh, Lịch học, Lịch sử buổi, **Tiến độ khung chương trình**, BTVN gần đây, Yêu cầu bổ trợ). Mã: bốn thẻ tab (Học sinh, Lịch, Buổi, BTVN) và **chưa có khối «Tiến độ khung chương trình»** (cần dữ liệu tiến độ khung từ hàm DB). Ghi chú 9189 nói GV-11 chưa so với fcd1: làm theo luật và bản đồ màn hình, khung chỉ tham khảo |
| GV-14 Tạo ticket giáo viên | Đúng về chữ | Các chữ «Đổi lịch học», «Khác môn»… là tên nhóm con từ danh mục |
| GV-15 Chấm kiểm tra đầu vào | Đúng | Chữ canvas có trong màn phiếu kiểm tra của giáo viên |
| GV-16, BUOI-03/07..09, GV07X | Chưa rà | Rà lượt sau |

## Việc cần Chat quyết
1. **GV-07K điện thoại từng em** (dựng lại cách chấm, cụm lớn).
2. **GV-11**: giữ tab hay chuyển trang cuộn theo canvas; thêm khối «Tiến độ khung chương trình» (cần thẻ DB trả tiến độ khung theo lớp).
