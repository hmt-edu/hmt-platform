Trạng thái BTVN của mỗi em cho mỗi bài (R-GV-11): Đã chấm · Làm chưa xong · Không làm · Nộp sau · Không áp dụng. Khi chọn "Đã chấm" hoặc "Làm chưa xong", giáo viên **gõ điểm từ 1 đến 5** (R-GV-11, A-47).

- Ô điểm là `ScoreInput`: bàn phím số trên điện thoại, căn phải, có đuôi "/ 5". Kiểm tra khi rời ô hoặc bấm Enter, với các lỗi "Điểm phải từ 1 đến 5", "Chỉ nhập số, ví dụ 4", "Tối đa 1 chữ số sau dấu phẩy". `decimals` mặc định là 1: nhận 4, 4,5 (chốt Q-6).
- Thiếu điểm khi trạng thái cần điểm: `showMissing` hiện lỗi "Nhập điểm từ 1 đến 5" (dùng sau khi bấm Hoàn tất hoặc Kiểm tra).
- Dạng xem: Badge có icon + chữ + "4/5". "Không làm" không phải điểm 0 (báo cáo tách hai chỉ số — R-GV-12).
- Bố cục tự đổi theo chỗ: hẹp thì xếp dọc (điện thoại); từ 380px thì Trạng thái và Điểm nằm cùng hàng (máy tính). Dùng `hideLabels` khi đặt trong bảng đã có tiêu đề cột.
- Cập nhật 12/10 (A-47…A-53): Thang điểm đổi thành 1–5 theo R-GV-11 (A-47); xem "4/5", lỗi "Chỉ nhập số, ví dụ 4". Kiểm tra đầu vào (GV-15) truyền 0–10.
