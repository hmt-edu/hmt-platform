# Nền dữ liệu (GĐ0 bước 2): bảng, luật, hàm

Spec: `docs/spec/02-chuan-ma-va-danh-muc.md`, `docs/spec/03-dac-ta-giai-doan-0.md` (Nền dữ liệu, Cấu hình trên giao diện).
Kiểm thử: `supabase/tests/database/002…006`. Lỗi nghiệp vụ: câu tiếng Việt ở MESSAGE, mã `HMT_*` ở HINT.

## Quyền ghi ở bước 2
Mọi hàm sửa cấu hình (danh mục, Cài đặt, công tắc, ghi chú) gọi `app.assert_config_writer()`:
lời gọi qua API (có JWT) bị chặn `HMT_KHONG_CO_QUYEN`; chỉ kết nối thẳng vào DB (migration, SQL Editor của chủ project)
được ghi. Bước 3 thay bằng ma trận quyền. Người đã đăng nhập đọc được danh mục, Cài đặt, công tắc; chưa đọc được
nhật ký, ghi chú.

## Khung chung cho bảng nghiệp vụ
Bảng nghiệp vụ có `id uuid`, `created_at/by`, `updated_at/by` (tự điền, không sửa created_*), `legacy_ref` nếu nhận dữ liệu từ Sheet.
Gắn bằng `select app.apply_standard('app.ten_bang');` trong migration: tự điền, ghi nhật ký, chặn xoá, chỉ mục `legacy_ref`.
Huỷ thay cho xoá: bảng nghiệp vụ dùng trạng thái + `cancelled_at/by`, `cancel_reason`; danh mục dùng `is_active` (Ngừng).

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.apply_standard(bảng)` | Gắn khung chung cho bảng | Migration |
| `app.raise_error(mã, câu)` | Báo lỗi nghiệp vụ có mã | Mọi hàm |
| `app.current_actor()` | Id người đang thao tác (NULL = hệ thống) | Trigger |
| `app.assert_config_writer()` | Chặn sửa cấu hình qua API (bước 2) | Hàm sửa cấu hình |

## Nhật ký thao tác `app.audit_log`
- Tạo (`I`): chỉ ghi ai, lúc nào. Sửa (`U`): chỉ trường đổi `{"cột": [cũ, mới]}`, bỏ qua `created_*`, `updated_*`; sửa không đổi gì thì không ghi.
  Xoá (`D`, chỉ Admin xoá bản ghi nhập nhầm từ bước 3): chép cả dòng.
- Không ai sửa, xoá, truncate được (trigger + thu quyền + RLS không policy). Giới hạn: chủ DB về lý thuyết tắt được trigger;
  mọi đổi cấu trúc phải qua migration nên vẫn để lại vết.
- Ước tính quy mô HMT (1.300 HS, 166 lớp): ~480.000 dòng/năm ≈ 60–100 MB/năm kể cả chỉ mục. Năm 3–4 cần đưa nhật ký cũ
  hơn 18 tháng sang Drive (mã hoá) rồi dọn; anh Trường chốt khi tới ngưỡng (báo cáo tuần theo dõi).

## Danh mục
- `app.catalog`: định nghĩa danh mục, `kind` = `HE_THONG` | `MO`, tầng cha (`parent_catalog`), danh mục nối (`linked_catalog`).
- `app.catalog_item`: `code` (không đổi), `name`, `sort_order`, `is_active`, `is_locked`, `parent_id`, `linked_item_id`, `legacy_ref`.
- Bảng riêng: `app.branch` (cơ sở), `app.academic_year` (năm học), `app.room` (phòng theo cơ sở), `app.holiday` (ngày nghỉ, `branch_id` NULL = mọi cơ sở).

**Luật (chặn trong DB):**
- Mã không đổi được (`HMT_MA_KHONG_DOI_DUOC`), không xoá được (`HMT_KHONG_XOA`).
- Danh mục hệ thống: chỉ đổi tên, thứ tự; thêm mục, Ngừng, đổi cha/nối bị chặn (`HMT_DANH_MUC_HE_THONG`), trừ migration.
- Mục `is_locked` (luật code bám vào): không Ngừng được (`HMT_MUC_BI_KHOA`).
- Danh mục nhiều tầng: mục cha phải thuộc danh mục cha (`HMT_MUC_CHA_SAI`); mục nối đúng danh mục nối (`HMT_MUC_NOI_SAI`).
- Phòng không chuyển cơ sở; mã phòng không trùng trong một cơ sở.

**Danh mục hệ thống (9):** STUDENT_STATUS, ENROLLMENT_STATUS, ATTENDANCE_STATUS, SESSION_TYPE, CLASS_TYPE, STUDY_MODE, TEST_STATUS, DOC_TYPE, MODULE.
**Danh mục mở:** SUBJECT, GRADE, LEVEL, FRAMEWORK_LEVEL, SOURCE_TYPE → SOURCE → SOURCE_CHANNEL, LEAD_STAGE → LEAD_SUBSTAGE,
OPP_STAGE → OPP_SUBSTAGE, TEST_CANCEL_REASON (nối OPP_SUBSTAGE), ACTIVITY_TYPE, PROVINCE → WARD; cùng cơ sở, năm học, phòng học.
Dữ liệu và chỗ đã làm sạch: `docs/nghiep-vu/lam-sach-du-lieu-cu.md`.

**Loại buổi (luật lõi):** `CHINH`, `CUNG_CO` trừ giờ; `HOC_BU`, `BO_TRO` không trừ giờ. Huỷ (nghỉ cả lớp, `N` cũ) là tình trạng buổi,
không phải loại buổi. Học thử là tư cách học sinh trong buổi (GĐ2). Kiểm tra đầu vào là lịch test, không phải buổi.

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.catalog_add_item(danh mục, mã, tên, [thứ tự], [cha], [nối])` | Thêm mục vào danh mục mở | Admin (bước 3) |
| `app.catalog_rename_item(id, tên)` | Đổi tên hiển thị | Admin |
| `app.catalog_reorder_item(id, thứ tự)` | Đổi thứ tự | Admin |
| `app.catalog_set_item_active(id, đang dùng?)` | Ngừng / dùng lại (danh mục mở) | Admin |
| `app.catalog_item_id(danh mục, mã)` | Lấy id mục theo mã, lỗi nếu không có | Hàm nghiệp vụ |
| `app.assert_catalog_code_active(danh mục, mã)` | Lỗi nếu mã không có hoặc đã Ngừng | Hàm nghiệp vụ |
| `app.is_holiday(ngày, cơ sở)` | Có phải ngày nghỉ của cơ sở | Hàm xếp lịch (GĐ2) |
| `app.session_type_deducts_hours(loại buổi)` | Loại buổi có trừ giờ không | Hàm trừ giờ (GĐ2) |

