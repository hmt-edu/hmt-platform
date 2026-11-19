# Đối chiếu giao diện nhóm Chăm sóc khách hàng và Aftersale với canvas (thẻ C50)

Code C, 19/11/2026. Nguồn: `design/hmt-canvas-9189/` (CSN01..09), `design/hmt-canvas-9933/` (TT01..04). Khuôn K06 (danh sách), K10. Mỗi dòng: lệch so với canvas, mức, tình trạng.

| Màn | Chỗ lệch | Mức | Tình trạng |
| --- | --- | --- | --- |
| CSN-01 Danh sách ticket | Cột «Hạn xử lý» gộp ngày và chữ «Quá hạn / Sắp quá hạn» trong một ô; canvas cột «Hạn» chỉ hiện tình trạng hạn | Cao (gộp thông tin) | **Sửa ở PR C50 cụm 1**: «Hạn» là nhãn tình trạng (Quá hạn, Sắp quá hạn, Chờ đóng, Trong hạn); ngày hạn tách cột «Hạn xử lý» (ẩn mặc định, bật ở Cột) |
| CSN-01 | Tên cột «Người phụ trách», canvas «Người xử lý»; ticket chưa giao hiện «—», canvas «Chưa giao» | Thấp | Sửa cụm 1 |
| CSN-01 | Thứ tự cột: «Người phụ trách» đứng trước «Trạng thái»; canvas: Mã, Loại, Nhóm·Nhóm con, Học sinh, Mức độ, Trạng thái, Người xử lý, Hạn, Tạo lúc | Trung bình | Sửa cụm 1 |
| CSN-01 | Cột thêm ngoài canvas: Tiêu đề, Người gửi, Cơ sở | Thấp | «Người gửi», «Cơ sở» ẩn mặc định. **«Tiêu đề» giữ hiện** (canvas không vẽ nhưng danh sách không có tiêu đề thì khó nhận ticket; nhiều bài e2e bấm vào ô tiêu đề): **cần Chat hỏi Design** có thêm cột Tiêu đề vào khung không |
| CSN-05 Danh sách phiếu | Khớp canvas: Mã phiếu, Loại phiếu, Ticket gốc, Học sinh, Trạng thái, Cấp duyệt, Người duyệt kế tiếp, Hạn. Thêm «Cơ sở», «Ngày tạo» | Thấp | Chưa sửa; đề xuất ẩn mặc định hai cột thêm (cụm sau) |
| CSN-02 Kanban, CSN-03 chi tiết, CSN-04 hộp thoại, CSN-06 phiếu chi tiết, TT-01..04 | Chưa rà từng khung | - | Cụm sau, theo thứ tự: CSN-03, CSN-06, TT-01 (danh sách phiếu tái tục có «Ghi danh (n)», «Campaign», «Sub-stage» là nhãn tiếng Anh: rà chữ theo canvas 9933) |

Không thiếu khuôn nào cho cụm 1 (chỉ đổi cột của khuôn K06).
