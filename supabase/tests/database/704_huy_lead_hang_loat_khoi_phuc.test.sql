-- R-CRM-45, R-CRM-46: quyền huỷ lead theo ma trận, huỷ hàng loạt, khôi phục, lọc «Thùng rác» (migration 704).
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@b704.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@b704.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

select pg_temp.sudo($$create temp table t (k text primary key, id uuid)$$);
select pg_temp.sudo($$grant all on t to public$$);
create function pg_temp.lid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from t where k = p_key); end $$;
grant execute on function pg_temp.lid(text) to public;

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into t select 'a', (app.create_lead(pg_temp.lead_data('0900704001'))->>'id')::uuid;
insert into t select 'b', (app.create_lead(pg_temp.lead_data('0900704002'))->>'id')::uuid;
insert into t select 'c', (app.create_lead(pg_temp.lead_data('0900704003'))->>'id')::uuid;
insert into t select 'hen', (app.create_lead(pg_temp.lead_data('0900704004'))->>'id')::uuid;
select app.create_appointment(pg_temp.lid('hen'), 'GOI_DIEN', now() + interval '1 day', 'Gọi lại');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
insert into t select 'cs5', (app.create_lead(pg_temp.lead_data('0900704005'))->>'id')::uuid;
insert into t select 'cs5b', (app.create_lead(pg_temp.lead_data('0900704006'))->>'id')::uuid;

-- ---------- Tư vấn: chỉ lead mình phụ trách, từng cái ----------
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.err($$select app.cancel_wrong_lead(pg_temp.lid('a'), 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN',
          'R-CRM-45 chặn: Tư vấn không huỷ được lead người khác phụ trách');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.lead_cancel_options(), '{"single": true, "bulk": false, "bulk_max": null, "restore": false}'::jsonb,
          'R-CRM-45: Tư vấn được huỷ từng cái, không hàng loạt, không khôi phục');
