# Nhật ký Claude Code (cập nhật 28/10/2026)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang. Bản dài trước 28/10 nằm trong lịch sử git của file này: `git log -- docs/nhat-ky/code.md`.)

## Đang làm
- Không còn PR của em đang mở (còn #86, #69 là PR lưu canvas của Design, em không đụng).
- Việc Chat giao 28/10: (1) PR tài liệu ghi QĐ-Đ255 và nợ kỹ thuật; (2) khảo sát chỉ đọc BH-05 (bản ghi đơn), BH-06 (danh sách đơn), hộp Chuyển thành đơn, BH-11. Chưa code BH-05.

## Đã gộp gần đây (Bán hàng, P5a)
- DB: đơn hàng (051, 052), báo giá tên em (053), lọc Đã chuyển đơn (054, 057), xem thử, gói bán, chính sách (055), mã đơn từng dòng (056), chính sách quà tặng (058), `total_discount_percent` (059).
- Giao diện BH-01 (danh sách, lọc, cột Đơn), BH-02 (xem, Gửi, Từ chối, Huỷ, sửa Nháp theo K06c có chiết khấu, giờ tặng, quà tặng, xem thử giá), Tạo báo giá từ cơ hội. Chi tiết từng PR nằm trong mô tả PR và `docs/TIEN-DO.md`.
- Gộp PR xếp chồng bằng merge commit, PR độc lập bằng squash (Đ240).

## Đã chốt
- Đ255: chấp nhận tạm "mỗi dòng lỗi thêm một lần gọi xem thử giá"; nợ kỹ thuật: `preview_quotation_lines` trả lỗi tất cả các dòng trong một lần (ghi ở `docs/design/quyet-dinh-thiet-ke-13-10.md` và mục Việc để sau của `docs/TIEN-DO.md`).
- Điện thoại giữ bản chỉ đọc cho BH-02, ẩn nút Sửa và Tạo (Đ248). Nút In mờ đến BH-03 (Đ249).
- Kiểm nhẹ trên máy thay CI cho tới khi Actions có phút (Đ208, Đ212).

## Đang chờ
- Anh Trường và Chat duyệt bản khảo sát BH-05, BH-06 rồi mới code.
- Nhánh gốc phiếu tái tục của Tạo báo giá (TT-02, L6 và L7): chờ bảng phiếu tái tục (P5b).
- Nút Huỷ báo giá đã dựng theo khung K06c (Đ239); BH-03 (In) chưa có.

## Việc theo ngày
- 31/10: chạy đủ e2e trên `main`, báo Chat.
- 1/11 (khi Actions có phút): chạy CI thật trên `main` (Đ208 mục e); rồi một PR workflow cho Đ210 (#1, #3, #4, #6), đo phút sau 7 ngày, so với 1.924 phút của tháng 10.

## File hoặc link mới
- Canvas HMT Platform nguồn mới nhất: `design/nguon-canvas/hmt-platform-v117/` (bản `e6d0`, sau v124; README ghi danh sách file đổi).
- Ảnh chụp BH-01, BH-02: `docs/anh-chup/bh01/`, `docs/anh-chup/bh02/`.
