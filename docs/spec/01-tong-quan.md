# HMT Platform: tổng quan

Bản gốc: tài liệu "HMT Platform - Tài liệu gốc" của anh Trường trên Claude. File này là bản chép cho Claude Code đọc; khi hai bên lệch nhau thì bản gốc đúng, hỏi lại anh Trường.

## Mục tiêu
HMT (Hòa Ma Toán) là trung tâm dạy thêm có 4 cơ sở ở Hà Nội: CS1 Nguyễn Chí Thanh, CS2 Đỗ Quang, CS4 Hà Đông, CS5 Mỹ Đình. Quy mô khoảng 1.300 học sinh, 166 lớp, 30 nhân viên, 50-60 giáo viên.

Dự án làm lại từ đầu bộ CRM, LMS và app giáo viên. Bản cũ chạy trên Apps Script và Google Sheet, chỉ dùng làm tham chiếu nghiệp vụ, không mang code sang.

**Một ứng dụng, một cơ sở dữ liệu, ba cổng:**

| Cổng | Người dùng | Việc chính |
|---|---|---|
| CRM | Sale, CSKH, Vận hành, Kế toán, Quản lý cơ sở, Ban giám đốc | Lead, cơ hội, kiểm tra đầu vào, báo giá, đơn hàng, phiếu thu, ghi danh, quỹ giờ, lớp, buổi học, điểm danh |
| Giáo viên | Giáo viên, trợ giảng | Lịch dạy, điểm danh, nhận xét buổi theo mẫu, chấm BTVN, căn cứ tính lương |
| Học tập (LMS) | Học sinh (chính), phụ huynh (xem) | Nhận bài tập, nộp bài trên điện thoại hoặc laptop, xem điểm, nhận xét |

## Công nghệ (chốt 09/10/2026: ưu tiên miễn phí, kể cả khi chạy thật)
- React thuần (Vite, TypeScript) + Tailwind, ứng dụng tĩnh đặt trên Cloudflare Pages (miễn phí, cho dùng thương mại). Không có máy chủ riêng.
- Supabase gói Free: Postgres, Auth, Edge Functions, pg_cron, vùng Singapore. Hai project: `hmt-staging`, `hmt-prod`.
- File bài tập (giai đoạn 4): Cloudflare R2 miễn phí 10 GB. Email: Brevo hoặc Resend gói miễn phí.
- Sao lưu tự làm mỗi đêm (gói Free không có): GitHub Actions xuất DB, mã hoá, đẩy lên Google Drive của `[email vận hành]`; khôi phục thử mỗi tháng.
- Báo cáo sử dụng hằng tuần (dung lượng DB, tải ra, tốc độ). Nâng Supabase Pro ($25/tháng) khi DB vượt 400 MB, tải ra vượt 4 GB/tháng, hoặc chậm giờ cao điểm.
- Phân quyền chặn bằng Row Level Security ngay trong cơ sở dữ liệu.
- Nghiệp vụ tiền, giờ, cấp mã, chuyển trạng thái chạy trong hàm Postgres, mỗi thao tác là một giao dịch trọn vẹn.
- Google Sheet chỉ là bản sao chỉ đọc để đối soát, đồng bộ theo lịch. Looker Studio làm báo cáo, nối vào các bảng/view chỉ đọc.
- Git và GitHub; kiểm thử tự động chạy mỗi lần đẩy code.

## Lộ trình
0 Nền móng → 1 Bán hàng & tiền → 2 Vận hành lớp → 3 Cổng giáo viên → **chạy thật** (chuyển dữ liệu từng cơ sở, CS5 trước, chạy song song 2-4 tuần) → 4 LMS → 5 Báo cáo nâng cao. Giao diện thiết kế ngay trong từng giai đoạn.

## Quy trình làm việc
1. Đặc tả (Claude Chat cùng anh Trường): luật nghiệp vụ, dữ liệu, cách kiểm thử.
2. Thiết kế (Claude Design): hệ thống thiết kế và wireframe.
3. Code kèm kiểm thử (Claude Code). Mỗi lỗi từng gặp ở hệ thống Apps Script trở thành một bài kiểm thử.
4. Anh Trường thử trên môi trường thử nghiệm.
5. Đưa lên bản chạy thật sau khi anh duyệt.

## Lỗi của hệ thống cũ phải có kiểm thử chặn
- Mã buổi, mã điểm danh trùng.
- Trừ giờ hai lần khi một em có hai ghi danh.
- Học bù bị trừ giờ; ghi danh sinh sau ngày buổi vẫn lọt vào danh sách.
- Kết thúc một ghi danh thu hồi luôn giờ của ghi danh khác.
- Đổi cấu hình (giá, tham số) làm thay đổi ngược bản ghi cũ.
