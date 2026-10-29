# Nhật ký Claude Code (cập nhật 28/10/2026)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang. Bản dài trước 28/10 nằm trong lịch sử git của file này: `git log -- docs/nhat-ky/code.md`.)

## Đang làm
- UI-O2b (BH-05 Trình, Huỷ đơn, #147): chờ CI xanh và OK của `caotruong276` sau commit cuối. Sau đó PR "Cắt phút CI" (Đ281, nhánh `ci/cat-phut-ci`, đã chạy `check:all` xanh trên máy), rồi DB-O2c (Đ283), UI-O2c (Duyệt, Từ chối), UI-O3, UI-O4.
- Đ279 đã gộp (#146): OK gộp PR từ `caotruong276`; remote Mac đã đổi sang `truongcx-95/hmt-platform`.

## Đã gộp gần đây (Bán hàng, P5a)
- DB: đơn hàng (051, 052), báo giá tên em (053), lọc Đã chuyển đơn (054, 057), xem thử, gói bán, chính sách (055), mã đơn từng dòng (056), chính sách quà tặng (058), `total_discount_percent` (059), quyền chung hàm đọc phụ và `student_names` (060), tạo đơn kèm điều khoản một giao dịch và `preview_order_students` (061).
- Giao diện BH-01, BH-02 (đủ chuỗi xem, Gửi, Từ chối, Huỷ, sửa Nháp, quà tặng, Tạo báo giá từ cơ hội), BH-06 danh sách đơn. Chi tiết nằm trong mô tả PR và `docs/TIEN-DO.md`.
- Gộp PR độc lập bằng squash, PR xếp chồng bằng merge commit (Đ240).

## Đã chốt
- Đ277: bản in báo giá giữ số điện thoại phụ huynh che giữa ("0912 *** 345").
- Đ278 (a đã sửa bởi Đ279): `truongcx-95` bật xác thực hai bước, chỉ dùng trên trình duyệt; `hmt-vanhanh` là collaborator quyền Write.
- Đ279: `truongcx-95` là chủ hai repo (đã chuyển xong); tài khoản OK gộp PR vẫn là `caotruong276` (collaborator của `hmt-platform`); Đ278a sửa lại: không thay hẳn.
- Đ255: nợ kỹ thuật `preview_quotation_lines` trả lỗi tất cả dòng trong một lần.
- Đ256 đến Đ276 (28/10): thứ tự làm; khung BH-05 là bản canvas `1793163092-bfd4` (Đ270, Đ272); canvas anh chốt thắng gói thiết kế và bản đồ (Đ271); bỏ Hình thức thanh toán, Cơ sở thu tiền khỏi đơn (Đ258); Chuyển thành đơn là form trắng bỏ bớt bằng ✕ (Đ259); gộp tạo đơn và điều khoản một giao dịch (Đ260); BH-06 Đã thu, Còn phải thu "—" (Đ262, Đ269); in báo giá mọi trạng thái, nhãn BẢN NHÁP, ĐÃ TỪ CHỐI, ĐÃ HUỶ, hộp in của trình duyệt (Đ263 đến Đ267, Đ273, Đ274); giữ chữ tiếng Anh của khuôn K03 (Đ268); bỏ gợi ý "dùng báo giá còn hiệu lực" (Đ275).
- Luật mới R-TIEN-39 (28/10): đơn thẳng từ cơ hội mà cơ hội đã có đơn Nháp thì cảnh báo, Mở đơn cũ hoặc Vẫn tạo.
- Điện thoại giữ bản chỉ đọc cho BH-02, BH-05 (Đ248). Kiểm nhẹ trên máy thay CI cho tới khi Actions có phút (Đ208, Đ212).

## Đang chờ
- Chat: duyệt chữ ký hàm và bài kiểm DB-O1c; báo canvas mới cho BH-03.
- Anh Trường: OK PR luật R-TIEN-39 và PR CLAUDE.md.
- Nhánh gốc phiếu tái tục của Tạo báo giá và Tạo đơn (TT-02, L6 và L7): chờ bảng phiếu tái tục (P5b).

## Việc theo ngày
- 31/10: chạy đủ e2e trên `main`, báo Chat.
- 1/11 (khi Actions có phút): chạy CI thật trên `main` (Đ208 mục e); rồi một PR workflow cho Đ210 (#1, #3, #4, #6), đo phút sau 7 ngày, so với 1.924 phút của tháng 10.

## File hoặc link mới
- Canvas HMT Platform nguồn mới nhất: `design/nguon-canvas/hmt-platform-v117/` (bản `e6d0`; canvas chuẩn hiện là `1793163092-bfd4` (Đ272), các khung BH05, BH06, BH07 giống bản đã lưu).
- Ảnh chụp: `docs/anh-chup/bh01/`, `bh02/`, `bh06/`, `bh05/`, `bh03/` (năm tình trạng, PDF A4 do trình duyệt xuất).
