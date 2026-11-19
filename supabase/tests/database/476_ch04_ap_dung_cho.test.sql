-- Migration 476 (Code D, CH-04): Chiết khấu «Áp dụng cho» (Báo giá, Đơn, Phiếu thu): mặc định cả ba, lưu và sửa, giá trị sai bị chặn, danh sách mời chọn lọc theo Báo giá/Đơn. Dữ liệu giả.
-- quá hạn mức thì máy chủ từ chối; cộng dồn vào trần tổng; chính sách hệ thống không sửa ở màn Chiết khấu. Mỗi luật có ca đúng và ca bị chặn.
-- cũ và 2 loại cũ; lead và cơ hội cũ đổi loại sang Marketing theo nguồn, nguồn và kênh giữ nguyên; luật HMT_NGUON_SAI giữ nguyên.
-- Mỗi luật có ca đúng và ca bị chặn; Sale trong cơ sở.
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






-- Trợ giúp: id chính sách theo mã; gọi price_apply_discounts (quyền chủ DB, chỉ đọc) và đọc kết quả.
select pg_temp.sudo($$create function pg_temp.pid(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.apply(p_discounts jsonb) returns jsonb language sql stable security definer as
  'select app.price_apply_discounts(1, ''LC'', (select id from app.branch where code = ''CS1''), current_date, p_discounts)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pid(text), pg_temp.apply(jsonb) to public$$);
create function pg_temp.flex(p_value text) returns jsonb language sql stable as $$
  select jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pid('UU_DAI_LINH_HOAT'), 'value', p_value)) $$;
grant execute on function pg_temp.flex(text) to public;

-- ================= (1) Tham số và chính sách có sẵn =================
select is(app.get_setting('flexible_discount_max_percent'), '5', 'R-V2-45: hạn mức mặc định 5%');
select is((select is_flexible from app.discount_policy where code = 'UU_DAI_LINH_HOAT'), true, 'R-V2-45: có chính sách hệ thống Ưu đãi linh hoạt');
select is((select kind || '/' || fixed_value::text from app.discount_policy where code = 'UU_DAI_LINH_HOAT'), 'PERCENT/false', 'R-V2-45: kiểu % nhập tay (không áp đúng mức)');

-- ================= (2) Nhập trong hạn mức được; nhập quá bị từ chối với câu "Ưu đãi linh hoạt tối đa N%" =================
select is(pg_temp.apply(pg_temp.flex('3')) ->> 'percent', '3', 'R-V2-45: nhập 3% trong hạn mức 5%: được, tính 3%');
select is(pg_temp.apply(pg_temp.flex('5')) ->> 'percent', '5', 'R-V2-45: đúng hạn mức 5%: được');
select is(pg_temp.err($$select pg_temp.apply(pg_temp.flex('5.01'))$$), 'HMT_UU_DAI_VUOT_MUC', 'R-V2-45: nhập 5,01% vượt hạn mức 5%: bị từ chối');
select is(pg_temp.msg($$select pg_temp.apply(pg_temp.flex('8'))$$), 'Ưu đãi linh hoạt tối đa 5%', 'R-V2-45: câu lỗi đúng chữ "Ưu đãi linh hoạt tối đa 5%"');
select is(pg_temp.err($$select pg_temp.apply('[{"policy_id": null}]'::jsonb)$$), 'HMT_CHINH_SACH_KHONG_CO', 'Chính sách không chỉ định: vẫn báo như cũ');
select is(pg_temp.err($$select pg_temp.apply(pg_temp.flex(''))$$), 'HMT_UU_DAI_THIEU_MUC', 'R-V2-45: không nhập % thì từ chối (không có mức mặc định)');
select is(pg_temp.err($$select pg_temp.apply(pg_temp.flex('0'))$$), 'HMT_UU_DAI_THIEU_MUC', 'R-V2-45: 0% bị từ chối');
select is(pg_temp.err($$select pg_temp.apply(pg_temp.flex('-2'))$$), 'HMT_UU_DAI_THIEU_MUC', 'R-V2-45: số âm bị từ chối');

-- ================= (3) Tính vào trần: cộng dồn với chiết khấu khác, vượt trần chỉ cảnh báo =================
select is((pg_temp.apply(pg_temp.flex('4') || jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pid('GIAM_6_THANG')))) ->> 'percent')::numeric, 9::numeric,
          'R-V2-45: ưu đãi 4% cộng dồn chiết khấu 5% thành 9%');
