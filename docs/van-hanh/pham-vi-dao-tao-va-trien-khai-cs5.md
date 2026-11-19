# Phạm vi ba việc lớn sau khi xong CRM và cổng Giáo viên: đào tạo, nạp dữ liệu thật, triển khai CS5

Soạn 19/11/2026 (Code F, theo thư Chat 16:05). Chỉ viết PHẠM VI và việc cần làm; chưa làm việc nào trên chạy thật. Việc nào cần anh quyết ghi «**cần anh quyết**». Mọi buổi tập huấn dùng staging với tài khoản giả, không dùng dữ liệu thật ở staging, local hay log.

Ba việc: (1) **Đào tạo** nhân sự cơ sở 5, (2) **Nạp dữ liệu thật** CS5 từ hệ thống cũ và Sheet (Code B viết `docs/van-hanh/ke-hoach-migrate-cs5.md`), (3) **Triển khai** dùng thật CS5. Thứ tự: (1) và (2) song song, (3) chỉ khi (1) và (2) đã đạt.

## 1. Đào tạo nhân sự cơ sở 5

| # | Việc | Sản phẩm | Ai làm | Ghi chú |
|---|---|---|---|---|
| 1.1 | Hướng dẫn theo vai (đã có bản nội dung, chưa có ảnh): `docs/huong-dan/` gồm chung, sale, cskh, ke-toan, truong-co-so, giao-vien, quan-tri | thêm ảnh chụp từ staging bằng tài khoản giả (`docs/huong-dan/CHUP-ANH.md`) | Code (ảnh), Tester (kiểm chữ khớp màn thật) | mỗi hướng dẫn có Mục đích, Ai làm, Các bước, Kết quả, Lỗi thường gặp |
| 1.2 | Bảng vai trò → màn dùng hằng ngày (một trang cho mỗi vai) | trang tóm tắt đầu mỗi hướng dẫn: «sáng mở gì, trong ngày làm gì, cuối ngày làm gì» | Code F | Admin, Trưởng cơ sở, Tuyển sinh, CSKH, Kế toán, Giáo viên, Trợ giảng |
| 1.3 | Kịch bản tập một học sinh giả đi trọn đường (lead → cơ hội → đơn → phiếu thu → ghi danh → xếp lớp → buổi → điểm danh → nhận xét → tái tục) | dùng `docs/van-hanh/kiem-tay-staging.md` (28 màn lõi) làm giáo án | Tester soạn, Chat duyệt | mỗi người tập đúng phần của vai mình |
| 1.4 | Buổi tập huấn trên staging | lịch (mỗi vai một buổi nhỏ, 60 đến 90 phút), danh sách tài khoản giả theo người, phiếu tick «đã tự làm được» | **cần anh quyết**: ngày giờ, ai dẫn buổi, họp trực tiếp hay trực tuyến | tài khoản giả đặt lại sau mỗi buổi; không nhập dữ liệu thật |
| 1.5 | Tài khoản thật của nhân sự CS5 | danh sách người, vai, cơ sở; tạo bằng màn Người dùng (QT-01) lúc go-live, KHÔNG tạo trước ở staging bằng tên thật | **cần anh quyết**: danh sách người và vai | mỗi người đổi mật khẩu lần đầu (nhân viên vẫn bắt buộc, anh chốt 19/11); Kế toán, Admin bật hai bước (tối đa 2 thiết bị) |
| 1.6 | Câu hỏi thường gặp và cách báo lỗi | một trang: lỗi hiện câu tiếng Việt thì chụp màn hình, ghi mã `HMT_…`, báo ai, qua kênh nào | Code F soạn, anh chọn kênh | **cần anh quyết**: kênh báo lỗi (nhóm chat nào) và người trả lời |

Tiêu chí xong đào tạo: mỗi vai có ít nhất một người đã tự làm trọn kịch bản của vai trên staging (phiếu tick), hướng dẫn có ảnh, người trực biết cách xử lý các lỗi hay gặp.

## 2. Nạp dữ liệu thật CS5 (tham chiếu, Code B viết kế hoạch)

Phần việc của lane F chỉ là nối với tài liệu của Code B và đảm bảo cấu hình đúng trước khi nạp:

| # | Việc | Xem ở | Ghi chú |
|---|---|---|---|
| 2.1 | Kế hoạch nạp (nguồn, cột, thứ tự, đối soát, diễn tập, quay lại) | `docs/van-hanh/ke-hoach-migrate-cs5.md` (Code B), màn QT-18 Nhập dữ liệu | thứ tự dự kiến: danh mục, người dùng, phụ huynh và học sinh, lớp, ghi danh, số dư giờ, công nợ |
| 2.2 | Cờ và tham số CS5 đúng trước khi nạp | `docs/van-hanh/cau-hinh-cs5.md` (chạy khối kiểm chỉ đọc, so từng dòng) | cờ VAN_HANH_LOP, BAN_HANG; ngày chốt số dư `opening_balance_date` |
| 2.3 | Danh mục và ngày nghỉ lễ năm học | màn Ngày nghỉ lễ (QT-14): nhập đủ ngày nghỉ năm học trước khi sinh buổi | **cần anh quyết**: danh sách ngày nghỉ lễ 2026–2027 (chung và riêng CS5) |
| 2.4 | Diễn tập nạp trên staging bằng dữ liệu GIẢ | báo cáo diễn tập: số dòng, tổng giờ, tổng tiền khớp nguồn giả | Code B, Tester |
| 2.5 | Đối soát sau nạp thật | tổng giờ và tổng tiền khớp nguồn; anh ký xác nhận | anh Trường |

