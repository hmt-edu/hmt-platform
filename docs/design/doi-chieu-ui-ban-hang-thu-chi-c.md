# So canvas nhóm Bán hàng, Thu chi (lượt C, 19/11/2026)

Cách rà: đối chiếu chữ nhãn của khung canvas (abea, 9933, 1aab) với chữ trong mã; chưa chụp màn hình từng điểm ảnh (Tester kiểm trên staging). Kết quả ghi theo luật 21:32.

| Màn | Kết quả | Ghi chú |
| --- | --- | --- |
| TC-17 Phiếu thu (bản ghi) | **Lệch, đã sửa một phần** (#363) | Thêm cột Học sinh, Thành tiền ở bảng chia tiền. CẦN CHAT: cột Lớp, Giờ cấp (cần hàm DB trả theo dòng); bản xem trước chia tiền ở bước Đã trình; «Tài khoản nhận» chưa lưu |
| TC-03, BH-09 Đơn hàng (bản ghi đã duyệt) | **Gần đúng, đã sửa chữ** (#364) | Tiêu đề «Lịch đóng tiền từng đợt (tự tính, chỉ đọc)», chữ khối Phiếu thu trống. Còn: nhãn «Đã duyệt · khoá», chú về xếp lớp, chuyển lớp |
| TC-09 Hoàn tác khoản tiền | **Đúng về cột, Gần đúng về chữ** | Danh sách TC-08 đã có cột Ghi chú, nút «Hoàn tác khoản tiền» (hộp lý do K08), khoản đảo «Hoàn tác của …». Lệch nhỏ: canvas ghi «Đã hoàn tác bằng …0006» (mã khoản đảo), mã ghi «Đã hoàn tác»: cần `list_money_in` trả mã khoản đảo. Đã có từ trước, không phải màn mới |
| TC-10, TC-11 Phiếu chi | Lệch (đã nêu ở #347, #356) | CẦN CHAT: hình thức chi, tài khoản nhận, ngày chi dự kiến |
| TC-07 Biên nhận (in) | Gần đúng | Nhãn khung in khớp; «Khổ giấy», «Màn nguồn» là chú thích thiết kế, không phải giao diện |
| BH-03 Báo giá (in) | Gần đúng | Như TC-07 |
| BH-02 Báo giá, đơn (tạo/sửa, 27 khung) | **Chưa kiểm được bằng nhãn** | Nhiều nhãn nút «+ Thêm em», «+ Thêm cả nhà», «+ Thêm quà tặng» ghép biểu tượng nên so chữ không đủ: cần Tester so ảnh trên staging |
| CH-05, CH-06, CH-07 | Không có khung cùng mã trong canvas abea, 9933; thuộc 1aab (Code A đã làm) | Giao Tester/Code A |
