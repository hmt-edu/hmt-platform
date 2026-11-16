# Báo cáo tổng quan Ban giám đốc (migration 211)

Code D, 16/11/2026. Luật: R-BC-01, R-BC-02, R-BC-04, R-BC-05. Màn BC-01 (K09). Chưa có giao diện (PR sau). Không bảng mới, chỉ đọc.

## Hàm

| Hàm                                 | Ai                                                             | Kết quả                                                                                                                                           |
| ----------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `report_overview(từ, đến, cơ sở)`   | Báo cáo · Xem (Toàn hệ thống chọn cơ sở; phạm vi Cơ sở bị khoá cơ sở mình) | jsonb: `students_active`, `students_on_hold`, `revenue_recognized`, `revenue_hours`, `hours_without_price`, `cash_received`, `hours_fund_value`, `hours_fund_hours`, `as_of` |
| `enrollment_recognized_prices()`    | Nội bộ (không cấp cho giao diện)                               | Đơn giá ghi nhận (đ/giờ) của từng ghi danh có dòng đơn                                                                                            |

## Cách tính và chỗ đã tự chọn (chờ Chat xác nhận)

- **Học sinh đang học / bảo lưu (R-BC-02):** đếm theo tình trạng ghi danh **hiện tại**, chưa có lịch sử tình trạng theo ngày nên không đúng «tại ngày cuối khoảng» khi xem quá khứ (`as_of` ghi ngày đọc). Em bảo lưu mà còn ghi danh Đang học thì chỉ tính đang học.
- **Doanh thu ghi nhận (R-BC-04):** giờ trừ của buổi chính, buổi củng cố theo ngày học trong khoảng, × đơn giá ghi nhận, tính cho cơ sở của buổi. **Đơn giá = tiền đã thu của dòng đơn ÷ (giờ mua + giờ tặng)** (R-BC-05 nói «bằng đúng tiền đã thu»; R-BC-04 nói «tiền dòng đơn»: chọn tiền đã thu). Học bù, bổ trợ không trừ giờ nên 0 đ.
- **Ghi danh không có dòng đơn (nạp từ hệ thống cũ):** không có giá, doanh thu 0 đ, giờ trừ đếm ở `hours_without_price` để không bịa số.
- **Quỹ giờ còn quy ra tiền (R-BC-05):** giờ còn dương của ghi danh Đã xếp lớp, Đang học, Bảo lưu × đơn giá ghi nhận.
- **Tiền đã thu:** tổng khoản tiền vào (kể cả khoản âm do đảo) theo ngày Việt Nam.

Chưa làm: tỉ lệ tái tục (R-BC-03, chưa có bảng phiếu tái tục), BC-02..07 (Looker, cần view chỉ đọc), giao diện.