select is(pg_temp.err($$select app.cancel_wrong_leads(array[pg_temp.lid('a')], 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN',
          'R-CRM-45 chặn: Tư vấn không huỷ hàng loạt');
select is(pg_temp.err($$select app.cancel_wrong_lead(pg_temp.lid('a'), 'Nhập nhầm')$$), null,
          'R-CRM-45 đúng: Tư vấn huỷ được lead mình phụ trách');

-- ---------- CSKH: không có quyền ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.cancel_wrong_lead(pg_temp.lid('b'), 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN',
          'R-CRM-45 chặn: CSKH không huỷ lead');
select is(pg_temp.err($$select app.cancel_wrong_leads(array[pg_temp.lid('b')], 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN',
          'R-CRM-45 chặn: CSKH không huỷ hàng loạt');

-- ---------- Trưởng cơ sở: cơ sở mình, có trần mỗi lần ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.lead_cancel_options() ->> 'bulk_max')::int, app.get_setting_int('lead_cancel_bulk_max')::int,
          'R-CRM-45: trần của Trưởng cơ sở lấy từ tham số');
select is(pg_temp.err($$select app.cancel_wrong_lead(pg_temp.lid('cs5'), 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN',
          'R-CRM-45 chặn: Trưởng cơ sở không huỷ lead cơ sở khác');
select is(pg_temp.err($$select app.cancel_wrong_leads(array[pg_temp.lid('b')], '  ')$$), 'HMT_THIEU_THONG_TIN',
          'R-CRM-45 chặn: huỷ hàng loạt thiếu lý do');
select is(pg_temp.err($$select app.cancel_wrong_leads('{}'::uuid[], 'x')$$), 'HMT_THIEU_THONG_TIN',
          'R-CRM-45 chặn: chưa chọn lead nào');
select pg_temp.sudo($$update app.setting_def set value = '2' where key = 'lead_cancel_bulk_max'$$);
select is(pg_temp.err($$select app.cancel_wrong_leads(array[pg_temp.lid('b'), pg_temp.lid('c'), pg_temp.lid('hen')], 'x')$$),
          'HMT_HUY_QUA_NHIEU', 'R-CRM-45 chặn: vượt trần mỗi lần');
select pg_temp.sudo($$update app.setting_def set value = '10' where key = 'lead_cancel_bulk_max'$$);
create temp table r (k text primary key, v jsonb);
insert into r select 'bm', app.cancel_wrong_leads(
  array[pg_temp.lid('b'), pg_temp.lid('b'), pg_temp.lid('hen'), pg_temp.lid('cs5'), pg_temp.lid('a')], 'Nhập trùng đợt');
select is((select (v ->> 'done')::int from r where k = 'bm'), 1, 'R-CRM-45 đúng: huỷ được 1 lead, id lặp chỉ tính một lần');
select is((select jsonb_array_length(v -> 'skipped') from r where k = 'bm'), 3,
          'R-CRM-45: bỏ qua lead có lịch hẹn, lead cơ sở khác, lead đã huỷ');
select ok((select bool_or(s ->> 'reason' like '%lịch hẹn%' and s ->> 'code' is not null)
             from r, jsonb_array_elements(v -> 'skipped') s where r.k = 'bm'),
          'R-CRM-45: dòng bỏ qua có mã lead và lý do');
select ok((select bool_or(s ->> 'id' = pg_temp.lid('cs5')::text and s ->> 'code' is null)
             from r, jsonb_array_elements(v -> 'skipped') s where r.k = 'bm'),
          'Quyền: không lộ mã lead người gọi không xem được');
select is((select record_status from app.lead where id = pg_temp.lid('b')), 'DA_HUY', 'R-CRM-45: lead chuyển Đã huỷ, không xoá');
select is(pg_temp.err($$select app.restore_cancelled_leads(array[pg_temp.lid('b')])$$), 'HMT_KHONG_CO_QUYEN',
          'R-CRM-46 chặn: Trưởng cơ sở không khôi phục');

-- ---------- Admin: mọi cơ sở, không trần; khôi phục ----------
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.sudo($$update app.setting_def set value = '1' where key = 'lead_cancel_bulk_max'$$);
insert into r select 'ad', app.cancel_wrong_leads(array[pg_temp.lid('c'), pg_temp.lid('cs5')], 'Dữ liệu thử');
select is((select (v ->> 'done')::int from r where k = 'ad'), 2, 'R-CRM-45 đúng: Admin huỷ mọi cơ sở, không bị trần');

-- Lọc: mặc định ẩn; «hiện lead đã gộp» không kéo theo lead đã huỷ; «Thùng rác» thấy kèm lý do.
select is((app.list_leads('{"q": "09007040"}') ->> 'total')::int, 2, 'R-CRM-45: danh sách mặc định ẩn lead đã huỷ');
select is((app.list_leads('{"q": "09007040", "include_merged": true}') ->> 'total')::int, 2,
          'B2: hiện lead đã gộp không kéo theo lead đã huỷ');
select is((app.list_leads('{"q": "09007040", "trash": true}') ->> 'total')::int, 4, 'B2: «Thùng rác» gồm lead đã huỷ');
select ok((select bool_and(x ->> 'record_status' in ('DA_HUY', 'DA_GOP'))
             from jsonb_array_elements(app.list_leads('{"trash": true, "q": "09007040"}') -> 'rows') x)
          and (select bool_or(x ->> 'cancel_reason' = 'Nhập trùng đợt')
                 from jsonb_array_elements(app.list_leads('{"trash": true, "q": "09007040"}') -> 'rows') x),
          'B2: «Thùng rác» trả lý do huỷ');
select is((app.export_leads('{"q": "09007040", "trash": true}') ->> 'total')::int, 4, 'B2: xuất file theo cùng bộ lọc');

insert into r select 'kp', app.restore_cancelled_leads(array[pg_temp.lid('b'), pg_temp.lid('hen')]);
select is((select (v ->> 'done')::int from r where k = 'kp'), 1, 'R-CRM-46 đúng: Admin khôi phục lead đã huỷ');
select is((select jsonb_array_length(v -> 'skipped') from r where k = 'kp'), 1, 'R-CRM-46 chặn: lead đang dùng thì bỏ qua');
select is((select record_status from app.lead where id = pg_temp.lid('b')), 'DANG_DUNG', 'R-CRM-46: lead về Đang dùng');
select ok((select cancel_reason is null and cancelled_at is null from app.lead where id = pg_temp.lid('b')),
          'R-CRM-46: xoá thông tin huỷ trên hồ sơ');
select ok(exists (select from app.note where entity_id = pg_temp.lid('b') and body like '%Nhập trùng đợt%' and body like 'Khôi phục%'),
          'R-CRM-46: ghi chú giữ lại lý do huỷ cũ');
select is(pg_temp.err($$update app.lead set parent_name = 'Đổi' where id = pg_temp.lid('c')$$) is not null, true,
          'CHUNG-20: lead đã huỷ vẫn chỉ xem');

-- Trùng số: trong lúc lead nằm «Đã huỷ», số đó đã được tạo lead mới.
insert into t select 'moi', (app.create_lead(pg_temp.lead_data('0900704001'))->>'id')::uuid;
insert into r select 'trung', app.restore_cancelled_leads(array[pg_temp.lid('a')]);
select is((select (v ->> 'done')::int from r where k = 'trung'), 0, 'R-CRM-46 chặn: số đang có lead dùng thì không khôi phục');
select ok((select v -> 'skipped' -> 0 ->> 'reason' like '%' || l.code || '%' from r, app.lead l
            where r.k = 'trung' and l.id = pg_temp.lid('moi')), 'R-CRM-46: dòng bỏ qua nêu mã bản đang dùng');
select is((select record_status from app.lead where id = pg_temp.lid('a')), 'DA_HUY', 'R-CRM-46: lead vẫn Đã huỷ');

select * from finish();
rollback;