## 3. Triển khai dùng thật CS5 (danh sách kiểm go-live)

Quy tắc cứng (CLAUDE.md): bản chạy thật chỉ cập nhật từ repo `hmt-deploy` do anh Trường bấm; Claude Code không có và không xin khoá chạy thật; không sửa tay DB chạy thật; không dùng dữ liệu thật ở staging, local, log.

| # | Việc | Làm bằng | Ai | Hạn / điều kiện |
|---|---|---|---|---|
| 3.1 | Chốt bản (tag) đưa lên chạy thật: đã qua staging, CI xanh, Tester ĐẠT các màn lõi | `docs/van-hanh/dua-len-chay-that.md` mục «Các bước trước ngày deploy» | Chat chọn, anh OK | không deploy khi đang có người dùng thật thao tác |
| 3.2 | Kiểm production bằng SQL chỉ đọc (số migration, số dòng các bảng chính, cờ, tham số) | `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql` | anh dán vào Supabase `hmt-prod`, gửi Chat ảnh kết quả | trước deploy |
| 3.3 | **Sao lưu** ngay trước deploy (không dùng bản đêm qua) và kiểm khoá giải mã `age` còn trong trình quản lý mật khẩu | workflow Backup production (`hmt-deploy`), file `HMT-backup/daily/hmt-prod-….tar.gz.age` trên Google Drive vận hành | anh | đỏ hoặc không thấy file: **dừng, không deploy** |
| 3.4 | Khôi phục thử bản sao lưu vào DB Docker tạm trên máy anh, xong xoá | `deploy/README.md` mục «Khôi phục thử» | anh | **cần anh quyết**: làm trước go-live hay sau |
| 3.5 | Kế hoạch quay lại khi deploy lỗi | `docs/van-hanh/quay-lai-khi-deploy-loi.md`: migration không có bản lùi (sửa tiến tới); giao diện quay lại được; DB chỉ quay lại bằng sao lưu và **chưa có cách bấm khôi phục lên chạy thật** | anh, Chat | **cần anh quyết**: chấp nhận rủi ro này hay cần làm cách khôi phục trước go-live |
| 3.6 | Chạy Deploy production (tag đã chọn) | `hmt-deploy` > Actions > Deploy production | anh | đủ bốn bước xanh; đỏ thì chụp màn hình, báo Chat, không sửa tay |
| 3.7 | Kiểm sau deploy | đăng nhập Admin, mở một danh sách, `select max(version) …` khớp migration cuối | anh, Tester | trong 15 phút đầu |
| 3.8 | Bootstrap Admin và tài khoản nhân sự CS5 | workflow Bootstrap admin (lần đầu), màn Người dùng; hai bước cho Kế toán, Admin | anh | xem 1.5 |
| 3.9 | Nạp dữ liệu thật (mục 2) rồi đối soát | màn Nhập dữ liệu (QT-18) | Code B hướng dẫn, anh làm | sau 3.7; có sao lưu ngay trước khi nạp |
| 3.10 | Ngày nghỉ lễ, cờ, tham số CS5 đúng | QT-14, QT-09, QT-10; khối kiểm `cau-hinh-cs5.md` | anh | trước ngày mở lớp |
| 3.11 | Người trực và đường báo lỗi tuần đầu | tên người trực theo ca, số điện thoại/kênh, thời gian phản hồi mong muốn | **cần anh quyết** | tuần đầu: kiểm danh sách việc chờ duyệt (CHUNG-15) và lỗi mỗi sáng |
| 3.12 | Sao lưu hằng đêm bật và kiểm | workflow Backup production 02:05 giờ Việt Nam; kiểm file mới mỗi sáng tuần đầu | anh | đỏ: báo Chat ngay |
| 3.13 | Theo dõi hạn mức gói Free (DB 500 MB, tải ra 5 GB/tháng) | bảng dung lượng Supabase, Cloudflare | anh, Chat | cảnh báo khi vượt 70% |
| 3.14 | Quyết định «đóng băng» thay đổi trong ngày go-live | không gộp PR có migration trong ngày go-live và 48 giờ sau (đề xuất) | **cần anh quyết** | tránh đổi DB khi dữ liệu thật mới nạp |

Tiêu chí xong triển khai: 3.1 đến 3.8 xanh, đối soát 3.9 khớp, người trực đã nhận việc, tuần đầu không có lỗi chặn chưa xử lý.

## Việc cần anh quyết (gom một chỗ)

1. Ngày giờ, người dẫn và hình thức các buổi tập huấn (1.4).
2. Danh sách nhân sự CS5 và vai (1.5).
3. Kênh báo lỗi và người trả lời (1.6, 3.11).
4. Danh sách ngày nghỉ lễ năm học 2026–2027 (2.3).
5. Khôi phục thử sao lưu trước hay sau go-live (3.4).
6. Chấp nhận chưa có cách bấm khôi phục DB chạy thật, hay làm trước (3.5).
7. Đóng băng migration quanh ngày go-live (3.14).

## Phụ thuộc và rủi ro

- Hướng dẫn chưa có ảnh: phụ thuộc staging ổn định và tài khoản giả (Tester chụp).
- Kế hoạch nạp của Code B (2.1) chưa có: 3.9 chờ tài liệu đó.
- Một số màn còn chờ luật (KH-08 lên khối, CHUNG-20 xoá nhập nhầm, «Chốt tháng» BC-09): không chặn go-live nhưng cần báo nhân sự là chưa có.
