> **CŨ — không dùng.** Cách làm theo ca này đã thay bằng quy trình hộp thư và `HANG-DOI.md` (repo điều phối). Giữ lại để tra cứu, không đọc đầu phiên.

# Cách làm việc theo ca (Q-276, hiệu lực 11/11/2026)

## 1. Vai trò
- Anh CHỦ DỰ ÁN: giao toàn bộ điều phối và quyết định cho Chat. Chỉ đọc báo cáo, sửa khi cần.
- Chat (BA + điều phối): ra kế hoạch từng ca, giao việc, quyết định (Q-xx), soát PR và bình luận OK, báo cáo anh Trường 4 lần mỗi ngày.
- Code 1, Code 2: viết mã theo hàng đợi, tự lấy việc kế tiếp, không chờ Chat khi còn việc khác.
- Claude Design: canvas và đề xuất đổi khung theo lệnh của Chat; không đăng canvas khi chưa có «OK ĐĂNG» của anh Trường.

## 2. Ca và báo cáo (giờ Việt Nam)
Ca đêm 23:00–09:00 (báo cáo 09:00); ca sáng 09:00–12:00 (báo cáo 12:00); ca chiều 12:00–17:00 (báo cáo 17:00); ca tối 17:00–23:00 (báo cáo 23:00).
Mỗi báo cáo của Chat gồm: A việc đã làm; B quyết định; C PR đã OK và đã gộp; D tiến độ; E kế hoạch ca kế tiếp; F cần anh. Chat đăng kế hoạch ca lên issue #244 ngay đầu ca.

## 3. Kênh liên lạc
- Chat ra lệnh trên issue #244: bình luận bắt đầu [CHAT→CODE1], [CHAT→CODE2] hoặc [CHAT→CẢ HAI]. Code đọc kênh ít nhất mỗi 15 phút khi đang làm và sau mỗi bước; lệnh mới nhất thắng lệnh cũ.
- Code báo trên #244: [CODE1→CHAT], [CODE2→CHAT]: mã commit, CI, việc kế tiếp, mục CẦN ANH.
- File kiểm của PR: sau mỗi commit cuối, Code dán nguyên nội dung file kiểm vào bình luận trên PR, mở đầu [FILE-KIỂM] <mã commit>.
- Claude Design: việc giao ở issue #245; kết quả và đề xuất Design gửi anh Trường dán lại cho Chat nếu Design không ghi được lên GitHub.

## 4. OK PR
Dấu OK của Chat: bình luận trên PR đúng dạng OK-CHAT-ĐÊM <mã commit>. Hợp lệ khi mã khớp commit cuối, CI xanh trên commit đó. Commit mới làm OK mất hiệu lực. Chat chỉ OK khi đã đọc file kiểm của commit cuối và không lệch luật.

## 5. Việc vẫn thuộc anh Trường
Sao lưu và deploy production; nạp dữ liệu thật; «OK ĐƯA VÀO LUẬT»; «OK ĐÓNG GÓI»; «OK ĐĂNG» canvas.

## 6. Quy tắc cho Code
Mọi quy tắc cứng trong docs/quy-tac-cung-cho-code.md vẫn giữ. Việc cần anh quyết (đổi luật, dữ liệu thật, production) ghi mục CẦN ANH rồi làm tiếp việc khác. Việc nhỏ tự chọn phương án ít thay đổi nhất, ghi lý do.

## 7. Mất liên lạc
Chat không thấy báo cáo của Code quá 2 giờ: ghi vào báo cáo cho anh Trường, anh dán lại tin giao việc. Code thấy #244 im quá 2 giờ: cứ làm tiếp theo hàng đợi, không dừng.
