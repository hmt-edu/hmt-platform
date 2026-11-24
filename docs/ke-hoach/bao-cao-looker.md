# Báo cáo trên Looker Studio: bản nháp (BC-02..BC-07, BC-10)

Trạng thái: **NHÁP để anh Trường duyệt**. PR chỉ có tài liệu: không tạo vai trò, không migration, không đụng chạy thật.
Căn cứ: anh chốt 23/11/2026 (7 báo cáo vẽ trên Looker Studio, không dựng màn trong hệ thống); R-BC-01 (`docs/spec/04`); `docs/design/ban-do-man-hinh.md` dòng BC-02..BC-10; migration 214, 230, 233 (các view `report.*` đã có).

## 1. Looker đọc dữ liệu thế nào cho an toàn (gói miễn phí)

### Hiện trạng cần biết
- Đã có schema `report` với 7 view: `lead_funnel` (BC-02), `revenue_by_session` (BC-03), `hours_fund` (BC-04), `class_attendance` (BC-06), `homework_summary` (BC-07), `ticket_summary` (BC-10), `enrollment_unit_price` (phụ trợ). Tất cả khai báo `security_invoker = true` và cấp `select` cho vai trò `authenticated`.
- Hệ quả quan trọng: view chạy theo quyền người gọi, nên **một vai trò Postgres riêng nối thẳng từ Looker không có `auth.uid()`, RLS trả về rỗng**. Phương án đọc trực tiếp vì vậy KHÔNG dùng được nguyên các view hiện có; phải thêm lớp view riêng cho Looker (xem 1.2).
- Các view hiện có chỉ chứa mã (`student_id`, `owner_id`, `teacher_id`), không có tên hay số điện thoại. Giữ nguyên nguyên tắc này: lớp view cho Looker không bao giờ có cột tên, số điện thoại, email.

### Ba cách đọc
| | A. Looker nối thẳng Postgres (pooler) | B. Đẩy tổng hợp sang Google Sheet theo lịch | C. Nối bằng tài khoản đăng nhập của người xem |
|---|---|---|---|
| Cách làm | Vai trò chỉ đọc `looker_ro`, kết nối qua Supavisor (pooler, có IPv4), chỉ `select` trên schema `looker` | GitHub Actions hoặc Edge Function chạy mỗi đêm/giờ, ghi bảng tổng hợp vào Sheet, Looker đọc Sheet | Looker gọi API Supabase bằng phiên người dùng |
| Chi phí | 0 đồng | 0 đồng | Không có sẵn trong Looker Studio, cần connector tự viết: loại |
| Dữ liệu mới | Gần thời gian thực (bộ nhớ đệm Looker 15 phút đến 12 giờ) | Chậm theo lịch (vài giờ) | — |
| Rủi ro | Cổng DB mở ra internet với một mật khẩu; lộ mật khẩu thì lộ mọi view được cấp | Không mở cổng DB; lộ link Sheet thì lộ dữ liệu tổng hợp; Sheet giới hạn khoảng 10 triệu ô | — |
| Băng thông (5 GB/tháng) | View tổng hợp nhỏ, đệm Looker giảm tải; cần theo dõi khi nhiều người mở | Chỉ một lần đẩy mỗi lịch, rất nhỏ | — |
| Phân quyền theo cơ sở | Phải làm trong lớp view hoặc bằng bộ lọc Looker (yếu) | Mỗi cơ sở một Sheet hoặc tab, chia sẻ riêng (chắc hơn) | — |

### Đề xuất: A trước, B là phương án dự phòng
1. Thêm schema `looker` chứa view **tổng hợp** (không dòng chi tiết, không cột định danh người), khai báo `security_invoker = false` và chủ view là vai trò giới hạn; chỉ view này được cấp cho `looker_ro` (`grant usage`, `grant select` đúng từng view; mặc định thu hồi mọi quyền khác, không cấp cho `public`).
2. `looker_ro`: `login`, `nobypassrls`, không `createdb`/`createrole`, đặt `statement_timeout` ngắn (ví dụ 15 giây), `connection limit` thấp (2 đến 3), chỉ kết nối bằng SSL qua pooler (cổng giao dịch). Mật khẩu dài, quay vòng định kỳ, lưu trong Secrets của `hmt-deploy` (chạy thật) và Secrets của `hmt-platform` (thử nghiệm), không nằm trong repo.
3. Mọi view có cột `branch_id`; mỗi nguồn dữ liệu Looker lọc cứng theo cơ sở của người xem bằng **tham số nguồn** hoặc báo cáo riêng cho từng cơ sở (xem rủi ro 3.2).
4. Ẩn dữ liệu mẫu: mọi view `looker.*` thêm `where not is_demo` ở bảng gốc có cờ (lead, cơ hội, đơn, học sinh, lớp, buổi, ticket, ghi danh, sổ giờ). Ở staging có thể bật xem cả dữ liệu mẫu bằng một view riêng, không bao giờ ở chạy thật.
5. Khi chạy thật: chỉ `hmt-deploy` tạo vai trò và cấp quyền (migration qua quy trình duyệt trên GitHub). Claude Code không giữ mật khẩu này.

