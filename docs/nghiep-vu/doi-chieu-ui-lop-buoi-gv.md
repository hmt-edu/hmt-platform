# Rà UI Lớp, Buổi, Giáo viên với canvas 9189 và 9933 (Code F, 19/11/2026; thẻ F66)

Cách làm: lấy mọi chữ hiện trong các khung canvas cùng mã màn (`LOP02*`, `LOP03*`, `BUOI02*`…), tìm trong `src/`; chữ không thấy được xét tay (tên người mẫu, chữ nhật ký «· Hệ thống», nội dung mẫu, mục lấy từ danh mục DB không tính là lệch). Chưa so bằng ảnh bản dựng, nên «Gần đúng» cần Tester xem ảnh.

| Màn | Chỗ canvas có mà code chưa thấy | Kết quả |
|---|---|---|
| LOP-02 Lớp (bản ghi) | khối «Tổ chức lớp» với lựa chọn «Học chung» hoặc «Học riêng», «Cùng nhóm:», «Lớp còn lại của nhóm:», nút «Sửa Time Table», câu «Bốn ô Lịch học, Phòng, Giáo viên, Trợ giảng ở trên tự sinh từ đây» | **lệch**: code chỉ có cột «Nhóm lớp» và ô «Tên chung của nhóm», chưa có khối Tổ chức lớp; cần Chat xác nhận luật nhóm lớp (Code A) |
| LOP-03 Tạo, sửa lớp | cùng khối «Tổ chức lớp»; «Tạo lớp còn lại cho nhóm này»; «Xem trước ngày kết thúc dự kiến» (số buổi theo khung, đã bỏ ngày nghỉ lễ); câu lỗi «Bắt buộc nhập…» | **lệch**: ba chỗ thiếu (khối Tổ chức lớp, tạo lớp còn lại, khung xem trước); câu lỗi khác chữ |
| LOP-05 Trình, xác nhận, duyệt, từ chối lớp | khối «Tổ chức lớp» (như LOP-02) | **gần đúng** |
| LOP-06 Đóng, huỷ lớp | khối «Tổ chức lớp» (như LOP-02); các câu chặn có | **gần đúng** |
| LOP-08 Lịch tuần cơ sở | chú giải «Cùng nhóm: cùng màu viền», «Cảnh báo trùng phòng hoặc giáo viên (không chặn)» | **gần đúng**: có luân phiên và cảnh báo trùng, thiếu chữ chú giải |
| BUOI-02 Buổi học (bản ghi) | «Kênh báo», «Người ghi» (buổi nháp), «Trung tâm huỷ buổi (cả lớp nghỉ)», «Buổi đã huỷ theo yêu cầu của học sinh lớp riêng» | **gần đúng**: thiếu các nhãn ở khối huỷ buổi và ghi nhận báo vắng |
| BUOI-04 Huỷ buổi | «Buổi đã huỷ: không có nhận xét» | **gần đúng** |
| BUOI-05 Dời buổi, BUOI-06 Thêm học thử | không có chữ thiếu | khớp |
| BUOI-07 Học bù (tạo), BUOI-08 Củng cố (tạo), BUOI-09 Bổ trợ (tạo) | «Thông tin yêu cầu», «Nhãn bài hiện tại», «Nhãn bài sau khi chèn», câu lỗi «Bắt buộc chọn buổi học bù», «Bắt buộc nhập ngày buổi củng cố» | **gần đúng**: thiếu nhãn khối và chữ lỗi |
| BUOI-11 Điểm danh vận hành | chỉ có tên mẫu và nhãn «Lọc thông minh» | khớp |
| BUOI-13 Đổi giáo viên một buổi, BUOI-14 Sửa điểm danh | chỉ có tên mẫu | khớp |
| GV-11 Lớp (chi tiết giáo viên) | «Lớp chưa có học sinh và chưa có buổi», «Về Lớp của tôi» (trạng thái trống) | **gần đúng**: thiếu câu trạng thái trống |

Không rà: LOP-04, LOP-07, LOP-10 (đã gộp vào LOP-03), LOP-09 và GV-17, GV-18 (chưa có màn).
