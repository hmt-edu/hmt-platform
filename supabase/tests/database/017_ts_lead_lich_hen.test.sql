-- P3b1: danh mục, mã, tham số, lead, lịch hẹn, RLS, danh sách phân trang của phân hệ Tuyển sinh
-- (docs/spec/04 R-CRM-01, 04, 06, 09, 15; R-HT-04; CLAUDE.md Hiệu năng).
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
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ================= Danh mục, mã, tham số =================
select is((select array_agg(code order by sort_order) from app.catalog_item
           where catalog_code = 'OPP_SUBSTAGE' and code in ('L5M', 'L5O', 'L5Q', 'L6A')), array['L5M', 'L5O', 'L5Q', 'L6A'],
          'R-CRM-06: L5Q xếp ngay sau L5O, trước L6A');
select is((select p.code from app.catalog_item i join app.catalog_item p on p.id = i.parent_id
           where i.catalog_code = 'OPP_SUBSTAGE' and i.code = 'L5Q'), 'L5', 'L5Q thuộc L5');
select is((select count(*)::int from app.catalog_item where catalog_code = 'TEST_CANCEL_REASON'), 13, 'Danh mục 13 có 13 lý do huỷ test');
select is((select l.code from app.catalog_item i join app.catalog_item l on l.id = i.linked_item_id
           where i.catalog_code = 'TEST_CANCEL_REASON' and i.name = 'Trung tâm không xếp được lịch test'), 'L5M',
          'R-CRM-06 (sửa 04/11, T3b): "Trung tâm không xếp được lịch test" nối L5M (L5Q Ngừng)');
select is((select linked_item_id from app.catalog_item where catalog_code = 'TEST_CANCEL_REASON' and name = 'Tạo phiếu sai'), null,
          'R-CRM-06: "Tạo phiếu sai" không nối nhóm con nào');
select is((select requires_note from app.catalog_item where catalog_code = 'TEST_CANCEL_REASON' and code = 'L5M'), true,
          'R-HT-04: "Lý do khác" của huỷ test bắt buộc ghi chú');
select is((select array_agg(name order by sort_order) from app.catalog_item where catalog_code = 'APPOINTMENT_CANCEL_REASON'),
          array['PH báo bận', 'Không liên lạc được', 'Tạo nhầm', 'Khác'], 'Danh mục 34: bốn lý do huỷ lịch hẹn');
select is((select requires_note from app.catalog_item where catalog_code = 'APPOINTMENT_CANCEL_REASON' and code = 'KHAC'), true,
          'Danh mục 34: "Khác" bắt buộc ghi chú');
select is((select name from app.catalog_item where catalog_code = 'TEST_STATUS' and code = 'TEACHER_REVIEW'), 'Chờ giáo viên chấm',
          'R-CRM-06: tình trạng phiếu "Chờ giáo viên chấm"');
select is((select is_active from app.catalog_item where catalog_code = 'TEST_STATUS' and code = 'REJECTED'), false,
          'R-CRM-06: bỏ nhánh Từ chối (Ngừng, không xoá)');
select is((select array_agg(code order by code) from app.code_format where code in ('LD', 'CO', 'PKT')), array['CO', 'LD', 'PKT'],
          'Spec 02: có định dạng mã LD, CO, PKT');
select is((select array_agg(key || '=' || value order by key) from app.setting_def
           where key in ('test_reminder_time_minutes', 'test_reminder_short_window_hours', 'test_reminder_short_lead_hours',
                         'lead_import_max_rows', 'list_page_size_default', 'list_page_size_max')),
          array['lead_import_max_rows=500', 'list_page_size_default=50', 'list_page_size_max=100', 'test_reminder_short_lead_hours=2',
                'test_reminder_short_window_hours=24', 'test_reminder_time_minutes=1020'], 'Tham số mới có mặc định đúng');

