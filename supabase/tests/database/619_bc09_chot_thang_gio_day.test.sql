-- BC-09 Chốt tháng (migration 619): app.close_teaching_hours_month, app.teaching_hours_view, bảng app.teaching_hours_close. Luật: chốt cả hệ thống, khoá, không mở lại, Trưởng cơ sở không chốt, không chốt tháng chưa kết thúc. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('acc1'), ('bm1'), ('gv1'), ('ta1'), ('gv3');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p619.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p619.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'gv3' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'acc1' then 'ACCOUNTANT' when 'bm1' then 'BRANCH_MANAGER' when 'ta1' then 'TA' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b join (values ('LOP619', 'CS1'), ('LOP619B', 'CS2')) c (code, br) on c.br = b.code$$);
-- Tháng TRƯỚC (đã kết thúc): s1 CHINH (gv1 + ta1), s2 CUNG_CO (gv1), s3 CHINH CS2 (gv3), mỗi buổi 1,5 giờ. Tháng này: s4 (gv1) để thử tháng chưa kết thúc.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, assistant_id, status_code, type_code)
  select c.id, c.branch_id, v.no, v.d, '18:00', '19:30', pg_temp.uid(v.t), case when v.a then pg_temp.uid('ta1') end, 'DONE', v.ty
    from (values ('LOP619', 1, (date_trunc('month', current_date) - interval '1 month')::date, 'gv1', true, 'CHINH'),
                 ('LOP619', 2, (date_trunc('month', current_date) - interval '1 month')::date, 'gv1', false, 'CUNG_CO'),
                 ('LOP619B', 3, (date_trunc('month', current_date) - interval '1 month')::date, 'gv3', false, 'CHINH'),
                 ('LOP619', 4, date_trunc('month', current_date)::date, 'gv1', false, 'CHINH')) v (cc, no, d, t, a, ty)
    join app.class c on c.code = v.cc$$);
create temp table m as select (date_trunc('month', current_date) - interval '1 month')::date as prev, date_trunc('month', current_date)::date as cur;
grant select on m to public;

-- ===== Luật quyền chốt: Trưởng cơ sở, giáo viên bị chặn; chỉ Kế toán, Admin =====
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.close_teaching_hours_month((select prev from m))$$), 'HMT_KHONG_CO_QUYEN', 'Luật: Trưởng cơ sở không có nút Chốt, gọi hàm bị chặn (chốt cả hệ thống)');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.close_teaching_hours_month((select prev from m))$$), 'HMT_KHONG_CO_QUYEN', 'Luật: giáo viên không chốt được');
reset role;

-- ===== Luật: không chốt tháng chưa kết thúc =====
select pg_temp.claims(pg_temp.uid('acc1'), 'aal2');
set local role authenticated;
select is(pg_temp.err($$select app.close_teaching_hours_month((select cur from m))$$), 'HMT_THANG_CHUA_KET_THUC', 'Luật: tháng hiện tại chưa kết thúc, không chốt được');
select is((app.teaching_hours_view((select prev from m)) -> 'closed') = 'null'::jsonb, true, 'Trước khi chốt: tháng ghi chưa chốt');

