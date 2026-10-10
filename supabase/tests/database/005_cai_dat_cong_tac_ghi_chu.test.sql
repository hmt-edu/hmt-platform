-- Luật Cài đặt, công tắc tính năng, ghi chú (docs/nghiep-vu/nen-du-lieu.md).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;

create temp table b as select code, id from app.branch;

-- ================= Cài đặt =================
select is(app.get_setting_int('max_sessions_ahead'), 2::bigint, 'Cho học trước tối đa = 2 buổi');
select is(app.get_setting_int('session_autoclose_before_minutes'), 30::bigint, 'Tự chốt buổi 30 phút trước giờ học');
select is(app.get_setting_int('session_autoclose_scan_hours'), 2::bigint, 'Quét tự chốt 2 giờ tới');
select is(app.get_setting_int('teacher_session_complete_hours'), 8::bigint, 'Hạn giáo viên hoàn tất buổi 8 giờ');
select is(app.get_setting_int('algebra_geometry_split_grade'), 7::bigint, 'Tách Đại/Hình từ khối 7');
select is(app.get_setting_int('package_default_validity_months'), 6::bigint, 'Thời hạn gói mặc định 6 tháng');
select is(app.get_setting_numeric('upsale_hours_left_threshold'), 10::numeric, 'Ngưỡng tái tục theo giờ: còn ≤ 10 giờ');
select is(app.get_setting_int('upsale_days_left_threshold'), 30::bigint, 'Ngưỡng tái tục theo ngày: còn ≤ 30 ngày');
select is(app.get_setting_int('absence_risk_sessions'), 3::bigint, 'Vắng 3 buổi gắn cờ rủi ro');
select is(app.get_setting_int('quotation_validity_days'), 14::bigint, 'Báo giá hiệu lực 14 ngày');
select is(app.get_setting_int('deposit_min_amount'), 1000000::bigint, 'Cọc tối thiểu 1.000.000 đồng');
select is(app.get_setting_int('reservation_max_months'), 6::bigint, 'Bảo lưu tối đa 6 tháng một lần');

select is(app.get_setting_numeric('refund_processing_fee_percent'), 10::numeric, 'Phí xử lý hoàn phí 10% (R-TIEN-28)');
select is(app.get_setting_numeric('discount_total_cap_percent'), 20::numeric, 'Trần tổng chiết khấu 20% (R-TIEN-29)');
select is(app.get_setting_int('sla_complaint_response_hours'), 24::bigint, 'SLA khiếu nại thường: phản hồi 24 giờ (R-CS-08)');
select is(app.get_setting_int('sla_complaint_resolve_days'), 3::bigint, 'SLA khiếu nại thường: xong 3 ngày');
select is(app.get_setting_int('sla_complaint_critical_response_hours'), 2::bigint, 'SLA khiếu nại nghiêm trọng: phản hồi 2 giờ');
select is(app.get_setting_int('sla_complaint_critical_resolve_days'), 1::bigint, 'SLA khiếu nại nghiêm trọng: xong 1 ngày');
select is(app.get_setting_int('sla_request_response_hours'), 24::bigint, 'SLA đề nghị: phản hồi 24 giờ');
select is(app.get_setting_int('sla_request_resolve_days'), 2::bigint, 'SLA đề nghị: xong 2 ngày');
select is(app.get_setting_int('sla_refund_resolve_days'), 7::bigint, 'SLA đề nghị hoàn tiền: xong 7 ngày');
select is(app.get_setting_int('complaint_reopen_max_days'), 7::bigint, 'Mở lại khiếu nại trong 7 ngày (R-CS-06)');
select is(pg_temp.err($$select app.set_setting('discount_total_cap_percent', '150')$$), 'HMT_CAI_DAT_NGOAI_KHOANG',
          'Trần chiết khấu quá 100% bị chặn');
select is(pg_temp.err($$select app.set_setting('refund_processing_fee_percent', '5', (select id from app.branch where code = 'CS5'))$$),
          'HMT_KHONG_DUOC_GHI_DE', 'Phí hoàn phí dùng chung toàn hệ thống, không ghi đè theo cơ sở');

-- Sửa giá trị chung trong khoảng: được, có nhật ký.
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '21')$$), null, 'Sửa tham số trong khoảng: được');
select is(app.get_setting_int('quotation_validity_days'), 21::bigint, 'Giá trị chung đã đổi');
select ok(exists (select from app.audit_log l join app.audited_table t on t.id = l.table_id
                   where t.table_name = 'app.setting_def' and l.action = 'U'
                     and l.changes ? 'value'),
          'Sửa tham số có ghi nhật ký (giá trị cũ → mới)');

-- Ngoài khoảng, sai kiểu: bị chặn (kể cả sửa thẳng bảng).
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '500')$$), 'HMT_CAI_DAT_NGOAI_KHOANG',
          'Tham số ngoài khoảng cho phép: bị chặn');
select is(pg_temp.err($$update app.setting_def set value = '0' where key = 'quotation_validity_days'$$), 'HMT_CAI_DAT_NGOAI_KHOANG',
          'Sửa thẳng bảng ngoài khoảng: cũng bị chặn');
select is(pg_temp.err($$select app.set_setting('max_sessions_ahead', 'hai')$$), 'HMT_CAI_DAT_SAI_KIEU',
          'Tham số sai kiểu (chữ thay vì số): bị chặn');
select is(pg_temp.err($$select app.set_setting('max_sessions_ahead', '1.5')$$), 'HMT_CAI_DAT_SAI_KIEU',
          'Tham số số nguyên không nhận số lẻ');
