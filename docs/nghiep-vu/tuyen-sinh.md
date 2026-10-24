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