select is((pg_temp.apply(pg_temp.flex('5') || jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pid('GIAM_THUONG_LUONG'), 'value', '10'),
                                                              jsonb_build_object('policy_id', pg_temp.pid('GIAM_6_THANG')))) ->> 'percent')::numeric, 20::numeric,
          'R-V2-45: 5% + 10% + 5% = 20%, đúng trần');
select is(pg_temp.err($$select pg_temp.apply(pg_temp.flex('5') || jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pid('GIAM_THUONG_LUONG'), 'value', '10'), jsonb_build_object('policy_id', pg_temp.pid('GIAM_6_THANG')), jsonb_build_object('policy_id', pg_temp.pid('GIAM_6_THANG'))))$$),
          'HMT_CHINH_SACH_TRUNG', 'Luật cũ giữ nguyên: một chính sách chọn hai lần bị chặn');

-- ================= (4) Admin đổi hạn mức trong Cài đặt (0 đến 20%); người khác và ghi đè theo cơ sở bị chặn =================
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$create function pg_temp.oidp(p_phone text) returns uuid language sql stable security definer as
  'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oidp(text) to public$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009101', '{"student_name": "Em Một", "student_birth_year": 2012}'));
reset role;
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where parent_phone = '0900009101'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity((select id from app.lead where parent_phone = '0900009101'));

select is((select applies_to from app.discount_policy where code = 'GIAM_6_THANG'), array['BAO_GIA', 'DON', 'PHIEU_THU'], 'CH-04: chính sách có sẵn mặc định áp dụng cả ba (cách tính không đổi)');
select is((select (x -> 'applies_to') from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oidp('0900009101'))) x where x ->> 'code' = 'GIAM_6_THANG'), '["BAO_GIA", "DON", "PHIEU_THU"]'::jsonb, 'CH-04: danh sách mời chọn trả khoá applies_to');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(pg_temp.err($$select app.save_discount_policy(pg_temp.pid('GIAM_6_THANG'), '{"applies_to": []}')$$), 'HMT_AP_DUNG_CHO_SAI', 'CH-04 chặn: để trống Áp dụng cho');
select is(pg_temp.err($$select app.save_discount_policy(pg_temp.pid('GIAM_6_THANG'), '{"applies_to": ["BAO_GIA", "KHAC"]}')$$), 'HMT_AP_DUNG_CHO_SAI', 'CH-04 chặn: nơi áp dụng không có trong danh sách');
select is(pg_temp.err($$select app.save_discount_policy(pg_temp.pid('GIAM_6_THANG'), '{"applies_to": ["PHIEU_THU"]}')$$), null, 'CH-04 đúng: Admin sửa chỉ áp dụng Phiếu thu');
select is((select applies_to from app.discount_policy where code = 'GIAM_6_THANG'), array['PHIEU_THU'], 'CH-04: đã lưu Chỉ Phiếu thu');
select is(pg_temp.err($$select app.save_discount_policy(pg_temp.pid('GIAM_6_THANG'), '{"max_value": 11}')$$), null, 'CH-04: sửa trường khác không đổi Áp dụng cho');
select is((select applies_to from app.discount_policy where code = 'GIAM_6_THANG'), array['PHIEU_THU'], 'CH-04: Áp dụng cho giữ nguyên khi không gửi');
reset role;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is((select count(*)::int from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oidp('0900009101'))) x where x ->> 'code' = 'GIAM_6_THANG'), 0, 'CH-04: chính sách chỉ áp dụng Phiếu thu không hiện ở danh sách báo giá, đơn');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "CK_CH04", "name": "Chiết khấu CH04", "kind": "PERCENT", "max_value": 5, "valid_from": "2026-11-01", "package_type_codes": ["LC"]}')$$), null, 'CH-04 đúng: tạo mới không gửi applies_to thì mặc định cả ba');
reset role;
select is((select applies_to from app.discount_policy where code = 'CK_CH04'), array['BAO_GIA', 'DON', 'PHIEU_THU'], 'CH-04: chính sách tạo mới mặc định cả ba');

select * from finish();
rollback;