select is(app.normalize_phone('+84 912.345-678'), '0912345678', 'SĐT: +84 đổi thành 0, bỏ dấu');
select is(app.normalize_phone('0912 345 678'), '0912345678', 'SĐT: bỏ dấu cách');
select is(app.issue_crm_code('LD'), 'LD000001', 'Mã lead đầu tiên LD000001');
select is(app.issue_crm_code('LD'), 'LD000002', 'Mã lead tăng liên tục, không nhảy số');
select is(app.issue_crm_code('CO'), 'CO000001', 'Mã cơ hội CO000001');
select is(app.issue_crm_code('PKT'), 'PKT000001', 'Mã phiếu PKT000001');
select is(pg_temp.err($$select app.issue_crm_code('XX')$$), 'HMT_LOAI_MA_SAI', 'Loại mã CRM sai bị chặn');

-- ================= Tạo lead, kiểm trùng, quyền =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

select is(pg_temp.err($$select app.issue_crm_code('LD')$$), '42501', 'Giao diện không tự cấp mã (hàm nội bộ)');
select is(pg_temp.err($$insert into app.lead (code) values ('X')$$), '42501', 'Không ghi thẳng bảng lead');

select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000001'))$$), null, 'Tạo lead đúng: được');
select is((select code from app.lead where parent_phone = '0900000001'), 'LD000003', 'Mã lead cấp lúc Lưu, liên tục');
select is((select array[stage_code, record_status] from app.lead where parent_phone = '0900000001'), array['C1', 'DANG_DUNG'],
          'Lead mới ở C1, đang dùng');
select is((select owner_id from app.lead where parent_phone = '0900000001'), pg_temp.uid('sales1'), 'Người phụ trách mặc định là người tạo');
select is((select branch_id from app.lead where parent_phone = '0900000001'), (select id from app.branch where code = 'CS1'),
          'Cơ sở mặc định là cơ sở người tạo');
select is((select next_appointment_at from app.lead where parent_phone = '0900000001'), null, 'Chưa có lịch hẹn thì "Lịch hẹn kế tiếp" trống');

select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('12345'))$$), 'HMT_SDT_SAI', 'Chặn: SĐT sai');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000002', '{"parent_name": " "}'))$$), 'HMT_THIEU_THONG_TIN',
          'Chặn: thiếu họ tên phụ huynh');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000002', '{"source_code": null}'))$$), 'HMT_THIEU_NGUON',
          'Chặn: thiếu nguồn');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000002', '{"channel_code": null}'))$$), 'HMT_THIEU_NGUON',
          'Chặn: nguồn có kênh con mà thiếu kênh (Facebook Ads)');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000002', '{"source_code": "WEBSITE", "channel_code": null}'))$$), null,
          'Đúng: nguồn không có kênh con (Website) thì không cần kênh');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000003', '{"source_type_code": "EVENT"}'))$$), 'HMT_NGUON_SAI',
          'Chặn: nguồn không thuộc loại nguồn');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000003', '{"branch_id": "00000000-0000-0000-0000-000000000000"}'))$$),
          'HMT_KHONG_CO_QUYEN', 'Chặn: cơ sở không có (không phải cơ sở của mình)');

-- Trùng SĐT (TS-03, TS-14).
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000001'))$$), 'HMT_SDT_TRUNG',
          'R-CRM-01/TS-14: SĐT đã có lead thì cần xác nhận lần hai');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000001'), true)$$), null, 'Xác nhận vẫn tạo mới: được');
select is((select count(*)::int from app.find_duplicate_contacts('0900000001')), 2, 'Kiểm trùng trả cả hai lead cùng SĐT');
select is((select count(*)::int from app.find_duplicate_contacts('+84 900 000 001')), 2, 'Kiểm trùng chuẩn hoá SĐT trước khi so');
select is((select count(*)::int from app.find_duplicate_contacts('12345')), 0, 'SĐT sai: không có kết quả trùng');
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH900001', 'Phụ Huynh Có Sẵn', '0900000009', id from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH900005', 'Phụ Huynh Ở CS5', '0900000010', id from app.branch where code = 'CS5'$$);
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000009'))$$), 'HMT_SDT_TRUNG', 'SĐT trùng phụ huynh có sẵn: cần xác nhận');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000009'), false, (select id from app.parent where code = 'PH900001'))$$),
          null, 'TS-14: "Gắn vào hồ sơ có sẵn" (phụ huynh) tạo lead không cần xác nhận');
