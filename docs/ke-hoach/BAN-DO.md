# BẢN ĐỒ VIỆC CÒN LẠI (Chat lập 23/11/2026 từ docs/ke-hoach/man-hinh-theo-trang-thai.md sinh tự động, 197 màn, và docs/tien-do.json 12/11)

Cỡ: S = vài giờ, một PR nhỏ; M = nửa ngày đến một ngày; L = nhiều PR hoặc cần Design/anh chốt luật. Phụ thuộc ghi rõ. Cập nhật khi PR gộp (một agent giữ, xem mục 14d).

## A. Màn chưa xong theo bảng 197 màn

| Mã | Màn | Trạng thái | Cỡ | Phụ thuộc |
|---|---|---|---|---|
| CHUNG-05 | Đặt mật khẩu mới (từ link email) (HOÃN, thiết kế P1 v | Chưa có | S | hoãn/không khung; chờ thiết kế P1 |
| CHUNG-08 | Không thể đăng nhập (chốt 12/10; chữ theo thiết kế P1 | Chưa có | S | hoãn/không khung; chờ thiết kế P1 |
| CHUNG-21 | Đính kèm tệp (tải lên, xem trước) | Chưa có | S | hoãn/không khung; chờ thiết kế P1 |
| CS-07 | Thực hiện chuyển cơ sở | Chỉ có DB* | M | không khung CS-07/10/12/14/16; chờ Design hoặc luật R-GD-09/16 |
| CS-10 | Thực hiện chuyển phí (sang môn khác, anh chị em, gói kh | Chỉ có DB* | M | không khung CS-07/10/12/14/16; chờ Design hoặc luật R-GD-09/16 |
| CS-12 | Từ chối / khách huỷ ticket (lý do) | Chưa có | M | không khung CS-07/10/12/14/16; chờ Design hoặc luật R-GD-09/16 |
| CS-14 | Thực hiện dừng học (ticket nhóm Dừng học) | Chỉ có DB* | M | không khung CS-07/10/12/14/16; chờ Design hoặc luật R-GD-09/16 |
| CS-16 | Nhận xét chờ gửi phụ huynh | Chưa có | M | không khung CS-07/10/12/14/16; chờ Design hoặc luật R-GD-09/16 |
| CHUNG-23 | Đăng nhập phụ huynh | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| QT-17 | Tài khoản phụ huynh (cấp, khoá, đặt lại) | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-01 | Trang chủ học sinh | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-02 | Bài tập (cần làm, đã nộp, đã chấm) | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-03 | Chi tiết bài tập | Chỉ có DB* | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-04 | Nộp bài (chụp ảnh, tải tệp) | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-05 | Kết quả bài và nhận xét | Chỉ có DB* | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-06 | Lịch học của em | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-07 | Kết quả học tập (tiêu chí theo thời gian) | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-08 | Nhận xét các buổi học | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| HT-09 | Khung cổng học tập (điện thoại: thanh dưới · laptop: me | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| PH-01 | Trang chủ phụ huynh (các con) | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| PH-02 | Kết quả và nhận xét của con | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| PH-03 | Học phí và giờ học của con | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| PH-04 | Gửi đề nghị / khiếu nại và theo dõi | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| PH-05 | Lịch học của con | Chưa có | L | giai đoạn sau go-live; cần Design vẽ khung cổng HS/PH |
| BC-02 | Báo cáo tuyển sinh (phễu lead → đăng ký) | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |
| BC-03 | Doanh thu ghi nhận theo buổi Done | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |
| BC-04 | Thu tiền và giờ chưa dạy (quỹ giờ còn) | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |
| BC-05 | Tái tục | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |
| BC-06 | Sĩ số, lấp đầy lớp, chuyên cần | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |
| BC-07 | BTVN (tỉ lệ làm bài, điểm TB) | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |
| BC-10 | Báo cáo ticket | Looker, không dựng màn CRM | — | anh duyệt 23/11: vẽ ở Looker Studio; vai trò DB chỉ đọc riêng sau go-live (docs/nghiep-vu/bao-cao-looker.md) |

## B. Màn đã có nhưng lệch canvas hoặc chưa so canvas (việc kiểm/sửa)

| Mã | Việc | Cỡ | Phụ thuộc |
|---|---|---|---|
| CH-04 | sửa cho đúng canvas (có (4 khung)) | S | không |
| TC-01 | sửa cho đúng canvas (có (17 khung)) | S | không |
| TC-04 | sửa cho đúng canvas (có (20 khung)) | S | không |
| TC-15 | so với canvas (có (16 khung)) | S | không |
| CH-05 | so với canvas (có (14 khung)) | S | không |
| CH-06 | so với canvas (có (14 khung)) | S | không |
| CS-01 | sửa cho đúng canvas (không có khung) | S | không |
| CH-07 | so với canvas (có (14 khung)) | S | không |
| BC-08 | so với canvas (có (10 khung)) | S | không |
| BC-09 | so với canvas (có (16 khung)) | S | không |

## C. Việc khác còn mở

(GV-17, GV-18 giao diện đã gộp 23/11: #472, #474; bảng sinh tự động sẽ cập nhật sau.)

- Group By cho KH-01, CS-01, TT-01, TT-04 (kho #19) · S · không.
- Câu hỏi luật còn chờ anh: LOP-02 (câu 2, 4), Kho #14 (TC-04 Xử lý, TC-10/11, TT-02, TC-03/17), GV-11 (a)–(e).
- Chạy thật: deploy production, nạp dữ liệu thật, thử tay T4/T5 trên staging: anh.

## D. Theo docs/tien-do.json (bản 12/11, 72 tính năng; 16 chưa «da_gop» ở thời điểm đó; nhiều mục đã gộp sau 12/11, cần rà lại bằng bảng ở mục A)

| Cổng | Mã | Tính năng | Giai đoạn |
|---|---|---|---|
| VAN-HANH | VH-02 | Xác nhận trạng thái migration của hmt-prod | chua_lam |
| VAN-HANH | VH-03 | Anh kiểm tay trên staging (14/11) | chua_lam |
| VAN-HANH | VH-04 | Diễn tập nạp dữ liệu trên staging | chua_lam |
| VAN-HANH | VH-05 | Sao lưu và deploy production (16/11 tối) | chua_lam |
| VAN-HANH | VH-06 | Nạp dữ liệu cơ sở 5, chạy thật (17/11) | chua_lam |
| SAU-17-11 | S-01 | Ticket (CS) | chua_lam |
| SAU-17-11 | S-02 | Quản trị QT-04, QT-05, QT-08, QT-09, QT-10 | chua_lam |
| SAU-17-11 | S-03 | Giáo viên GV-09 đến GV-12, GV-14, GV-16 | chua_lam |
| SAU-17-11 | S-04 | Báo cáo | chua_lam |
| SAU-17-11 | S-05 | Cổng học tập và cổng phụ huynh | chua_lam |
| SAU-17-11 | S-06 | Hoàn tiền, bảo lưu, chuyển lớp | chua_lam |
| SAU-17-11 | S-07 | Đối soát | chua_lam |
| SAU-17-11 | S-08 | Cột Đúng hạn/Trễ hạn và báo cáo tham số, cờ cơ sở 5 | chua_lam |
| SAU-17-11 | GV-02B | GV-02B Tab «Cần làm» của cổng giáo viên | chua_lam |
| SAU-17-11 | GV-03 | GV-03 Tab «Lịch dạy» | chua_lam |
| SAU-17-11 | GV-LOP | Tab «Lớp» của cổng giáo viên | chua_lam |
