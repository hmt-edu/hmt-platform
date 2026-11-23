# Rà màn nhóm B (không có khung canvas) so luật và khuôn chung, 23/11/2026

Thẻ D-23-10. Cách rà: đọc dòng màn trong `docs/design/ban-do-man-hinh.md`, luật trong `docs/spec/`, code màn; kiểm nội dung, quyền, trạng thái tải/rỗng/lỗi, khoá nút khi lưu, không dùng hộp thoại trình duyệt, phân trang ở máy chủ, dùng khuôn chung. Chỉ đọc code, không chạy DB. Số luật S03-11, S03-12, S03-14, S03-16, S03-18, S03-21 không tìm thấy trong `docs/spec/` nên chưa đối chiếu được theo số đó.

| Màn | Kết quả | Chỗ lệch | Xử lý |
| --- | --- | --- | --- |
| CHUNG-14 Trang chủ theo vai | Gần đúng | Bản đồ nêu 4 loại việc, code mới có khối lịch hẹn; ba khối còn lại chờ màn nguồn (TC-04, BUOI-01, CS-01). Chưa chắc nút «Mở danh sách» đã lọc sẵn «của tôi, hôm nay». | Ghi nhận, làm khi màn nguồn xong |
| CHUNG-16 Không có quyền | Đúng | | |
| CHUNG-17 Không tìm thấy, lỗi hệ thống | Đúng | «Thử lại» tải lại cả trang; «Về trang chủ» trỏ `/` (đã có chuyển về đúng cổng). Chấp nhận. | |
| CHUNG-20 Xoá bản ghi nhập nhầm | Gần đúng | Bản đồ ghi «Xoá cứng», code là «Huỷ lead nhập nhầm» (đổi trạng thái), đúng luật không xoá cứng. | Sửa chữ trong bản đồ thành «Huỷ có lý do (không xoá cứng)» |
| CHUNG-24 Phân hệ chưa bật | Đúng | | |
| CHUNG-25 Chọn cổng | Đúng | Hiện thêm cổng học tập, phụ huynh và nhãn «chỉ xem» ngoài bản đồ (không hại). | |
| CHUNG-26 Xác nhận chung, cảnh báo rời trang | Đúng | Không còn `alert/confirm/prompt` trong `src`. Chưa kiểm hết màn có form riêng đã dùng `UnsavedGuard`. | |
| QT-04 Vai trò | Gần đúng | Hiện thêm «Số người», «Ô quyền»; đếm và tìm ở trình duyệt (chỉ vài dòng). Nút «Thử lại» không khoá khi đang tải lại. | Không cần |
| QT-05 Ma trận quyền | Gần đúng | Thiếu cảnh báo rời trang khi đang sửa có ô đã đổi. «Xem lịch sử → QT-11»: lịch sử hiện 5 phiên bản trên trang, không liên kết sang QT-11. Lưu thẳng, không qua hộp xác nhận (bản đồ không đòi). | Đã thêm `UnsavedGuard`. Liên kết sang QT-11: hỏi anh |
| QT-06 Danh mục | Đúng | Danh sách danh mục không phân trang (số danh mục ít, chưa đọc hàm tổng hợp). | |
| QT-10 Công tắc tính năng | Đúng | Chưa mở `teachingBranches` để xác nhận cột CS3. | |
| QT-11 Nhật ký thao tác | Gần đúng | Bản đồ ghi «Lọc; Xuất», màn chỉ đọc, không có nút Xuất. Xuất cần hàm DB và ghi nhật ký xuất file (CHUNG-18). | Cần anh quyết: làm Xuất hay bỏ khỏi bản đồ |
| QT-12 Nhật ký đăng nhập, xuất file | Đúng | | |
| CH-02 Gói bán (bản ghi) | Gần đúng | Lỗi tải hiện «Không tìm thấy», không có nút Thử lại; Spinner trần; chữ giữ chỗ «làm sau» ở ghi chú bên cạnh. | Đã tách lỗi tải có nút Thử lại, thêm nhãn Spinner. Chữ «làm sau» để lại |
| CH-08 Chiến dịch marketing | Gần đúng | Tự dựng bằng LineTable, chưa chắc khớp K10. Biểu mẫu tạo chưa kiểm ngày kết thúc ≥ ngày bắt đầu (DB đã chặn, giao diện chỉ báo sau khi gửi). «Ngừng» chạy ngay không qua hộp xác nhận. | Đã thêm kiểm ngày ở giao diện. Hộp xác nhận «Ngừng» và khuôn K10: hỏi anh |

Cần anh quyết: (1) QT-11 có làm nút Xuất; (2) QT-05 có liên kết «Xem lịch sử» sang QT-11; (3) CH-08 «Ngừng» có hộp xác nhận.
