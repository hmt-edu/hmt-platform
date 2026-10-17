-- P3b1 (1/3): danh mục, mã và tham số cho phân hệ Tuyển sinh (luật 16/10 tối, docs/spec/04 R-CRM-04…15; spec 06).
-- Danh mục: L5Q, hai lý do huỷ test mới, danh mục 34 "Lý do huỷ lịch hẹn", tên và trạng thái phiếu test.
-- Mã: LD, CO, PKT (docs/spec/02). Tham số: giờ nhắc phiếu test, số dòng nhập lead.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Nhóm con L5Q (R-CRM-06, 15): xếp ngay sau L5O.
-- ---------------------------------------------------------------------------
update app.catalog_item set sort_order = sort_order + 1
where catalog_code = 'OPP_SUBSTAGE'
  and sort_order > (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5O');

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'OPP_SUBSTAGE', 'L5Q', 'Huỷ test, trung tâm không xếp được lịch',
       (select sort_order + 1 from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5O'),
       (select id from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5');

-- ---------------------------------------------------------------------------
-- Danh mục 13 "Lý do huỷ test": thêm hai lý do (R-CRM-06). Mã lý do nối nhóm con = mã nhóm con (như L5C…L5O).
--   - "Trung tâm không xếp được lịch test" nối L5Q.
--   - "Tạo phiếu sai" không nối nhóm con nào (R-CRM-15 bỏ qua phiếu huỷ vì lý do này).
-- "Lý do khác" (L5M) bắt buộc ghi chú (R-HT-04).
-- ---------------------------------------------------------------------------
insert into app.catalog_item (catalog_code, code, name, sort_order, linked_item_id)
values
  ('TEST_CANCEL_REASON', 'L5Q', 'Trung tâm không xếp được lịch test', 12,
   (select id from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5Q')),
  ('TEST_CANCEL_REASON', 'TAO_PHIEU_SAI', 'Tạo phiếu sai', 13, null);

update app.catalog_item set requires_note = true where catalog_code = 'TEST_CANCEL_REASON' and code = 'L5M';

-- ---------------------------------------------------------------------------
-- Tình trạng phiếu test (R-CRM-06): "Chờ giáo viên chấm"; bỏ nhánh "Từ chối" (Ngừng, không xoá).
-- ---------------------------------------------------------------------------
update app.catalog_item set name = 'Chờ giáo viên chấm' where catalog_code = 'TEST_STATUS' and code = 'TEACHER_REVIEW';
update app.catalog_item set is_active = false where catalog_code = 'TEST_STATUS' and code = 'REJECTED';

-- ---------------------------------------------------------------------------
-- Danh mục 34 "Lý do huỷ lịch hẹn" (R-CRM-04). Danh mục Mở; "Khác" bắt buộc ghi chú.
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order)
values ('APPOINTMENT_CANCEL_REASON', 'Lý do huỷ lịch hẹn', 'MO', null, null,
        'Bắt buộc chọn khi huỷ lịch hẹn (R-CRM-04).', 45);

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  ('APPOINTMENT_CANCEL_REASON', 'PH_BAO_BAN', 'PH báo bận', 1, false),
  ('APPOINTMENT_CANCEL_REASON', 'KHONG_LIEN_LAC_DUOC', 'Không liên lạc được', 2, false),
  ('APPOINTMENT_CANCEL_REASON', 'TAO_NHAM', 'Tạo nhầm', 3, false),
  ('APPOINTMENT_CANCEL_REASON', 'KHAC', 'Khác', 4, true);

-- ---------------------------------------------------------------------------
-- Mã lead LD, cơ hội CO, phiếu kiểm tra PKT: 6 số, đánh số toàn hệ thống, không gắn cơ sở (docs/spec/02).
-- Cấp lúc Lưu (R-CRM-19: bấm Tạo chỉ mở khuôn trống).
-- ---------------------------------------------------------------------------
insert into app.code_format (code, name, prefix, pad_width, start_value) values
  ('LD', 'Lead', 'LD', 6, 1),
  ('CO', 'Cơ hội', 'CO', 6, 1),
  ('PKT', 'Phiếu kiểm tra đầu vào', 'PKT', 6, 1);

-- Cấp mã CRM. Ai gọi: các hàm tạo lead, cơ hội, phiếu (không cấp cho giao diện). Không nhảy số: dùng bảng đếm khoá dòng.
create or replace function app.issue_crm_code(p_kind text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format;
  v_number bigint;
begin
  if p_kind not in ('LD', 'CO', 'PKT') then
    perform app.raise_error('HMT_LOAI_MA_SAI', format('Không có loại mã CRM "%s".', p_kind));
  end if;
  v_format := app.code_format_of(p_kind);
  v_number := app.next_counter_value(p_kind, v_format.start_value);
  return v_format.prefix || lpad(v_number::text, v_format.pad_width, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- Tham số Cài đặt (không viết cứng trong code).
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('test_reminder_time_minutes', 'Giờ nhắc phiếu test (ngày trước)', 'INT', 'phút kể từ 0 giờ', 0, 1439, '1020', false, 'BAN_HANG', null,
   'Lịch hẹn nhắc tự sinh cùng phiếu test được đặt vào giờ này của ngày trước giờ test (1020 = 17:00).'),
  ('test_reminder_short_window_hours', 'Test sắp tới trong (giờ) thì nhắc ngắn', 'INT', 'giờ', 1, 72, '24', false, 'BAN_HANG', null,
   'Phiếu test bắt đầu trong khoảng này kể từ lúc tạo thì nhắc trước giờ test thay vì giờ cố định của ngày trước.'),
  ('test_reminder_short_lead_hours', 'Nhắc ngắn: trước giờ test (giờ)', 'INT', 'giờ', 1, 24, '2', false, 'BAN_HANG', null,
   'Với phiếu test sắp tới, lịch hẹn nhắc đặt trước giờ test bấy nhiêu giờ.'),
  ('list_page_size_default', 'Số dòng mỗi trang danh sách (mặc định)', 'INT', 'dòng', 10, 100, '50', false, null, null,
   'Danh sách phân trang ở máy chủ (CLAUDE.md, Hiệu năng).'),
  ('list_page_size_max', 'Số dòng mỗi trang danh sách (tối đa)', 'INT', 'dòng', 20, 200, '100', false, null, null,
   'Giới hạn trên của một trang danh sách; yêu cầu lớn hơn bị cắt về mức này.'),
  ('lead_import_max_rows', 'Số dòng tối đa mỗi lần nhập lead từ file', 'INT', 'dòng', 1, 5000, '500', false, 'BAN_HANG', null,
   'Giới hạn một lần nhập file CSV lead (TS-04).');

select set_config('hmt.migration', '', false);
