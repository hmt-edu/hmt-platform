-- Q-137 (08/11): bộ nguồn lead khớp spec 06 mục 1.1: 4 loại · 11 nguồn · 12 kênh (migration 087). Referral, Upsale là nguồn dưới Marketing; Ngừng 2 kênh
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




-- ================= (1) Danh mục sau migration =================
select is((select array_agg(code order by code) from app.catalog_item where catalog_code = 'SOURCE_TYPE' and is_active),
          array['BAN_GIAM_DOC', 'EVENT', 'MARKETING', 'TELEMARKETING'], 'Q-137: chỉ còn 4 loại nguồn đang dùng');
select is((select array_agg(code order by code) from app.catalog_item where catalog_code = 'SOURCE_TYPE' and not is_active),
          array['REFERRAL', 'UPSALE'], 'Q-137: 2 loại cũ Referral, Upsale đã Ngừng (không xoá)');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE' and is_active), 11, 'Q-137: 11 nguồn đang dùng');
select is((select count(*)::int from app.catalog_item s join app.catalog_item t on t.id = s.parent_id
            where s.catalog_code = 'SOURCE' and s.code in ('REFERRAL', 'UPSALE') and t.code = 'MARKETING'), 2, 'Q-137: Referral và Upsale là nguồn dưới Marketing');
select is((select count(*)::int from app.catalog_item s join app.catalog_item t on t.id = s.parent_id
            where s.catalog_code = 'SOURCE' and t.code = 'MARKETING'), 8, 'Q-137: Marketing có 8 nguồn (FB, Google, Website, Hotline, Walk-in, Zalo, Referral, Upsale)');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE_CHANNEL' and is_active), 12, 'Q-137: 12 kênh đang dùng');
select is((select array_agg(code order by code) from app.catalog_item where catalog_code = 'SOURCE_CHANNEL' and not is_active),
          array['UPSALE_NEW_OPP', 'UPSALE_RENEW_LOST'], 'Q-137: Ngừng đúng 2 kênh Renew Lost, New Opp (không xoá)');
select is((select is_active from app.catalog_item where catalog_code = 'SOURCE_CHANNEL' and code = 'UPSALE_CROSS_SALE'), true, 'Q-137: kênh Cross-Sale của Upsale vẫn dùng');

-- ================= (2) Luật HMT_NGUON_SAI giữ nguyên với lead mới =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900007001', '{"source_type_code": "MARKETING", "source_code": "REFERRAL", "channel_code": "REFERRAL_BY_CUSTOMER"}'))$$), null,
          'Q-137: tạo lead nguồn Referral dưới loại Marketing được');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900007002', '{"source_type_code": "MARKETING", "source_code": "UPSALE", "channel_code": "UPSALE_CROSS_SALE"}'))$$), null,
          'Q-137: tạo lead nguồn Upsale, kênh Cross-Sale được');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900007003', '{"source_type_code": "TELEMARKETING", "source_code": "REFERRAL", "channel_code": "REFERRAL_BY_CUSTOMER"}'))$$), 'HMT_NGUON_SAI',
          'Q-137: luật HMT_NGUON_SAI giữ nguyên: nguồn Referral không thuộc loại Telemarketing');
select isnt(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900007004', '{"source_type_code": "REFERRAL", "source_code": "REFERRAL", "channel_code": "REFERRAL_BY_CUSTOMER"}'))$$), null,
          'Q-137: không tạo lead mới với loại cũ Referral (sai loại hoặc đã Ngừng)');
reset role;

-- ================= (3) Chạy migration trên dữ liệu kiểu cũ: loại đổi theo nguồn, nguồn và kênh giữ nguyên =================
-- Đưa danh mục về trạng thái TRƯỚC migration (6 loại, Referral và Upsale là loại riêng, 14 kênh), dựng lead và cơ hội kiểu cũ bằng hàm nghiệp vụ.
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.catalog_item s set parent_id = (select t.id from app.catalog_item t where t.catalog_code = 'SOURCE_TYPE' and t.code = s.code)
                       where s.catalog_code = 'SOURCE' and s.code in ('REFERRAL', 'UPSALE')$$);
