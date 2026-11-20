# Hiệu năng các bảng và hàm mới gộp 20/11/2026 (thẻ Chat 03:13, Code C)

Phạm vi: QT-16 (hồ sơ giáo viên, migration 313), KH-08 (lên khối, 566), CS-07 (chuyển cơ sở hai cơ sở duyệt, 568), CS-10 (chuyển phí, 567), cùng QT-13 (569, PR #370) và QT-15 (479, PR #369) **chưa gộp** nên xem trên nhánh PR. Chỉ tài liệu và đề xuất; không sửa migration đã gộp.

## Cách đo

Supabase local trống (`db:reset`, `db:seed-users`), dữ liệu giả dựng trong MỘT giao dịch rồi `rollback` (không để lại gì, không dùng dữ liệu thật): 5.000 phụ huynh, 50.000 học sinh (khối 1–12, 5% chưa có khối), 35.000 ghi danh (đủ 5 tình trạng), 2.000 hồ sơ giáo viên, 30.000 phiếu ticket và 30.000 phiếu nghiệp vụ (một nửa có cơ sở đích), 10.000 tài khoản học sinh. Gọi hàm bằng `set local role authenticated` với claims thật của Admin (aal2) hoặc Trưởng cơ sở. Máy Mac chạy nhiều việc nên số dao động khoảng ±50%.

## Kết quả

| Hàm (màn) | Dữ liệu | Thời gian | Nhận xét |
|---|---|---|---|
| `preview_grade_promotion` trang 1 (KH-08) | 50.000 HS, 35.000 ghi danh | 119 ms | |
| … tìm theo tên (`q`) | như trên | 100 ms | |
| … trang 100 (offset 4.950) | như trên | 128 ms | |
| `list_grade_promotion_batches` (KH-08) | | 2 ms | bảng đợt rất nhỏ, có chỉ mục theo ngày tạo |
| `list_teaching_profiles` trang 1 (QT-16) | 2.000 hồ sơ | 5 ms | |
| … tìm kiếm tên/mã | | 13 ms | |
| … lọc môn, khối, loại | | 3 ms | |
| `list_teaching_candidates` (QT-16) | | 1 ms | |
| `list_student_accounts` trang 1 (QT-13, PR #370) | 50.000 HS, 10.000 tài khoản | 23 ms | nối qua chỉ mục duy nhất `user_account_student_code_key` |
| … tìm `q` | | 84 ms | tìm trong `search_text`, có nhánh tìm theo tên phụ huynh |
| … tình trạng Chưa cấp / Bị khoá | | 25 / 38 ms | |
| `list_tasks_for_destination` (CS-07) | 3.750 phiếu chờ cơ sở đích | **5.650 ms** | **CHẬM**, xem dưới |

Mục tiêu tham chiếu trong CLAUDE.md: danh sách dưới 1 giây. Mọi câu đạt trừ một câu.

## Chỉ mục (đã có lý do trong migration)

- QT-16: `teaching_profile_list_idx (is_active, kind)` cho lọc danh sách; `user_id` unique (mỗi người một hồ sơ). Đủ: bảng cỡ vài trăm đến vài nghìn dòng.
- KH-08: `student_graduated_idx` (một phần, chỉ em đã tốt nghiệp), `grade_promotion_batch_created_idx (created_at desc)`, `grade_promotion_item_batch_idx`, `grade_promotion_item_student_idx` cho hai khoá ngoại. Đủ.
- CS-07: `ticket_task_dest_idx (dest_branch_id, status_code)` có điều kiện một phần; kế hoạch dùng đúng chỉ mục này (bitmap scan 1 ms). Chỉ mục không phải chỗ chậm.
- QT-13 (#370, không thêm chỉ mục): dựa vào chỉ mục sẵn có `user_account_student_code_key`. Đủ.
- QT-15 (#369): bảng `ticket_task_rule_version` chỉ vài chục dòng, có `unique (task_type, valid_from)` phục vụ đúng câu `order by valid_from desc limit 1`. Không cần thêm; chưa đo EXPLAIN vì chưa gộp (tra tĩnh).
- CS-10 (`apply_fee_transfer`): thao tác một ghi danh, không phải danh sách; không có bảng mới. Không đo.

## Vấn đề phát hiện: `app.list_tasks_for_destination` (migration 568)

**Nguyên nhân:** điều kiện `app.can_see_branch('TICKET', 'DUYET', k0.dest_branch_id)` gọi lại hàm quyền cho TỪNG dòng phiếu (mỗi lần tra ma trận quyền), vì hàm có `set search_path` nên không được gộp vào câu truy vấn. Với 3.750 phiếu chờ khớp điều kiện đầu, mất 5,65 giây. Chỉ mục cho câu này vẫn đúng; thời gian nằm ở gọi hàm theo dòng, đúng điều CLAUDE.md dặn (hàm quyền viết dạng `(select app.has_permission(...))`).

**Đề xuất sửa (migration mới, không sửa 568):** tính phạm vi quyền một lần rồi so cơ sở:

```sql
and (select app.permission_scope('TICKET', 'DUYET')) is not null
and ((select app.permission_scope('TICKET', 'DUYET')) = 'TOAN_HE_THONG'
     or k0.dest_branch_id = (select app.current_branch_id()))
```

Đo cùng dữ liệu: **5.654 ms → 25 ms** (kết quả giống `can_see_branch`, vì hàm đó chỉ so `TOAN_HE_THONG` hoặc cơ sở hiện tại). Thực tế số phiếu chờ cơ sở đích ở một thời điểm rất ít (hàng chục), nên hiện chưa chậm với người dùng; nhưng đây là mẫu sai cần sửa trước khi lượng phiếu lớn. Cần một thẻ DB nhỏ (mức CAO vì đụng kiểm quyền): Chat giao cho lane B (chủ migration 568), kèm pgTAP người ngoài phạm vi vẫn không thấy phiếu.

**Cùng mẫu cần rà (chưa đo):** các hàm mới khác gọi `app.can_see_branch(...)` hoặc `app.has_permission(...)` trong `where` theo dòng. Gợi ý lane B/D grep `can_see_branch(` trong `where` của hàm danh sách khi viết hàm mới.

## Chưa làm / giới hạn

- QT-13 đo bằng cách nạp thân hàm từ nhánh PR trong giao dịch (chưa có trong `main`); đo lại sau khi #370 gộp.
- Không đo ghi (run/undo lên khối với 35.000 em): thao tác Admin chạy tay, hiếm; nếu cần đo thì dùng cùng kịch bản.
- Chỉ đo một cơ sở tải; số liệu chỉ để so sánh tương đối.

## Dung lượng gói tải trang đầu cổng CRM (Code C, 20/11/2026, thẻ Chat 20:22)

Đo bằng bước dò có sẵn của CI (`npm run build` rồi `npm run size`, `scripts/bundle-size.ts`) trên `main` lúc 20:35. Số nén gzip, gồm gói điểm vào, các gói nó import tĩnh và CSS. **Chỉ báo số, không đặt ngưỡng** (anh Trường chốt 18/10/2026).

| Điểm vào | Dung lượng nén | Số tệp |
|---|---|---|
| Đăng nhập | 201 KB | 10 |
| **Trang đầu cổng CRM (khung + trang chủ)** | **229 KB** | 17 |
| Cổng Giáo viên (khung + trang đầu) | 226 KB | 16 |
| Cổng Học tập (khung + trang đầu) | 226 KB | 16 |
| Màn danh sách mẫu `/dev/danh-sach` (thêm vào khung CRM) | 280 KB | 28 |
| Màn Lead `/crm/lead` (thêm vào khung CRM) | 292 KB | 37 |

Nhận xét: trang đầu CRM 229 KB, dưới mốc tham chiếu khoảng 250 KB của CLAUDE.md (còn dư khoảng 21 KB, chưa phải ngưỡng cứng). Màn danh sách thêm khoảng 50 đến 60 KB vào khung. Mỗi màn mới đã tải lười theo màn nên không cộng vào trang đầu. Cần theo dõi: nếu khung CRM (menu, K03) lớn thêm hơn 20 KB thì trang đầu vượt mốc 250 KB.
