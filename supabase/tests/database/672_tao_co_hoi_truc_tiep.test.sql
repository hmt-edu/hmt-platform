begin;
-- Migration 672 (E-26-01): app.create_opportunity_direct, cơ hội không qua lead.
-- Luật: R-CRM-01 (tạo trực tiếp; trùng SĐT cảnh báo kèm mã, xác nhận lần hai), R-CRM-03 (từ L5 em đủ tên, năm sinh),
--   R-CRM-23 (danh sách em, tối đa), R-CRM-27 (phụ huynh theo SĐT), spec 06 mục 1.1 (nguồn), E67 (không lộ mã ngoài phạm vi). Dữ liệu giả.
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
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.branch(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
create function pg_temp.data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Trực Tiếp', 'parent_phone', p_phone, 'need', 'Cần học Toán',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
-- Gọi hàm tạo, trả về câu SQL để dùng với err/msg.
create function pg_temp.sql_tao(p_data jsonb, p_students jsonb default '[]'::jsonb, p_confirm boolean default false, p_parent uuid default null)
returns text language sql as $$
  select format('select app.create_opportunity_direct(%L::jsonb, %L::jsonb, %L, %L)', p_data, p_students, p_confirm, p_parent);
$$;
create function pg_temp.opp(p_phone text) returns app.opportunity language sql stable security definer as $$
  select o.* from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1 $$;
create function pg_temp.so_co_hoi(p_phone text) returns integer language sql stable security definer as $$
  select count(*)::int from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone $$;
create function pg_temp.so_phu_huynh(p_phone text) returns integer language sql stable security definer as $$
  select count(*)::int from app.parent where phone = p_phone $$;
create function pg_temp.so_em(p_opp uuid) returns integer language sql stable security definer as $$
  select count(*)::int from app.prospect_student where opportunity_id = p_opp $$;
create function pg_temp.co_nhat_ky(p_id uuid) returns boolean language sql stable security definer as $$
  select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id
                  where t.table_name = 'app.opportunity' and a.record_id = p_id and a.action = 'I' and a.actor = auth.uid()) $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sales5'), ('cskh1'), ('bm1'), ('teacher1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e672.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e672.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('cskh1', 'CS1'), ('bm1', 'CS1'), ('teacher1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales5', 'SALES'), ('cskh1', 'CSKH'),
                                        ('bm1', 'BRANCH_MANAGER'), ('teacher1', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Tạo được, không lead =================
select lives_ok(pg_temp.sql_tao(pg_temp.data('0900672001'),
  '[{"full_name": "Em Một", "birth_year": 2013}, {"full_name": "Em Hai"}]'),
  'R-CRM-01: Tuyển sinh tạo được cơ hội trực tiếp, không cần lead');
select is((pg_temp.opp('0900672001')).lead_id, null, 'Cơ hội trực tiếp: lead_id trống');
select is((pg_temp.opp('0900672001')).stage_code, 'L1', 'Giai đoạn đầu L1');
select is((pg_temp.opp('0900672001')).substage_code, null, 'L1 không có nhóm con');
select is((pg_temp.opp('0900672001')).owner_id, pg_temp.uid('sales1'), 'Người phụ trách mặc định là người tạo');
select is((pg_temp.opp('0900672001')).branch_id, pg_temp.branch('CS1'), 'Cơ sở mặc định là cơ sở đang làm việc');
select is((pg_temp.opp('0900672001')).source_code, 'FACEBOOK_ADS', 'Ghi đúng nguồn');
select is(pg_temp.so_em((pg_temp.opp('0900672001')).id), 2, 'R-CRM-23: ghi đủ danh sách em');
select ok(pg_temp.co_nhat_ky((pg_temp.opp('0900672001')).id), 'Có nhật ký tạo cơ hội, đúng người làm');

-- ================= Các màn đọc không giả định có lead =================
select is((app.list_opportunities('{"q": "0900672001"}') ->> 'total')::int, 1, 'Danh sách đếm cơ hội không lead');
select is(app.list_opportunities('{"q": "0900672001"}') -> 'rows' -> 0 ->> 'code', (pg_temp.opp('0900672001')).code,
  'Danh sách TRẢ DÒNG cơ hội không lead');
select is(app.list_opportunities('{"q": "0900672001"}') -> 'rows' -> 0 ->> 'lead_code', null, 'Dòng danh sách: mã lead trống');
select is(app.get_opportunity((pg_temp.opp('0900672001')).id) ->> 'lead_code', null, 'Mở bản ghi cơ hội không lead được');
select lives_ok(format('select * from app.record_notes(''OPPORTUNITY'', %L)', (pg_temp.opp('0900672001')).id),
  'Đọc ghi chú cơ hội không lead được');
select is(pg_temp.err(format('select app.add_lead_students_to_opportunity(%L)', (pg_temp.opp('0900672001')).id)),
  'HMT_CO_HOI_KHONG_CO_LEAD', 'Không chép em từ lead cho cơ hội không có lead');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.export_opportunities('{"q": "0900672001"}') -> 'rows' -> 0 ->> 'code', (pg_temp.opp('0900672001')).code,
  'Xuất file có cơ hội không lead');

-- ================= Quyền và phạm vi =================
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672010'))), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không có quyền tạo cơ hội');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672011', jsonb_build_object('branch_id', pg_temp.branch('CS5'))))),
  'HMT_KHONG_CO_QUYEN', 'Tuyển sinh không tạo được cơ hội ở cơ sở khác');