select pg_temp.sudo($$update app.catalog_item set is_active = true where (catalog_code = 'SOURCE_TYPE' and code in ('REFERRAL', 'UPSALE'))
                       or (catalog_code = 'SOURCE_CHANNEL' and code in ('UPSALE_RENEW_LOST', 'UPSALE_NEW_OPP'))$$);
select pg_temp.sudo($$select set_config('hmt.migration', '', true)$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900008001', '{"source_type_code": "REFERRAL", "source_code": "REFERRAL", "channel_code": "REFERRAL_BY_HMT"}'));
select app.create_lead(pg_temp.lead_data('0900008002', '{"source_type_code": "UPSALE", "source_code": "UPSALE", "channel_code": "UPSALE_RENEW_LOST"}'));
select app.create_lead(pg_temp.lead_data('0900008003'));
reset role;
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where parent_phone = '0900008001'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity((select id from app.lead where parent_phone = '0900008001'));
reset role;
select is((select count(*)::int from app.lead where source_type_code in ('REFERRAL', 'UPSALE')), 2, 'Trước: 2 lead kiểu cũ (loại Referral, Upsale)');
select is((select count(*)::int from app.opportunity where source_type_code in ('REFERRAL', 'UPSALE')), 1, 'Trước: 1 cơ hội kiểu cũ');
-- Cùng thứ tự và câu lệnh với migration 087 (đổi cha hai nguồn, đổi loại lead và cơ hội theo nguồn, rồi Ngừng).
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.catalog_item set parent_id = (select id from app.catalog_item where catalog_code = 'SOURCE_TYPE' and code = 'MARKETING')
                       where catalog_code = 'SOURCE' and code in ('REFERRAL', 'UPSALE')$$);
select pg_temp.sudo($$update app.lead set source_type_code = 'MARKETING' where source_type_code in ('REFERRAL', 'UPSALE') and source_code in ('REFERRAL', 'UPSALE')$$);
select pg_temp.sudo($$update app.opportunity set source_type_code = 'MARKETING' where source_type_code in ('REFERRAL', 'UPSALE') and source_code in ('REFERRAL', 'UPSALE')$$);
select pg_temp.sudo($$update app.catalog_item set is_active = false where (catalog_code = 'SOURCE_CHANNEL' and code in ('UPSALE_RENEW_LOST', 'UPSALE_NEW_OPP'))
                       or (catalog_code = 'SOURCE_TYPE' and code in ('REFERRAL', 'UPSALE'))$$);
select pg_temp.sudo($$select set_config('hmt.migration', '', true)$$);
select is((select count(*)::int from app.lead where source_type_code in ('REFERRAL', 'UPSALE')), 0, 'Sau: không còn lead mang loại cũ');
select is((select count(*)::int from app.opportunity where source_type_code in ('REFERRAL', 'UPSALE')), 0, 'Sau: không còn cơ hội mang loại cũ');
select is((select source_type_code || '/' || source_code || '/' || channel_code from app.lead where parent_phone = '0900008001'), 'MARKETING/REFERRAL/REFERRAL_BY_HMT',
          'Lead Referral: loại thành Marketing; nguồn và kênh giữ nguyên');
select is((select source_type_code || '/' || source_code || '/' || channel_code from app.lead where parent_phone = '0900008002'), 'MARKETING/UPSALE/UPSALE_RENEW_LOST',
          'Lead Upsale: kênh Renew Lost (đã Ngừng) vẫn giữ giá trị cũ');
select is((select source_type_code || '/' || source_code from app.lead where parent_phone = '0900008003'), 'MARKETING/FACEBOOK_ADS', 'Lead đối chứng Marketing không đổi');
select is((select count(*)::int from app.opportunity where source_type_code = 'MARKETING' and source_code = 'REFERRAL'), 1, 'Cơ hội cũ: loại thành Marketing, nguồn giữ nguyên');
-- Lead đã chuyển vẫn lưu lại được (HMT_NGUON_SAI không báo vì loại đã khớp nguồn).
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.update_lead((select id from app.lead where parent_phone = '0900008001'), pg_temp.lead_data('0900008001', '{"source_type_code": "MARKETING", "source_code": "REFERRAL", "channel_code": "REFERRAL_BY_HMT"}'))$$), null,
          'Lead cũ đã chuyển loại lưu lại được, không báo HMT_NGUON_SAI');

select * from finish();
rollback;
