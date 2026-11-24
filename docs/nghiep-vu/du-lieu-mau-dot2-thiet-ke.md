# Dữ liệu mẫu đợt 2: học sinh, lớp, ticket (bản thiết kế ngắn, C-23-39)

Trạng thái: **ĐÃ LÀM ở migration 657 (#674, đã gộp)**; bản làm xong mô tả ở `docs/nghiep-vu/du-lieu-mau.md`, tài liệu này giữ làm lý lịch thiết kế. Khác thiết kế: lớp Toán được duyệt thật, 3 em ghi danh ở sổ giờ mẫu, ticket bỏ qua khi Aftersale tắt (ghi chú `notice`). Soạn 24/11/2026 theo thẻ C-23-39 (anh OK concept 01:11). Nguồn đọc: `docs/nghiep-vu/du-lieu-mau.md` và migration 648 trên nhánh #647; hàm hiện có `app.create_class` (589), `app.create_ticket` (cs ticket), `app.issue_person_code`, `app.issue_class_code`.

## 1. Việc cần làm
Mở rộng `app.create_demo_data_set()` (đợt 1 chỉ tạo bản ghi bộ) để đổ **một chuỗi dữ liệu cố định**: **6 học sinh**, **2 lớp**, **3 ticket**, gắn vào bộ để xoá hoặc ẩn cả bộ. Mọi bản ghi mang cờ `is_demo = true` và có dòng trong `app.demo_data_item`.

## 2. Khoá an toàn (giữ nguyên đợt 1)
- Đầu hàm gọi `app.assert_demo_data_allowed()` (công tắc `demo_data_enabled` bật **và** `app.deployment_env` = `STAGING`). Thiếu một trong hai: `HMT_DEMO_TAT`. Thẻ ghi «kiểm `app.demo_data_enabled`»: trong code hiện tại là tham số `demo_data_enabled` đọc qua hàm kiểm trên, **không có hàm tên đó**; thiết kế dùng hàm kiểm.
- Hàm nhận **không tham số nội dung** (cơ sở lấy từ token), nội dung là hằng cố định: không có đường đưa dữ liệu tuỳ ý vào. Hạn mức bộ mỗi người, mỗi cơ sở như đợt 1.
- Không tự duyệt: lớp dừng ở Đã trình (quyết định 3); ticket ở Mới hoặc Đang xử lý; chỉ một phiếu «Cập nhật hồ sơ» chờ duyệt (quyết định 4); không ghi danh, không sổ giờ, không phiếu thu.

## 3. Cách tạo (hàm con, mỗi hàm một việc, đều `security definer`, chỉ gọi được từ hàm tạo bộ)
| Hàm con | Việc | Cách tạo |
|---|---|---|
| `app.demo_make_parents(set_id, branch_id)` | 4 phụ huynh [MẪU] (6 học sinh, có hai cặp anh em) | `app.issue_person_code('PH')`, chèn `app.parent` |
| `app.demo_make_students(set_id, branch_id, parent_ids)` | 6 học sinh [MẪU] khối, năm sinh khác nhau | `app.issue_person_code('HS')`, chèn `app.student` |
| `app.demo_make_classes(set_id, branch_id)` | 2 lớp [MẪU] (một Toán, một Tiếng Anh; thêm online/OMO nếu danh mục có; quyết định 2) | gọi `app.create_class(jsonb)` để lớp qua đủ luật mã, thời khoá biểu, kiểm môn theo khối |
| `app.demo_make_tickets(set_id, branch_id, parent_ids, student_ids, class_ids)` | 3 ticket (1 Đề nghị, 1 Khiếu nại, 1 Đề nghị gắn lớp) và 1 phiếu «Cập nhật hồ sơ» chờ duyệt | gọi `app.create_ticket(jsonb)` |
| `app.demo_tag(set_id, entity_type, entity_id)` | đặt `is_demo = true` và ghi `demo_data_item` | một chỗ duy nhất, mọi hàm trên gọi |

Dùng đường nghiệp vụ có sẵn (create_class, create_ticket) để mã, nhật ký và luật giống bản thật; người gọi **không** cần quyền tạo lớp/ticket (quyết định 5, xem mục 8). Học sinh và phụ huynh chèn trực tiếp vì chưa có hàm công khai tạo riêng.

## 4. Dữ liệu cố định
- **Nhãn:** họ tên bắt đầu bằng «[MẪU] » (ví dụ «[MẪU] Nguyễn Văn An») để nhận ra ngay ở mọi danh sách; lớp đặt tên mô tả «[MẪU] …» ở ghi chú nếu bảng lớp không có cột tên.
- **Liên hệ giả, không gửi thật:** số điện thoại dải **0999 000 001–999**, email `@example.invalid`. Sinh theo số thứ tự bộ (không trùng giữa các bộ): `0999000` + số 3 chữ số tăng dần từ bộ đếm trong `app.demo_data_set`. Mọi chỗ gửi tin thật (SMS, email, Zalo) **loại** dòng `is_demo` hoặc số dải 0999 (mục 6).
- **Lớp:** ngày khai giảng sau hôm nay ít nhất một tuần, số buổi và thời khoá biểu lấy từ tham số hoặc hằng của hàm có chú thích (không viết số trong code: dùng giá trị mặc định đã có trong danh mục). Không gán giáo viên thật.
- **Ticket:** tiêu đề và mô tả cố định, kênh «Gọi điện», gắn phụ huynh/học sinh/lớp của bộ.

## 5. Xoá và ẩn
`app.delete_demo_data_set` (đợt 1) đổi bộ sang `DA_XOA`. Đợt 2 thêm: dùng `demo_data_item` đánh dấu **ẩn** các bản ghi của bộ (bộ lọc «Ẩn dữ liệu mẫu» ở báo cáo và danh sách đọc `is_demo`), **không xoá cứng**; lớp và ticket của bộ chuyển trạng thái Huỷ/Đóng theo luật sẵn có nếu hàm cho phép, nếu không thì chỉ ẩn bằng cờ. Học sinh, phụ huynh chỉ ẩn. Chỉ mục từng phần `where is_demo` đã có từ đợt 1.

## 6. Cô lập khỏi thao tác thật
- Báo cáo, đếm, nhắc việc, gửi tin: thêm điều kiện loại `is_demo` ở các truy vấn lớn (làm theo PR riêng khi có danh sách chỗ cần, không gộp vào PR này).
- Tìm trùng phụ huynh theo số điện thoại: số 0999 000 xxx là số giả, không gộp với khách thật (kiểm lúc viết migration).

## 7. Kiểm thử (pgTAP) khi viết migration
Mỗi luật một bài, tên ghi luật bằng tiếng Việt: tắt công tắc → `HMT_DEMO_TAT`; khoá môi trường PROD hoặc không có dòng → `HMT_DEMO_TAT`; bộ tạo đủ **6 học sinh (hai cặp anh em), 2 lớp ở Đã trình, 3 ticket, 1 phiếu chờ duyệt** đều `is_demo` và có `demo_data_item`; Kế toán, Giáo viên, Trợ giảng (không có quyền tạo lớp/ticket) vẫn tạo được bộ; số điện thoại trong dải 0999 và không trùng giữa hai bộ; xoá bộ → các bản ghi bị ẩn, không xoá cứng; vượt hạn mức → lỗi đợt 1; một người không xoá bộ của người khác (trừ Admin).

## 8. Quyết định (Chat trả lời 07:05 24/11 cho 5 câu hỏi; anh OK concept 01:11, chi tiết anh chỉnh được)
1. **Có hai cặp anh em** trong 6 học sinh (thử màn «nhiều con» ở cổng Học tập).
2. **Hai lớp: Toán và Tiếng Anh**, chọn mã có sẵn trong danh mục của cơ sở (không viết cứng mã). Thêm một lớp online/OMO **chỉ khi** danh mục của cơ sở có; không có thì bỏ, không báo lỗi.
3. **Lớp dừng ở Đã trình (chờ duyệt)** để người duyệt có việc thử. Hàm tạo gọi hàm trình lớp hiện có (kiểm tên khi viết migration); không tự duyệt.
4. **Có**: kèm một phiếu «Cập nhật hồ sơ» chờ duyệt để thử màn «Việc chờ tôi duyệt». Phiếu này cũng gắn vào bộ (`demo_data_item`) và bị ẩn khi xoá bộ. Sửa lại mục 2 cho khớp: bộ có **một** phiếu duyệt, ở trạng thái chờ, không tự duyệt.
5. **Không dùng `HMT_DEMO_THIEU_QUYEN`.** Kế toán, Giáo viên, Trợ giảng cũng phải tạo được bộ (anh 01:01). Vì vậy `app.create_demo_data_set()` là `security definer`, chỉ đòi: đã đăng nhập, `demo_data_enabled` bật (và môi trường STAGING), còn hạn mức; **không** đòi quyền tạo lớp hay ticket. Hàm con không gọi `create_class`/`create_ticket` qua kiểm quyền theo người gọi: cần đường nội bộ bỏ kiểm quyền người gọi nhưng vẫn giữ luật mã, nhật ký (kiểm khi viết migration; nếu hai hàm đó không tách được phần kiểm quyền thì chèn trực tiếp và cấp mã bằng `app.issue_class_code`, báo Chat).

Chỗ mục 3 và 7 nhắc `HMT_DEMO_THIEU_QUYEN` hoặc «kiểm trước CLASS · Tạo, TICKET · Tạo» **thay bằng quyết định 5**; bài pgTAP «thiếu quyền → HMT_DEMO_THIEU_QUYEN» đổi thành «Kế toán, Giáo viên, Trợ giảng tạo được bộ».

Còn lại: chờ #647 (migration 648) gộp rồi xin Chat số migration, mới viết migration.
