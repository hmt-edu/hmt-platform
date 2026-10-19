-- P3c-1a: dữ liệu màn Lead danh sách và Kanban (docs/spec/04 R-CRM-07, 09, 22, 29; TS-01, TS-01b, TS-05).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò nhập trong và ngoài cơ sở.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
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
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs');
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


-- ================= Dựng dữ liệu =================
select pg_temp.sudo($$insert into app.campaign (name) values ('Chiến dịch thử lọc')$$);
select pg_temp.sudo($$create function pg_temp.camp() returns uuid language sql stable security definer as 'select id from app.campaign where name = ''Chiến dịch thử lọc'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.camp() to public$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- 6 lead ở CS1 do sales1 phụ trách (L1..L6), 1 lead CS1 của sales1b, 1 lead CS5.
create temp table ld (k text primary key, id uuid);
grant select on ld to public;
insert into ld select 'L' || n, (app.create_lead(pg_temp.lead_data('09000006' || lpad(n::text, 2, '0'), jsonb_build_object('parent_name', 'Phụ Huynh Lọc ' || n))) ->> 'id')::uuid
  from generate_series(1, 6) n;
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
insert into ld select 'B1', (app.create_lead(pg_temp.lead_data('0900000670', '{"parent_name": "Phụ Huynh Của Bạn"}')) ->> 'id')::uuid;
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
insert into ld select 'X5', (app.create_lead(pg_temp.lead_data('0900000680', '{"parent_name": "Phụ Huynh Cơ Sở Năm"}')) ->> 'id')::uuid;
reset role;
-- Lịch hẹn kế tiếp: L1 quá hạn (hôm qua), L2 hôm nay, L3 ngày mai, L4 sau 10 ngày, L5 và L6 chưa có.
update app.lead set next_appointment_at = now() - interval '1 day' where id = (select id from ld where k = 'L1');
update app.lead set next_appointment_at = date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh' + interval '12 hours' where id = (select id from ld where k = 'L2');
update app.lead set next_appointment_at = date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh' + interval '1 day 12 hours' where id = (select id from ld where k = 'L3');
update app.lead set next_appointment_at = now() + interval '10 days' where id = (select id from ld where k = 'L4');
update app.lead set stage_code = 'C2', substage_code = 'C2A', channel_code = 'FACEBOOK_ADS_CHAT', campaign_id = pg_temp.camp(), supporter_id = pg_temp.uid('cskh1')
 where id = (select id from ld where k = 'L2');
update app.lead set stage_code = 'C3' where id = (select id from ld where k = 'L3');
update app.lead set source_type_code = 'REFERRAL', source_code = 'REFERRAL', channel_code = 'REFERRAL_BY_CUSTOMER' where id = (select id from ld where k = 'L4');
create function pg_temp.n(p_filters jsonb) returns bigint language sql stable as $$ select (app.list_leads(p_filters) ->> 'total')::bigint $$;
grant execute on function pg_temp.n(jsonb) to public;
create function pg_temp.base() returns jsonb language sql stable as $$ select jsonb_build_object('q', 'Phụ Huynh') $$;
grant execute on function pg_temp.base() to public;
create function pg_temp.today() returns timestamptz language sql stable as $$ select date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh' $$;
grant execute on function pg_temp.today() to public;

-- ================= Bộ lọc list_leads (R-CRM-07) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.n(pg_temp.base()), 7::bigint, 'Trưởng cơ sở CS1 thấy 7 lead cơ sở mình (không thấy CS5)');
select is(pg_temp.n(pg_temp.base() || '{"next_before": "9999-01-01T00:00:00Z"}'), 4::bigint, 'next_before xa: 4 lead có lịch');
select is(pg_temp.n(pg_temp.base() || jsonb_build_object('next_before', pg_temp.today())), 1::bigint, 'Quá hạn: lịch kế tiếp trước đầu ngày hôm nay (L1)');
select is(pg_temp.n(pg_temp.base() || '{"no_appointment": true}'), 3::bigint, 'Chưa có lịch: 3 lead');
select is(pg_temp.n(pg_temp.base() || jsonb_build_object('next_from', pg_temp.today() + interval '1 day')), 2::bigint, 'Sắp tới: từ ngày mai trở đi (L3, L4)');
select is(pg_temp.n(pg_temp.base() || '{"channel": ["FACEBOOK_ADS_CHAT"]}'), 1::bigint, 'Lọc theo kênh');
select is(pg_temp.n(pg_temp.base() || jsonb_build_object('campaign_id', pg_temp.camp())), 1::bigint, 'Lọc theo chiến dịch');
select is(pg_temp.n(pg_temp.base() || '{"stage": ["C2", "C3"]}'), 2::bigint, 'Cùng nhóm lọc: HOẶC');
select is(pg_temp.n(pg_temp.base() || '{"stage": ["C2", "C3"], "source_type": ["REFERRAL"]}'), 0::bigint, 'Khác nhóm lọc: VÀ');
select is(pg_temp.n(pg_temp.base() || '{"supporter_mine": true}'), 0::bigint, 'Tôi hỗ trợ: Trưởng cơ sở không hỗ trợ lead nào');
select is(pg_temp.n(pg_temp.base() || jsonb_build_object('owner_id', pg_temp.uid('sales1'))), 6::bigint, 'Lọc theo người phụ trách');
select is(app.list_leads(pg_temp.base() || '{"owner_id": "00000000-0000-0000-0000-000000000000"}') -> 'rows', '[]'::jsonb, 'Người phụ trách không có lead: rỗng');
select is(app.list_leads(pg_temp.base() || jsonb_build_object('campaign_id', pg_temp.camp())) -> 'rows' -> 0 ->> 'campaign_name', 'Chiến dịch thử lọc', 'Có cột campaign_name');
select isnt(app.list_leads(pg_temp.base() || jsonb_build_object('campaign_id', pg_temp.camp())) -> 'rows' -> 0 ->> 'supporter_name', null, 'Có cột supporter_name');
-- Tôi phụ trách / tôi hỗ trợ với người đúng.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.n(pg_temp.base() || '{"supporter_mine": true}'), 1::bigint, 'Tôi hỗ trợ: CSKH thấy lead mình hỗ trợ');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.n(pg_temp.base() || '{"mine": true}'), 6::bigint, 'Tôi phụ trách: 6 lead');
select is(pg_temp.n(pg_temp.base()), 7::bigint, 'Không lọc: sales1 thấy cả lead của sales1b cùng cơ sở (quyền CO_SO)');
-- Bản đã gộp.
reset role;
update app.lead set record_status = 'DA_GOP', merged_into_id = (select id from ld where k = 'L1') where id = (select id from ld where k = 'L6');
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.n(pg_temp.base()), 6::bigint, 'Mặc định ẩn bản "Đã gộp"');
select is(pg_temp.n(pg_temp.base() || '{"only_merged": true}'), 1::bigint, 'Chỉ bản "Đã gộp": 1');
select is(pg_temp.n(pg_temp.base() || '{"include_merged": true}'), 7::bigint, 'Gồm cả bản "Đã gộp": 7');