select is((select parent_id from app.lead where parent_phone = '0900000009'), (select id from app.parent where code = 'PH900001'),
          'Lead gắn đúng phụ huynh đã chọn');
select pg_temp.sudo($$create temp table other_parent as select id from app.parent where code = 'PH900005'$$);
select pg_temp.sudo($$grant all on other_parent to public$$);
select is((select count(*)::int from app.parent where id = (select id from other_parent)), 1,
          'R-CRM-26 (phiên bản 4): phụ huynh dùng chung toàn hệ thống, Tuyển sinh CS1 thấy phụ huynh của cơ sở khác');
-- Trùng khác cơ sở vẫn cảnh báo nhưng không lộ tên.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000001'))$$), 'HMT_SDT_TRUNG', 'Trùng với lead cơ sở khác: vẫn cảnh báo');
select is((select array[visible::text, coalesce(label, 'ẨN')] from app.find_duplicate_contacts('0900000001') order by code limit 1),
          array['false', 'ẨN'], 'Hồ sơ cơ sở khác: không lộ tên');
-- E67 (KHẨN): hồ sơ ngoài phạm vi cũng KHÔNG lộ id, mã, cơ sở; người xem chỉ biết «đã có trong hệ thống».
select is((select count(*)::int from app.find_duplicate_contacts('0900000001') where not visible), 2, 'E67: hai lead cơ sở khác báo là ngoài phạm vi (visible = false)');
select is((select count(*)::int from app.find_duplicate_contacts('0900000001') where not visible and (id is not null or code is not null or branch_code is not null or label is not null)), 0,
          'E67: hồ sơ ngoài phạm vi không lộ id, mã, tên, cơ sở');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.find_duplicate_contacts('0900000001') where visible and id is not null and code is not null and branch_code is not null), 2,
          'E67: hồ sơ trong phạm vi vẫn trả đủ id, mã, cơ sở');

-- Giao việc khi tạo: giao cho người khác cần quyền Giao việc (Tuyển sinh có từ ma trận phiên bản 3).
select is(pg_temp.err(format($f$select app.create_lead(pg_temp.lead_data('0900000019', '{"owner_id": "%s"}'))$f$, pg_temp.uid('sales1b'))),
          null, 'Tuyển sinh có Giao việc: giao cho nhân sự cùng cơ sở khi tạo được');
select is(pg_temp.err(format($f$select app.create_lead(pg_temp.lead_data('0900000018', '{"owner_id": "%s"}'))$f$, pg_temp.uid('teacher5'))),
          'HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách không phải nhân sự cùng cơ sở: bị chặn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err(format($f$select app.create_lead(pg_temp.lead_data('0900000020', '{"owner_id": "%s"}'))$f$, pg_temp.uid('sales1b'))),
          null, 'Trưởng cơ sở giao cho nhân sự cùng cơ sở khi tạo: được');
select is(pg_temp.err(format($f$select app.create_lead(pg_temp.lead_data('0900000021', '{"owner_id": "%s"}'))$f$, pg_temp.uid('sales5'))),
          'HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách khác cơ sở: bị chặn');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000030'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không tạo được lead');
