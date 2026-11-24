# Đo hiệu năng danh sách trên dữ liệu giả lớn (A-23-40, 24/11/2026)

Mục đích: bổ sung bằng chứng EXPLAIN cho các PR có bảng mới (CLAUDE.md, mục Hiệu năng). **Chỉ đề xuất, không có migration trong PR này.**

## Cách đo
- Chỉ ở máy local (Docker Mac, Supabase local), dữ liệu giả. `db:reset` → `db:seed-users` → `db:seed-lon` (50.000 lead, 30.000 phụ huynh, 20.000 cơ hội, 10.000 học sinh, 15.000 phiếu kiểm tra).
- `seed-lon` không có ticket: nhân bản một ticket thật (tạo bằng `app.create_ticket`) thành 20.001 ticket giả bằng SQL, nửa mỗi cơ sở (CS1 thấy 10.001). Bước này làm tay, chưa nằm trong file seed nào. Đề xuất thêm vào `seed-lon.sql` để lần sau đo lại được.
- Gọi đúng hàm giao diện dùng (`app.list_leads`, `app.list_opportunities`, `app.list_tickets`, `app.list_demo_data_sets`) dưới vai `authenticated` với claim thật của tài khoản giả (Sale CS1, CSKH CS1), nên RLS và `has_permission` chạy như thật. Mỗi câu chạy 3 lần, lấy 2 lần đầu (lần ba sau khi cache). Plan nội bộ lấy bằng `auto_explain` (analyze, buffers, nested). Số đo chỉ là tương đối giữa các câu, máy khác sẽ khác.

## Kết quả (một trang 50 dòng)
| Màn / hàm | Lọc | Thời gian (ms) | Nhận xét |
|---|---|---|---|
| Lead (`list_leads`) | không lọc, Sale CS1 | 22–24 | Trang dữ liệu đi theo `lead_branch_idx`; đếm tổng (`count(*)`) quét tuần tự 50.000 dòng (loại 25.000 dòng cơ sở khác). |
| Lead | tìm «nguyen» | 13–16 | Dùng `lead_search_idx` (bitmap, 11.426 dòng khớp), trang lấy qua `lead_branch_idx`. |
| Cơ hội (`list_opportunities`) | không lọc | 12–14 | `opportunity_branch_created_idx`; đếm quét tuần tự 20.000 dòng. |
| Cơ hội | tìm «nguyen» | 12–13 | `opportunity_search_idx`. |
| **Ticket (`list_tickets`)** | không lọc, CSKH CS1 | **186–217** | Chậm nhất; xem dưới. |
| **Ticket** | tìm «giả số 12» | **176–182** | Cùng nguyên nhân. |
| Bộ dữ liệu mẫu (`list_demo_data_sets`) | — | ~1–3 | Bảng nhỏ (hạn mức theo người và cơ sở), chưa có bộ nào lúc đo; chưa đo với nhiều bộ. |
| `has_permission` / `permission_scope` | — | ~1 lần đầu trong phiên, ~0,1 sau đó | Dùng chỉ mục `permission_role_code_module_code_action_code_key`; không đáng kể khi viết dạng `(select …)` (initplan). |

Chỉ mục is_demo (mig 648 trở đi): các chỉ mục từng phần `… where is_demo` (ví dụ `ticket_demo_idx`) không xuất hiện trong plan của các màn danh sách ở trên (đúng thiết kế: danh sách không lọc `is_demo`); chúng chỉ dùng khi xoá bộ mẫu. Chưa đo bước xoá bộ mẫu.

## Chỗ chậm: danh sách Ticket (>200 ms ở một lần đo)
- Phần lọc/đếm (`ticket_filter_rows`) chỉ ~23 ms cho 10.001 dòng; RLS bảng `ticket` ~10 ms. Phần còn lại, khoảng 150–170 ms, là **`app.ticket_row` chạy cho 50 dòng của trang (~3 ms mỗi dòng)**.
- Mỗi dòng gọi 3 truy vấn con vào `app.ticket_category` (tên nhóm con, tên nhóm cha, tên nhóm), mỗi truy vấn đều chạy lại chính sách RLS của bảng này (initplan quyền ~1–2 ms mỗi lần) và quét tuần tự 94 dòng. Admin (RLS rút gọn) chỉ ~9–13 ms cho cùng câu → thủ phạm là RLS lặp theo dòng, không phải dữ liệu lớn.
- Đề xuất (cần số migration + Tester, không làm trong PR này): (1) trong `ticket_row`, lấy ba tên nhóm bằng **một** truy vấn (join `ticket_category` với chính nó một lần) thay vì ba; (2) hoặc gom tên nhóm ra ngoài vòng 50 dòng (join một lần trong `list_tickets`); (3) cân nhắc cho `ticket_category` đọc qua hàm `security definer` chỉ trả tên (danh mục không nhạy cảm), để khỏi chạy RLS theo dòng. Đo lại sau khi sửa; mục tiêu < 50 ms.
- Chỉ mục `(branch_id, created_at desc, id)` thử trong giao dịch rồi huỷ: **không giảm thời gian** (186 → 171–195 ms), nên chưa cần thêm.

## Lead và cơ hội
- Dưới 25 ms ở 50.000 lead / 20.000 cơ hội: đạt mục tiêu (< 200 ms). `count(*)` quét tuần tự là khoản lớn nhất (~10 ms); chấp nhận được ở quy mô này. Nếu số lead nhân lên nhiều lần, cân nhắc đếm xấp xỉ hoặc bỏ tổng khi không lọc.

## Còn thiếu / chưa đo
- Bước xoá bộ dữ liệu mẫu và `list_demo_data_sets` với nhiều bộ.
- Các bảng mới khác của mig 648–660 ngoài ticket (đơn hàng, phiếu thu, ghi danh mẫu): chưa đo riêng.
- Số đo trên Docker Mac chỉ để so tương đối; chạy thật dùng Supabase Free nên cần đo lại trên bản thử nghiệm khi có dữ liệu giả lớn ở đó (chưa làm, cần anh Trường đồng ý vì chạm môi trường chung).
