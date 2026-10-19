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
| `app.change_lead_stage(id, giai đoạn, nhóm con)` | Đổi giai đoạn lead tự do hai chiều; C4D chỉ hệ thống | Lead · Sửa | R-CRM-09 |
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
| `app.create_opportunity(lead, dữ liệu, xác nhận)` | Lead đã có cơ hội thì chặn kèm mã (`HMT_LEAD_DA_CO_CO_HOI`), xác nhận lần hai mới tạo thêm; không chặn theo C4C. Tìm hoặc tạo phụ huynh, cấp mã CO, giai đoạn đầu L1, đưa lead về C4D | Cơ hội · Tạo, Lead · Xem (cơ sở); giao người khác cần Giao việc | R-CRM-01, 09, 19, 27 |
| `app.update_opportunity(id, dữ liệu)` | Sửa nhu cầu, học sinh, người hỗ trợ. Đã có hồ sơ học sinh thì sửa luôn hồ sơ đó (cần Học sinh · Sửa ở cơ sở của hồ sơ) | Cơ hội · Sửa | R-CRM-03, 26, 27 |
| `app.change_opportunity_stage(id, giai đoạn, nhóm con, lý do bỏ qua, ghi chú, xác nhận L8)` | Chỉ đi tới; từ L5 bắt học sinh; người dùng không bấm L6; vào L5 hệ thống gắn nhóm con; sang L7, L8: chặn phiếu dang dở, không có phiếu hoàn thành bắt lý do bỏ qua test; L8 bắt L8A, B, C và xác nhận. Cùng giai đoạn (R-CRM-35): đổi nhóm con được, cả lùi, trừ rời L8C, đổi tay nhóm con L5, chọn lại L6A; ở L6 người dùng chọn L6B…L6F (R-CRM-34) | Cơ hội · Sửa | R-CRM-02, 03, 12, 13, 14, 15, 16, 17 |
| `app.assign_owner('OPPORTUNITY', ids, người)` | Mở rộng hàm có sẵn cho cơ hội | Cơ hội · Giao việc | TS-05 |
| `app.create_appointment(lead, …, cơ hội)` | Thêm tham số cuối `p_opportunity_id`; đúng một trong lead, cơ hội | Lịch hẹn · Tạo | R-CRM-04 |
| `app.list_opportunities(...)`, `app.opportunity_board(bộ lọc, số thẻ)` | Danh sách phân trang; Kanban L1–L8 một lần gọi (tổng mỗi cột + N thẻ mới nhất, N theo tham số `kanban_cards_per_column`) | Cơ hội · Xem | CLAUDE.md Hiệu năng |
| `app.list_appointments(...)` | Thêm bộ lọc `opportunity_id`; cột `opportunity_id`, `record_code`, `record_label` | Lịch hẹn · Xem | |
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

Bốn hàm danh sách dùng chung một khuôn bộ lọc; bài kiểm đối chiếu tổng giữa `list_leads`, `lead_board`, `lead_group_counts`. Bài kiểm `change_lead_stage`: kéo sang C4 không tự gắn C4D, người dùng không gắn được C4D, lead rời rồi về C4 không lấy lại C4D.

### Hiệu năng
Đo trên `seed-lon` (50.000 lead), tài khoản Admin (phạm vi rộng nhất): `list_leads` 22 đến 31 ms, `lead_board` 36 đến 40 ms, `lead_group_counts` 24 đến 29 ms, `list_assignable_staff` 2 ms, `export_leads` 5.000 dòng 376 ms. Không thêm chỉ mục mới (dùng chỉ mục sẵn có của lead).
