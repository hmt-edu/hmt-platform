-- KH-07 Gộp phụ huynh, học sinh: chuyển toàn bộ dữ liệu kể cả tiền, kiểm tổng, điều kiện chặn (migration 583; R-CRM-25, anh chốt 20/11).
begin;
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
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
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin');
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select id, 'ADMIN' from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- Dữ liệu giả: phụ huynh PA (giữ) và PB (bị gộp); sáu học sinh dưới PA; một học sinh dưới PB.
insert into app.parent (code, full_name, phone, branch_id) select c, 'Phụ huynh ' || c, ph, (select id from app.branch where code = 'CS1')
  from (values ('PHKH7A', '0991830001'), ('PHKH7B', '0991830002')) as v (c, ph);
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c, (select id from app.parent where code = case when c = 'HSKH7C' then 'PHKH7B' else 'PHKH7A' end), 'Em ' || c, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HSKH71A'), ('HSKH71B'), ('HSKH72A'), ('HSKH72B'), ('HSKH73A'), ('HSKH73B'), ('HSKH7C')) as v (c);
-- Lớp: X (thứ Hai 18:00-19:00), Y (thứ Hai 18:30-19:30, trùng X), Z (thứ Ba 18:00-19:00, không trùng).
insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, start_date, total_sessions, level_code)
select c, (select id from app.branch where code = 'CS1'), '2627', 'TOAN', 'K08', 'LR', date '2026-11-23', 10, null
  from (values ('LOPKH7X'), ('LOPKH7Y'), ('LOPKH7Z')) as v (c);
insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
select (select id from app.class where code = v.c), (select id from app.branch where code = 'CS1'), v.wd, v.st::time, v.en::time, v.fd::date
  from (values ('LOPKH7X', 1, '18:00', '19:00', '2026-11-23'), ('LOPKH7Y', 1, '18:30', '19:30', '2026-11-23'), ('LOPKH7Z', 2, '18:00', '19:00', '2026-11-24')) as v (c, wd, st, en, fd);
-- Ghi danh giả có xếp lớp: (mã ghi danh, học sinh, lớp).
create function pg_temp.mke(p_code text, p_student text, p_class text) returns void language plpgsql as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
  values (p_code, (select id from app.student where code = p_student), (select parent_id from app.student where code = p_student),
          (select id from app.branch where code = 'CS1'), 'TOAN', 'DANG_HOC') returning id into v_id;
  insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  values (v_id, (select id from app.class where code = p_class), (select id from app.branch where code = 'CS1'), date '2026-11-23');
end $$;
select pg_temp.mke('GDKH71A', 'HSKH71A', 'LOPKH7X');
select pg_temp.mke('GDKH71B', 'HSKH71B', 'LOPKH7X');   -- cùng lớp X với HSKH71A
select pg_temp.mke('GDKH72A', 'HSKH72A', 'LOPKH7X');
select pg_temp.mke('GDKH72B', 'HSKH72B', 'LOPKH7Y');   -- lớp Y trùng giờ lớp X
select pg_temp.mke('GDKH73A', 'HSKH73A', 'LOPKH7X');
select pg_temp.mke('GDKH73B', 'HSKH73B', 'LOPKH7Z');   -- lớp Z không trùng
select pg_temp.mke('GDKH7C', 'HSKH7C', 'LOPKH7Z');
-- Giờ và số dư theo em, theo phụ huynh.
insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
select e.id, e.branch_id, 'CAP_MUA', v.h from app.enrollment e join (values ('GDKH73A', 10), ('GDKH73B', 5), ('GDKH7C', 7)) as v (c, h) on v.c = e.code;
insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date)
select p.id, s.id, p.branch_id, 'DAU_KY_THU_THUA', v.a, date '2026-11-20'
  from (values ('PHKH7A', 'HSKH73B', 200000), ('PHKH7B', null, 500000)) as v (pc, sc, a)
  join app.parent p on p.code = v.pc left join app.student s on s.code = v.sc;
insert into app.lead (code, parent_name, parent_phone, parent_id, branch_id, source_catalog, source_code, stage_code)
select 'LDKH7C', 'Lead PB', '0991830002', (select id from app.parent where code = 'PHKH7B'), (select id from app.branch where code = 'CS1'),
       (select catalog_code from app.catalog_item where catalog_code = 'LEAD_SOURCE' order by sort_order limit 1),
       (select code from app.catalog_item where catalog_code = 'LEAD_SOURCE' order by sort_order limit 1), 'L1'
 where exists (select from app.catalog_item where catalog_code = 'LEAD_SOURCE');
create temp table ids as select
  (select id from app.student where code = 'HSKH71A') as s1a, (select id from app.student where code = 'HSKH71B') as s1b,
  (select id from app.student where code = 'HSKH72A') as s2a, (select id from app.student where code = 'HSKH72B') as s2b,
  (select id from app.student where code = 'HSKH73A') as s3a, (select id from app.student where code = 'HSKH73B') as s3b,
  (select id from app.parent where code = 'PHKH7A') as pa, (select id from app.parent where code = 'PHKH7B') as pb;