Nếu anh thấy mở cổng DB là quá rủi ro thì dùng B: giữ nguyên lớp view `looker.*`, nhưng người đọc là một job hẹn giờ (không phải Looker), kết quả đẩy vào Sheet; Looker chỉ đọc Sheet.

## 2. Từng báo cáo

Chung cho cả bảy báo cáo: lọc thời gian và cơ sở; xuất bằng chức năng của Looker; quyền xem theo bảng vai trò ở bản đồ màn hình (AD, BM, KT, CS, SA); số trong khung chỉ minh hoạ.

| BC | Câu hỏi nghiệp vụ | View cần có | Cột chính | Nguồn bảng | Lọc cơ sở, ẩn mẫu | Hàm/view đã có |
|---|---|---|---|---|---|---|
| BC-02 Tuyển sinh | Lead nào về từ nguồn, chiến dịch, sale nào; bao nhiêu thành cơ hội, bao nhiêu chốt (L8); tỉ lệ test, chốt | `looker.lead_funnel` | tháng, cơ sở, loại nguồn, nguồn, chiến dịch, người phụ trách, số lead, cơ hội, chốt L8 | `lead`, `opportunity` | `branch_id`; thêm `not is_demo` ở cả hai bảng | `report.lead_funnel` (214). Thiếu: tỉ lệ làm test (cần đếm phiếu kiểm tra đầu vào) |
| BC-03 Doanh thu ghi nhận | Doanh thu theo buổi Done, theo cơ sở nơi buổi diễn ra, môn, Đại/Hình (R-BC-04, R-GD-10) | `looker.revenue_by_session` | ngày buổi, cơ sở, môn, loại buổi, giờ trừ, đơn giá, doanh thu | `hour_ledger`, `class_session`, `class`, `enrollment` | `branch_id` của buổi; `not is_demo` ở buổi | `report.revenue_by_session` (214). Thiếu: tách Đại/Hình (cần xác định cột nào của lớp mang dấu này); buổi huỷ có tính phí chưa kiểm là đã có dòng |
| BC-04 Thu tiền và quỹ giờ | Tiền đã thu, giờ đã cấp, giờ còn, giờ còn quy ra tiền (R-BC-05, R-GD-04) | `looker.hours_fund` | ghi danh, cơ sở, trạng thái, giờ đã cấp, giờ còn, đơn giá, giá trị còn, tiền đã thu | `enrollment`, `hour_ledger`, `money_in_allocation` | `branch_id`; `not is_demo` ở ghi danh | `report.hours_fund` (214). Lưu ý: mã ghi danh là mã nội bộ, không có tên em |
| BC-05 Tái tục | Tỉ lệ tái tục = L8 ÷ (L8 + L5) của phiếu kết thúc trong khoảng (R-BC-03); phiếu theo giai đoạn; rủi ro | `looker.renewal_funnel` (chưa có) | tháng kết thúc, cơ sở, giai đoạn, số phiếu, số L8, số L5, nhóm rủi ro | bảng phiếu tái tục (chưa có trong DB) | `branch_id`; ẩn mẫu | **Chưa có nguồn.** R-GD-13 đã chốt làm lại ngày 18/11 (R-V2-25) nhưng chưa có bảng phiếu tái tục; báo cáo này phải chờ phần đó |
| BC-06 Sĩ số, chuyên cần | Sĩ số so với tối đa, tỉ lệ có mặt, vắng theo lớp và em (R-DD-01, R-DD-02) | `looker.class_attendance` | lớp, cơ sở, sĩ số tối đa, sĩ số hiện tại, lượt điểm danh, có mặt, vắng | `class`, `enrollment_class`, `class_session`, `session_attendance` | `branch_id`; `not is_demo` ở lớp, buổi | `report.class_attendance` (214) theo lớp. Thiếu: mức em (cần view theo mã em, không tên) |
| BC-07 BTVN | Hai chỉ số tách riêng: tỉ lệ làm bài và điểm trung bình theo lớp, em, giáo viên (R-GV-12) | `looker.homework_summary` | tháng, cơ sở, lớp, giáo viên, em, số bài phải làm, số đã làm, tỉ lệ, điểm trung bình | `homework_result`, `class_session` | `branch_id`; `not is_demo` ở buổi | `report.homework_summary` (233), đã đúng công thức R-GV-12 |
| BC-10 Ticket | Số ticket theo loại, nhóm, cơ sở; tỉ lệ đúng hạn; giờ xử lý; khiếu nại theo người; lý do chuyển, bảo lưu, hoàn (R-CS-12) | `looker.ticket_summary` | ticket, loại, nhóm, cơ sở, ưu tiên, trạng thái, tháng, người xử lý, người bị khiếu nại, cờ đúng hạn, giờ xử lý | `ticket`, `ticket_category` | `branch_id`; `not is_demo` ở ticket | `report.ticket_summary` (230). Thiếu: lý do chuyển/bảo lưu/hoàn (nằm trong nội dung ticket, cần cột có mã) |

