# Kế hoạch video hướng dẫn (A-23-41b, 24/11/2026)

Hướng đi anh Trường chốt 24/11: video quay bằng Playwright trên dữ liệu mẫu, có **chữ chú thích từng bước ngay trên màn hình**, 1280×720, mỗi video 1–3 phút cho luồng chi tiết, nén mp4. **Video không nằm trong repo**: lưu trên Google Drive của tài khoản vận hành, trang Hướng dẫn nhúng khung xem trước qua file manifest. Danh sách luồng lấy từ `docs/huong-dan/KE-NGHIEP-VU.md` (PR #696) (mã luồng ở cột đầu).

## Cách hoạt động
1. Quay và nén video (mp4, H.264, không tiếng, 1280×720, 15–25 khung hình/giây).
2. Anh kéo thả cả loạt vào một thư mục Drive; đặt «ai có đường liên kết đều xem được». **Chỉ dữ liệu giả** (nội dung «[MẪU]»), không tên thật.
3. Lấy ID file từ đường dẫn `https://drive.google.com/file/d/<ID>/view`.
4. Ghi vào `public/huong-dan/video-manifest.json`: `"ts1": { "drive": "<ID>" }`. Muốn lưu nơi khác (R2, máy chủ riêng) chỉ đổi dòng đó thành `{ "url": "https://…/ts1.mp4" }`; không sửa code.
5. Trong bài viết chỗ cần video: `[VIDEO: ts1]` (tên = mã luồng viết thường). Bài **chưa có** dòng trong manifest hiện «Video đang cập nhật».
6. Trang đọc manifest mỗi lần mở (không lưu bộ nhớ đệm trình duyệt lâu), nên thêm video mới **không cần dựng lại** ứng dụng nếu chỉ sửa manifest ở bản đã chạy; đổi file trong repo thì theo quy trình gộp PR bình thường.
- Sáu video cũ (≤ 60 giây, trong `public/huong-dan/video/`) đã ghi vào manifest dạng `url` nội bộ, vẫn chạy; có thể thay dần bằng bản quay mới rồi xoá file khỏi repo.
- Khung nhúng: `drive.google.com/file/d/<ID>/preview` trong iframe có `sandbox`; CSP hiện cho phép khung `https:`. Nếu sau này siết `frame-src`, thêm đúng `https://drive.google.com`.

## Ước lượng
- **Dung lượng:** các video cũ đo được ~0,27 MB mỗi phút (116–272 KB cho 26–60 giây). Ước **0,3–0,5 MB/phút** (màn nhiều chữ, có chú thích). 
- **P1 (51 luồng, khoảng 95 phút theo bảng dưới):** ~**30–50 MB**. **Cả 112 luồng:** ~70–110 MB (P2, P3 quay sau).
- **Drive 15 GB dùng chung** với ảnh bài nộp: video P1 chiếm dưới 0,5%; không đáng lo. Không tốn băng thông Supabase hay Cloudflare Pages (video do Drive phát).
- **Công quay:** mỗi video một kịch bản Playwright (đăng nhập tài khoản giả, đi các bước, chèn chú thích bằng lớp phủ chữ, `recordVideo` 1280×720). Khoảng 0,5–1 ngày công cho 5 video đầu để dựng khung chung (lớp phủ chú thích, nhịp dừng giữa bước, nén bằng ffmpeg), sau đó mỗi video thêm ~1–2 giờ gồm viết kịch bản và xem lại. **Chưa quay hàng loạt cho tới khi anh xem bản kê này.**
- **Rủi ro:** (1) Drive có thể hạn chế phát khi nhiều người xem cùng lúc một file; nếu gặp thì chuyển nơi lưu qua manifest. (2) Người dùng chặn cookie bên thứ ba có thể không xem được khung Drive; bài vẫn đọc được bằng chữ và ảnh. (3) Đổi giao diện thì video cũ lệch: ghi mã luồng và ngày quay trong tên file Drive để biết video nào cần quay lại.

## Luồng P1 cần video (ưu tiên quay trước)
| Mã video | Luồng | Vai | Phút | Đã có video? |
|---|---|---|---|---|
| ts1 | Tạo lead nhanh, xử lý cảnh báo trùng SĐT | SA, CS | 2 | có (huong-dan-tu-van-tong-quan, quay lại theo chuẩn mới) |
| ts2 | Nhập lead từ file CSV (ghép cột, xem trước, dòng lỗi) | SA, CS, BM | 2 | — |
| ts3 | Chăm sóc lead: đổi giai đoạn C1–C4, nhóm con, ghi chú | SA, CS | 2 | — |
| ts5 | Tạo cơ hội từ lead (cảnh báo đã có cơ hội: mở cũ / thêm em / ...) | SA, CS | 2 | — |
| ts6 | Đi cơ hội qua L1–L8 (chỉ đi tới, nhóm con, lý do, tên và năm sinh học sinh từ L5) | SA, CS | 2 | — |
| ts9 | Lịch hẹn: tạo, dời, hoàn thành 1 bấm, huỷ | SA, CS | 2 | — |
| ts10 | Tạo phiếu kiểm tra từ cơ hội (môn, khối, hình thức, lịch) | SA, CS | 2 | — |
| ts11 | Phiếu kiểm tra: Nháp → Đang test → Chờ GV chấm → Hoàn thành; huỷ; gợi ý lớp | SA, CS | 2 | — |
| kh1 | Tìm khách, xem hồ sơ phụ huynh và học sinh 360° | SA, CS, BM, KT | 2 | — |
| bh1 | Lập báo giá, dòng gói, in và gửi phụ huynh | SA, CS | 2 | — |
| bh3 | Lập đơn hàng; chọn lớp và ngày vào lớp cho dòng đơn | SA, CS | 2 | — |
| bh4 | Trình và duyệt / từ chối đơn hàng | BM, AD | 2 | — |
| tc1 | Tạo phiếu thu từ đơn hàng (đợt, hạn, hình thức) | SA, CS | 2 | — |
| tc2 | Quản lý (Trưởng cơ sở) duyệt phiếu thu | BM | 2 | — |
| tc3 | Kế toán duyệt / từ chối phiếu thu | KT | 2 | có (huong-dan-ke-toan-phieu-thu, quay lại theo chuẩn mới) |
| tc6 | Khoản tiền vào (sổ thu tiền) và đảo khoản | KT, BM | 2 | — |
| tc7 | Công nợ và thu nợ đầu kỳ | KT, BM, SA, CS | 2 | — |
| tc9 | Phiếu chi: lập, duyệt, in (kể cả chi hoàn học phí) | KT, BM | 2 | — |
| dt1 | Ghi danh: xem danh sách, bản ghi, số giờ | CS, BM | 2 | — |
| dt2 | Xếp lớp cho ghi danh (theo nhóm hoặc theo lớp), hàng chờ xếp lớp | CS, BM | 2 | — |
| dt6 | Tái tục: phiếu tái tục (danh sách, kanban L1–L8, tạo thủ công) | CS, SA | 2 | — |
| dt7 | Tạo / sửa lớp, thời khoá biểu, trình duyệt | CS | 2 | — |
| dt8 | Duyệt / từ chối lớp | BM | 2 | — |
| dt12 | Buổi học: danh sách hôm nay, bản ghi; theo dõi buổi chưa Done | CS, BM | 2 | — |
| dt13 | Điểm danh vận hành trong ngày (gọi nhắc, lý do liên hệ) | CS | 2 | — |
| dt14 | Huỷ buổi, dời một buổi | CS, BM | 2 | — |
| cs1 | Tạo ticket (loại, nhóm, nhóm con) và xử lý | CS, SA | 2 | — |
| cs2 | Khiếu nại: xử lý, nâng cấp, mở lại | CS, BM | 2 | — |
| cs3 | Phiếu nghiệp vụ, cách làm chung và duyệt từng cấp | CS, BM, KT | 2 | — |
| cs4 | Phiếu Cập nhật hồ sơ | CS | 2 | — |
| cs12 | Hàng nhận xét chờ gửi phụ huynh | CS | 2 | — |
| gv1 | Hôm nay: xem buổi, việc sắp trễ hạn | GV, TG | 2 | — |
| gv3 | Điểm danh (4 trạng thái, lưu) | GV, TG | 2 | — |
| gv4 | Nội dung buổi và giao BTVN | GV, TG | 2 | — |
| gv5 | Chấm nhận xét từng em; xuất nhận xét | GV, TG | 2 | — |
| gv6 | Chấm BTVN của buổi trước (5 trạng thái) | GV, TG | 2 | — |
| gv7 | Kiểm còn thiếu và Hoàn tất buổi (Done ngay) | GV, TG | 2 | — |
| gv8 | Việc cần làm / quá hạn | GV, TG | 2 | — |
| qt1 | Tạo người dùng; sửa email; đặt lại mật khẩu; khoá / mở | AD | 2 | — |
| qt4 | Cơ sở và phòng học | AD | 2 | — |
| qt6 | Công tắc tính năng theo cơ sở | AD | 2 | — |
| qt8 | Nhập dữ liệu cũ (CSV: chọn loại, xem trước, nạp) | AD | 2 | — |
| qt9 | Gói bán, bảng giá có ngày hiệu lực, chiết khấu, điều khoản thanh toán | AD | 2 | — |
| ch1 | Đăng nhập, đổi mật khẩu lần đầu, quên mật khẩu, hết phiên | tất cả | 1 | có (huong-dan-dang-nhap, quay lại theo chuẩn mới) |
| ch2 | Xác thực hai bước (Admin, Kế toán) | AD, KT | 1 | — |
| ch3 | Menu, chọn cơ sở, đổi cổng, đăng xuất | tất cả | 1 | — |
| ch4 | Danh sách: tìm, Filters, Group By, Favorites, cột, phân trang | tất cả | 1 | có (huong-dan-danh-sach, quay lại theo chuẩn mới) |
| ch5 | Bản ghi: mở, tạo, sửa, lưu; ghi chú; nhật ký | tất cả | 1 | có (huong-dan-ghi-chu, quay lại theo chuẩn mới) |
| ch7 | Việc chờ tôi duyệt (gộp mọi loại) | BM, KT, AD | 1 | — |
| ch8 | Trang chủ theo vai trò | SA, CS, BM, KT | 1 | — |
| ch10 | Gặp lỗi: không có quyền, phân hệ chưa bật, không tìm thấy; mã lỗi HMT_… | tất cả | 2 | — |

Thời lượng ở cột «Phút» là ước tính ban đầu (1 phút cho luồng ngắn của nhóm Chung, 2 phút còn lại); luồng dài như duyệt phiếu nghiệp vụ nhiều cấp có thể cần 3 phút. Tổng ~95 phút.