## Cấp mã (spec 02 mục "Mã các đối tượng")
Bảng đếm khoá dòng `app.code_counter` (không dùng sequence): hai người xin cùng lúc thì người sau chờ, không trùng;
giao dịch huỷ thì số được trả lại, không nhảy số. Bộ đếm không lùi, không xoá. Định dạng (tiền tố, số chữ số, số bắt đầu)
ở `app.code_format`, chỉ đổi qua migration. GV bắt đầu 2001, TG 8001 (khi nhập dữ liệu thật đặt = số cũ lớn nhất + 1).

| Hàm | Kết quả | Ai gọi |
|---|---|---|
| `app.issue_person_code('HS'\|'PH'\|'NV'\|'GV'\|'TG')` | `HS000123`, `PH000045`, `NV0012`, `GV2007`, `TG8002` | Hàm tạo hồ sơ, cùng giao dịch |
| `app.issue_class_code(CS, năm, môn, khối, phân loại, [trình độ])` | `CS5-2627-TOAN-K08-CB-A-001`, lớp riêng `CS2-2627-TOAN-K09-LR-014` | Hàm tạo lớp |
| `app.build_framework_code(môn, khối, cấp độ, năm, [phiên bản])` | `TOAN-K03-CB-2627`, bản sửa `TOAN-K03-CB-2627-V2` | Hàm tạo khung |
| `app.build_lesson_code(mã khung, số bài)` | `TOAN-K03-CB-2627-B05` | Hàm tạo bài |
| `app.build_package_code(loại, môn, khối, hình thức)` | `LC-TOAN-K09-OFF` (không có gói DAI/HINH) | Hàm tạo gói |
| `app.issue_document_number(loại, CS, [thời điểm])` | `PT-CS1-2610-0001`; STT riêng loại, cơ sở, tháng (giờ VN) | Hàm tạo chứng từ |

Hàm `issue_*` không mở cho API: mã chỉ cấp trong cùng giao dịch với lệnh tạo bản ghi.

