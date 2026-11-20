# Chip nhiều «Cơ sở» ở TC-01, TC-04 (migration 580)

Anh Trường duyệt 20/11/2026 (Chat 20:38/20:44): canvas TC01, TC04 có chip chọn nhiều cơ sở (CS1, CS2, CS4, CS5), làm theo canvas.

| Hàm | Thay đổi | Ai gọi | Luật |
|---|---|---|---|
| `app.list_receipts(...)` | Nhận thêm bộ lọc `branch_ids` (mảng mã cơ sở); giữ `branch_id` cũ | người xem được phiếu thu theo phạm vi cơ sở | phạm vi cơ sở R-HT |
| `app.receipt_group_counts(...)` | Cùng bộ lọc `branch_ids`, để số đếm Group By khớp danh sách | như trên | Đ35, phạm vi cơ sở |

Phạm vi cơ sở của người gọi vẫn cắt bên trong hàm: mảng chỉ **thu hẹp thêm**, không nới. Trưởng cơ sở chỉ thấy cơ sở của mình thì đưa mảng cơ sở khác vẫn không thấy phiếu đó. Các cơ sở trong mảng là HOẶC với nhau, VÀ với các bộ lọc khác.
Giao diện: nhóm chip «Cơ sở» chỉ hiện khi người dùng xem được nhiều cơ sở. Chỉ đọc, không đổi bảng. Bài pgTAP `580_c89_chip_nhieu_co_so.test.sql`: một cơ sở, hai cơ sở, mảng rỗng, số đếm khớp danh sách, tương thích `branch_id`, Trưởng cơ sở không bị nới phạm vi, giáo viên bị chặn.
