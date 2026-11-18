# Hiệu năng phiếu tái tục: đo trên dữ liệu lớn (thẻ C20, 18/11/2026)

Bộ dữ liệu giả dựng trong một giao dịch rồi huỷ (không để lại gì): 1 cơ sở, 5.000 phụ huynh, 50.000 học sinh, 500 lớp, **50.000 phiếu tái tục** (8 giai đoạn, ngày hết giờ dự kiến trải 90 ngày). Người gọi: vai CSKH có RLS (chính sách đọc bật). Máy Mac đang chạy nhiều việc nên số dao động khoảng ±50%.

| Câu (hàm) | Trước tối ưu | Sau tối ưu (migration 419) |
|---|---|---|
| `list_upsale_tickets('{}')` trang 50 | 267 ms | 109 ms |
| `list_upsale_tickets({"stage_code":"L2"})` | 133 ms | 89 ms |
| `list_upsale_tickets({"q":"Em số 4321"})` (tìm tên học sinh) | 288 ms | 308 ms |
| `list_upsale_tickets({"campaign_month":"2026-12"})` offset 100 | 162 ms | 110 ms |
| `upsale_board('{}', 20)` (Kanban 8 cột một lần gọi) | **1.313 ms** | **337 ms** |

**Nguyên nhân chậm trước đó:** luật lọc nối học sinh và lớp cho từng dòng (mỗi dòng chịu thêm chính sách RLS của hai bảng); Kanban gọi hàm danh sách 16 lần. **Sửa:** luật lọc dùng chung `app.upsale_filtered`, chỉ tra tên học sinh, mã lớp khi có chữ tìm (`exists`); Kanban lọc một lần rồi xếp hạng theo cột bằng cửa sổ (`row_number`, `count over`).

**EXPLAIN (lọc L2, trang 50, trước tối ưu):** `upsale_ticket_class_idx` (bitmap) + `student_pkey` + sắp xếp top-N, 61 ms trong DB; không quét tuần tự bảng phiếu.

Không có câu nào trên 1 giây sau tối ưu. Chưa đo: `generate_upsale_tickets` (chạy đêm, không ở đường người dùng) và `upsale_candidates` trên 50.000 ghi danh; TC-16 và TT-E (báo cáo đối chiếu tháng, Code F) chưa nằm trong phạm vi lane C đã làm. Nếu cần đo, dùng cùng kịch bản dựng ở trên.

Cách đo lại (local, chỉ khi có khoá DB theo `LUOT-DB.txt`): dựng dữ liệu bằng `generate_series` trong một giao dịch, `set local role authenticated` với claims của một CSKH (đặt claims trước khi đổi vai trò), chạy các câu trên bằng `\timing`, rồi `rollback`.