select is(pg_temp.err($$select * from app.find_duplicate_contacts('0900000001')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không kiểm trùng được');

-- Ngoài phạm vi cơ sở.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err(format($f$select app.create_lead(pg_temp.lead_data('0900000040', '{"branch_id": "%s"}'))$f$,
                              (select id from app.branch where code = 'CS1'))), 'HMT_KHONG_CO_QUYEN', 'Không tạo lead ở cơ sở khác');

-- ================= RLS đọc =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((select count(*) from app.lead) >= 4, 'Tuyển sinh CS1 thấy lead cơ sở mình');
select is((select count(*)::int from app.lead l join app.branch b on b.id = l.branch_id where b.code <> 'CS1'), 0, 'Tuyển sinh CS1 không thấy lead cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.lead), 0, 'Tuyển sinh CS5 không thấy lead của CS1');
select is((select count(*)::int from app.parent where code = 'PH900001'), 1, 'R-CRM-26 (phiên bản 4): Tuyển sinh CS5 thấy phụ huynh CS1 (hồ sơ dùng chung)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok((select count(distinct branch_id) from app.lead) >= 1 and (select count(*) from app.parent) >= 2, 'ADMIN thấy mọi cơ sở');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is((select count(*)::int from app.lead), 0, 'Giáo viên không đọc được lead');
select is((select count(*)::int from app.appointment), 0, 'Giáo viên không đọc được lịch hẹn');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is((select count(*)::int from app.lead), 0, 'Học sinh không đọc được lead');

-- ================= Sửa lead, đổi giai đoạn, giao việc =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$create temp table t (lead_id uuid)$$);
select pg_temp.sudo($$grant all on t to public$$);
insert into t select id from app.lead where parent_phone = '0900000001' order by created_at limit 1;

select is(pg_temp.err($$select app.update_lead((select lead_id from t), '{"need": "Ôn thi vào 10", "school": "THCS Thử"}')$$), null, 'Sửa lead: được');
select is((select array[l.need, ps.school] from app.lead l join app.prospect_student ps on ps.lead_id = l.id where l.id = (select lead_id from t) and ps.position = 1), array['Ôn thi vào 10', 'THCS Thử'], 'Sửa lead: ô đã đổi');
select is((select code from app.lead where id = (select lead_id from t)), 'LD000003', 'Sửa lead không đổi mã');
select is(pg_temp.err($$select app.update_lead((select lead_id from t), '{"parent_phone": "0900000009"}')$$), 'HMT_SDT_TRUNG', 'Đổi sang SĐT đã có hồ sơ: cần xác nhận');
select is(pg_temp.err($$select app.update_lead((select lead_id from t), '{"parent_phone": "0900000009"}', true)$$), null, 'Đã xác nhận: đổi được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.update_lead((select lead_id from t), '{"need": "x"}')$$), 'HMT_KHONG_CO_QUYEN', 'Sửa lead cơ sở khác: bị chặn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- R-CRM-09: đổi tự do hai chiều; C4D chỉ hệ thống gắn.
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C4', 'C4B')$$), null, 'R-CRM-09: C1 → C4 được');
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C2', 'C2A')$$), null, 'R-CRM-09: C4 → C2 (lùi) được');
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C1')$$), null, 'R-CRM-09: về C1 không nhóm con được');
select is((select array[stage_code, substage_code] from app.lead where id = (select lead_id from t)), array['C1', null], 'Giai đoạn lead đã đổi theo');
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C4', 'C4D')$$), 'HMT_C4D_HE_THONG', 'R-CRM-09: C4D chỉ hệ thống gắn');
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C3', 'C4A')$$), 'HMT_NHOM_CON_SAI', 'Nhóm con không thuộc giai đoạn: bị chặn');
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C9')$$), 'HMT_DANH_MUC_KHONG_CO', 'Giai đoạn không có: bị chặn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok((select count(*) from app.audit_log l join app.audited_table a on a.id = l.table_id
            where a.table_name = 'app.lead' and l.record_id = (select lead_id from t) and l.action = 'U') >= 3,
          'R-CRM-09: mọi lần đổi giai đoạn ghi lịch sử (nhật ký, Quản trị đọc)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- Giao người phụ trách.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err(format($f$select app.assign_owner('LEAD', array[(select lead_id from t)], '%s')$f$, pg_temp.uid('sales5'))),
          'HMT_KHONG_CO_QUYEN', 'Giao lead của cơ sở khác: bị chặn dù có quyền Giao việc ở cơ sở mình');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err(format($f$select app.assign_owner('LEAD', array[(select lead_id from t)], '%s')$f$, pg_temp.uid('sales1b'))),
          null, 'Tuyển sinh có Giao việc: giao lead cho nhân sự cùng cơ sở được');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err(format($f$select app.assign_owner('LEAD', array[(select lead_id from t)], '%s')$f$, pg_temp.uid('sales1b'))),
          null, 'Trưởng cơ sở giao lead cho nhân sự cùng cơ sở: được');
select is((select owner_id from app.lead where id = (select lead_id from t)), pg_temp.uid('sales1b'), 'Người phụ trách đã đổi');
select is(pg_temp.err(format($f$select app.assign_owner('LEAD', array[(select lead_id from t)], '%s')$f$, pg_temp.uid('sales5'))),
          'HMT_NGUOI_PHU_TRACH_SAI', 'Giao cho người khác cơ sở: bị chặn');
select is(pg_temp.err($$select app.assign_owner('LEAD', '{}'::uuid[], null)$$), 'HMT_THIEU_THONG_TIN', 'Giao mà không chọn bản ghi: bị chặn');
select is(pg_temp.err(format($f$select app.assign_owner('LEAD', (select array_agg(gen_random_uuid()) from generate_series(1, 101)), '%s')$f$,
                              pg_temp.uid('sales1b'))), 'HMT_QUA_NHIEU_BAN_GHI', 'Giao quá số bản ghi tối đa một lần: bị chặn');
select is(pg_temp.err($$select app.assign_owner('PARENT', array[gen_random_uuid()], null)$$), 'HMT_LOAI_BAN_GHI_SAI',
          'Loại bản ghi chưa hỗ trợ: báo rõ');

-- Bản "Đã gộp" chỉ đọc (R-CRM-22).
select pg_temp.sudo($$update app.lead set record_status = 'DA_GOP',
  merged_into_id = (select id from app.lead where parent_phone = '0900000020' limit 1)
  where id = (select lead_id from t)$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.update_lead((select lead_id from t), '{"need": "x"}')$$), 'HMT_BAN_GHI_DA_GOP', 'R-CRM-22: bản đã gộp không sửa được');
