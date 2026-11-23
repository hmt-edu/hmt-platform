-- KH-08 chặn lên khối lần hai trong cùng năm học (migration 635): luật chặn, hoàn tác chạy lại được, mốc năm học theo tham số.
begin;
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.sid(p_code text) returns uuid language sql stable as $$ select id from app.student where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ---------- Học sinh giả ----------
-- A lớp 8, B lớp 12 (đang học, cơ sở CS1); C lớp 6 đang học ở CS2 (để thử «mọi cơ sở»).
insert into app.parent (code, full_name, phone, branch_id) values ('PHKH635', 'Phụ huynh KH635', '0991800635', (select id from app.branch where code = 'CS1'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade)
select c.code, (select id from app.parent where code = 'PHKH635'), c.name, 2012, (select id from app.branch where code = c.branch), c.grade
  from (values ('HS990001', 'Em A', 8, 'CS1'), ('HS990002', 'Em B', 12, 'CS1'), ('HS990003', 'Em C', 6, 'CS2')) as c (code, name, grade, branch);
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
select 'GDKH635' || right(s.code, 1), s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC' from app.student s where s.code in ('HS990001', 'HS990002', 'HS990003');
select is((select value from app.setting_def where key = 'school_year_start_month'), '6', 'Mặc định tháng bắt đầu năm học là 6 (khai báo trong migration 635)');
-- Cố định tháng bắt đầu năm học = tháng hiện tại, để mốc năm học là ngày 1 tháng này (không phụ thuộc ngày chạy kiểm thử).
select pg_temp.sudo($$update app.setting_def set value = extract(month from (now() at time zone 'Asia/Ho_Chi_Minh'))::int::text where key = 'school_year_start_month'$$);

-- ===== Tham số khai báo đúng =====
select is((select min_value::int || '-' || max_value::int || '-' || value from app.setting_def where key = 'school_year_start_month'),
          '1-12-' || extract(month from (now() at time zone 'Asia/Ho_Chi_Minh'))::int, 'Tham số tháng bắt đầu năm học khai báo 1..12');

-- ===== Lần đầu: chạy riêng CS1 =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(app.run_grade_promotion(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'))) ->> 'promoted' is not null, true, 'Lần đầu trong năm học: chạy CS1 được');
reset role;
select is((select grade::int from app.student where code = 'HS990001'), 9, 'Em A lên khối 9');
select is((select graduated_on is not null from app.student where code = 'HS990002'), true, 'Em B lớp 12 tốt nghiệp');

-- ===== Luật chặn lần hai =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(pg_temp.err(format($$select app.run_grade_promotion('{"branch_id":"%s"}'::jsonb)$$, (select id from app.branch where code = 'CS1'))),
          'HMT_DA_LEN_KHOI_NAM_NAY', 'Chặn lần hai: chạy lại CS1 trong cùng năm học bị chặn, có mã lỗi');
select is(app.preview_grade_promotion(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'), 'q', 'HS99000')) ->> 'total', '0',
          'Chặn lần hai: xem trước CS1 không còn em A, B');
select is((app.preview_grade_promotion(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'))) -> 'skipped' ->> 'da_len_khoi_nam_nay')::int >= 2, true,
          'Xem trước đếm em đã lên khối năm học này (da_len_khoi_nam_nay)');
select isnt(app.preview_grade_promotion(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'))) ->> 'last_run_at', null,
          'Xem trước trả ngày chạy lần trước');
-- Sau CS1, chạy «mọi cơ sở»: em A, B không bị lên thêm; em C ở CS2 vẫn đủ điều kiện.
select is(app.preview_grade_promotion('{"q":"HS99000"}'::jsonb) ->> 'total', '1', 'CS1 rồi mọi cơ sở: chỉ còn em C (CS2) đủ điều kiện, em A, B bị bỏ qua');
reset role;
select is((select grade::int from app.student where code = 'HS990001'), 9, 'Mọi cơ sở không lên thêm cho em A (vẫn khối 9)');

-- ===== Hoàn tác thì chạy lại được =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(app.undo_grade_promotion((select id from app.grade_promotion_batch order by created_at desc limit 1)) ->> 'restored' is not null, true, 'Hoàn tác đợt CS1');
select is(app.preview_grade_promotion('{"q":"HS99000"}'::jsonb) ->> 'total', '3', 'Hoàn tác đợt xong: em A, B, C đủ điều kiện lại');
select is(app.run_grade_promotion('{"q":"x"}'::jsonb) ->> 'promoted' is not null, true, 'Hoàn tác xong chạy lại được');
reset role;

-- ===== Đổi tháng bắt đầu năm học: đợt chạy trước mốc thì không chặn =====
select pg_temp.sudo($$alter table app.grade_promotion_batch disable trigger grade_promotion_batch_fill_standard$$);
select pg_temp.sudo($$update app.grade_promotion_batch set created_at = now() - interval '60 days' where status_code = 'DA_CHAY'$$);
select pg_temp.sudo($$alter table app.grade_promotion_batch enable trigger grade_promotion_batch_fill_standard$$);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(app.preview_grade_promotion('{"q":"HS99000"}'::jsonb) ->> 'total', '2',
          'Đợt chạy từ 60 ngày trước (trước ngày 1 tháng bắt đầu) không còn chặn: em A, C lên khối được ở năm học mới (em B đã tốt nghiệp)');
reset role;

select * from finish();
rollback;