-- ================= Kanban lead_board =================
select is(jsonb_array_length(app.lead_board(pg_temp.base())), 4, 'lead_board trả 4 cột C1 đến C4');
select is((select sum((c ->> 'total')::int) from jsonb_array_elements(app.lead_board(pg_temp.base())) c), 6::bigint, 'Tổng các cột = số lead đang dùng (không tính bản đã gộp)');
select is((select (c -> 'bar') from jsonb_array_elements(app.lead_board(pg_temp.base())) c where c ->> 'stage_code' = 'C1'),
          '{"ok": 1, "today": 0, "overdue": 1, "none": 2}'::jsonb, 'Thanh màu C1: L1 quá hạn, L4 sắp tới, L5 và B1 chưa có');
select is((select (c -> 'bar') from jsonb_array_elements(app.lead_board(pg_temp.base())) c where c ->> 'stage_code' = 'C2'),
          '{"ok": 0, "today": 1, "overdue": 0, "none": 0}'::jsonb, 'Thanh màu C2: L2 hôm nay (giờ Việt Nam)');
select is((select jsonb_array_length(c -> 'rows') from jsonb_array_elements(app.lead_board(pg_temp.base(), 1)) c where c ->> 'stage_code' = 'C1'), 1,
          'Số thẻ mỗi cột theo p_per_column');
select is((select (c ->> 'total')::int from jsonb_array_elements(app.lead_board(pg_temp.base(), 1)) c where c ->> 'stage_code' = 'C1'), 4, 'Tổng cột C1 không bị cắt theo số thẻ');
select is((select (c ->> 'total')::int from jsonb_array_elements(app.lead_board(pg_temp.base() || '{"no_appointment": true}')) c where c ->> 'stage_code' = 'C1'), 2,
          'Lọc next_* chỉ lọc tổng và thẻ của cột');
select is((select sum((c ->> 'total')::int) from jsonb_array_elements(app.lead_board(pg_temp.base() || '{"channel": ["FACEBOOK_ADS_CHAT"]}')) c), pg_temp.n(pg_temp.base() || '{"channel": ["FACEBOOK_ADS_CHAT"]}'),
          'Nhất quán: tổng lead_board = tổng list_leads cùng bộ lọc');

