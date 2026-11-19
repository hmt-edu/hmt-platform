-- E60 / CHUNG-20: Huỷ lead nhập nhầm (chỉ Admin): app.cancel_wrong_lead, record_status = DA_HUY chỉ cho lead.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e60.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e60.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ---------- Dựng dữ liệu: ba lead (một trống, một có lịch hẹn, một có cơ hội) ----------
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$create temp table t (k text primary key, id uuid)$$);
select pg_temp.sudo($$grant all on t to public$$);
insert into t select 'trong', (app.create_lead(pg_temp.lead_data('0900060001'))->>'id')::uuid;
insert into t select 'hen', (app.create_lead(pg_temp.lead_data('0900060002'))->>'id')::uuid;
insert into t select 'coh', (app.create_lead(pg_temp.lead_data('0900060003'))->>'id')::uuid;
select app.create_appointment((select id from t where k = 'hen'), 'GOI_DIEN', now() + interval '1 day', 'Gọi lại');
-- Lead 'coh' phải ở C4C mới tạo được cơ hội (migration 48).
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where id = (select id from t where k = 'coh')$$);
select app.create_opportunity((select id from t where k = 'coh'));
-- Lead 'moi' (trống, Đang dùng) để thử thêm cơ hội, lịch hẹn sau khi huỷ.
insert into t select 'moi', (app.create_lead(pg_temp.lead_data('0900060004'))->>'id')::uuid;
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where id = (select id from t where k = 'moi')$$);

-- ---------- Chặn: không phải Admin ----------
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'trong'), 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN', 'CHUNG-20: Sale không được huỷ lead nhập nhầm');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'trong'), 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN', 'CHUNG-20: Trưởng cơ sở không được huỷ lead nhập nhầm');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'trong'), 'Nhập nhầm')$$), 'HMT_KHONG_CO_QUYEN', 'CHUNG-20: CSKH không được huỷ lead nhập nhầm');

-- ---------- Chặn khác (Admin) ----------
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'trong'), '   ')$$), 'HMT_THIEU_THONG_TIN', 'CHUNG-20: thiếu lý do thì chặn');
select is(pg_temp.err($$select app.cancel_wrong_lead(gen_random_uuid(), 'Nhập nhầm')$$), 'HMT_KHONG_TIM_THAY', 'CHUNG-20: không có lead thì báo không tìm thấy');
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'hen'), 'Nhập nhầm')$$), 'HMT_LEAD_CO_LICH_HEN', 'CHUNG-20: lead đã có lịch hẹn thì chặn');
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'coh'), 'Nhập nhầm')$$), 'HMT_LEAD_CO_CO_HOI', 'CHUNG-20: lead đã có cơ hội thì chặn');
select is((select record_status from app.lead where id = (select id from t where k = 'hen')), 'DANG_DUNG', 'CHUNG-20: lead bị chặn vẫn Đang dùng');

-- ---------- Đúng: Admin huỷ lead trống ----------
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'trong'), 'Nhập nhầm số điện thoại')$$), null, 'CHUNG-20: Admin huỷ lead trống: được');
select is((select record_status from app.lead where id = (select id from t where k = 'trong')), 'DA_HUY', 'CHUNG-20: lead chuyển DA_HUY, không xoá');
select is((select cancel_reason from app.lead where id = (select id from t where k = 'trong')), 'Nhập nhầm số điện thoại', 'CHUNG-20: lưu lý do huỷ');
select isnt((select cancelled_by from app.lead where id = (select id from t where k = 'trong')), null, 'CHUNG-20: lưu người huỷ');
select is((select count(*)::int from app.lead where id = (select id from t where k = 'trong')), 1, 'CHUNG-20: bản ghi vẫn còn (không xoá cứng)');
select ok((select count(*) from app.note where entity_type = 'LEAD' and entity_id = (select id from t where k = 'trong') and body like 'Huỷ lead nhập nhầm:%') = 1, 'CHUNG-20: có ghi chú hệ thống trên lead');
select ok((select count(*) from app.audit_log l join app.audited_table a on a.id = l.table_id
            where a.table_name = 'app.lead' and l.record_id = (select id from t where k = 'trong') and l.action = 'U') >= 1, 'CHUNG-20: nhật ký ghi lần huỷ');

-- ---------- Sau khi huỷ ----------
select is(pg_temp.err($$select app.cancel_wrong_lead((select id from t where k = 'trong'), 'Lần hai')$$), 'HMT_LEAD_KHONG_HUY_DUOC', 'CHUNG-20: huỷ lại lead đã huỷ thì chặn');
select is(pg_temp.err($$select app.update_lead((select id from t where k = 'trong'), '{"need": "x"}')$$), 'HMT_LEAD_DA_HUY', 'CHUNG-20: lead đã huỷ không sửa được');
select is(pg_temp.err($$select app.create_appointment((select id from t where k = 'trong'), 'GOI_DIEN', now() + interval '2 day', 'Mới')$$), 'HMT_LEAD_DA_HUY', 'CHUNG-20: không thêm lịch hẹn cho lead đã huỷ');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.cancel_wrong_lead((select id from t where k = 'moi'), 'Nhập nhầm lần hai');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_opportunity((select id from t where k = 'moi'))$$), 'HMT_LEAD_DA_HUY', 'CHUNG-20: không tạo cơ hội cho lead đã huỷ');
select is((select count(*)::int from app.lead where id = (select id from t where k = 'trong')), 1, 'CHUNG-20: bản ghi huỷ vẫn nằm trong dữ liệu');
select is((app.list_leads('{"q": "0900060001"}'::jsonb) ->> 'total')::int, 0, 'CHUNG-20: lead đã huỷ ẩn khỏi danh sách mặc định');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900060001'))$$), null, 'CHUNG-20: SĐT của lead đã huỷ không tính trùng, tạo lại được');

select * from finish();
rollback;
