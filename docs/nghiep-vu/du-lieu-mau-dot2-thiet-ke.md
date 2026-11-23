# Dữ liệu mẫu đợt 2: học sinh, lớp, ticket (bản thiết kế ngắn, C-23-39)

Trạng thái: **thiết kế, chưa viết migration** (chờ #647 gộp, đợt 1 = khung, migration 648). Soạn 24/11/2026 theo thẻ C-23-39 (anh OK concept 01:11). Nguồn đọc: `docs/nghiep-vu/du-lieu-mau.md` và migration 648 trên nhánh #647; hàm hiện có `app.create_class` (589), `app.create_ticket` (cs ticket), `app.issue_person_code`, `app.issue_class_code`.

## 1. Việc cần làm
Mở rộng `app.create_demo_data_set()` (đợt 1 chỉ tạo bản ghi bộ) để đổ **một chuỗi dữ liệu cố định**: **6 học sinh**, **2 lớp**, **3 ticket**, gắn vào bộ để xoá hoặc ẩn cả bộ. Mọi bản ghi mang cờ `is_demo = true` và có dòng trong `app.demo_data_item`.

## 2. Khoá an toàn (giữ nguyên đợt 1)
- Đầu hàm gọi `app.assert_demo_data_allowed()` (công tắc `demo_data_enabled` bật **và** `app.deployment_env` = `STAGING`). Thiếu một trong hai: `HMT_DEMO_TAT`. Thẻ ghi «kiểm `app.demo_data_enabled`»: trong code hiện tại là tham số `demo_data_enabled` đọc qua hàm kiểm trên, **không có hàm tên đó**; thiết kế dùng hàm kiểm.
- Hàm nhận **không tham số nội dung** (cơ sở lấy từ token), nội dung là hằng cố định: không có đường đưa dữ liệu tuỳ ý vào. Hạn mức bộ mỗi người, mỗi cơ sở như đợt 1.
- Không tự duyệt: lớp dừng ở trạng thái Nháp hoặc Đã trình (chọn ở câu hỏi 3); ticket ở Mới hoặc Đang xử lý; không tạo phiếu duyệt, không ghi danh, không sổ giờ, không phiếu thu.

## 3. Cách tạo (hàm con, mỗi hàm một việc, đều `security definer`, chỉ gọi được từ hàm tạo bộ)
| Hàm con | Việc | Cách tạo |
|---|---|---|
| `app.demo_make_parents(set_id, branch_id)` | 4 phụ huynh [MẪU] (6 học sinh, có hai cặp anh em) | `app.issue_person_code('PH')`, chèn `app.parent` |
| `app.demo_make_students(set_id, branch_id, parent_ids)` | 6 học sinh [MẪU] khối, năm sinh khác nhau | `app.issue_person_code('HS')`, chèn `app.student` |
| `app.demo_make_classes(set_id, branch_id)` | 2 lớp [MẪU] (một Toán, một Tiếng Anh nếu danh mục có; xem câu hỏi 2) | gọi `app.create_class(jsonb)` để lớp qua đủ luật mã, thời khoá biểu, kiểm môn theo khối |
| `app.demo_make_tickets(set_id, branch_id, parent_ids, student_ids, class_ids)` | 3 ticket: 1 Đề nghị, 1 Khiếu nại, 1 Đề nghị gắn lớp | gọi `app.create_ticket(jsonb)` |
| `app.demo_tag(set_id, entity_type, entity_id)` | đặt `is_demo = true` và ghi `demo_data_item` | một chỗ duy nhất, mọi hàm trên gọi |

Dùng hàm nghiệp vụ có sẵn (create_class, create_ticket) để mã, nhật ký và luật giống bản thật; vì hàm kiểm quyền theo người gọi, `app.create_demo_data_set()` **kiểm trước** người gọi có `CLASS · Tạo` và `TICKET · Tạo` ở cơ sở của mình, thiếu thì báo `HMT_DEMO_THIEU_QUYEN` (câu: «Tài khoản này chưa đủ quyền tạo lớp và ticket để làm dữ liệu mẫu.») và không tạo gì (cả giao dịch lui). Học sinh và phụ huynh chèn trực tiếp vì chưa có hàm công khai tạo riêng.

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
Mỗi luật một bài, tên ghi luật bằng tiếng Việt: tắt công tắc → `HMT_DEMO_TAT`; khoá môi trường PROD hoặc không có dòng → `HMT_DEMO_TAT`; bộ tạo đủ **6 học sinh, 2 lớp, 3 ticket** đều `is_demo` và có `demo_data_item`; thiếu quyền tạo lớp/ticket → `HMT_DEMO_THIEU_QUYEN` và không để lại bản ghi; số điện thoại trong dải 0999 và không trùng giữa hai bộ; xoá bộ → các bản ghi bị ẩn, không xoá cứng; vượt hạn mức → lỗi đợt 1; một người không xoá bộ của người khác (trừ Admin).

## 8. Câu hỏi cho Chat/anh Trường (chờ trả lời trước khi viết migration)
1. Hai cặp anh em trong 6 học sinh có cần không (để thử màn «nhiều con» ở cổng Học tập)?
2. Hai lớp: môn nào, khối nào, và có cần một lớp online/OMO không? (Danh mục lớp khác nhau theo cơ sở; cần chọn mã có sẵn ở staging.)
3. Lớp dừng ở **Nháp** hay **Đã trình (chờ duyệt)**? Thẻ nói «dừng ở trạng thái chờ duyệt»; nếu chọn Đã trình thì cần hàm chuyển trạng thái lớp đúng quyền (kiểm tên hàm khi viết).
4. Ticket có cần kèm một phiếu nghiệp vụ (ví dụ Cập nhật hồ sơ chờ duyệt) để thử màn «Việc chờ tôi duyệt» không? Mặc định thiết kế: **không**.
5. Chấp nhận lỗi `HMT_DEMO_THIEU_QUYEN` cho tài khoản thiếu quyền tạo lớp hoặc ticket (ví dụ Kế toán) thay vì tạo một phần bộ?
