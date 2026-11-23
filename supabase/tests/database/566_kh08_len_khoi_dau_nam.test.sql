-- KH-08 Lên khối đầu năm học: preview_grade_promotion, run_grade_promotion, undo_grade_promotion, list_grade_promotion_batches (migration 566).
-- Luật: chỉ Admin (aal2); chỉ em đang học, đã có khối; lớp 12 tốt nghiệp; em bảo lưu, dừng học, tiềm năng, chưa có khối bỏ qua; loại trừ từng em;
-- hoàn tác cả đợt trong số ngày cho phép; nhật ký từng em.
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
-- A lớp 8 đang học; B lớp 12 đang học (tốt nghiệp); C lớp 9 bảo lưu; D lớp 10 chưa ghi danh (tiềm năng); E chưa có khối nhưng đang học; F lớp 7 đang học (sẽ loại trừ).
insert into app.parent (code, full_name, phone, branch_id) values ('PHKH08', 'Phụ huynh KH08', '0991800001', (select id from app.branch where code = 'CS1'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade)
select c.code, (select id from app.parent where code = 'PHKH08'), c.name, 2012, (select id from app.branch where code = 'CS1'), c.grade
  from (values ('HS980001', 'Em A', 8), ('HS980002', 'Em B', 12), ('HS980003', 'Em C', 9), ('HS980004', 'Em D', 10), ('HS980005', 'Em E', null), ('HS980006', 'Em F', 7)) as c (code, name, grade);
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
select 'GDKH08' || right(s.code, 1), s.id, s.parent_id, s.branch_id, 'TOAN', v.status
  from app.student s join (values ('HS980001', 'DANG_HOC'), ('HS980002', 'DANG_HOC'), ('HS980003', 'BAO_LUU'), ('HS980005', 'DANG_HOC'), ('HS980006', 'DA_XEP_LOP')) as v (code, status) on v.code = s.code;

-- ===== Luật 1: chỉ Admin =====
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.preview_grade_promotion('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Luật chỉ Admin: nhân viên Sale xem trước bị chặn');
select is(pg_temp.err($$select app.run_grade_promotion('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Luật chỉ Admin: nhân viên Sale chạy đợt bị chặn');
select is(pg_temp.err($$select app.list_grade_promotion_batches()$$), 'HMT_KHONG_CO_QUYEN', 'Luật chỉ Admin: nhân viên Sale xem các đợt bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.run_grade_promotion('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa qua hai bước (aal1) chạy đợt bị chặn');
reset role;

-- ===== Xem trước =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(app.preview_grade_promotion('{"q":"HS98000"}'::jsonb) ->> 'total', '3', 'Xem trước: ba em đủ điều kiện (A, B, F)');
select is(app.preview_grade_promotion('{"q":"HS98000"}'::jsonb) -> 'rows' -> 0 ->> 'new_grade', '9', 'Em A lớp 8 lên khối 9');
select is((select r ->> 'new_grade' from jsonb_array_elements(app.preview_grade_promotion('{"q":"HS98000"}'::jsonb) -> 'rows') r where r ->> 'code' = 'HS980002'),
          null, 'Em B lớp 12: khối mới trống (tốt nghiệp)');
select ok((app.preview_grade_promotion('{}'::jsonb) -> 'skipped' ->> 'khong_dang_hoc')::int >= 1, 'Xem trước đếm em bảo lưu, đã dừng vào «không đang học»');
select ok((app.preview_grade_promotion('{}'::jsonb) -> 'skipped' ->> 'chua_co_khoi')::int >= 1, 'Xem trước đếm em chưa có khối');
select is(jsonb_array_length(app.preview_grade_promotion('{"q":"HS98000"}'::jsonb, 2, 0) -> 'rows'), 2, 'Xem trước phân trang ở máy chủ');

-- ===== Chạy đợt, loại trừ em F =====
select is(app.run_grade_promotion('{}'::jsonb, array[pg_temp.sid('HS980006')]) ->> 'excluded', '1', 'Chạy: loại trừ em F');
reset role;
select is((select grade::int from app.student where code = 'HS980001'), 9, 'Luật 3: em A lên khối 9');
select is((select grade::int from app.student where code = 'HS980002'), 12, 'Lớp 12 giữ khối 12');
select is((select graduated_on is not null from app.student where code = 'HS980002'), true, 'Lớp 12 ghi ngày tốt nghiệp');
select is((select grade::int from app.student where code = 'HS980003'), 9, 'Luật 2: em bảo lưu không đổi khối');
select is((select grade::int from app.student where code = 'HS980004'), 10, 'Luật 2: em tiềm năng (chưa ghi danh) không đổi khối');
select is((select grade::int from app.student where code = 'HS980006'), 7, 'Em bị loại trừ không đổi khối');
select ok((select grade is null from app.student where code = 'HS980005'), 'Em chưa có khối không đổi');
select is((select count(*)::int from app.grade_promotion_item where student_id = pg_temp.sid('HS980001')), 1, 'Nhật ký từng em: một dòng đợt cho em A');
select is((select old_grade::int || '>' || coalesce(new_grade::text, 'TN') from app.grade_promotion_item where student_id = pg_temp.sid('HS980002')), '12>TN', 'Dòng đợt em B: 12 sang tốt nghiệp');

-- Chạy lại ngay: em B đã tốt nghiệp, em A (khối 9) lại đủ điều kiện nên không chặn; kiểm em đã tốt nghiệp không bị tăng lần nữa.
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.preview_grade_promotion('{"q":"HS980002"}'::jsonb) ->> 'total'), '0', 'Em đã tốt nghiệp không còn trong xem trước');

-- ===== Hoàn tác =====
select is(((select (r ->> 'can_undo')::boolean from jsonb_array_elements(app.list_grade_promotion_batches() -> 'rows') r limit 1)), true, 'Đợt mới còn trong hạn hoàn tác');
reset role;
select pg_temp.sudo($$update app.student set grade = 11 where code = 'HS980006'$$); -- em F sửa tay sau đợt (đợt không đụng em F)
select pg_temp.sudo($$update app.student set grade = 10 where code = 'HS980001'$$); -- em A sửa tay sau đợt: hoàn tác phải giữ nguyên
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.undo_grade_promotion((select id from app.grade_promotion_batch order by created_at desc limit 1)) ->> 'restored')::int, 1, 'Hoàn tác khôi phục em B, giữ em A đã sửa tay');
reset role;
select is((select graduated_on is null and grade = 12 from app.student where code = 'HS980002'), true, 'Hoàn tác: em B hết tốt nghiệp');
select is((select grade::int from app.student where code = 'HS980001'), 10, 'Hoàn tác: em A sửa tay giữ nguyên');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(pg_temp.err($$select app.undo_grade_promotion((select id from app.grade_promotion_batch order by created_at desc limit 1))$$), 'HMT_DOT_DA_HOAN_TAC', 'Hoàn tác lần hai bị chặn');
reset role;

-- Quá hạn hoàn tác: dựng đợt cũ.
select pg_temp.sudo($$alter table app.grade_promotion_batch disable trigger grade_promotion_batch_fill_standard$$);
select pg_temp.sudo($$insert into app.grade_promotion_batch (promoted_count, graduated_count, excluded_count, created_at) values (0, 0, 0, now() - interval '30 days')$$);
select pg_temp.sudo($$alter table app.grade_promotion_batch enable trigger grade_promotion_batch_fill_standard$$);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(pg_temp.err($$select app.undo_grade_promotion((select id from app.grade_promotion_batch order by created_at asc limit 1))$$), 'HMT_QUA_HAN_HOAN_TAC', 'Quá hạn hoàn tác bị chặn');
reset role;

select * from finish();
rollback;
