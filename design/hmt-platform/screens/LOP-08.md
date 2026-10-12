**LOP-08 · Lịch tuần cơ sở (theo phòng, giáo viên)** — mức A · Lịch · K05 · Máy tính · vai trò: CS, BM, AD.

- Nội dung (bản đồ): Mọi buổi trong tuần theo phòng hoặc giáo viên; thấy trùng phòng, trùng GV
- Hành động: Mở buổi; Lọc · Dẫn tới: BUOI-02 · Luật: R-LOP-08
- Trạng thái đã vẽ: Có dữ liệu, Trống, Đang tải, Lỗi, Không có quyền
- Ghi chú: Trùng phòng và trùng giáo viên đều là cảnh báo kèm chữ trên buổi (không dùng màu làm tín hiệu duy nhất). Chuyển Ngày + theo phòng để thấy ba buổi Thứ Năm cạnh nhau. Bấm buổi để mở ngăn kéo, nút mở bản ghi buổi (BUOI-02).
- Điểm cần soát: Trùng phòng, trùng giáo viên hiện bằng chữ trên buổi (EventChip conflict = room/teacher/both).
- Dựng bằng: Alert, Badge, Button, Calendar, Chip, Drawer, PageHeader, Skeleton; dữ liệu trong thẻ là dữ liệu giả.
