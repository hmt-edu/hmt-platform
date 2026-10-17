# P5c: Chăm sóc KH (Ticket)

(Dán sau brief chung.)

Canvas: **"P5c Chăm sóc KH"**. Giai đoạn 2 (máy tính). Mã màn: **CS-01 đến CS-16** (không có CS-15 trong bản đồ).

**Mức A:** CS-02 Ticket đề nghị (bản ghi), CS-03 Ticket khiếu nại (bản ghi), CS-05 Thực hiện hoàn tiền (bảng tính hoàn).
**Mức B:** CS-01 (danh sách và kanban theo bước), CS-04 Tạo ticket (biểu mẫu), CS-06 Chuyển lớp, CS-07 Chuyển cơ sở, CS-08 Duyệt, từ chối từng cấp, CS-09 Bảo lưu, CS-10 Chuyển phí, CS-11 Đổi lịch học, CS-16 Nhận xét chờ gửi phụ huynh.
**Mức C: không vẽ**, ghi dựng từ khuôn nào: CS-12, CS-13, CS-14.

**Chú ý riêng**
- **Hai loại ticket:** Đề nghị và Khiếu nại, hai luồng trạng thái khác nhau. Đề nghị: Mới → Đang xử lý → Chờ duyệt → Đã duyệt → Đang thực hiện → Hoàn thành, có chuỗi người duyệt. Khiếu nại: Mới → Đã tiếp nhận → Đang xác minh → Có phương án → Chờ PH xác nhận → Đóng (hài lòng, không hài lòng), có mức độ, người bị khiếu nại, mức hài lòng. Bảy nhóm đề nghị (Chuyển lớp, Chuyển cơ sở, Bảo lưu, Chuyển phí, Hoàn tiền, Đổi lịch học, Dừng học), nhóm con theo danh mục. Màn P4 HS-07 là mẫu cách lọc theo nhóm.
- **CS-02:** nút "Thực hiện" **hiện đúng theo nhóm con**, chỉ khi ticket đã duyệt (R-CS-02): mỗi nhóm con mở hộp thoại thực hiện tương ứng (CS-05, 06, 07, 09, 10, 11, 14). Thao tác thật ghi ngược mã ticket.
- **CS-04 Tạo ticket:** trường thay đổi theo nhóm con; chọn học sinh, phụ huynh, lớp **từ hồ sơ có sẵn**; **ô ghi danh chọn được nhiều ghi danh** (học sinh Đại + Hình có hai ghi danh; bảo lưu, dừng học, chuyển cơ sở áp cho các ghi danh đã chọn); kênh tiếp nhận, mức độ, mô tả, đính kèm. Dùng cả từ hồ sơ học sinh, phụ huynh (nút "Tạo ticket") và từ App Giáo viên (GV-14, chỉ tạo).
- **CS-05 Hoàn tiền:** bảng tính hoàn (giờ đã học × giá gốc, bỏ chiết khấu, trừ phí xử lý, giờ tặng không hoàn), sinh phiếu chi (nối TC-11 ở P5a). CS-10 Chuyển phí: dừng ghi danh cũ, quy tiền còn lại sang đơn mới; thiếu đóng thêm, dư hoàn hoặc giữ số dư. **Mới (17/10):** chuyển phí cũng là cách duy nhất để chuyển giờ từ ghi danh (lớp) này sang ghi danh (lớp) khác của cùng học sinh.
- **CS-06, CS-07, CS-09:** chuyển lớp (đóng dòng xếp lớp cũ, mở dòng mới; giờ còn lại đi theo ghi danh; Đại và Hình là hai ghi danh nên đổi riêng), chuyển cơ sở (giữ nguyên giờ; **quản lý hai cơ sở cùng duyệt**, cơ sở đích được xem ticket), bảo lưu (từ ngày, đến ngày ≤ tối đa, giữ nguyên giờ).
- **CS-16:** lời nhắn phụ huynh sau mỗi buổi đã chấm xong: xem, sao chép nhanh, xuất ảnh để gửi Zalo tay, đánh dấu đã gửi (R-CS-13). Nội dung lấy từ App Giáo viên.
- **Ticket chăm sóc tháng** (R-CRM-30, 04f): mỗi học sinh đang học mỗi tháng một ticket, tự sinh, giao CSKH của cơ sở có lớp chính; xuất hiện trong CS-01 với loại riêng, hạn xử lý là tham số cấu hình.
- SLA và người duyệt là cấu hình (không viết cứng): hiển thị "sắp quá hạn", "quá hạn" bằng thẻ trạng thái chung của hệ thống.

Nối với: nhóm B, C, E, H, I. Vẽ CS-01, CS-02, CS-03, CS-04 trước, rồi các hộp thoại thực hiện.