select is(pg_temp.err($$select app.get_setting('khong_co')$$), 'HMT_CAI_DAT_KHONG_CO', 'Đọc tham số chưa khai báo: báo lỗi');
select is(pg_temp.err($$update app.setting_def set max_value = 999 where key = 'quotation_validity_days'$$), 'HMT_LUAT_LOI',
          'Khai báo khoảng, kiểu chỉ đổi qua migration');
select is(pg_temp.err($$insert into app.setting_def (key, name, value_type, description, value) values ('moi', 'Mới', 'INT', 'x', '1')$$),
          'HMT_LUAT_LOI', 'Thêm tham số mới phải qua migration');

-- Ghi đè theo cơ sở.
select app.set_setting('max_sessions_ahead', '3', (select id from b where code = 'CS5'));
select is(app.get_setting_int('max_sessions_ahead', (select id from b where code = 'CS5')), 3::bigint,
          'Cơ sở có ghi đè: dùng giá trị riêng');
select is(app.get_setting_int('max_sessions_ahead', (select id from b where code = 'CS1')), 2::bigint,
          'Cơ sở không ghi đè: dùng giá trị chung');
select is(pg_temp.err($$select app.set_setting('max_sessions_ahead', '50', (select id from app.branch where code = 'CS5'))$$),
          'HMT_CAI_DAT_NGOAI_KHOANG', 'Giá trị ghi đè ngoài khoảng: bị chặn');
select is(pg_temp.err($$select app.set_setting('algebra_geometry_split_grade', '6', (select id from app.branch where code = 'CS5'))$$),
          'HMT_KHONG_DUOC_GHI_DE', 'Tham số dùng chung (tách Đại/Hình) không ghi đè theo cơ sở được');
select app.clear_setting_override('max_sessions_ahead', (select id from b where code = 'CS5'));
select is(app.get_setting_int('max_sessions_ahead', (select id from b where code = 'CS5')), 2::bigint,
          'Bỏ ghi đè: quay về giá trị chung');

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '10')$$), 'HMT_KHONG_CO_QUYEN',
          'Qua API: chưa có quyền sửa Cài đặt ở bước 2');
select is(app.get_setting_int('quotation_validity_days'), 21::bigint, 'Qua API: đọc được tham số');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= Công tắc tính năng =================
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from b where code = 'CS1')), 'Mặc định: phân hệ tắt');
select is(pg_temp.err($$select app.require_feature('VAN_HANH_LOP', (select id from app.branch where code = 'CS1'))$$),
          'HMT_TINH_NANG_TAT', 'Hàm nghiệp vụ bị chặn khi phân hệ tắt');
select app.set_feature('VAN_HANH_LOP', (select id from b where code = 'CS5'), true);
select ok(app.feature_enabled('VAN_HANH_LOP', (select id from b where code = 'CS5')), 'Bật ở CS5: CS5 dùng được');
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from b where code = 'CS1')), 'Bật ở CS5 không ảnh hưởng CS1');
select is(pg_temp.err($$select app.require_feature('VAN_HANH_LOP', (select id from app.branch where code = 'CS5'))$$),
          null, 'Hàm nghiệp vụ chạy được khi phân hệ bật');
select app.set_feature('VAN_HANH_LOP', (select id from b where code = 'CS5'), false);
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from b where code = 'CS5')), 'Tắt lại được');
select is(pg_temp.err($$select app.set_feature('KHONG_CO', (select id from app.branch where code = 'CS5'), true)$$),
          'HMT_DANH_MUC_KHONG_CO', 'Không bật được phân hệ không có trong danh mục');
select is(pg_temp.err($$delete from app.feature_flag$$), 'HMT_KHONG_XOA', 'Không xoá được công tắc (tắt thay cho xoá)');

-- ================= Ghi chú =================
create temp table n as
  select app.add_note('BRANCH', (select id from b where code = 'CS1'), 'Ghi chú thử cho CS1') as id;
select is((select body from app.note where id = (select id from n)), 'Ghi chú thử cho CS1', 'Gắn được ghi chú vào cơ sở');
select is(pg_temp.err($$select app.add_note('BRANCH', gen_random_uuid(), 'Gắn vào bản ghi không có')$$),
          'HMT_GHI_CHU_DOI_TUONG_KHONG_CO', 'Không gắn được ghi chú vào bản ghi không tồn tại');
select is(pg_temp.err($$select app.add_note('KHONG_CO', gen_random_uuid(), 'Loại lạ')$$),
          'HMT_GHI_CHU_LOAI_KHONG_CO', 'Không gắn được ghi chú vào loại bản ghi chưa đăng ký');
select is(pg_temp.err($$select app.add_note('BRANCH', (select id from app.branch where code = 'CS1'), '   ')$$),
          '23514', 'Ghi chú không được để trống');
select is(pg_temp.err(format($$update app.note set entity_id = (select id from app.branch where code = 'CS2') where id = %L$$,
                             (select id from n))),
          'HMT_MA_KHONG_DOI_DUOC', 'Không chuyển ghi chú sang bản ghi khác');
select app.cancel_note((select id from n), 'Ghi nhầm');
select ok((select is_cancelled and cancelled_at is not null from app.note where id = (select id from n)),
          'Huỷ ghi chú: đánh dấu huỷ, ghi lúc huỷ');
select is(pg_temp.err(format($$delete from app.note where id = %L$$, (select id from n))), 'HMT_KHONG_XOA',
          'Không xoá được ghi chú');

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(pg_temp.err($$select count(*) from app.note$$), '42501', 'Qua API: chưa đọc được ghi chú ở bước 2');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