-- ================= Group By lead_group_counts =================
select is((app.lead_group_counts(pg_temp.base(), array['stage']) ->> 'total')::bigint, pg_temp.n(pg_temp.base()), 'Nhất quán: tổng nhóm = tổng list_leads');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.lead_group_counts(pg_temp.base(), array['stage']) -> 'groups') g where g ->> 'k1' = 'C1'), 4, 'Nhóm theo giai đoạn: C1 có 4');
select is((select g ->> 'l1' from jsonb_array_elements(app.lead_group_counts(pg_temp.base(), array['stage']) -> 'groups') g where g ->> 'k1' = 'C1'), (select name from app.catalog_item where catalog_code = 'LEAD_STAGE' and code = 'C1'), 'Nhãn nhóm là tên danh mục');
select is((app.lead_group_counts(pg_temp.base(), array['stage', 'substage']) ->> 'total')::bigint, pg_temp.n(pg_temp.base()), 'Nhóm hai cấp: tổng khớp');
select is((select g ->> 'l2' from jsonb_array_elements(app.lead_group_counts(pg_temp.base(), array['stage', 'substage']) -> 'groups') g where g ->> 'k1' = 'C1' limit 1), 'Chưa có', 'Giá trị rỗng gọi là "Chưa có"');
select isnt(app.lead_group_counts(pg_temp.base(), array['owner']) -> 'groups' -> 0 ->> 'l1', null, 'Nhóm theo người phụ trách có tên');
select is(pg_temp.err($$select app.lead_group_counts('{}', array['stage', 'stage'])$$), 'HMT_NHOM_SAI', 'Hai cấp phải khác nhau');
select is(pg_temp.err($$select app.lead_group_counts('{}', array['password'])$$), 'HMT_NHOM_SAI', 'Chỉ nhóm theo trường cho phép');
select is(pg_temp.err($$select app.lead_group_counts('{}', array[]::text[])$$), 'HMT_NHOM_SAI', 'Phải có ít nhất một trường nhóm');

-- ================= Nhân sự được giao list_assignable_staff =================
select is((select count(*) from app.list_assignable_staff('LEAD') where id = pg_temp.uid('sales1')), 1::bigint, 'Danh sách giao có nhân viên cùng cơ sở');
select is((select count(*) from app.list_assignable_staff('LEAD') where id = pg_temp.uid('sales5')), 0::bigint, 'Không có nhân viên cơ sở khác');
select is((select count(*) from app.list_assignable_staff('LEAD') where id = pg_temp.uid('hs') or id = pg_temp.uid('teacher5')), 0::bigint, 'Không có học sinh, giáo viên');
select is(pg_temp.err($$select * from app.list_assignable_staff('LEAD', (select id from app.branch where code = 'CS5'))$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở không xem nhân sự cơ sở khác');
select is(pg_temp.err($$select * from app.list_assignable_staff('LOP_HOC')$$), 'HMT_LOAI_BAN_GHI_SAI', 'Loại bản ghi chưa hỗ trợ');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select count(*) from app.list_assignable_staff('LEAD', (select id from app.branch where code = 'CS5')) where id = pg_temp.uid('sales5')), 1::bigint, 'Admin chọn cơ sở khác được');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select * from app.list_assignable_staff('LEAD')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không có quyền giao việc');

-- ================= Lọc nhiều lựa chọn cùng nhóm (R-CRM-07, migration 034) =================
reset role;
-- B1 (của sales1b) do sales1 hỗ trợ: để thử "Tôi phụ trách" HOẶC "Tôi hỗ trợ".
update app.lead set supporter_id = pg_temp.uid('sales1') where id = (select id from ld where k = 'B1');
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["OVERDUE"]}'), 1::bigint, 'Lịch hẹn Quá hạn: 1 (L1)');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["TODAY"]}'), 1::bigint, 'Lịch hẹn Hôm nay: 1 (L2)');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["UPCOMING"]}'), 2::bigint, 'Lịch hẹn Sắp tới: từ ngày mai (L3, L4)');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["NONE"]}'), 2::bigint, 'Lịch hẹn Chưa có: L5 và B1 (L6 đã gộp)');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["OVERDUE", "UPCOMING"]}'), 3::bigint, 'Cùng nhóm Lịch hẹn là HOẶC: Quá hạn hoặc Sắp tới (hai mốc không liền nhau)');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["OVERDUE", "TODAY", "UPCOMING", "NONE"]}'), 6::bigint, 'Chọn đủ bốn mốc = không lọc');
select is(pg_temp.n(pg_temp.base() || '{"appointment": ["OVERDUE", "TODAY"], "stage": ["C2"]}'), 1::bigint, 'Khác nhóm là VÀ: Quá hạn hoặc Hôm nay, và ở C2');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.n(pg_temp.base() || '{"mine_roles": ["OWNER"]}'), 5::bigint, 'Tôi phụ trách: 5 lead đang dùng');
select is(pg_temp.n(pg_temp.base() || '{"mine_roles": ["SUPPORT"]}'), 1::bigint, 'Tôi hỗ trợ: 1 lead (B1)');
select is(pg_temp.n(pg_temp.base() || '{"mine_roles": ["OWNER", "SUPPORT"]}'), 6::bigint, 'Cùng nhóm Của tôi là HOẶC: phụ trách hoặc hỗ trợ');
-- Nhất quán giữa bốn hàm với cùng bộ lọc mới.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is((select sum((c ->> 'total')::int) from jsonb_array_elements(app.lead_board(pg_temp.base() || '{"appointment": ["OVERDUE", "UPCOMING"]}')) c), 3::bigint,
          'Nhất quán: lead_board với appointment cùng tổng list_leads');
