# Tuyển sinh (P3): dữ liệu, hàm, quyền

Đặc tả: `docs/design/dac-ta/P3-tuyen-sinh.md`. Luật: `docs/spec/04` mục 1 (R-CRM-01…23). Gói thiết kế: `design/hmt-p3/`.
Kiểm thử: `supabase/tests/database/017_ts_lead_lich_hen.test.sql` (P3b1). File này cập nhật theo từng PR của P3.

## P3b1: nền, lead, lịch hẹn (migration `20261017000023` … `025`)

### Bảng
| Bảng | Ý chính |
|---|---|
| `app.campaign` | Chiến dịch marketing (tên không trùng, từ ngày, đến ngày). Màn quản lý CH-08 làm sau |
| `app.parent`, `app.student` | Phụ huynh, học sinh tối giản; tạo khi bấm "Tạo cơ hội" (P3b2). Mã PH, HS cấp bằng `app.issue_person_code` |
| `app.lead` | Mã `LD` + 6 số cấp lúc Lưu; thông tin phụ huynh, học sinh dạng chữ; nguồn 3 cấp (danh mục 9); giai đoạn C1–C4 + nhóm con; `record_status` Đang dùng / Đã gộp; `next_appointment_at` do trigger tự tính |
| `app.appointment` | Gắn **đúng một** hồ sơ (hiện chỉ lead; P3b2 thêm cơ hội, phiếu); trạng thái Chưa làm / Hoàn thành / Huỷ; lý do huỷ (danh mục 34) |

Mọi bảng: RLS bật, đọc theo ma trận quyền (phạm vi toàn hệ thống hoặc đúng cơ sở), ghi chỉ qua hàm, nhật ký, không xoá cứng.
Chính sách dùng `(select app.permission_scope(...))` để tính một lần. Ghi chú và lịch sử gắn được vào `LEAD`.

### Danh mục, mã, tham số
- L5Q (nhóm con cơ hội), lý do huỷ test "Trung tâm không xếp được lịch test" (nối L5Q) và "Tạo phiếu sai" (không nối),
  danh mục 34 `APPOINTMENT_CANCEL_REASON`; phiếu: "Chờ giáo viên chấm", bỏ "Từ chối".
- Mã `LD`, `CO`, `PKT` (6 số, toàn hệ thống): `app.issue_crm_code` (hàm nội bộ, giao diện không gọi).
- Tham số: `test_reminder_time_minutes` (1020 = 17:00), `test_reminder_short_window_hours` (24), `test_reminder_short_lead_hours` (2),
  `lead_import_max_rows` (500), `list_page_size_default` (50), `list_page_size_max` (100). Giá trị chung, không ghi đè theo cơ sở.

### Hàm
| Hàm | Làm gì | Quyền | Luật |
|---|---|---|---|
| `app.find_duplicate_contacts(SĐT)` | Lead và phụ huynh trùng số; hồ sơ ngoài phạm vi chỉ lộ mã và cơ sở | Lead · Tạo | TS-03, TS-14 |
| `app.create_lead(dữ liệu, xác nhận trùng, phụ huynh)` | Tạo lead C1, cấp mã LD; trùng SĐT cần xác nhận lần hai, hoặc gắn vào phụ huynh có sẵn | Lead · Tạo (cơ sở); giao người khác cần Giao việc | R-CRM-01, 19 |
| `app.update_lead(id, dữ liệu, xác nhận trùng)` | Sửa các ô thông tin; bản "Đã gộp" chỉ đọc | Lead · Sửa | R-CRM-22 |
| `app.change_lead_stage(id, giai đoạn, nhóm con)` | Đổi giai đoạn lead tự do hai chiều; C4D chỉ hệ thống; sang C2, C3, C4 bắt buộc chọn nhóm con, thiếu thì `HMT_THIEU_NHOM_CON` (migration 049, bài kiểm 041) | Lead · Sửa | R-CRM-09, R-CRM-41 |
| `app.assign_owner('LEAD', ids, người)` | Giao người phụ trách (tối đa `list_page_size_max` bản ghi), cùng cơ sở | Lead · Giao việc | TS-05 |
| `app.create_appointment(...)` | Tạo lịch hẹn gắn lead; không có lịch mồ côi | Lịch hẹn · Tạo | R-CRM-04 |
| `app.reschedule_appointment`, `complete_appointment`, `cancel_appointment`, `reopen_appointment` | Dời (chỉ Chưa làm); Hoàn thành bấm một lần; Huỷ bắt buộc lý do danh mục 34 ("Khác" bắt ghi chú); Mở lại về Chưa làm. Không đổi giai đoạn, không tạo việc, không gửi thông báo | Sửa (dời, hoàn thành, mở lại), Huỷ (huỷ) | R-CRM-04, R-HT-04 |
| `app.list_leads(bộ lọc, sắp xếp, cỡ trang, bắt đầu)` | Danh sách phân trang ở DB, trả `{total, rows}` chỉ các cột màn hiện | Lead · Xem | CLAUDE.md Hiệu năng |
| `app.list_appointments(...)`, `app.appointment_overdue_count(mốc, của tôi)` | Như trên cho lịch hẹn; dải nhắc "Quá hạn" | Lịch hẹn · Xem | |

`list_leads`, `list_appointments` là `security definer` có chủ ý: dưới RLS, toán tử LIKE không "leakproof" nên chỉ mục
trigram không dùng được cho ô tìm kiếm (đo: quét cả bảng). Hàm tự áp đúng luật của chính sách đọc, lấy phạm vi từ
`app.permission_scope` (một nơi duy nhất).

### Khoá nhóm con
C4D khoá từ PR 6a. Các nhóm con còn lại khoá **cùng hàm dùng chúng**: L5A, L5B, L5P, L5C…L5Q, L6A, L8A, L8B, L8C ở P3b2 (đổi giai đoạn
cơ hội, tính lại L5/L6, R-CRM-15, 16, 17); L7A, L7B, L8A của giai đoạn phiếu tái tục khi viết hàm tái tục.

### Hiệu năng (đo trên `supabase/seed-lon.sql`: 50.000 lead, 30.000 phụ huynh, 100.000 lịch hẹn)
Mọi lệnh dưới 20 ms trừ lúc đếm tổng. Chi tiết EXPLAIN nằm trong mô tả PR P3b1. Chỉ mục có lý do ghi ngay trong migration `024`.

### Lưu ý về phạm vi quyền (cần xử lý sau)
Các hàm và chính sách đọc hiện coi mọi phạm vi khác "toàn hệ thống" là "cùng cơ sở" (như `app.can_see_branch`: phạm vi `CUA_TOI`, `DUOC_PHAN_CONG`,
`CHINH_MINH` đều so cơ sở). Hiện chưa sao vì các vai trò dùng phân hệ Tuyển sinh chỉ có phạm vi toàn hệ thống hoặc cơ sở mình. Khi có vai trò dùng
phạm vi **được phân công** (giáo viên chấm phiếu kiểm tra, P3e) cần tính riêng: phiếu mà người đó là giáo viên chấm hoặc người phụ trách.

## P3b2a: cơ hội (migration `20261018000028`)
Kiểm thử: `supabase/tests/database/020_co_hoi.test.sql` (134 bài). Luật: R-CRM-01, 02, 03, 09, 13, 14, 16, 23, 26, 27, 28, 34, 35.

### Bảng
| Bảng | Ý chính |
|---|---|
| `app.opportunity` | Mã `CO` + 6 số cấp lúc Lưu; lead gốc, phụ huynh, cơ sở, người phụ trách, người hỗ trợ, nguồn (chép từ lead), giai đoạn L1–L8 + nhóm con, lý do bỏ qua test (danh mục 33), `record_status` Đang dùng / Đã gộp (hàm gộp ở P3b3), `next_appointment_at` do trigger tính, ô tìm kiếm do trigger giữ (đổi theo khi phụ huynh đổi tên, SĐT). Thông tin học sinh giữ dạng chữ; `student_id` gắn khi có hồ sơ học sinh (phiếu kiểm tra, duyệt đơn: R-CRM-27) |
| `app.appointment` | Thêm `opportunity_id`; ràng buộc "đúng một hồ sơ" gồm lead hoặc cơ hội (phiếu thêm ở P3b2b); trigger tính lịch kế tiếp cho cả cơ hội |

