# Nhật ký Claude Code (cập nhật 28/10/2026)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang. Bản dài trước 28/10 nằm trong lịch sử git của file này: `git log -- docs/nhat-ky/code.md`.)

## Đang làm
- Việc Chat giao 28/10, làm theo thứ tự: (1) PR tài liệu Đ256 đến Đ262 (xong khi gộp); (2) BH-06 danh sách đơn; (3) kế hoạch DB-O1 gửi Chat (chưa viết migration); (4) khảo sát BH-03 (In báo giá).
- Chưa dựng BH-05 (chờ khung mới của Design, Đ257) và BH-11 (chờ luật, Đ261).

## Đã gộp gần đây (Bán hàng, P5a)
- DB: đơn hàng (051, 052), báo giá tên em (053), lọc Đã chuyển đơn (054, 057), xem thử, gói bán, chính sách (055), mã đơn từng dòng (056), chính sách quà tặng (058), `total_discount_percent` (059).
- Giao diện BH-01 (danh sách, lọc, cột Đơn), BH-02 (xem, Gửi, Từ chối, Huỷ, sửa Nháp theo K06c, quà tặng, xem thử giá), Tạo báo giá từ cơ hội. Chi tiết nằm trong mô tả PR và `docs/TIEN-DO.md`.
- Gộp PR xếp chồng bằng merge commit, PR độc lập bằng squash (Đ240).

## Đã chốt
- Đ255: chấp nhận tạm "mỗi dòng lỗi thêm một lần gọi xem thử giá"; nợ kỹ thuật: `preview_quotation_lines` trả lỗi tất cả các dòng trong một lần.
- Đ256 đến Đ262: thứ tự BH-06, DB-O1, BH-03, rồi BH-05; khung BH-05 vẽ lại theo K06c; bỏ Hình thức thanh toán, Cơ sở thu tiền khỏi đơn; Chuyển thành đơn là form trắng bỏ bớt bằng ✕; gộp tạo đơn và lưu điều khoản một giao dịch; BH-11 chờ luật; BH-06 cột Đã thu, Còn phải thu để "—".
- Điện thoại giữ bản chỉ đọc cho BH-02 (Đ248). Mục "In" mờ đến khi BH-03 xong (Đ249).
- Kiểm nhẹ trên máy thay CI cho tới khi Actions có phút (Đ208, Đ212).

## Đang chờ
- Design: khung BH-05 mới theo K06c (Đ257).
- Chat: duyệt kế hoạch DB-O1; chữ luật BH-11 (Đ261).
- Nhánh gốc phiếu tái tục của Tạo báo giá và Tạo đơn (TT-02, L6 và L7): chờ bảng phiếu tái tục (P5b).

## Việc theo ngày
- 31/10: chạy đủ e2e trên `main`, báo Chat.
- 1/11 (khi Actions có phút): chạy CI thật trên `main` (Đ208 mục e); rồi một PR workflow cho Đ210 (#1, #3, #4, #6), đo phút sau 7 ngày, so với 1.924 phút của tháng 10.

## File hoặc link mới
- Canvas HMT Platform nguồn mới nhất: `design/nguon-canvas/hmt-platform-v117/` (bản `e6d0`, sau v124).
- Ảnh chụp BH-01, BH-02: `docs/anh-chup/bh01/`, `docs/anh-chup/bh02/`.
