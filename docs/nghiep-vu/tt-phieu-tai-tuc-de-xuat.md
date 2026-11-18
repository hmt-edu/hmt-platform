# TT-01..04 Phiếu tái tục: đề xuất làm (Code C, 18/11/2026, chờ Chat/anh OK)

Căn cứ: Chat 10:10 18/11 (GIỮ TT-01..04 theo canvas 9933 và abea); luật R-GD-13 (spec 04, dòng 127) làm lại sau khi R-V2-25 chốt lại (PR #83); ban-do-man-hinh TT-01..TT-03; canvas `TT01*`, `TT02*`, `TT03_tao`, `TT04*`. Mã `TT` + 6 số (spec 02). Quyền: module `UPSALE` đã có trong ma trận (không có Duyệt; Trưởng cơ sở chỉ Xem, Giao việc). Tham số đã có: `upsale_hours_left_threshold` (10), `upsale_days_left_threshold` (30), `absence_risk_sessions` (3), `absence_risk_window_days` (30).

Hiện chưa có bảng nào cho phiếu tái tục (chỉ có quyền, tham số, danh mục giai đoạn 8 + 5 nhóm con). Đây là phân hệ mới, nên xin chia 5 PR, mỗi PR một việc:

| PR | Nội dung | Migration | Mức |
|---|---|---|---|
| TT-A | Bảng `upsale_ticket` (một phiếu mở tối đa cho mỗi học sinh + lớp, chỉ mục riêng), `upsale_ticket_event` (lịch sử), cấp mã `TT`, RLS, hàm tạo tay (TT-03), đổi giai đoạn (L1..L7, L5 bắt buộc lý do), giao việc, sửa hai ô tự do; pgTAP | 410 | CAO (quyền) |
| TT-B | Tự sinh: hàm `generate_upsale_tickets` tính theo (học sinh, lớp), giờ còn = tổng ghi danh còn hiệu lực, ngày hết dự kiến từ lịch buổi, cờ vắng; pg_cron mỗi đêm; móc bảo lưu (dừng sinh), dừng học (đóng), chuyển lớp (chuyển theo); L5 không sinh lại | 411 | CAO |
| TT-C | Giao diện TT-01 (danh sách K03 + kanban L1..L8) và TT-03 (hộp tạo tay), điều hướng «Tái tục» | không | TB |
| TT-D | TT-02 bản ghi (giờ còn, ngày hết dự kiến, vắng, email phụ huynh chỉ đọc, hai ô tự do, tab Tình hình học tập mờ) và nút Tạo báo giá, Tạo đơn: L7A, L7B, vào BH-02/BH-05 theo canvas abea; đơn đóng đủ thì L8A | 412 | CAO (tiền) |
| TT-E | TT-04 «Đối chiếu tái tục theo tháng» (view báo cáo: học sinh + lớp hết giờ trong tháng, đã có phiếu, còn thiếu, theo cơ sở; nút «Tạo phiếu tái tục sớm») | 413 | THẤP |

## Câu hỏi cần chốt trước khi làm TT-A
1. **Ngày hết giờ dự kiến**: có hàm nào trong main tính từ lịch buổi sắp tới của lớp (đã trừ nghỉ lễ, dời buổi) chưa? Nếu chưa, TT-B tự viết, hay dùng hàm dự báo của GD-07 (Code A) khi xong?
2. **TT-04**: canvas hiện số «87 học sinh + lớp hết giờ trong tháng, 79 đã có phiếu, 8 thiếu». Nguồn «hết giờ trong tháng» lấy theo ngày hết giờ dự kiến hay theo giờ còn = 0? Đề xuất: theo ngày hết giờ dự kiến (cùng với TT-01 cột «Hết giờ dự kiến»).
3. **Campaign «Tái tục 10/2026»** ở TT-01, TT-04: là nhãn theo tháng hết giờ (sinh tự động theo tháng) hay là chiến dịch tuyển sinh có sẵn? Đề xuất: nhãn tháng tính ra, không tạo bản ghi chiến dịch.
4. **Đẩy khoảng PR**: TT-B phụ thuộc hàm ngày hết giờ (câu 1); nếu chưa có thì làm TT-A, TT-C trước.

## Không làm trong đợt này
Tab Tình hình học tập (hiện mờ, chưa dùng); phiếu chuyển phí (xem BH, theo R-V2-25 vẫn qua ticket Đề nghị).