select is(pg_temp.err($$select app.change_lead_stage((select lead_id from t), 'C2')$$), 'HMT_BAN_GHI_DA_GOP', 'R-CRM-22: bản đã gộp không đổi giai đoạn');
select pg_temp.sudo($$update app.lead set record_status = 'DANG_DUNG', merged_into_id = null where id = (select lead_id from t)$$);

-- ================= Lịch hẹn (R-CRM-04) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.lead set owner_id = (select id from app.user_account where login_name like 'sales1@%') where id = (select lead_id from t)$$);
select pg_temp.sudo($$create temp table ap (n int primary key, id uuid)$$);
select pg_temp.sudo($$grant all on ap to public$$);
select is(pg_temp.err($$select app.create_appointment(null, 'GOI_DIEN', now(), 'Mồ côi')$$), 'HMT_LICH_HEN_MO_COI', 'R-CRM-04: không có lịch hẹn mồ côi');
select is(pg_temp.err($$select app.create_appointment((select lead_id from t), 'KHONG_CO', now(), 'x')$$), 'HMT_DANH_MUC_KHONG_CO', 'Loại hoạt động không có: bị chặn');
select is(pg_temp.err($$select app.create_appointment((select lead_id from t), 'GOI_DIEN', null, 'x')$$), 'HMT_THIEU_THONG_TIN', 'Thiếu ngày giờ: bị chặn');
select is(pg_temp.err($$select app.create_appointment((select lead_id from t), 'GOI_DIEN', now(), ' ')$$), 'HMT_THIEU_THONG_TIN', 'Thiếu nội dung: bị chặn');
insert into ap select 1, app.create_appointment((select lead_id from t), 'GOI_DIEN', now() + interval '2 days', 'Gọi lại hỏi lịch học');
insert into ap select 2, app.create_appointment((select lead_id from t), 'ZALO', now() + interval '1 day', 'Gửi bảng học phí');
select is((select status from app.appointment where id = (select id from ap where n = 1)), 'CHUA_LAM', 'Lịch hẹn mới ở trạng thái Chưa làm');
select is((select next_appointment_at from app.lead where id = (select lead_id from t)),
          (select scheduled_at from app.appointment where id = (select id from ap where n = 2)),
          'R-CRM-04: "Lịch hẹn kế tiếp" tự tính = lịch Chưa làm gần nhất');