Ghi chú chung về cột định danh: `student_id`, `teacher_id`, `owner_id`, `assignee_id`, `accused_user_id` là mã nội bộ. Để Looker hiện được «giáo viên A» mà không lộ tên học sinh, view chỉ thêm tên **nhân viên** (giáo viên, sale, CSKH) khi báo cáo cần; **không bao giờ** thêm tên hay số điện thoại học sinh, phụ huynh.

## 3. Rủi ro và việc cần anh quyết

1. **Chọn A hay B** (mục 1). Em đề xuất A; nếu anh ưu tiên không mở cổng DB thì chọn B.
2. **Phân quyền theo cơ sở trong Looker** khá yếu: bộ lọc Looker người xem có thể đổi. Cách chắc: mỗi cơ sở một báo cáo riêng, mỗi báo cáo có bộ lọc cứng, chia sẻ theo nhóm người xem. Số báo cáo nhân lên theo số cơ sở. Cần anh quyết dùng báo cáo riêng từng cơ sở hay một báo cáo chung cho Ban giám đốc.
3. **Lộ thông tin nhân viên**: tên giáo viên, sale, CSKH có trong báo cáo; chỉ nhóm AD, BM, KT, CS, SA được xem (ma trận ở bản đồ màn hình). Cần anh xác nhận.
4. **Băng thông gói Free (5 GB/tháng)**: view tổng hợp nhỏ; vẫn nên đặt bộ nhớ đệm Looker tối thiểu 1 giờ và không để báo cáo tự làm mới dưới 15 phút.
5. **Chưa có nguồn cho BC-05** (phiếu tái tục) và còn thiếu vài cột (tỉ lệ làm test ở BC-02, Đại/Hình ở BC-03, mức em ở BC-06, lý do ở BC-10). Mỗi mục cần một PR nhỏ có migration, làm sau khi anh duyệt tài liệu này.
6. **Thử trên thử nghiệm trước**: vai trò và view tạo ở `hmt-staging` với dữ liệu mẫu; chạy thật chỉ qua `hmt-deploy`.
7. **Việc chưa chốt từ trước** (`quyet-dinh-thiet-ke-13-10.md`): công thức luỹ kế, ASP bán mới, dashboard theo vai trò làm trong app hay Looker. Chưa ảnh hưởng bản nháp này nhưng cần chốt trước khi vẽ báo cáo tuyển sinh.

## 4. Trình tự đề xuất sau khi anh duyệt
1. PR migration: schema `looker`, view tổng hợp cho BC-02, 03, 04, 06, 07, 10 (có `not is_demo`, mô tả cột, pgTAP: không thấy cột định danh, vai trò `looker_ro` đọc đúng và không đọc được bảng gốc).
2. Staging: tạo `looker_ro`, nối Looker thử bằng dữ liệu mẫu.
3. Bổ sung cột còn thiếu và nguồn BC-05.
4. Chạy thật: anh tạo vai trò và mật khẩu qua `hmt-deploy`; Claude Code không giữ.