Chặn ngay ở bảng (trigger): giai đoạn không lùi (R-CRM-02, trừ người chạy migration), từ L5 bắt tên và năm sinh học sinh (R-CRM-03), nguồn, kênh, nhóm con đúng cấp, không ghi cơ sở văn phòng.

### Hàm
| Hàm | Làm gì | Quyền | Luật |
|---|---|---|---|
| `app.create_opportunity(lead, dữ liệu, xác nhận)` | Lead đã có cơ hội thì chặn kèm mã (`HMT_LEAD_DA_CO_CO_HOI`), xác nhận lần hai mới tạo thêm; lead phải ở nhóm con C4C (hoặc C4D, đã tạo rồi) mới tạo được, chưa đủ thì chặn `HMT_LEAD_CHUA_DU_DIEU_KIEN` (migration 048, luật R-CRM-40 ở #90). Tìm hoặc tạo phụ huynh, cấp mã CO, giai đoạn đầu L1, đưa lead về C4D | Cơ hội · Tạo, Lead · Xem (cơ sở); giao người khác cần Giao việc | R-CRM-01, 09, 19, 27 |
| `app.update_opportunity(id, dữ liệu)` | Sửa nhu cầu, học sinh, người hỗ trợ. Đã có hồ sơ học sinh thì sửa luôn hồ sơ đó (cần Học sinh · Sửa ở cơ sở của hồ sơ) | Cơ hội · Sửa | R-CRM-03, 26, 27 |
| `app.change_opportunity_stage(id, giai đoạn, nhóm con, lý do bỏ qua, ghi chú, xác nhận L8)` | Chỉ đi tới; từ L5 bắt học sinh; người dùng không bấm L6; vào L5 hệ thống gắn nhóm con; sang L7, L8: chặn phiếu dang dở, không có phiếu hoàn thành bắt lý do bỏ qua test; L8 bắt L8A, B, C và xác nhận. Cùng giai đoạn (R-CRM-35): đổi nhóm con được, cả lùi, trừ rời L8C, đổi tay nhóm con L5, chọn lại L6A; ở L6 người dùng chọn L6B…L6F (R-CRM-34) | Cơ hội · Sửa | R-CRM-02, 03, 12, 13, 14, 15, 16, 17 |
| `app.assign_owner('OPPORTUNITY', ids, người)` | Mở rộng hàm có sẵn cho cơ hội | Cơ hội · Giao việc | TS-05 |
| `app.create_appointment(lead, …, cơ hội)` | Thêm tham số cuối `p_opportunity_id`; đúng một trong lead, cơ hội | Lịch hẹn · Tạo | R-CRM-04 |
| `app.list_opportunities(...)`, `app.opportunity_board(bộ lọc, số thẻ)` | Danh sách phân trang; Kanban L1–L8 một lần gọi (tổng mỗi cột + N thẻ mới nhất, N theo tham số `kanban_cards_per_column`) | Cơ hội · Xem | CLAUDE.md Hiệu năng |
| `app.list_appointments(...)` | Thêm bộ lọc `opportunity_id`; cột `opportunity_id`, `record_code`, `record_label` | Lịch hẹn · Xem | |
| `app.list_appointments(...)` (037) | Thêm bộ lọc `q` (tên, SĐT, mã của lead hoặc cơ hội gắn) và `owner_id` (người phụ trách) cho màn Lịch hẹn TS-11 | Lịch hẹn · Xem | |
| `app.find_or_create_parent`, `app.find_or_create_student`, `app.normalize_person_name` | **Nội bộ** (giao diện không gọi). Phụ huynh khớp SĐT chuẩn hoá (cũ nhất nếu nhiều), không ghi đè tên; học sinh khớp phụ huynh + tên chuẩn hoá + năm sinh, cùng tên khác năm sinh là hai hồ sơ | | R-CRM-27, 28 |
| `app.opportunity_test_state`, `app.opportunity_l5_substage` | Trạng thái phiếu của cơ hội (dang dở, hoàn thành, huỷ) và nhóm con L5 theo phiếu; từ P3b2b dùng bảng phiếu thật | | R-CRM-12, 14, 15 |

### Chưa làm
R-CRM-16 phần chặn tạo đơn, R-CRM-17 (tự lên L8C), R-CRM-18 (cảnh báo lệch) chờ đơn hàng, phiếu thu. Hàm gộp (R-CRM-22) ở P3b3.

### Khoá nhóm con
L5A, L5B, L5P, L5C…L5Q, L6A, L8A, L8B, L8C đã khoá. L7A, L7B của giai đoạn phiếu tái tục khoá khi viết hàm tái tục.

### Hiệu năng (đo trên `seed-lon`: 50.000 lead, 20.000 cơ hội)
Số đo và EXPLAIN nằm trong mô tả PR P3b2a. Sửa kèm: `list_leads` và `list_appointments` thêm `not materialized` cho CTE dùng hai lần (trước đó quét cả bảng rồi sắp xếp).

## P3b2b: phiếu kiểm tra (migration `20261018000030`)
Kiểm thử: `supabase/tests/database/022_phieu_kiem_tra.test.sql` (174 bài). Luật: R-CRM-05, 06, 10, 11, 12, 13, 14, 15, 21, 27. Màn: TS-15 (K4), TS-16 (K1, K2, K5), TS-17 (K3), dựng ở P3e.

### Bảng
| Bảng | Ý chính |
|---|---|
| `app.student_test` | Mã `PKT` cấp lúc Lưu. Cơ hội, học sinh (tìm hoặc tạo lúc tạo phiếu), môn, khối, hình thức (`TEST_MODE`), cấp độ đề (`TEST_LEVEL`), tên đề, giờ test, `branch_id` (cơ sở của cơ hội, dùng cho RLS), `test_branch_id` (cơ sở test), `created_branch_id` (tự ghi), phòng, giáo viên chấm, người phụ trách, trạng thái (Nháp, Đang test, Chờ giáo viên chấm, Hoàn thành, Đã huỷ), lý do huỷ, kết quả (điểm 0 đến 10 một số lẻ, nhận xét, trình độ S/A/B/C, phân loại CB/NC), người nhập và cờ "nhập thay" |
| `app.appointment` | Thêm `student_test_id`, `is_auto_reminder`, `auto_scheduled_at`; "đúng một hồ sơ" gồm lead, cơ hội hoặc phiếu |

RLS đọc theo phạm vi của ô Xem: toàn hệ thống, đúng cơ sở của cơ hội, hoặc **được phân công** (giáo viên chấm hoặc người phụ trách phiếu).

### Hàm
| Hàm | Làm gì | Quyền | Luật |
|---|---|---|---|
| `app.create_student_test(cơ hội, dữ liệu, giờ nhắc, loại nhắc)` | Cơ hội từ L5; ngày giờ bắt buộc, ở tương lai; tìm hoặc tạo hồ sơ học sinh; tự sinh lịch hẹn nhắc; nhiều phiếu một cơ hội | Kiểm tra đầu vào · Tạo | R-CRM-05, 27 |
| `app.reschedule_student_test` | Đổi lịch phiếu Nháp; lịch nhắc đổi theo nếu chưa sửa tay | Sửa | TS-15 |
| `app.update_student_test` | Người phụ trách, cơ sở test, phòng, giáo viên chấm, tên đề | Sửa (Giao việc nếu đổi người phụ trách) | R-CRM-21 |
| `app.start_student_test`, `submit_student_test` | Nháp → Đang test → Chờ giáo viên chấm | Sửa | R-CRM-10 |
| `app.enter_test_result` | Điểm, nhận xét, trình độ, phân loại; người phụ trách nhập thay thì ghi "nhập thay" | Sửa | R-CRM-10, 11 |
| `app.complete_student_test` | Cần giáo viên chấm, điểm, nhận xét; cơ hội ở L5 trở xuống tự lên L6A | Sửa | R-CRM-13 |
| `app.step_back_student_test` | Lùi một bước; Hoàn thành về Nháp bắt lý do; cơ hội không lùi | Sửa | R-CRM-21, 02 |
| `app.cancel_student_test` | Bắt lý do danh mục 13; Hoàn thành phải về Nháp trước; huỷ lịch nhắc tự sinh | Huỷ | R-CRM-06 |
| `app.reopen_student_test` | Phiếu huỷ về Nháp, bắt lý do; bật lại lịch nhắc | Sửa | R-CRM-10 |
| `app.list_student_tests`, `app.student_test_board` | Danh sách phân trang; Kanban 4 cột + Đã huỷ một lần gọi | Xem | CLAUDE.md Hiệu năng |
| `app.opportunity_test_state`, `app.opportunity_l5_substage`, `app.refresh_opportunity_l5_substage` | Nội bộ: trạng thái phiếu của cơ hội, nhóm con L5 theo thứ tự ưu tiên R-CRM-15, tính lại sau mỗi lần phiếu đổi | | R-CRM-12, 14, 15 |
| `app.test_reminder_time`, `app.ensure_test_reminder`, `app.cancel_test_reminder`, `app.test_scope_ok` | Nội bộ: giờ nhắc theo ba tham số `test_reminder_*`, sinh, huỷ lịch nhắc; quyền theo phạm vi phiếu | | R-CRM-05 |

### Hiệu năng (đo trên `seed-lon`: 15.000 phiếu)
Số đo và EXPLAIN nằm trong mô tả PR P3b2b.

## P3b3a: gộp trùng (migration `20261018000031`)
Kiểm thử: `supabase/tests/database/023_gop_trung.test.sql` (106 bài), `022` thêm 25 bài lịch nhắc tự đóng. Luật: R-CRM-22, 25, 37. Màn: TS-10, KH-07 (K4), dựng ở P3f.

### Bảng
`app.parent`, `app.student` thêm `record_status` ("Đang dùng" hoặc "Đã gộp") và `merged_into_id` (như lead, cơ hội); ghi chú gắn được vào Phụ huynh, Học sinh.

### Hàm
| Hàm | Làm gì | Luật |
|---|---|---|
| `app.merge_preview(loại, giữ, gộp)` | Xem trước: số bản ghi sẽ chuyển, điều kiện chặn, cảnh báo; cùng kiểm quyền như gộp thật | TS-10, KH-07 |
| `app.merge_leads` | Chuyển lịch hẹn, ghi chú, cơ hội sang lead giữ lại | R-CRM-22 |
| `app.merge_opportunities` | Chuyển lịch hẹn, ghi chú, phiếu; ô trống của bản giữ lại lấy của bản kia; **giai đoạn bản giữ lại giữ nguyên**; chặn: khác phụ huynh, khác học sinh, bản bị gộp có báo giá hoặc đơn; cảnh báo: bản bị gộp ở giai đoạn cao hơn | R-CRM-22, 37(a), 02 |
| `app.merge_students` | Chuyển cơ hội, phiếu, ghi chú; chặn nếu khác phụ huynh | R-CRM-37(b) |
| `app.merge_parents` | Chuyển lead, cơ hội, học sinh, ghi chú; không tự gộp học sinh; trả danh sách học sinh trùng; không chặn theo báo giá, đơn (R-CRM-25 còn [CHỜ]) | R-CRM-25, 37(c) |
| `app.duplicate_students_of_parent` | Các cặp học sinh trùng tên (chuẩn hoá) và năm sinh dưới một phụ huynh | R-CRM-37(c) |
| Nội bộ: `merge_common`, `merge_check_opportunities`, `merge_check_students`, `move_notes`, `add_system_note`, `opportunity_sales_documents` | Kiểm chung, điều kiện chặn từng loại, chuyển ghi chú (cờ trong giao dịch), ghi chú hệ thống, điểm nối báo giá và đơn (rỗng, P5 thay thân) | |

Quyền: hành động Duyệt của phân hệ, kiểm cho **cả hai** hồ sơ; người một cơ sở chỉ gộp khi cả hai ở cơ sở mình; hai cơ sở khác nhau chỉ Admin. Không hoàn tác, cần xác nhận. Làm phẳng chuỗi gộp (A→B rồi B→C thì A cũng trỏ về C). Tìm hoặc tạo phụ huynh, học sinh và dò trùng SĐT gặp hồ sơ đã gộp thì trỏ về bản giữ lại; danh sách lead, cơ hội: bản đã gộp vẫn tìm được bằng mã.

### Lịch nhắc của phiếu
`start_student_test` đóng (Huỷ, lý do Khác, ghi chú "Phiếu đã bắt đầu") lịch nhắc tự sinh còn Chưa làm và chưa sửa tay; lịch người dùng sửa tay hoặc tự tạo giữ nguyên. Lùi về Nháp, đổi lịch sau đó: không mở lại, không sinh mới. Mở lại phiếu đã huỷ: chỉ bật lại lịch nhắc bị huỷ theo phiếu.

### Hiệu năng
Số đo và EXPLAIN trên `seed-lon` nằm trong mô tả PR P3b3a.

## P3b3b: nhập lô lead (migration `20261019000032`)
Kiểm thử: `supabase/tests/database/024_nhap_lo_lead.test.sql` (53 bài). Luật: R-CRM-11 (giữ như bản cũ), `lead_import_max_rows`. Màn: TS-04 (K4b), dựng ở P3f.

| Hàm, bảng | Làm gì | Quyền |
|---|---|---|
| `app.import_leads(hàng, nhập thật?, mặc định, tên file)` | Mỗi hàng chạy qua `create_lead` trong một khối con bắt lỗi: HOP_LE (kèm mã), TRUNG (kèm mã bản có sẵn, kể cả dòng trước trong file), LOI (câu tiếng Việt). Xem trước chạy hết rồi hoàn tác nên khớp nhập thật, mã không nhảy số. Nhập thật: một giao dịch, bỏ dòng lỗi và trùng, ghi nhật ký. Tối đa `lead_import_max_rows` hàng, quá thì chặn cả lô | Lead · Tạo ở cơ sở nhập (CSKH nhập được) |
| `app.import_one_lead` | Nội bộ: ghép hàng với giá trị mặc định rồi gọi `create_lead` | |
| `app.lead_import_log` | Một dòng mỗi lần nhập thật: người nhập, cơ sở, tên file, số liệu | Người nhập, Admin đọc |

Cột của hàng: `parent_name`, `parent_phone`, `student_name`, `student_birth_year`, `source_type_code`, `source_code`, `channel_code`, `need` (ô "ghi chú" của file), `owner_email` (chỉ có tác dụng khi người nhập có Giao việc, cùng cơ sở). Mặc định chọn một lần: nguồn, kênh, chiến dịch, cơ sở, người phụ trách. Hàng có nguồn riêng thì không thừa kế kênh mặc định.

### Hiệu năng
Số đo trên `seed-lon` nằm trong mô tả PR P3b3b.

## P3c-1a: dữ liệu màn Lead danh sách và Kanban (migration `20261019000033`)
Kiểm thử: `supabase/tests/database/025_lead_danh_sach.test.sql` (49 bài). Luật: R-CRM-07 (lọc nhanh), R-CRM-09 (C4D chỉ hệ thống gắn), R-CRM-22 (bản "Đã gộp"), R-CRM-29 (xuất file). Màn: TS-01, TS-01b, TS-05 (dựng ở P3c-1b). Tham số mới: `export_max_rows` (5.000 dòng, 1 đến 20.000).

| Hàm | Làm gì | Quyền |
|---|---|---|
| `app.list_leads(bộ lọc, sắp xếp, limit, offset)` | Thêm bộ lọc `channel`, `campaign_id`, `next_from`, `next_to`, `next_before` (quá hạn), `no_appointment`, `only_merged`; thêm cột `supporter_name`, `campaign_name`, `assigned_at`, `student_birth_year` | Lead · Xem |
| `app.lead_board(bộ lọc, số thẻ/cột)` | Bốn cột C1 đến C4: tổng cột, N thẻ mới nhất, số đếm thanh màu (còn xa, hôm nay, quá hạn, chưa có lịch) tính trên CẢ cột, "hôm nay" theo giờ Việt Nam | Lead · Xem |
| `app.lead_group_counts(bộ lọc, trường nhóm[])` | Đếm cho Group By một đến hai cấp (giai đoạn, nhóm con, loại nguồn, nguồn, người phụ trách, cơ sở); chỗ rỗng là "Chưa có"; lỗi `HMT_NHOM_SAI` | Lead · Xem |
| `app.list_assignable_staff(loại bản ghi, cơ sở)` | Nhân sự đang hoạt động có vai trò ở cổng CRM, đúng cơ sở, cho hộp Giao (LEAD, OPPORTUNITY, STUDENT_TEST, APPOINTMENT) | Quyền Giao việc của loại đó |
| `app.export_leads(bộ lọc)` | Kiểm quyền, ghi nhật ký xuất, lấy tối đa `export_max_rows` dòng (có tên danh mục) trong một giao dịch; quá thì `truncated` | Lead · Xuất |

### P3d-1: dữ liệu màn Cơ hội (migration `20261019000038`)

| Hàm | Việc | Quyền |
|---|---|---|
| `app.get_opportunity(id)` | Một lần gọi cho trang bản ghi (TS-08): cột cơ hội, phụ huynh (mã, tên, SĐT, tỉnh, phường, địa chỉ), tên người phụ trách, hỗ trợ, tạo, sửa, cơ sở, chiến dịch, lead gốc, bản giữ lại; số đếm cho sáu nút liên kết; trạng thái phiếu test (cho hộp chặn R-CRM-12, 14); danh sách phiếu kiểm tra (tab "Kiểm tra đầu vào", chỉ khi người gọi có Phiếu kiểm tra · Xem) | Cơ hội · Xem ở cơ sở của cơ hội |
| `app.list_opportunities(...)`, `app.opportunity_board(...)` (thay thân) | Thêm bộ lọc nguồn, loại nguồn, kênh, chiến dịch, lịch hẹn (`appointment[]`: Quá hạn, Hôm nay, Sắp tới, Chưa có), `mine_roles[]`, `only_merged`; cột nguồn, chiến dịch, người hỗ trợ; Kanban có thanh màu tính cả cột (`bar`), thẻ có SĐT và nguồn | Cơ hội · Xem |
| `app.opportunity_group_counts(bộ lọc, trường nhóm[])` | Đếm cho Group By một đến hai cấp (giai đoạn, nhóm con, loại nguồn, nguồn, người phụ trách, cơ sở) | Cơ hội · Xem |
| `app.export_opportunities(bộ lọc)` | Kiểm quyền, ghi nhật ký xuất, tối đa `export_max_rows` dòng có tên danh mục trong một giao dịch | Cơ hội · Xuất (Trưởng cơ sở trong cơ sở mình, Admin) |

Cùng khuôn bộ lọc với Lead (R-CRM-07: cùng nhóm HOẶC, khác nhóm VÀ). Không bảng mới, không chỉ mục mới. Kiểm thử: `supabase/tests/database/030_co_hoi_ban_ghi.test.sql`. Đo trên `seed-lon` (50.000 lead, 20.000 cơ hội; Trưởng cơ sở CS1 chỉ thấy một nửa vì lọc theo cơ sở), Trưởng cơ sở CS1: danh sách 12 đến 38 ms, lọc lịch hẹn và nguồn 14 ms, Kanban 15 ms, Group By hai cấp 11 ms, `get_opportunity` 15 ms.

### P3e-1: dữ liệu màn Phiếu kiểm tra (migration `20261023000039`)

| Hàm | Việc | Quyền |
|---|---|---|
| `app.get_student_test(id)` | Một lần gọi cho trang phiếu (TS-17): cột phiếu, tên danh mục (trạng thái, môn, khối, hình thức, cấp độ, trình độ và phân loại đề xuất, lý do huỷ), cơ sở của cơ hội và cơ sở test, phòng (tên, sức chứa), giáo viên chấm, người phụ trách, người tạo, người nhập kết quả (cờ "nhập thay"), học sinh, phụ huynh, cơ hội, lead gốc, số lịch hẹn | Kiểm tra đầu vào · Xem theo phạm vi của phiếu (toàn hệ thống, cơ sở, được phân công) |
| `app.list_student_tests(...)`, `app.student_test_board(...)` (thay thân) | Thêm lọc môn, hình thức, cấp độ; `mine_roles[]` (tôi phụ trách, tôi tạo, tôi chấm: HOẶC); `when[]` (quá hạn là phiếu Nháp quá giờ test, hôm nay, sắp tới: HOẶC, mốc theo giờ Việt Nam); cột người tạo; Kanban có `bar` (sắp tới, hôm nay, quá giờ) tính trên cả cột | Kiểm tra đầu vào · Xem |
| `app.student_test_group_counts(bộ lọc, trường nhóm[])` | Đếm cho Group By một đến hai cấp (trạng thái, môn, hình thức, cấp độ, người phụ trách, giáo viên chấm, cơ sở test) | Kiểm tra đầu vào · Xem |
| `app.export_student_tests(bộ lọc)` | Kiểm quyền, ghi nhật ký xuất, tối đa `export_max_rows` dòng có tên danh mục trong một giao dịch | Kiểm tra đầu vào · Xuất (Trưởng cơ sở trong cơ sở mình, Admin) |
| `app.list_test_graders(cơ sở)`, `app.list_test_rooms(cơ sở)` | Giáo viên đang hoạt động của cơ sở, phòng đang dùng (kèm sức chứa) để chọn trong hộp tạo, sửa phiếu | Kiểm tra đầu vào · Tạo hoặc Sửa |

Không bảng mới, không chỉ mục mới. Kiểm thử: `supabase/tests/database/031_phieu_kiem_tra_ban_ghi.test.sql`. Đo trên `seed-lon` (15.000 phiếu; Trưởng cơ sở CS1 thấy 10.000), danh sách 8 đến 35 ms (lần đầu), tìm `q` 11 ms, Kanban 3 đến 30 ms, Group By hai cấp 12 ms, `get_student_test` 7 ms.

Bốn hàm danh sách dùng chung một khuôn bộ lọc; bài kiểm đối chiếu tổng giữa `list_leads`, `lead_board`, `lead_group_counts`. Bài kiểm `change_lead_stage`: kéo sang C4 không tự gắn C4D, người dùng không gắn được C4D, lead rời rồi về C4 không lấy lại C4D.

### Hiệu năng
Đo trên `seed-lon` (50.000 lead), tài khoản Admin (phạm vi rộng nhất): `list_leads` 22 đến 31 ms, `lead_board` 36 đến 40 ms, `lead_group_counts` 24 đến 29 ms, `list_assignable_staff` 2 ms, `export_leads` 5.000 dòng 376 ms. Không thêm chỉ mục mới (dùng chỉ mục sẵn có của lead).

## P3c-1b: lọc nhiều lựa chọn cùng nhóm (migration `20261019000034`)
Kiểm thử: thêm vào `supabase/tests/database/025_lead_danh_sach.test.sql` (15 bài). Luật: R-CRM-07 (cùng nhóm HOẶC, khác nhóm VÀ). Thay thân bốn hàm P3c-1a (`list_leads`, `lead_board`, `lead_group_counts`, `export_leads`), thêm hai bộ lọc dạng danh sách:

| Khoá lọc | Giá trị | Nghĩa |
|---|---|---|
| `appointment[]` | `OVERDUE`, `TODAY`, `UPCOMING`, `NONE` | Lịch hẹn kế tiếp: trước đầu ngày hôm nay, hôm nay, từ ngày mai, chưa có. Chọn nhiều thì HOẶC. Mốc ngày tính trong DB theo giờ Việt Nam |
| `mine_roles[]` | `OWNER`, `SUPPORT` | Tôi phụ trách, tôi hỗ trợ. Chọn nhiều thì HOẶC |

Các bộ lọc cũ (`next_from`, `next_to`, `next_before`, `no_appointment`, `mine`, `supporter_mine`) vẫn dùng được. Ở `lead_board`, `appointment` lọc tổng và thẻ của cột như `next_*`, không đổi số đếm thanh màu.

### Hiệu năng
Đo trên `seed-lon` (50.000 lead), Admin: `list_leads` với `appointment` hai mốc 81 ms (lần đầu), `appointment` + `mine_roles` 2 ms, `lead_board` 32 ms, `lead_group_counts` hai cấp 31 ms, dòng của một nhóm lá 13 ms. Không thêm chỉ mục.

## P3c-2a: `get_lead` và dời lịch hẹn (migration `20261019000035`)
Kiểm thử: `supabase/tests/database/026_lead_ban_ghi.test.sql` (42 bài). Luật: R-CRM-04, R-CRM-22 (bản "Đã gộp" chỉ đọc), R-CRM-38 (dời lịch hẹn, vào luật 19/10). Màn dùng hai hàm này (trang Lead TS-02, hộp Dời lịch hẹn TS-13) làm ở PR giao diện P3c-2.

| Hàm | Làm gì | Quyền |
|---|---|---|
| `app.get_lead(id)` | Một lần gọi đủ cho trang bản ghi: các cột của lead (trừ cột tìm kiếm), tên người phụ trách, hỗ trợ, tạo, sửa, cơ sở, chiến dịch, mã bản giữ lại (bản "Đã gộp"), số lịch hẹn (tổng, chưa làm), số cơ hội đang dùng | Lead · Xem ở cơ sở của lead |
| `app.reschedule_appointment(id, giờ mới, người phụ trách mới, ghi chú)` | Thay hàm hai tham số: dời lịch Chưa làm; đổi người phụ trách khi dời cần quyền Lịch hẹn · Giao việc (người mới đúng cơ sở); ghi nhật ký của lịch hẹn (giờ, người phụ trách) và **một ghi chú trên hồ sơ gắn** (lead, cơ hội hoặc phiếu) nêu giờ cũ, giờ mới, người phụ trách mới, ghi chú | Lịch hẹn · Sửa; đổi người: thêm Giao việc |

**Ghi chú khi dời lưu ở đâu:** trong ghi chú của hồ sơ gắn (cột "Ghi chú và hoạt động"), cùng dòng "Dời lịch hẹn "…" từ … sang …"; không ghi đè cột `note` của lịch hẹn. Lỗi: `HMT_LICH_HEN_TRANG_THAI_SAI` (không còn Chưa làm), `HMT_KHONG_CO_QUYEN` (đổi người phụ trách thiếu Giao việc), `HMT_NGUOI_PHU_TRACH_SAI` (người mới khác cơ sở), `HMT_THIEU_THONG_TIN` (thiếu giờ mới).

### Hiệu năng
Đo trên `seed-lon` (50.000 lead, 120.000 lịch hẹn), Trưởng cơ sở CS5: `get_lead` 3 ms (lead có nhiều lịch hẹn nhất); 10 lead liên tiếp 21 ms. Dùng chỉ mục sẵn có (`appointment_lead_idx`, `opportunity_lead_idx`), không thêm chỉ mục.

## P3c-2b: giao diện trang Lead (không migration mới)
Kiểm thử: `supabase/tests/database/027_lead_giai_doan_khoi_dau.test.sql` (9 bài, R-CRM-39). Màn: TS-02 `/crm/lead/:id`, TS-03 `/crm/lead/moi`, TS-14 (hộp trùng SĐT), TS-13 (hộp Tạo, Dời lịch hẹn), Huỷ lịch hẹn chọn lý do. Dùng `get_lead`, `create_lead`, `update_lead`, `change_lead_stage`, `find_duplicate_contacts`, các hàm lịch hẹn, `record_notes`, `record_history`. `create_lead` luôn đặt lead mới ở C1, bỏ qua giai đoạn người gọi truyền vào (R-CRM-39).

### P3f-1: dữ liệu hộp Gộp trùng TS-10 (migration `20261023000040`)

| Hàm | Việc | Quyền |
|---|---|---|
| `app.merge_candidates(loại, id)` | Gợi ý "bản kia" cho lead (cùng SĐT chuẩn hoá) hoặc cơ hội (cùng phụ huynh): mã, nhãn, cơ sở, giai đoạn, `can_merge` kèm mã và câu tiếng Việt khi không gộp được; tối đa `merge_preview_max_items` dòng, mới nhất trước. **Chỉ trả bản trong phạm vi xem của người gọi** (như RLS): người không phải Admin không thấy bản ở cơ sở khác; hồ sơ gốc ngoài phạm vi trả `HMT_KHONG_TIM_THAY`. `HMT_GOP_KHAC_CO_SO` chỉ gặp ở người xem được nhiều cơ sở mà không phải Admin. Báo giá, đơn của bản bị gộp phụ thuộc chiều gộp nên để `merge_preview` báo | Lead, Cơ hội · Duyệt (R-CRM-22) |
| `app.merge_preview(...)` (thay thân) | Thêm `sides` (so sánh hai bên: mã, phụ huynh, SĐT, học sinh, nguồn hoặc giai đoạn, người phụ trách, cơ sở, ngày tạo, số lịch hẹn, ghi chú, cơ hội hoặc phiếu) và `items` (lịch hẹn: tiêu đề, giờ, trạng thái; ghi chú: người viết, giờ, 200 ký tự đầu) của bản bị gộp, chỉ cho lead và cơ hội; số thật vẫn ở `move` | như gộp thật |

Hàm nội bộ: `app.merge_side`, `app.merge_items` (không cấp cho giao diện). Tham số mới `merge_preview_max_items` (INT, mục, 5 đến 100, mặc định 20). Không bảng mới, không chỉ mục mới (dùng `lead_phone_idx`, `opportunity_parent_idx`, `appointment_lead_idx`, `note_entity_idx`). Luật gộp (`merge_leads`, `merge_opportunities`) giữ nguyên. Gộp Phụ huynh, Học sinh và điều kiện lớp trùng giờ ở phân hệ Khách hàng, Ghi danh (QĐ-P3f-1); KD6 (học sinh trùng tên, năm sinh dưới một phụ huynh) giữ nguyên hành vi (QĐ-P3f-2). Mã lỗi dùng lại mã đã có. Kiểm thử: `supabase/tests/database/032_gop_trung_goi_y.test.sql`.

### P3f-2: giao diện Gộp trùng và Nhập file (không đổi DB)
Hộp TS-10 gọi `merge_candidates`, `merge_preview`, `merge_leads`, `merge_opportunities`; hộp TS-04 gọi `import_leads` (xem trước `p_commit = false`, nhập `p_commit = true`). Luật và quyền do hàm kiểm; giao diện chỉ hiện kết quả và lỗi. CSV đọc ở trình duyệt (UTF-8 có hoặc không BOM; dấu "," hoặc ";"); nguồn, kênh trong file là tên hoặc mã, đổi sang mã theo danh mục, không khớp thì gửi nguyên chữ để hàm báo lỗi. Giá trị mặc định (nguồn, kênh, chiến dịch; cơ sở, người phụ trách khi có quyền Giao việc) chọn ở bước ghép cột.

### Lịch hẹn bổ sung-1: Xuất, Group By, giao hàng loạt (migration `20261024000041`)

| Hàm | Việc | Quyền |
|---|---|---|
| `app.export_appointments(bộ lọc)` | Xuất danh sách lịch hẹn: loại và mã hồ sơ gắn, hoạt động, tiêu đề, giờ hẹn, trạng thái, người phụ trách, cơ sở, đánh dấu lịch nhắc tự sinh, lý do huỷ. Tên danh mục (không phải mã). Tối đa `export_max_rows` dòng, báo `truncated` và tổng số thật. **Ghi nhật ký xuất** (`app.log_export`: ai, module `APPOINTMENT`, bộ lọc, số dòng) trong cùng giao dịch. `export_student_tests` cũng đã ghi nhật ký xuất như vậy (kiểm lại 24/10), nên không có việc sửa ở PR khác | Lịch hẹn · Xuất (Trưởng cơ sở trong cơ sở mình, Admin mọi cơ sở) |
| `app.appointment_group_counts(bộ lọc, trường[])` | Đếm cho Group By một đến hai cấp (Đ35): `status`, `activity`, `owner`, `branch`, `kind` (lead, cơ hội, phiếu). Nhãn tiếng Việt. Trường lạ, quá hai cấp, hai cấp trùng: `HMT_NHOM_SAI` | Lịch hẹn · Xem |
| `app.assign_appointments(ids[], người phụ trách)` | Giao nhiều lịch hẹn một lần (tối đa `list_page_size_max`), **giao phần hợp lệ** và trả `{requested, assigned, skipped, reasons: [{code, message, count, ids}]}`, không im lặng bỏ dòng. Chỉ giao lịch **Chưa làm** (Đ33, R-CRM-38; `HMT_LICH_HEN_TRANG_THAI_SAI`); **lịch nhắc tự sinh của phiếu không giao tay** (Đ36; `HMT_LICH_NHAC_THEO_PHIEU`); người nhận phải thuộc đúng cơ sở của lịch (`HMT_NGUOI_PHU_TRACH_SAI`); lịch đã do người đó phụ trách (`HMT_GIAO_CUNG_NGUOI`); lịch ngoài cơ sở của người gọi coi như không thấy (`HMT_KHONG_TIM_THAY`). **Chỉ đổi người phụ trách của lịch hẹn, KHÔNG đổi người phụ trách của lead, cơ hội, phiếu mà lịch gắn vào.** Mỗi lịch đã giao ghi một ghi chú hệ thống trên hồ sơ gắn; nhật ký thao tác tự ghi người cũ, người mới | Lịch hẹn · Giao việc (Trưởng cơ sở trong cơ sở mình, Admin) |
| `app.list_appointments` (thay thân) | Thêm bộ lọc `kind` (LEAD, OPPORTUNITY, STUDENT_TEST) để mở một nhóm của Group By | Lịch hẹn · Xem |

| `app.reschedule_appointment` (thay thân, Đ37) | Dời lịch hẹn như cũ (R-CRM-38: chỉ lịch Chưa làm; đổi người phụ trách cần Giao việc và người mới đúng cơ sở; ghi chú hệ thống trên hồ sơ gắn). **Thêm:** lịch nhắc tự sinh của phiếu kiểm tra **không đổi người phụ trách bằng tay**, kể cả Trưởng cơ sở và Admin: `HMT_LICH_NHAC_THEO_PHIEU` (đi theo người phụ trách phiếu). Chỉ chặn việc đổi người; dời giờ, đổi ghi chú vẫn được; truyền chính người phụ trách hiện tại không tính là đổi | Lịch hẹn · Sửa (+ Giao việc để đổi người) |

Hàm nội bộ `app.appointment_group_label`. Không bảng mới, không chỉ mục mới (bộ lọc dùng `appointment_branch_time_idx`, `appointment_owner_idx`, `appointment_status_time_idx`, các chỉ mục khoá ngoại). `app.assign_owner` giữ nguyên (lead, cơ hội), vì trả một số nguyên còn lô lịch hẹn cần trả lý do từng nhóm. Lịch "Theo người" (Đ34) không cần hàm mới. Kiểm thử: `supabase/tests/database/033_lich_hen_bo_sung.test.sql`.

### Lịch hẹn bổ sung-2: giao diện (không đổi DB)
Nút Xuất gọi `export_appointments` theo bộ lọc đang xem (CSV, cắt ở `export_max_rows`, báo khi bị cắt); Group By gọi `appointment_group_counts` rồi tải dòng từng nhóm bằng `list_appointments` kèm bộ lọc của nhóm; chọn hàng loạt chỉ hiện với người có quyền Giao việc, kết quả của `assign_appointments` hiện trong hộp nêu số giao được, số bị bỏ và lý do từng nhóm (lịch Hoàn thành, Huỷ; lịch nhắc tự sinh của phiếu; lịch đã do người đó phụ trách; lịch ngoài cơ sở). Lịch "Theo người" (Đ34, Đ38): trong chế độ Ngày, mỗi người có lịch hẹn trong ngày là một cột, xếp theo tên, trong phạm vi lịch mà người xem được xem theo ma trận quyền hiện có (Tuyển sinh, CSKH vẫn xem mọi lịch của cơ sở mình; không thu hẹp quyền); không có "Theo phòng".


## P5a-DB0: cấu hình bán hàng (migration `20261025000044`, QĐ-Đ100 đến Đ107, Đ117 đến Đ120)
Kiểm thử: `supabase/tests/database/036_p5a_cau_hinh.test.sql` (122 bài); sửa 3 file cũ (006, 013, 018) theo số liệu mới. Luật: R-TIEN-07, 10, 14, 15, 29, 30, 36. Cấu hình chỉ Admin ghi (Cấu hình bán hàng · Tạo / Sửa, toàn hệ thống); mọi vai bán hàng đọc (Cấu hình bán hàng · Xem); giáo viên, học sinh đọc 0 dòng.

| Đối tượng | Làm gì |
|---|---|
| `app.sales_package` | Gói bán (CH-01): mã `Loại-Môn-Khối` hoặc `Loại-Môn-KhốiđầuKhốicuối` (DV, TL: `Loại-TÊN`), không chứa hình thức, không số giờ, không loại lớp (R-TIEN-36); mã, loại, môn, khối không đổi; Ngừng bằng `is_active` |
| `app.package_price` | Bảng giá (CH-03): giá theo gói, hình thức (OFF, ONL), `effective_from`; giá `null` = ngừng bán hình thức từ ngày đó; chỉ thêm, không sửa, không xoá; DV, TL không có giá online |
| `app.package_price_at(gói, hình thức, ngày)` | Giá hiệu lực tại một ngày (null nếu chưa có hoặc đã ngừng bán) |
| `app.discount_policy` | Chiết khấu (CH-04): PERCENT hoặc GIFT_HOURS, `max_value`, `fixed_value` (bật: áp đúng mức; tắt: nhân viên điền từ 0 đến mức; tặng giờ luôn loại điền), `requires_approval` (dùng chung ô tích với vượt trần, Đ102), hiệu lực, loại gói, cơ sở |
| `app.gift_policy` | Quà tặng (R-TIEN-30): gói quà phải là DV hoặc TL, số lượng tối đa, cần duyệt, hiệu lực |
| `app.payment_term`, `app.payment_term_installment` | Điều khoản thanh toán (CH-09): mẫu chia đợt theo `(code, version)`; đợt 1 có thể là số tiền cố định (cọc), các đợt sau chia % của phần còn lại, tổng 100%; số ngày đến hạn tính từ ngày duyệt đơn; không sửa, chỉ tạo bản mới |
| `app.payment_term_amounts(điều khoản, tổng đơn)` | Chia tiền từng đợt: cọc A < tổng; phần còn lại chia % (làm tròn xuống), đợt cuối nhận phần dư |
| `app.package_unit(loại gói)` | Đơn vị: DV tháng, TL bộ, còn lại giờ (Đ101); dòng báo giá, đơn (DB1) chụp lại `quantity` và đơn vị |
| `app.save_sales_package`, `add_package_price`, `save_discount_policy`, `save_gift_policy`, `create_payment_term`, `set_config_active` | Hàm ghi của Admin (kiểm quyền bên trong, mã lỗi tiếng Việt) |
| Danh mục | `PACKAGE_UNIT` (Giờ, Tháng, Bộ); `ORDER_CANCEL_REASON` sáu lý do (Đ104); `applies_to` của lý do từ chối (Đ103) |
| Tham số | `debt_due_soon_days` (1 đến 30, mặc định 3, không ghi đè theo cơ sở; Đ107) |
| Ma trận quyền | Phiên bản mới (Đ105): Sale, CSKH bỏ Xuất báo giá; Kế toán thêm Xem và Xuất báo giá (toàn hệ thống). Xuất đơn, phiếu thu giữ nguyên (Trưởng cơ sở cơ sở mình, Kế toán, Admin) |

### Hiệu năng
Đo trên `seed-lon` (355 gói, 2.120 dòng giá): tra giá hiệu lực một gói Index Scan Backward trên chỉ mục duy nhất `(gói, hình thức, ngày)` 0,09 ms; danh sách gói đang bán theo loại 0,65 ms; chính sách đang hiệu lực 0,06 ms; chia tiền một điều khoản 1,4 ms.

## Danh sách em của lead và cơ hội, DB-1 (migration `20261025000043`, QĐ-Đ75, Đ81, Đ86, Đ88)
Kiểm thử: `supabase/tests/database/035_danh_sach_em_nen.test.sql` (69 bài) và 34 file cũ (1.861 bài). Giữ đúng hành vi cũ: mỗi hồ sơ vẫn một em (dòng 1). Luật mới (thêm, sửa, bỏ em, kiểm trùng, tối đa số em, gộp hợp danh sách, ít nhất một em đủ tên và năm sinh) làm ở PR DB-2.

| Đối tượng | Làm gì | Quyền |
|---|---|---|
| Bảng `app.prospect_student` | Một dòng một em, của lead HOẶC của cơ hội; `branch_id` chép từ hồ sơ cha (đổi theo khi cha đổi cơ sở); gắn hồ sơ học sinh (`student_id`) thì tên, năm sinh, trường, học lực, mục tiêu đọc thẳng từ hồ sơ, dòng không giữ bản sao | Đọc theo Lead · Xem / Cơ hội · Xem ở đúng cơ sở; ghi chỉ qua hàm |
| `app.prospect_student_v` | Dạng đã giải (đọc từ hồ sơ học sinh khi đã gắn) | Chỉ hàm nghiệp vụ |
| `app.lead_first(id)`, `app.opp_first(id)` | Em đầu của lead, cơ hội | Hàm nội bộ |
| `app.set_first_prospect(...)` | Ghi em đầu từ dữ liệu kiểu cũ (`student_name`, `student_birth_year`…): `create_lead`, `update_lead`, `create_opportunity`, `update_opportunity` gọi; R-CRM-26, 27 (em đã gắn hồ sơ thì sửa hồ sơ), R-CRM-03 (từ L5 không xoá tên, năm sinh) | Hàm nội bộ |
| Các hàm đọc cũ (`list_leads`, `list_opportunities`, hai bảng Kanban, hai hàm xuất, lịch hẹn, gợi ý và xem trước gộp…) | Vẫn trả `student_name`, `student_birth_year`… của em đầu; `get_lead`, `get_opportunity` thêm mảng `students` | Như cũ |
| `create_student_test` | Phiếu dùng em đầu; gắn hồ sơ học sinh vào dòng em; `student_test.prospect_student_id` | Như cũ |
| Tham số `prospect_max_students` | Số em tối đa (1 đến 20, mặc định 5; Đ88); kiểm ở DB-2 | Cài đặt |

Chuyển dữ liệu: mỗi lead, cơ hội có thông tin học sinh thành dòng 1; migration tự kiểm số dòng trước và sau, lệch thì huỷ. Các cột chữ cũ trên lead và cơ hội (và `opportunity.student_id`) đã bỏ; `lead.search_text` chuyển từ cột sinh sang trigger (như cơ hội), cả hai tính cả tên các em.

### Hiệu năng
Đo trên `seed-lon` (50.000 lead, 20.000 cơ hội, 65.000 dòng em của lead, 26.000 của cơ hội), Admin: `list_leads` tìm theo tên em (11.426 kết quả) 82 ms, một trang 28 ms; `list_opportunities` một trang 3 ms; sắp xếp theo tên em đầu (quét 20.000 cơ hội) 289 ms; `get_opportunity` 10 ms. Danh sách em của một cơ hội: Index Scan `prospect_student_opp_pos_uidx`, 0,02 ms. Chỉ mục mới và lý do ghi trong migration.

## Cơ hội hiện ghi chú của lead gốc (migration `20261026000047`, lỗi 26/10)
Kiểm thử: `supabase/tests/database/039_co_hoi_doc_ghi_chu_lead.test.sql` (12 bài); Vitest `entries`; Playwright `co-hoi.spec.ts`.

`app.record_notes(loại, id)` thêm cột `source_label`. Với cơ hội, hàm trả ghi chú của chính cơ hội cộng ghi chú của lead gốc (`opportunity.lead_id`), nhãn "Lead <mã lead>"; chỉ hiện ghi chú lead nếu người xem cũng thấy được lead (Lead · Xem ở cơ sở của lead). Ghi chú chỉ nằm một bản ở lead, không sao chép; ghi chú viết thêm ở lead sau khi tạo cơ hội cũng hiện ở cơ hội; ghi chú viết ở cơ hội không hiện ở lead; ghi chú đã huỷ không hiện. Dòng thời gian hiện nhãn "Từ Lead LD…" cạnh chữ "Ghi chú". Lịch sử đổi trường của lead và lịch hẹn của lead không hiện ở cơ hội.
## Lịch hẹn: Hoàn thành, Mở lại, Huỷ ghi dòng vào dòng thời gian (migration `20261026000046`, R-CRM-04)
Kiểm thử: `supabase/tests/database/038_lich_hen_ghi_chu_he_thong.test.sql` (25 bài); Playwright `lich-hen-dong-bo.spec.ts`. Trước đây chỉ Dời (R-CRM-38 c) ghi dòng lên hồ sơ gắn; Hoàn thành, Mở lại, Huỷ không ghi gì nên trang Cơ hội (hoặc Lead, Phiếu) không thấy việc đã làm.

| Hàm | Dòng ghi lên hồ sơ gắn (lead, cơ hội hoặc phiếu kiểm tra) |
|---|---|
| `app.complete_appointment(id)` | `Hoàn thành lịch hẹn "<tiêu đề>" (hẹn lúc dd/mm/yyyy hh:mm).` |
| `app.reopen_appointment(id)` | `Mở lại lịch hẹn "<tiêu đề>" (hẹn lúc …), trước đó đã hoàn thành` hoặc `đã huỷ` |
| `app.cancel_appointment(id, lý do, ghi chú)` | `Huỷ lịch hẹn "<tiêu đề>" (hẹn lúc …). Lý do: <tên lý do>. Ghi chú: <ghi chú>` |
| `app.add_appointment_note(lịch hẹn, chữ)` | Hàm nội bộ ghi dòng hệ thống lên hồ sơ gắn |

Không đổi giai đoạn, không tạo việc, không gửi thông báo (R-CRM-04 giữ nguyên). Lần thao tác bị từ chối không ghi dòng nào.

Giao diện: một hàm làm mới chung `useRefreshAppointmentData` (`appointmentApi.ts`) làm mới mọi dữ liệu liên quan lịch hẹn (màn Lịch hẹn, lead, cơ hội, phiếu, dòng thời gian). Màn Lịch hẹn và các trang bản ghi đều gọi hàm này sau khi ghi, nên hai chiều luôn đồng bộ (trước đây màn Lịch hẹn chỉ làm mới lead; trang Cơ hội không làm mới màn Lịch hẹn).
## P5a-DB1a: báo giá (migration `20261026000045`, QĐ-Đ83, Đ93, Đ101, Đ102, Đ105, Đ106, Đ169 đến Đ174)
Kiểm thử: `supabase/tests/database/037_p5a_bao_gia.test.sql` (161 bài); sửa bài 006 (25 danh mục hệ thống). Luật: R-CRM-19, 20, 22; R-TIEN-02, 05, 10, 13, 14, 15, 29, 30, 35, 36. Hàm trong schema `app` (đặc tả viết `crm.`). Công tắc BAN_HANG (Đ173) kiểm trong lưu, gửi, từ chối, huỷ qua `app.require_feature`; hàm đọc không chặn (Đ181); giao diện ẩn mục báo giá khi tắt.

| Đối tượng | Làm gì | Quyền |
|---|---|---|
| `app.quotation`, `quotation_line`, `quotation_line_discount` | Báo giá Nháp, Đã gửi, Từ chối, Huỷ (Đã chuyển đơn tính từ dòng, không lưu); mã `BG-CS1-AAMM-STT` cấp lúc Lưu; dòng chụp lại gói, đơn giá, số lượng, đơn vị, chiết khấu từng chính sách | Đọc theo Báo giá · Xem ở đúng cơ sở; ghi chỉ qua hàm |
| `app.price_line`, `price_apply_discounts` | Nơi duy nhất tính tiền báo giá và đơn: thành tiền = số lượng × đơn giá; chiết khấu % cộng dồn; giờ tặng quy ra % tính vào trần; tiền chiết khấu làm tròn xuống đồng (Đ172); một dòng tối đa một chính sách tặng giờ (Đ174); quà tặng giá 0, ngoài trần; cờ cần người duyệt tích chung (Đ102) | Hàm nội bộ |
| `app.save_quotation(id, cơ hội, dòng)` | Tạo hoặc sửa Nháp, tính lại theo bảng giá hiệu lực lúc lưu (Đ169); trả cảnh báo vượt trần, không chặn (D3) | Báo giá · Tạo / Sửa |
| `app.send_quotation(id)` | Nháp → Đã gửi: tính lại mọi dòng theo giá và chính sách ngày Gửi rồi đóng băng (Đ175), trả `{id, total_amount, previous_total, warnings}` (cảnh báo `HMT_TONG_TIEN_DOI` khi tổng đổi); cần dòng; mọi em đủ họ tên, năm sinh (Đ170); hạn = ngày gửi + `quotation_validity_days` | Báo giá · Sửa |
| `app.reject_quotation`, `app.cancel_quotation` | Từ chối (lý do áp dụng cho báo giá, "Khác" bắt ghi chú); Huỷ (Đ171). Chặn khi đã có đơn đang sống (DB1b) | Báo giá · Sửa |
| `app.get_quotation`, `list_quotations`, `export_quotations` | Bản ghi kèm dòng, chiết khấu, em; danh sách phân trang ở máy chủ, tìm theo mã, phụ huynh, SĐT, tên em (D17); xuất theo Đ105 (Trưởng cơ sở, Kế toán, Admin) | Báo giá · Xem / Xuất |
| `app.opportunity_sales_documents` | Mã báo giá còn hiệu lực của cơ hội (trừ Từ chối và Huỷ, Đ106); DB1b thêm mã đơn | Hàm nội bộ |

Làm tròn: Đ172, Đ176 đã vào docs/spec/04 (R-TIEN-37).

### Hiệu năng
Đo trên `seed-lon` (15.000 báo giá, 30.000 dòng), Admin: `list_quotations` một trang 36 ms, trạng thái Đã gửi 17 ms, tìm tên em 14 ms, lọc theo cơ hội 2,5 ms; `get_quotation` 4 ms; `export_quotations` 5.000 dòng 215 ms. Danh sách mặc định dùng chỉ mục `quotation_branch_created_idx` (Index Only Scan, 0,29 ms).

## P5a-DB1b-1: đơn hàng, bảng và hàm ghi (migration `20261027000051`, QĐ-Đ201 đến Đ205, Đ187)
Kiểm thử: `supabase/tests/database/043_p5a_don_hang.test.sql` (148 bài); sửa bài 006 (26 danh mục hệ thống). Luật: R-TIEN-01, 02, 03, 06, 07, 14, 35, 37, 38; R-GD-06, R-GD-08; R-CRM-16, 27; R-HT-01, 06. Hàm đọc, xuất đơn để DB1b-2.

| Hàm / bảng | Làm gì | Quyền |
|---|---|---|
| `app.sales_order`, `sales_order_line`, `sales_order_line_discount`, `sales_order_installment`, `sales_order_event` | Đơn (Nháp, Đã trình, Đã duyệt, Huỷ), dòng chụp lại giá, chiết khấu, lịch đóng tiền từng đợt, lịch sử (tạo, trình, duyệt, từ chối, huỷ). Đúng một gốc: cơ hội hoặc phiếu tái tục (`renewal_ticket_id` chưa có khoá ngoại, chờ P5b). Cờ `is_live` trên dòng đơn + chỉ mục duy nhất từng phần: một dòng báo giá không nằm trong hai đơn sống | RLS theo Đơn hàng · Xem |
| `app.create_order_from_quotation(báo giá, số dòng)` | Chỉ báo giá Đã gửi; cơ hội phải L8 (R-CRM-16); dòng sao nguyên giá đã đóng băng lúc Gửi, kể cả quá hạn (R-TIEN-14) | Đơn hàng · Tạo |
| `app.create_order_from_opportunity(cơ hội, dòng)` | Đơn thẳng, cơ hội phải L8; tính theo giá ngày tạo đơn bằng `price_line` | Đơn hàng · Tạo |
| `app.save_order(id, dòng, điều khoản)` | Sửa Nháp: điều khoản, lớp, ngày vào lớp (đơn từ báo giá); dòng và giờ (đơn thẳng); lịch đóng tiền tính lại | Đơn hàng · Sửa |
| `app.submit_order(id)` | Em đủ họ tên, năm sinh (R-TIEN-35); điều khoản; chốt người duyệt theo NGƯỜI LẬP (R-HT-06); chặn khi người duyệt không có quyền Duyệt (Đ205) | Đơn hàng · Sửa |
| `app.approve_order(id, đồng ý)` | Cần có quyền Duyệt VÀ đúng người đã chốt hoặc Admin thay (aal2); tích đồng ý khi vượt trần (Đ102); tìm hoặc tạo hồ sơ học sinh (R-CRM-27); hai em trùng tên và năm sinh thì chặn (KD6); chốt hạn đóng từng đợt; khoá đơn (R-TIEN-03) | Đơn hàng · Duyệt |
| `app.reject_order(id, lý do, ghi chú)` | Đã trình → Nháp, lý do dành cho đơn, "Khác" bắt ghi chú; lịch sử giữ lần từ chối (R-TIEN-06) | Đơn hàng · Duyệt |
| `app.cancel_order(id, lý do, ghi chú)` | R-TIEN-38, Đ202, Đ204: đơn Nháp chỉ người lập huỷ; đơn Đã trình, Đã duyệt do người duyệt đã chốt (Admin thay); chỉ khi chưa có phiếu thu; trả dòng về báo giá | Đơn hàng · Huỷ |
| `app.check_order_line_class` | Kiểm lớp (R-GD-08): bảng lớp thuộc P5b chưa có nên lớp có giá trị thì báo `HMT_LOP_CHUA_CO_BANG`; P5b thay thân hàm | Hàm nội bộ |
| `app.order_has_receipt` | Đơn đã có phiếu thu chưa: trả false cho tới DB2 | Hàm nội bộ |
| `app.quotation_has_live_order`, `quotation_converted`, `opportunity_sales_documents` | Thay hàm trống của DB1a: báo giá có đơn sống, "Đã chuyển đơn" khi mọi dòng nằm trong đơn sống; giấy tờ của cơ hội thêm mã đơn chưa huỷ (Đ106) | Hàm nội bộ |

Mã lỗi có mã `HMT_…` kèm câu tiếng Việt: `HMT_CHUA_O_L8`, `HMT_BAO_GIA_CHUA_GUI`, `HMT_DONG_DA_CO_DON`, `HMT_KHONG_CO_DONG_DE_CHUYEN`, `HMT_THIEU_DIEU_KHOAN`, `HMT_EM_THIEU_THONG_TIN`, `HMT_KHONG_CO_QUAN_LY`, `HMT_NGUOI_DUYET_THIEU_QUYEN`, `HMT_KHONG_PHAI_NGUOI_DUYET`, `HMT_CAN_TICH_DONG_Y`, `HMT_EM_TRUNG_TEN_NAM_SINH`, `HMT_KHONG_DUOC_HUY_DON`, `HMT_DON_DA_CO_PHIEU_THU`, `HMT_DON_DA_KHOA`, `HMT_LOP_CHUA_CO_BANG`.

### Hiệu năng
Đo trên `seed-lon` thêm 8.000 đơn: danh sách trang 1 theo cơ sở 4,6 ms (chỉ mục `sales_order_branch_created_idx`), lọc Đã duyệt 1,8 ms, tìm theo mã 1,7 ms, đơn của một cơ hội 4,1 ms, dòng của một đơn 2,5 ms. Tìm theo chữ quét tuần tự 12 ms ở 8.000 đơn (bảng nhỏ); khi ép dùng chỉ mục trigram thì 1 ms.