select pg_temp.sudo($$create temp table before_state as select
  (select stage_code from app.lead where id = (select lead_id from t)) as stage, (select count(*) from app.notification) as notes$$);
select pg_temp.sudo($$grant all on before_state to public$$);

select is(pg_temp.err($$select app.complete_appointment((select id from ap where n = 2))$$), null, 'Hoàn thành: bấm một lần');
select is((select array[status, (completed_by = auth.uid())::text] from app.appointment where id = (select id from ap where n = 2)),
          array['HOAN_THANH', 'true'], 'Hoàn thành ghi người và lúc hoàn thành');
select is((select next_appointment_at from app.lead where id = (select lead_id from t)),
          (select scheduled_at from app.appointment where id = (select id from ap where n = 1)), 'Hoàn thành xong, "Lịch hẹn kế tiếp" chuyển sang lịch sau');
select is(pg_temp.err($$select app.complete_appointment((select id from ap where n = 2))$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'Hoàn thành lại: bị chặn');
select is(pg_temp.err($$select app.cancel_appointment((select id from ap where n = 2), 'TAO_NHAM')$$), 'HMT_LICH_HEN_TRANG_THAI_SAI',
          'R-CRM-04: Hoàn thành không chuyển thẳng sang Huỷ (phải Mở lại)');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where n = 2), now())$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'Lịch đã hoàn thành không dời được');
select is(pg_temp.err($$select app.reopen_appointment((select id from ap where n = 2))$$), null, 'R-CRM-04: Mở lại lịch Hoàn thành');
select is((select array[status, completed_at::text, (reopened_by = auth.uid())::text] from app.appointment where id = (select id from ap where n = 2)),
          array['CHUA_LAM', null, 'true'], 'Mở lại về Chưa làm, ghi người mở lại');
select is(pg_temp.err($$select app.reopen_appointment((select id from ap where n = 2))$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'Mở lại lịch chưa làm: không cần');

select is(pg_temp.err($$select app.cancel_appointment((select id from ap where n = 2), null)$$), 'HMT_THIEU_LY_DO', 'R-CRM-04: huỷ bắt buộc lý do');
select is(pg_temp.err($$select app.cancel_appointment((select id from ap where n = 2), 'KHAC')$$), 'HMT_THIEU_GHI_CHU', 'R-HT-04: "Khác" bắt ghi chú');
select is(pg_temp.err($$select app.cancel_appointment((select id from ap where n = 2), 'KHONG_CO')$$), 'HMT_DANH_MUC_KHONG_CO', 'Lý do không có trong danh mục 34: bị chặn');
select is(pg_temp.err($$select app.cancel_appointment((select id from ap where n = 2), 'KHAC', 'PH đổi ý')$$), null, 'Huỷ với lý do "Khác" kèm ghi chú: được');
select is((select array[status, cancel_reason_code, cancel_note] from app.appointment where id = (select id from ap where n = 2)),
          array['HUY', 'KHAC', 'PH đổi ý'], 'Huỷ ghi lý do và ghi chú');
select is(pg_temp.err($$select app.complete_appointment((select id from ap where n = 2))$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'Huỷ không chuyển thẳng sang Hoàn thành');
select is(pg_temp.err($$select app.reopen_appointment((select id from ap where n = 2))$$), null, 'Mở lại lịch Huỷ');
select is((select array[status, cancel_reason_code] from app.appointment where id = (select id from ap where n = 2)), array['CHUA_LAM', null],
          'Mở lại xoá lý do huỷ');
select is(pg_temp.err($$select app.cancel_appointment((select id from ap where n = 1), 'PH_BAO_BAN')$$), null, 'Huỷ với lý do danh mục: được');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where n = 2), now() + interval '9 days')$$), null, 'Dời lịch Chưa làm: được');
select is((select next_appointment_at from app.lead where id = (select lead_id from t)),
          (select scheduled_at from app.appointment where id = (select id from ap where n = 2)), 'Dời lịch: "Lịch hẹn kế tiếp" cập nhật');