select is(pg_temp.so_phu_huynh('0900672011'), 0, 'Bị chặn thì không sinh phụ huynh');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select lives_ok(pg_temp.sql_tao(pg_temp.data('0900672012')), 'CSKH tạo được trong cơ sở mình');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok(pg_temp.sql_tao(pg_temp.data('0900672013')), 'Trưởng cơ sở tạo được trong cơ sở mình');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select lives_ok(pg_temp.sql_tao(pg_temp.data('0900672014',
  jsonb_build_object('branch_id', pg_temp.branch('CS5'), 'owner_id', pg_temp.uid('sales5')))), 'Admin tạo được ở cơ sở khác, giao sale của cơ sở đó');

-- ================= Dữ liệu bắt buộc =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672020', '{"parent_name": " "}'))), 'HMT_THIEU_THONG_TIN', 'Thiếu họ tên phụ huynh');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('12345'))), 'HMT_SDT_SAI', 'Số điện thoại sai');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672021') - 'source_code')), 'HMT_THIEU_NGUON', 'Spec 06 mục 1.1: thiếu Source');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672022') - 'channel_code')), 'HMT_THIEU_NGUON', 'Spec 06 mục 1.1: nguồn có kênh con thì bắt buộc Medium');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672023'),
  (select jsonb_agg(jsonb_build_object('full_name', 'Em ' || n))
     from generate_series(1, app.get_setting_int('prospect_max_students', pg_temp.branch('CS1'))::int + 1) n))),
  'HMT_EM_TOI_DA', 'R-CRM-23: vượt số em tối đa bị chặn');
select is(pg_temp.so_co_hoi('0900672023') + pg_temp.so_phu_huynh('0900672023'), 0, 'Vượt số em thì không tạo gì cả');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672024'), '[{"birth_year": 2013}]')), 'HMT_THIEU_TEN_EM', 'R-CRM-23: em mới bắt buộc họ tên');

-- ================= R-CRM-03: từ L5 phải đủ tên, năm sinh =================
select lives_ok(pg_temp.sql_tao(pg_temp.data('0900672030'), '[{"full_name": "Em Chưa Năm"}]'), 'L1 cho phép em chưa có năm sinh');
select is(pg_temp.err(format('select app.change_opportunity_stage(%L, ''L5'')', (pg_temp.opp('0900672030')).id)),
  'HMT_THIEU_HOC_SINH', 'R-CRM-03: cơ hội trực tiếp lên L5 mà em thiếu năm sinh bị chặn');

-- ================= R-CRM-01: trùng số điện thoại =================
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672001'))), 'HMT_SDT_TRUNG', 'Trùng SĐT với cơ hội đang dùng thì cảnh báo');
select matches(pg_temp.msg(pg_temp.sql_tao(pg_temp.data('0900672001'))), (pg_temp.opp('0900672001')).code, 'Cảnh báo nêu mã cơ hội cũ');
select lives_ok(pg_temp.sql_tao(pg_temp.data('0900672001', '{"parent_name": "Tên Khác"}'), '[]', true), 'Xác nhận lần hai thì tạo thêm được');
select is(pg_temp.so_co_hoi('0900672001'), 2, 'Có hai cơ hội cùng phụ huynh');
select is(pg_temp.so_phu_huynh('0900672001'), 1, 'R-CRM-27: dùng lại phụ huynh theo SĐT, không tạo mới');
select is(pg_temp.err(pg_temp.sql_tao('{"source_type_code": "MARKETING", "source_code": "FACEBOOK_ADS", "channel_code": "FACEBOOK_ADS_LEAD_FORM"}'::jsonb,
  '[]', false, (pg_temp.opp('0900672001')).parent_id)), 'HMT_SDT_TRUNG', 'Chọn phụ huynh có sẵn vẫn cảnh báo cơ hội cũ');
select lives_ok(pg_temp.sql_tao('{"source_type_code": "MARKETING", "source_code": "FACEBOOK_ADS", "channel_code": "FACEBOOK_ADS_LEAD_FORM"}'::jsonb,
  '[]', true, (pg_temp.opp('0900672001')).parent_id), 'Phụ huynh có sẵn: không cần nhập lại tên, SĐT');
select is(pg_temp.so_co_hoi('0900672001'), 3, 'Cơ hội mới gắn đúng phụ huynh đã chọn');

select app.create_lead(pg_temp.data('0900672040'));
select matches(pg_temp.msg(pg_temp.sql_tao(pg_temp.data('0900672040'))), 'LD', 'Trùng SĐT với lead: cảnh báo nêu mã lead cũ');
select is(pg_temp.so_co_hoi('0900672040'), 0, 'Chưa xác nhận thì không tạo');

-- Người cơ sở khác: vẫn cảnh báo nhưng không lộ mã (E67).
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err(pg_temp.sql_tao(pg_temp.data('0900672001'))), 'HMT_SDT_TRUNG', 'Trùng với hồ sơ cơ sở khác vẫn cảnh báo');
select matches(pg_temp.msg(pg_temp.sql_tao(pg_temp.data('0900672001'))), 'ngoài phạm vi', 'Báo có hồ sơ ngoài phạm vi');
select doesnt_match(pg_temp.msg(pg_temp.sql_tao(pg_temp.data('0900672001'))), 'CO[0-9-]', 'Không lộ mã cơ hội ngoài phạm vi');

-- Hàm trong không gọi thẳng được.
select is(pg_temp.err($$select app.assert_no_phone_duplicate(array['0900672001'], null)$$), '42501', 'Hàm kiểm trùng không cấp cho người dùng');

select * from finish();
rollback;
