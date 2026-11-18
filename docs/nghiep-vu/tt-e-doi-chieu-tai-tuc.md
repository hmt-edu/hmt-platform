# TT-E: Đối chiếu tái tục theo tháng (TT-04, migration 553, Code F)

Màn chỉ xem số liệu (mức THẤP, không bảng mới). Xếp sau TT-A (410) và TT-B (415): dùng bảng `app.upsale_ticket` và `app.upsale_candidates()`.

| Hàm | Làm gì |
|---|---|
| `app.upsale_reconcile_base(tháng, cơ sở)` | Nội bộ, không mở cho người dùng: mỗi dòng một (học sinh, lớp) hết giờ trong tháng, đã áp phạm vi cơ sở theo quyền Phiếu tái tục · Xem. |
| `app.upsale_reconcile_summary(tháng, cơ sở)` | Thẻ tổng: hết giờ, đã có phiếu, còn thiếu, tạo tay, và số theo cơ sở. |
| `app.list_upsale_reconcile(tháng, bộ lọc, số dòng, bỏ qua)` | Bảng phân trang ở máy chủ; bộ lọc `branch_id`, `only_missing`, `q`. |

Luật áp dụng (R-GD-13): «hết giờ trong tháng» tính theo ngày hết giờ dự kiến (phiếu đang mở lấy ngày đã chụp; chưa có phiếu lấy ngày tính từ `upsale_candidates`, cùng cách GD-07). Em đã hết giờ (giờ còn từ 0 trở xuống) tính là hết giờ hôm nay theo giờ Việt Nam. «Đã có phiếu» là phiếu đang mở (L1 đến L4, L6, L7). Lý do chưa có phiếu: `CO_PHIEU_L5` (L5 không tự sinh lại), `LOP_CHUA_CO_LICH` (không tính được ngày), `CHO_QUET_DEM`. Campaign là nhãn tháng tính ra. Nút Tạo phiếu ở dòng thiếu dùng `create_upsale_ticket` của TT-03.
Giao diện: `/crm/doi-chieu-tai-tuc`, mục «Đối chiếu tái tục» dưới Tái tục.