select pg_temp.sudo($$update app.appointment set status = 'HUY', cancel_reason_code = 'TAO_NHAM' where id = (select id from ap where n = 2)$$);
select is((select next_appointment_at from app.lead where id = (select lead_id from t)), null, 'Hết lịch Chưa làm thì "Lịch hẹn kế tiếp" trống');
select pg_temp.sudo($$update app.appointment set status = 'CHUA_LAM', cancel_reason_code = null where id = (select id from ap where n = 2)$$);

-- Không có tác dụng phụ (R-CRM-04): không đổi giai đoạn, không tạo thông báo.
select is((select stage_code from app.lead where id = (select lead_id from t)), (select stage from before_state),
          'R-CRM-04: Hoàn thành, Huỷ, Mở lại không đổi giai đoạn');
select is((select count(*) from app.notification), (select notes from before_state), 'R-CRM-04: không gửi thông báo');

-- Quyền lịch hẹn.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.complete_appointment((select id from ap where n = 2))$$), 'HMT_KHONG_CO_QUYEN', 'Lịch hẹn cơ sở khác: không thao tác được');
select is(pg_temp.err($$select app.create_appointment((select lead_id from t), 'GOI_DIEN', now(), 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Không tạo lịch hẹn cho lead cơ sở khác');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.create_appointment((select lead_id from t), 'GOI_DIEN', now(), 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không tạo lịch hẹn');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.complete_appointment((select id from ap where n = 2))$$), null, 'CSKH cùng cơ sở hoàn thành lịch hẹn được');

