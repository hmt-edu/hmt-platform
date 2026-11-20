# Group By «Sao kê» của TC-04 (migration 579)

Anh Trường duyệt 20/11/2026 (Chat 20:38/20:44): canvas TC04 có nhóm Group By «Sao kê» (Đã khớp, Chưa khớp), làm theo canvas.

| Hàm | Thay đổi | Ai gọi | Luật |
|---|---|---|---|
| `app.receipt_group_counts(bộ lọc, trường nhóm[])` | Nhận thêm trường nhóm `bank` (khoá `KHOP` hoặc `CHUA`, theo cờ `bank_matched_at` của TC-15) và bộ lọc `bank_matched` cùng nghĩa với `list_receipts` (migration 576), nên số đếm khớp danh sách | người xem được phiếu thu theo phạm vi cơ sở | Đ35 (Group By tối đa hai cấp, hai cấp khác nhau) |
| `app.receipt_group_label(trường, khoá)` | Thêm nhãn «Đã khớp», «Chưa khớp» | hàm trong | — |

Giao diện: nhóm «Sao kê» chỉ có ở TC-04 (TC-01 không có theo canvas); mở một nhóm lọc `bank_matched`.
Chỉ đọc, không đổi bảng, không thêm chỉ mục. Bài pgTAP `579_c88_group_by_sao_ke.test.sql`: đếm hai nhóm, nhãn, bộ lọc khớp danh sách, hai cấp, chặn trường lạ và hai cấp trùng, giáo viên bị chặn.