select pg_temp.claims((select id from u where key = 'admin'), 'aal2');

-- ---------- Điều kiện chặn (R-CRM-25, anh chốt 20/11) ----------
select is(pg_temp.err($$select app.merge_students((select s1a from ids), (select s1b from ids), true)$$), 'HMT_GOP_CUNG_LOP',
          'Chặn: hai em cùng có ghi danh còn hiệu lực ở cùng một lớp');
select is(pg_temp.err($$select app.merge_students((select s2a from ids), (select s2b from ids), true)$$), 'HMT_GOP_TRUNG_GIO',
          'Chặn: hai em đang học hai lớp trùng giờ');
select is((select count(*)::int from app.student where record_status = 'DA_GOP' and code like 'HSKH7%'), 0, 'Bị chặn thì không hồ sơ nào thành Đã gộp');

-- ---------- Gộp học sinh thành công: chuyển ghi danh, giờ, số dư; tổng giữ nguyên ----------
create temp table before_s as select app.merge_totals('STUDENT', array[(select s3a from ids), (select s3b from ids)]) as t;
select lives_ok($$select app.merge_students((select s3a from ids), (select s3b from ids), true)$$, 'Gộp học sinh khác lớp, không trùng giờ: được');
select is((select count(*)::int from app.enrollment where student_id = (select s3a from ids)), 2, 'Hai ghi danh đều về học sinh giữ lại');
select is((select count(*)::int from app.enrollment where student_id = (select s3b from ids)), 0, 'Học sinh bị gộp không còn ghi danh');
select is((select sum(amount)::bigint from app.customer_balance_entry where student_id = (select s3a from ids)), 200000::bigint, 'Số dư theo em chuyển sang, đủ 200.000');
select is(app.merge_totals('STUDENT', array[(select s3a from ids)]), (select t from before_s), 'Tổng giờ, số dư, ghi danh sau gộp bằng tổng hai hồ sơ trước gộp');
select is((select record_status from app.student where id = (select s3b from ids)), 'DA_GOP', 'Học sinh bị gộp thành Đã gộp');

-- ---------- Gộp phụ huynh: chuyển cả số dư, ghi danh, học sinh ----------
create temp table before_p as select app.merge_totals('PARENT', array[(select pa from ids), (select pb from ids)]) as t;
select lives_ok($$select app.merge_parents((select pa from ids), (select pb from ids), true)$$, 'Gộp phụ huynh: được');
select is((select sum(amount)::bigint from app.customer_balance_entry where parent_id = (select pa from ids)), 700000::bigint,
          'Số dư của phụ huynh bị gộp (500.000) cộng vào phụ huynh giữ lại (200.000)');
select is((select count(*)::int from app.customer_balance_entry where parent_id = (select pb from ids)), 0, 'Phụ huynh bị gộp không còn dòng số dư');
select is((select count(*)::int from app.enrollment where parent_id = (select pb from ids)), 0, 'Ghi danh của phụ huynh bị gộp đã chuyển');
select is((select parent_id from app.student where code = 'HSKH7C'), (select pa from ids), 'Học sinh của phụ huynh bị gộp về phụ huynh giữ lại');
select is(app.merge_totals('PARENT', array[(select pa from ids)]), (select t from before_p), 'Tổng tiền, giờ, số chứng từ sau gộp bằng tổng hai hồ sơ trước gộp');
select is((select record_status from app.parent where id = (select pb from ids)), 'DA_GOP', 'Phụ huynh bị gộp thành Đã gộp');

-- ---------- Lệch tiền thì huỷ ----------
select is(pg_temp.err($$select app.merge_assert_totals('PARENT', (select pa from ids), jsonb_build_object('balance', 1))$$), 'HMT_GOP_LECH_TIEN',
          'Tổng sau gộp lệch tổng trước gộp thì dừng cả giao dịch (HMT_GOP_LECH_TIEN)');

-- ---------- Sổ số dư vẫn chỉ-thêm ngoài lúc gộp; cờ gộp không còn sau khi gộp ----------
select is(coalesce(current_setting('hmt.merge', true), ''), '', 'Cờ hmt.merge đã tắt sau khi gộp');
select is(pg_temp.err($$update app.customer_balance_entry set amount = amount + 1 where parent_id = (select pa from ids)$$), 'HMT_SO_DU_CHI_THEM',
          'Ngoài lúc gộp, sổ số dư vẫn chỉ thêm, không sửa số tiền');
select is(pg_temp.err($$update app.customer_balance_entry set parent_id = (select pb from ids) where parent_id = (select pa from ids)$$), 'HMT_SO_DU_CHI_THEM',
          'Ngoài lúc gộp, không đổi được phụ huynh của dòng sổ số dư');

-- ---------- Hàm nội bộ không cấp cho giao diện ----------
select is(has_function_privilege('authenticated', 'app.merge_move_refs(text, uuid, uuid)', 'execute'), false, 'merge_move_refs không cấp cho người đăng nhập');
select is(has_function_privilege('authenticated', 'app.merge_totals(text, uuid[])', 'execute'), false, 'merge_totals không cấp cho người đăng nhập');

select * from finish();
rollback;