select is((select (c -> 'bar') from jsonb_array_elements(app.lead_board(pg_temp.base() || '{"appointment": ["OVERDUE"]}')) c where c ->> 'stage_code' = 'C1'),
          '{"ok": 1, "today": 0, "overdue": 1, "none": 2}'::jsonb, 'Lọc Lịch hẹn không đổi số đếm thanh màu');
select is((app.lead_group_counts(pg_temp.base() || '{"appointment": ["OVERDUE", "UPCOMING"]}', array['stage']) ->> 'total')::bigint, 3::bigint,
          'Nhất quán: lead_group_counts với appointment cùng tổng list_leads');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select (c ->> 'total')::int from jsonb_array_elements(app.lead_board(pg_temp.base() || '{"mine_roles": ["OWNER", "SUPPORT"]}')) c where c ->> 'stage_code' = 'C1'), 4,
          'Nhất quán: lead_board với mine_roles (C1: L1, L4, L5, B1)');

-- ================= Xuất export_leads (R-CRM-29) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.export_leads('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên kinh doanh không có quyền xuất');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is((app.export_leads(pg_temp.base()) ->> 'exported')::int, 6, 'Trưởng cơ sở xuất được đúng số lead trong phạm vi');
select is((select count(*) from app.export_log where module_code = 'LEAD' and row_count = 6), 1::bigint, 'Xuất file ghi nhật ký xuất');
select isnt(app.export_leads(pg_temp.base()) -> 'rows' -> 0 ->> 'stage', null, 'Dòng xuất có tên giai đoạn (không phải mã)');
select is((app.export_leads(pg_temp.base() || '{"appointment": ["OVERDUE", "UPCOMING"]}') ->> 'exported')::int, 3, 'Xuất cũng theo bộ lọc nhiều lựa chọn cùng nhóm');
select is((app.export_leads('{"q": "Cơ Sở Năm"}') ->> 'exported')::int, 0, 'Xuất không lấy lead cơ sở khác');
reset role;
update app.setting_def set value = '2' where key = 'export_max_rows';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(app.export_leads(pg_temp.base()) - 'rows', '{"total": 6, "exported": 2, "truncated": true}'::jsonb, 'Quá export_max_rows: cắt và báo đã cắt');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.export_leads(pg_temp.base() || '{"include_merged": true}') ->> 'total')::int, 8, 'Admin xuất toàn hệ thống');

-- Xem toàn hệ thống nhưng Xuất chỉ trong cơ sở: phạm vi dòng theo quyền Xuất.
reset role;
update app.permission set scope_code = 'TOAN_HE_THONG' where role_code = 'BRANCH_MANAGER' and module_code = 'LEAD' and action_code = 'XEM';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is((app.export_leads('{"q": "Cơ Sở Năm"}') ->> 'exported')::int, 0, 'Xem toàn hệ thống + Xuất trong cơ sở: không xuất lead cơ sở khác');
select is(pg_temp.n('{"q": "Cơ Sở Năm"}'), 1::bigint, 'Cùng vai trò đó vẫn xem được lead cơ sở khác trên danh sách');

-- ================= change_lead_stage: C4 không tự gắn C4D (R-CRM-09) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.change_lead_stage((select id from ld where k = 'L5'), 'C4');
select is((select substage_code from app.lead where id = (select id from ld where k = 'L5')), null, 'R-CRM-09: kéo sang C4 không tự gắn C4D');
select is(pg_temp.err($$select app.change_lead_stage((select id from ld where k = 'L5'), 'C4', 'C4D')$$), 'HMT_C4D_HE_THONG', 'R-CRM-09: người dùng không gắn C4D được');
select app.change_lead_stage((select id from ld where k = 'L5'), 'C4', 'C4B');
select app.change_lead_stage((select id from ld where k = 'L5'), 'C2', 'C2A');
select app.change_lead_stage((select id from ld where k = 'L5'), 'C4');
select isnt((select substage_code from app.lead where id = (select id from ld where k = 'L5')), 'C4D', 'R-CRM-09: lead rời rồi về C4 không lấy lại C4D');

select * from finish();
rollback;
