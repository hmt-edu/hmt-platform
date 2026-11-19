# Đối chiếu giao diện Tái tục TT-02, TT-03 với canvas 9933 (Code C, 19/11/2026)

Cách rà: lấy chữ nhãn các khung `TT02_l1, l3, l5, l6, l7, chuyen` và `TT03_tao`, so với chữ trong mã (luật 21:32: ghi «So canvas»).

| Màn | Kết quả | Chỗ lệch |
| --- | --- | --- |
| TT-01 Danh sách | Đúng | Cột khớp; Group By đã thêm (#350) |
| TT-02 Bản ghi phiếu tái tục | **Lệch** | (1) Thiếu khối **«Lịch sử liên hệ»** (bảng Ngày, Kênh, Kết quả) và dòng «Lần liên hệ gần nhất»: cần ghi chú/lịch hẹn gắn vào phiếu (chưa đăng ký `UPSALE` ở `note_target`, đã báo Chat) → **CẦN CHAT**. (2) Thiếu «Đã mua gần nhất» ở khối Tổng quan: cần dữ liệu (đơn gần nhất của em) → CẦN CHAT. (3) Chữ trạng thái trống «Chưa có báo giá hay đơn tái tục. Tạo từ các nút phía trên.» **đã sửa**. (4) Thanh thông báo ở L6 «Phụ huynh đã đồng ý tái tục. Tạo báo giá hoặc tạo đơn từ phiếu này…» **đã thêm**; thanh L5 «Không tái tục. Lý do: …» đã có từ trước. (5) Nút «Tạo báo giá» từ phiếu mờ: báo giá từ phiếu chờ quyết định (PR #107). |
| TT-03 | Gần đúng | Khung `TT03_tao` hiện bảng «Đối chiếu theo tháng» (bộ lọc Campaign, cơ sở): trên mã đây là TT-04 Đối soát tái tục, chưa có màn riêng; hộp thoại tạo phiếu tay (CreateUpsaleDialog) làm theo luật, không có khung riêng |
| TT-04 Đối soát tái tục | Chưa có màn | Cần cấu hình K03 riêng (Chat/Design chốt) |