## Cài đặt (tham số nghiệp vụ, tầng 2)
`app.setting_def` (key, tên, kiểu, đơn vị, min, max, mô tả, giá trị chung, cho ghi đè theo cơ sở?) và `app.setting_branch` (ghi đè).
Giá trị sai kiểu, ngoài khoảng bị chặn kể cả khi sửa thẳng bảng. Khai báo (kiểu, khoảng, đơn vị) chỉ đổi qua migration.

| Key | Giá trị | Khoảng | Ghi đè |
|---|---|---|---|
| `max_sessions_ahead` cho học trước tối đa | 2 buổi | 0–10 | có |
| `session_autoclose_before_minutes` tự chốt buổi trước giờ học | 30 phút | 0–240 | có |
| `session_autoclose_scan_hours` khoảng quét tự chốt | 2 giờ | 1–24 | có |
| `teacher_session_complete_hours` hạn GV hoàn tất buổi (điểm danh + nhận xét đủ lớp) | 8 giờ sau khi buổi kết thúc | 1–72 | có |
| `algebra_geometry_split_grade` khối bắt đầu tách Đại/Hình | 7 | 2–12 | **không** |
| `package_default_validity_months` thời hạn gói mặc định | 6 tháng | 1–24 | có |
| `upsale_hours_left_threshold` tái tục khi còn ≤ giờ (BR-UPSALE-HOUR) | 10 giờ | 0–100 | có |
| `upsale_days_left_threshold` tái tục khi ngày hết giờ còn ≤ (BR-UPSALE-DAY) | 30 ngày | 0–180 | có |
| `absence_risk_sessions` vắng gắn cờ rủi ro | 3 buổi | 1–20 | có |
| `quotation_validity_days` hạn hiệu lực báo giá | 14 ngày | 1–90 | có |
| `deposit_min_amount` tiền cọc tối thiểu | 1.000.000 đồng | 0–100.000.000 | có |
| `reservation_max_months` bảo lưu tối đa một lần | 6 tháng | 1–24 | có |

Hai ngưỡng tái tục chạy song song: chạm ngưỡng nào trước thì cảnh báo, sinh phiếu tái tục (GĐ1).

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.get_setting(key, [cơ sở])` / `_int` / `_numeric` / `_bool` | Giá trị ghi đè của cơ sở hoặc giá trị chung | Hàm nghiệp vụ |
| `app.set_setting(key, giá trị, [cơ sở])` | Sửa giá trị chung hoặc ghi đè | Admin (bước 3) |
| `app.clear_setting_override(key, cơ sở)` | Bỏ ghi đè, dùng lại giá trị chung | Admin |

## Công tắc tính năng
`app.feature_flag` (phân hệ × cơ sở), không có dòng = tắt. Phân hệ: BAN_HANG, VAN_HANH_LOP, CONG_GIAO_VIEN, HOC_TAP, BAO_CAO.

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.feature_enabled(phân hệ, cơ sở)` | Đang bật? | Giao diện, hàm nghiệp vụ |
| `app.require_feature(phân hệ, cơ sở)` | Lỗi `HMT_TINH_NANG_TAT` nếu tắt | Đầu mỗi hàm nghiệp vụ |
| `app.set_feature(phân hệ, cơ sở, bật?)` | Bật/tắt | Admin (bước 3) |

## Ghi chú trao đổi
`app.note` gắn vào bản ghi của loại đã đăng ký ở `app.note_target` (hiện: BRANCH, ROOM, CATALOG_ITEM, SETTING; bảng nghiệp vụ mới
đăng ký thêm bằng migration). Bản ghi phải tồn tại; không chuyển sang bản ghi khác; huỷ thay cho xoá; sửa có nhật ký.

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.add_note(loại, id bản ghi, nội dung)` | Thêm ghi chú | Người dùng (quyền ở bước 3) |
| `app.cancel_note(id, lý do)` | Huỷ ghi chú | Người viết / Admin (bước 3) |

## Dữ liệu giả (`supabase/seed.sql`)
Chỉ local và hmt-staging (workflow thử nghiệm chạy sau migration; chạy lại không nhân đôi): 3 phòng mỗi cơ sở, 2 ngày nghỉ,
bật BAN_HANG ở CS5, ghi đè hạn báo giá CS5 = 7 ngày, 1 ghi chú. Không có tên, số điện thoại thật.