-- ================= Danh sách phân trang =================
select pg_temp.sudo($$insert into app.lead (code, parent_name, parent_phone, branch_id, owner_id, source_type_code, source_code,
    stage_code, created_at)
  select 'LDT' || g, 'Phụ huynh số ' || g, '0999' || lpad(g::text, 6, '0'),
         (select id from app.branch where code = 'CS1'), (select id from app.user_account where login_name like 'sales1@%'),
         'MARKETING', 'WEBSITE', case when g % 4 = 0 then 'C2' else 'C1' end, now() - (g || ' minutes')::interval
    from generate_series(1, 120) g$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(jsonb_array_length(app.list_leads() -> 'rows'), 50, 'Danh sách mặc định 50 dòng');
select is(jsonb_array_length(app.list_leads('{}', 'created_desc', 1000) -> 'rows'), 100, 'Yêu cầu quá lớn bị cắt về tối đa 100 dòng');
select is(jsonb_array_length(app.list_leads('{}', 'created_desc', 0) -> 'rows'), 1, 'Cỡ trang tối thiểu 1');
select ok((app.list_leads() ->> 'total')::int >= 125, 'Danh sách trả tổng số (để phân trang)');
select is(jsonb_array_length(app.list_leads('{}', 'created_desc', 50, 100) -> 'rows'), (app.list_leads() ->> 'total')::int - 100, 'Trang cuối đúng số dòng còn lại');
select is((app.list_leads('{"stage": ["C2"]}') ->> 'total')::int, 30, 'Lọc theo giai đoạn ở DB');
select is((app.list_leads('{"q": "pHỤ HUYNH SỐ 7"}') ->> 'total')::int, 11, 'Tìm kiếm không dấu, không phân biệt hoa thường ("số 7" khớp 7 và 70–79)');
select is((app.list_leads('{"q": "phu huynh so 77"}') ->> 'total')::int, 1, 'Tìm kiếm gõ không dấu');
select is((app.list_leads('{"mine": true}') ->> 'total')::int, (select count(*)::int from app.lead where owner_id = auth.uid()), 'Chip "Tôi phụ trách"');
select is(app.list_leads('{}', 'name_asc', 1) -> 'rows' -> 0 ->> 'parent_name', (select min(parent_name) from app.lead where record_status = 'DANG_DUNG'),
          'Sắp xếp theo tên ở DB');
select is((select array_agg(k order by k) from jsonb_object_keys(app.list_leads('{}', 'created_desc', 1) -> 'rows' -> 0) k),
          array['assigned_at', 'branch_code', 'campaign_id', 'campaign_name', 'channel_code', 'code', 'created_at', 'id', 'merged_into_code',
                'next_appointment_at', 'owner_id', 'owner_name', 'parent_name', 'parent_phone', 'record_status', 'source_code',
                'source_type_code', 'stage_code', 'student_birth_year', 'student_name', 'substage_code', 'supporter_id', 'supporter_name'], 'Danh sách chỉ lấy các cột màn hiện (không có ô Nhu cầu, Mục tiêu…)');
select ok(app.list_leads('{}', 'created_desc', 1) -> 'rows' -> 0 ->> 'owner_name' is not null, 'Danh sách có tên người phụ trách');
select pg_temp.sudo($$update app.lead set record_status = 'DA_GOP',
  merged_into_id = (select id from app.lead where code = 'LDT2') where code = 'LDT1'$$);
select is((app.list_leads('{"q": "0999000001"}') ->> 'total')::int, 0, 'Bản "Đã gộp" ẩn khỏi danh sách mặc định');
select is((app.list_leads('{"q": "0999000001", "include_merged": true}') ->> 'total')::int, 1, 'Tìm được bản "Đã gộp" khi bật hiện');
select is(app.list_leads('{"q": "0999000001", "include_merged": true}') -> 'rows' -> 0 ->> 'merged_into_code', 'LDT2', 'Bản đã gộp ghi mã bản giữ lại');

select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_leads() ->> 'total')::int, 0, 'Danh sách tôn trọng phạm vi: CS5 không thấy lead CS1');

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((app.list_appointments('{}') ->> 'total')::int >= 2, 'Danh sách lịch hẹn trả lịch của cơ sở mình');
select is((app.list_appointments(format('{"lead_id": "%s"}', (select lead_id from t))::jsonb) ->> 'total')::int, 2, 'Lọc lịch hẹn theo hồ sơ gắn');
select is((app.list_appointments(format('{"lead_id": "%s", "status": ["HUY"]}', (select lead_id from t))::jsonb) ->> 'total')::int, 1, 'Lọc lịch hẹn theo trạng thái (một lịch đã huỷ)');
select is((app.list_appointments(format('{"lead_id": "%s", "from": "%s", "to": "%s"}', (select lead_id from t),
           now() + interval '36 hours', now() + interval '3 days')::jsonb) ->> 'total')::int, 1, 'Lọc lịch hẹn theo khoảng thời gian ("Tuần này")');
select is(app.list_appointments('{}', 'time_asc', 1) -> 'rows' -> 0 ->> 'lead_code' is not null, true, 'Lịch hẹn có mã hồ sơ gắn (cột "Gắn với")');
select is(app.appointment_overdue_count(now() + interval '10 days', true), (select count(*)::int from app.appointment where owner_id = auth.uid() and status = 'CHUA_LAM'),
          'Dải nhắc quá hạn đếm lịch Chưa làm của tôi trước mốc');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_appointments('{}') ->> 'total')::int, 0, 'Lịch hẹn tôn trọng phạm vi: CS5 không thấy lịch của CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.list_leads()$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không có quyền xem danh sách lead: báo lỗi');
select is(pg_temp.err($$select app.list_appointments()$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không có quyền xem lịch hẹn: báo lỗi');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_leads('{"include_merged": true}') ->> 'total')::int, (select count(*)::int from app.lead), 'ADMIN (toàn hệ thống) thấy mọi lead trong danh sách');

select * from finish();
rollback;