-- ===== Kế toán chốt tháng trước =====
create temp table c as select app.close_teaching_hours_month((select prev from m)) as j;
grant select on c to public;
select is((select (j ->> 'total_hours')::numeric from c), 6.0, 'Chốt: tổng 6 giờ (gv1 3 giờ, ta1 1,5, gv3 1,5)');
select is(app.teaching_hours_view((select prev from m)) -> 'closed' ->> 'closed_by_name', 'Giả acc1', 'Sau chốt: hiện «Đã chốt bởi» đúng người chốt');
select isnt(app.teaching_hours_view((select prev from m)) -> 'closed' ->> 'closed_at', null, 'Sau chốt: có thời điểm chốt');
select is((app.teaching_hours_view((select prev from m)) ->> 'total')::int, 3, 'Sau chốt: ba dòng (gv1 CS1, ta1 CS1, gv3 CS2)');
select is((app.teaching_hours_view((select prev from m)) -> 'totals' ->> 'hours')::numeric, 6.0, 'Sau chốt: tổng giờ đọc từ ảnh chụp');
select is((app.teaching_hours_view((select prev from m), (select id from app.branch where code = 'CS2')) ->> 'total')::int, 1, 'Sau chốt: vẫn lọc được theo cơ sở (CS2 chỉ gv3)');
select is((app.teaching_hours_view((select prev from m), null, 1, 0) -> 'rows')::jsonb is not null and jsonb_array_length(app.teaching_hours_view((select prev from m), null, 1, 0) -> 'rows') = 1, true, 'Sau chốt: phân trang theo số dòng');
select is(pg_temp.err($$select app.close_teaching_hours_month((select prev from m))$$), 'HMT_THANG_DA_CHOT', 'Luật: chốt lần hai bị chặn, không có Mở lại');
reset role;

-- ===== Sửa buổi sau khi chốt: số đã chốt giữ nguyên =====
select pg_temp.sudo($$update app.class_session set end_time = '21:30' where session_no = 1 and class_id = (select id from app.class where code = 'LOP619')$$);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.teaching_hours_view((select prev from m)) -> 'totals' ->> 'hours')::numeric, 6.0, 'Tháng đã chốt giữ nguyên số khi buổi bị sửa sau đó (số chụp lúc chốt)');
select is((app.report_teaching_hours((select prev from m)) -> 'totals' ->> 'hours')::numeric > 6.0, true, 'Đối chứng: báo cáo sống đã đổi theo buổi sửa');
reset role;

-- ===== Bảng chốt khoá: không sửa, không xoá =====
select is(pg_temp.err($$update app.teaching_hours_close set total_hours = 1$$), 'HMT_THANG_DA_CHOT', 'Luật: dòng đã chốt không sửa được');
select is(pg_temp.err($$delete from app.teaching_hours_close$$), 'HMT_KHONG_XOA', 'Luật: dòng đã chốt không xoá được');

-- ===== Trưởng cơ sở xem tháng đã chốt: chỉ cơ sở mình =====
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is((app.teaching_hours_view((select prev from m)) ->> 'total')::int, 2, 'Trưởng cơ sở CS1 xem tháng đã chốt: chỉ gv1 và ta1 của CS1');
select is(pg_temp.err($$select app.teaching_hours_view((select prev from m), (select id from app.branch where code = 'CS2'))$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở xem cơ sở khác bị chặn');
reset role;

-- ===== Admin chốt được tháng khác (có quyền toàn hệ thống và Xuất) =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select lives_ok($$select app.close_teaching_hours_month(((select prev from m) - interval '1 month')::date)$$, 'Admin chốt được tháng đã kết thúc (tháng trống vẫn chốt, 0 giờ)');
reset role;
-- ===== N1 (migration 629): đọc thẳng bảng chốt theo phạm vi, không lộ giờ cơ sở khác =====
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is((select count(*)::int from app.teaching_hours_close), 0, 'N1: Trưởng cơ sở (phạm vi cơ sở) đọc thẳng bảng chốt không thấy dòng nào (không lộ giờ cơ sở khác)');
select is((app.teaching_hours_view((select prev from m)) ->> 'total')::int, 2, 'N1: Trưởng cơ sở vẫn xem tháng đã chốt qua hàm của màn BC-09 (chỉ cơ sở mình)');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is((select count(*)::int from app.teaching_hours_close), 0, 'N1: giáo viên không đọc được bảng chốt');
reset role;
select pg_temp.claims(pg_temp.uid('acc1'), 'aal2');
set local role authenticated;
select cmp_ok((select count(*)::int from app.teaching_hours_close), '>=', 1, 'N1: Kế toán (toàn hệ thống) đọc được bảng chốt');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select cmp_ok((select count(*)::int from app.teaching_hours_close), '>=', 1, 'N1: Admin đọc được bảng chốt');
reset role;
select * from finish();
rollback;
