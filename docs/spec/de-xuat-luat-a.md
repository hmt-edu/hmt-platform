# Đề xuất luật của Code A (chưa chốt)

Trạng thái: **ĐỀ XUẤT**, chưa phải luật. Chat chốt (hoặc đổi) rồi mới chép vào `04-luat-nghiep-vu.md`. Theo thư Chat 01:00 (16/11/2026), Code A làm mã sau cờ tắt theo đề xuất này và ghi lệch nếu Chat đổi. Căn cứ: canvas `design/hmt-canvas-9933/` (BUOI15*, GD07*), `docs/design/ban-do-man-hinh.md`, R-GD-07, R-GD-13 (đã bị R-V2-25 bỏ phần tự sinh phiếu), R-BUOI-09, R-GIO-02..04.

## BUOI-15 Điểm danh trong ngày (đề xuất)

Mã BUOI-15 hiện **không có trong bản đồ màn hình**; canvas có 6 khung (danh sách, Báo nghỉ trước, điểm danh, đang tải, trống, không quyền). Đề xuất gán: **BUOI-15 = "Điểm danh trong ngày"**, màn danh sách (khuôn K03) cho CSKH và Trưởng cơ sở theo dõi điểm danh của các buổi hôm nay.

1. **Mục đích**: một danh sách các buổi học trong ngày của cơ sở, để CSKH biết buổi nào đã có điểm danh, buổi nào thiếu, em nào báo nghỉ; chỉ xem, không sửa điểm danh tại đây (sửa ở màn buổi, R-GIO-07).
2. **Mỗi dòng là một buổi** (tên lớp · Buổi N · phòng, theo R-BUOI-08), kèm ngày, giờ, cơ sở, giáo viên, tình trạng buổi (Nháp, Đang diễn ra, Hoàn thành, Huỷ).
3. **Cột đếm điểm danh** theo trạng thái của danh mục `ATTENDANCE_STATUS`: Có mặt, Đi muộn, Vắng có phép, Vắng không phép, Chưa ghi; đếm trên các dòng điểm danh đang hiệu lực (không đếm em bị loại khỏi danh sách theo R-GIO-02..04).
4. **Cột "Điểm danh"** là tình trạng ghi: Chưa ghi, Ghi dở, Ghi đủ (đủ khi mọi em trong danh sách đã có trạng thái khác Chưa ghi). **Hai cột phụ "VH điểm danh" và "GV điểm danh"**: số em do nhân viên vận hành và do giáo viên ghi (theo người ghi cuối của từng dòng).
5. **Cột Lưu ý** chỉ là gợi ý đọc: "PH báo nghỉ n" = số em đã có báo nghỉ trước cho buổi này (xem mục 7); không chặn gì.
6. **Mặc định** lọc ngày = hôm nay theo giờ Việt Nam, cơ sở theo phạm vi quyền của người xem; phân trang 50 ở máy chủ; bộ lọc: ngày, cơ sở, giáo viên, tình trạng buổi, tình trạng điểm danh, có báo nghỉ.
7. **Báo nghỉ trước** (khung BUOI15_bao_nghi): phụ huynh báo em nghỉ trước giờ học; CSKH ghi nhận vào dòng điểm danh của buổi dưới dạng **ghi chú báo nghỉ** (ngày giờ, người nhận báo, lý do), **chưa đổi trạng thái điểm danh**: trạng thái vẫn do giáo viên hoặc vận hành ghi (Vắng có phép nếu đúng). Báo nghỉ **không trừ, không hoàn giờ**; giờ vẫn theo R-GIO-01.
8. **Quyền**: xem theo `SESSION · XEM` (phạm vi cơ sở); ghi báo nghỉ cần `SESSION · SUA` ở cơ sở của buổi (CSKH, Trưởng cơ sở). Giáo viên không dùng màn này (có màn riêng ở cổng giáo viên).
9. **Phân hệ có công tắc** `DIEM_DANH_TRONG_NGAY`, **tắt mặc định** (chạm luồng điểm danh ổn định); tắt thì ẩn menu và hàm trả "chưa bật".
10. **Chưa làm ở bản đầu**: gửi tin nhắc tự động cho phụ huynh, thống kê theo tuần; chỉ danh sách và ghi báo nghỉ.

## GD-07 Sắp hết giờ (đề xuất)

Màn danh sách (khuôn K03) dự báo hết giờ theo **(học sinh, lớp)**, cho CSKH và Trưởng cơ sở. R-GD-13 phần tự sinh phiếu tái tục đã bị R-V2-25 bỏ; đề xuất giữ màn ở dạng **dự báo chỉ đọc**, không sinh phiếu, và cột "Phiếu tái tục" chỉ hiện phiếu **đã có** (nếu có).

1. **Mục đích**: giúp CSKH thấy sớm em sắp hết giờ để tư vấn tái tục; không chặn học, không tự tạo phiếu.
2. **Mỗi dòng là một (học sinh, lớp)** có ghi danh còn hiệu lực; không tính ghi danh Bảo lưu hoặc đã Dừng, Hoàn thành, Hoàn phí.
3. **Giờ còn** = tổng giờ còn của mọi ghi danh còn hiệu lực của em ở lớp đó, kể cả giờ tặng (theo R-GD-13 cũ); cột "Ghi danh (n)" liệt kê các mã ghi danh gộp.
4. **Hết giờ dự kiến** = ngày hôm nay + giờ còn ÷ số giờ học mỗi tuần của lớp (theo khung giờ đang chạy); không có khung giờ thì để trống.
5. **Hạn gói (dự báo)** = ngày vào lớp + `package_default_validity_months` (R-GD-07); **chỉ để dự báo, không chặn**. Một ghi danh một lớp nên mỗi lớp một hạn riêng (khớp ghi chú "CHỜ anh quyết 17/10" ở R-GD-07); nhiều ghi danh trong cùng lớp thì lấy hạn **muộn nhất**.
6. **Tình trạng** (chỉ gợi ý, không lưu): **Hết giờ** khi giờ còn ≤ 0; **Sắp hết giờ** khi giờ còn ≤ `upsale_hours_left_threshold` hoặc hết giờ dự kiến còn ≤ `upsale_days_left_threshold` ngày; **Quá hạn gói, còn giờ** khi quá hạn gói mà còn giờ (vẫn học bình thường, R-GD-07); còn lại không hiện.
7. **Phiếu tái tục**: hiện mã phiếu đã tồn tại của (học sinh, lớp) nếu có (chỉ đọc, bấm mở); nếu không có thì ghi "Chưa có phiếu". Nút tạo phiếu tay **không có** (R-TIEN-02).
8. **Bộ lọc, sắp xếp**: cơ sở theo phạm vi quyền, lớp, giáo viên, môn, tình trạng; mặc định sắp theo hết giờ dự kiến tăng dần; phân trang 50 ở máy chủ, tính ở DB (một hàm rpc), không tải cả bảng.
9. **Quyền**: xem theo `ENROLLMENT · XEM` (phạm vi cơ sở); không có thao tác ghi. Phân hệ có công tắc `SAP_HET_GIO`, **tắt mặc định**.
10. **Điểm cần anh quyết (vẫn chờ)**: (a) hạn gói theo từng lớp hay theo ghi danh gốc (đề xuất theo lớp, mục 5); (b) có giữ ngưỡng `upsale_*` làm tham số cho màn này không (đề xuất giữ, để dùng lại khi anh cho tự sinh phiếu); (c) `absence_risk_sessions` (3 buổi) có hiện thêm cờ "nguy cơ nghỉ" ở màn này không (đề xuất chưa).
