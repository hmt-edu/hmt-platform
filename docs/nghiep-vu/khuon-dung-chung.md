# Khuôn dùng chung (GĐ0 bước 4b): bảng, luật, hàm

Migration `20261012000016_khuon_dung_chung.sql`, kiểm thử `supabase/tests/database/010_khuon_dung_chung.test.sql`.
Phần giao diện: thành phần ở `src/ui/`, nối dữ liệu ở `src/features/`.

## Tìm không dấu (S03-15)

- `app.fold_text(chuỗi)`: bỏ dấu tiếng Việt, đổi về chữ thường ("Đặng Quốc Huy" → "dang quoc huy"). Giao diện có hàm
  tương ứng `foldText` trong `src/lib/format.ts`.
- `app.user_account.search_text`: cột tự sinh gồm tên, tên đăng nhập, mã nhân viên/học sinh, mã cũ, đã gấp chữ. Màn danh
  sách lọc bằng cột này. Bảng nghiệp vụ mới cần tìm theo tên thì thêm cột cùng kiểu.

## Ghi chú, nhắc tên, thông báo (CHUNG-22, CHUNG-12)

- Loại bản ghi mới gắn được ghi chú: `USER_ACCOUNT` (tài khoản người dùng). Ai thấy tài khoản theo quyền Tài khoản · Xem
  thì đọc và viết ghi chú được.
- `app.note_mention`: ai được nhắc tên trong ghi chú nào. `app.notification`: thông báo của từng người; loại thông báo
  là mục của danh mục `NOTIFICATION_KIND` (giai đoạn 0 chỉ có `MENTION` "Được nhắc tên").
- Thông báo **không chép nội dung ghi chú**, chỉ ghi ai nhắc và ở loại bản ghi nào; người nhận mở bản ghi mới đọc được,
  lúc đó quyền xem bản ghi vẫn do RLS quyết định.

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.mention_candidates(chữ)` | Gợi ý đồng nghiệp khi gõ @: chỉ tên, vai trò, mã cơ sở; không có tài khoản khoá, học sinh, chính mình | Nhân viên, giáo viên |
| `app.add_note_mentioning(loại, id, nội dung, id[] người được nhắc)` | Thêm ghi chú (quyền như `app.add_note`), lưu người được nhắc, tạo thông báo cho từng người | Người thấy được bản ghi |
| `app.record_notes(loại, id)` | Ghi chú chưa huỷ của bản ghi, kèm tên người viết và tên người được nhắc | Người thấy được bản ghi |
| `app.mark_notifications_read(id, tất_cả)` | Đánh dấu đã đọc một thông báo, hoặc mọi thông báo của mình khi `tất_cả = true` | Chính người nhận |

Luật: chỉ nhắc được nhân viên, giáo viên đang hoạt động (`HMT_NHAC_TEN_KHONG_HOP_LE`); số người nhắc trong một ghi chú
không vượt tham số `note_mention_max` (`HMT_NHAC_TEN_QUA_NHIEU`); bỏ trùng và bỏ chính mình; mỗi người chỉ thấy và chỉ
đánh dấu được thông báo của mình; vai trò bắt hai bước chưa xác thực thì chưa thấy thông báo.

## Lịch sử thay đổi của bản ghi (CHUNG-22)

- `app.record_history(loại, id, [số dòng], [trước lúc])`: ai đổi trường nào, từ gì sang gì, lúc nào. Người thấy được bản
  ghi thì xem được lịch sử của **chính bản ghi đó**; nhật ký thao tác toàn hệ thống (`app.audit_log`) vẫn chỉ ADMIN đọc.
- Cột kỹ thuật khai trong `app.history_hidden_column` (đếm sai mật khẩu, khoá tạm, phiên bản phiên, cột tìm kiếm…)
  không đưa vào lịch sử cho người dùng.
- Riêng tài khoản người dùng: gộp cả thay đổi vai trò (bảng `user_role`), tên cột trả về dạng `role:<tên vai trò>`.

## Bộ lọc yêu thích (CHUNG-19)

Bảng `app.saved_filter`: của từng người, theo mã màn (`QT-01`…), có thể đặt mặc định và dùng chung. Huỷ, không xoá.

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.save_filter(mã màn, tên, điều kiện, dùng_chung, mặc_định)` | Lưu mới, hoặc ghi đè bộ lọc cùng tên của mình; mỗi người mỗi màn chỉ một bộ lọc mặc định | Nhân viên, giáo viên |
| `app.remove_filter(id)` | Bỏ bộ lọc (huỷ) | Người tạo; ADMIN với bộ lọc dùng chung |

**Chờ anh Trường chốt:** hiện chỉ ADMIN lưu được bộ lọc dùng chung cho mọi người (`HMT_KHONG_CO_QUYEN` với người khác).

## Tìm kiếm toàn hệ thống (CHUNG-11)

`app.search_records(chữ)`: tìm theo tên, mã mới, mã cũ, không cần gõ dấu; chạy bằng quyền của người gọi nên chỉ ra bản
ghi người đó xem được. Giai đoạn 0 mới có tài khoản người dùng; mỗi giai đoạn sau nối thêm một nhánh (học sinh, phụ
huynh, lead, đơn, phiếu thu, lớp) và khai đường dẫn bản ghi ở `src/features/records/entities.ts`.

## Xuất file (CHUNG-18)

Giao diện xuất CSV (UTF-8 có BOM). Trước khi tạo file luôn gọi `app.log_export(phân hệ, bộ lọc, số dòng)` (đã có từ
bước 3); ghi nhật ký không được (kể cả thiếu quyền Xuất) thì không tạo file.

## Tham số mới

| Khoá | Mặc định | Dùng cho |
|---|---|---|
| `list_page_size` | 25 | Số dòng mỗi trang danh sách, lịch sử thay đổi, trung tâm thông báo |
| `note_mention_max` | 10 | Số người nhắc tên tối đa trong một ghi chú |
| `search_result_max` | 8 | Số kết quả của ô tìm kiếm và ô gõ @ |
| `search_min_length` | 2 | Số ký tự tối thiểu để tìm |
