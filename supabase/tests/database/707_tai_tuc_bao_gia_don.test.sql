-- C-27-10 (migration 707): báo giá và đơn từ phiếu tái tục ở mọi giai đoạn; báo giá gắn đúng MỘT trong cơ hội hoặc phiếu. Luật R-GD-13. Dữ liệu giả.
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
create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as $$ select id from app.upsale_ticket where code = p_code $$;
create function pg_temp.tk(p_code text) returns app.upsale_ticket language sql stable security definer as $$ select t from app.upsale_ticket t where t.code = p_code $$;
create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_package where code = p_code $$;
create function pg_temp.lines() returns jsonb language sql stable as $$
  select jsonb_build_array(jsonb_build_object('kind', 'ENROL', 'package_id', pg_temp.pkg('LC-TOAN-K09'), 'quantity', 10, 'discounts', '[]'::jsonb)) $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('cskh1'), ('ke1'), ('bm1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p707.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p707.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('cskh1', 'CSKH'), ('ke1', 'ACCOUNTANT'), ('bm1', 'BRANCH_MANAGER')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH707', 'Phụ huynh giả 707', '0900707001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS707A', 'Em A'), ('HS707B', 'Em B'), ('HS707C', 'Em C')) s (code, name) where p.code = 'PH707'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code, max_students)
  select 'LOP707', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10, 'DA_DUYET', 0 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code, delivery_mode_code)
  select 'GD707' || right(s.code, 1), s.id, s.parent_id, s.branch_id, 'DANG_HOC', 'OFF' from app.student s where s.code in ('HS707A', 'HS707B')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date - 30 from app.enrollment e, app.class c where e.code in ('GD707A', 'GD707B') and c.code = 'LOP707'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select c.id, c.branch_id, current_date + n, '18:00', '19:30' from app.class c, generate_series(1, 3) n where c.code = 'LOP707'$$);
-- Phiếu: A ở L6, B ở L1, C ở L6 nhưng không còn học ở lớp.
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code, lost_reason_code)
  select v.code, s.branch_id, s.id, s.parent_id, c.id, v.st, null, 'TAY', case when v.st = 'L5' then 'KHAC' end
    from (values ('TT917071', 'HS707A', 'L5'), ('TT917072', 'HS707B', 'L1'), ('TT917073', 'HS707C', 'L6')) v (code, sc, st)
    join app.student s on s.code = v.sc, app.class c where c.code = 'LOP707'$$);

create function pg_temp.qline() returns jsonb language sql stable as $$
  select jsonb_build_array(jsonb_build_object('kind', 'ENROL', 'package_id', pg_temp.pkg('LC-TOAN-K09'), 'delivery_mode_code', 'OFF', 'quantity', 10, 'discounts', '[]'::jsonb)) $$;
create function pg_temp.qid(p_ticket text) returns uuid language sql stable security definer as $$
  select id from app.quotation where upsale_ticket_id = pg_temp.tid(p_ticket) order by code limit 1 $$;
grant execute on function pg_temp.qline(), pg_temp.qid(text) to public;

-- ---- Ràng buộc: đúng một trong cơ hội hoặc phiếu ----
select throws_ok($$insert into app.quotation (code, branch_id, parent_id, priced_on)
  select 'BG707X', branch_id, id, current_date from app.parent where code = 'PH707'$$, '23514', null, 'Báo giá không có cơ hội lẫn phiếu bị chặn');
select throws_ok($$insert into app.quotation (code, branch_id, parent_id, priced_on, opportunity_id, upsale_ticket_id)
  select 'BG707Y', branch_id, id, current_date, gen_random_uuid(), pg_temp.tid('TT917071') from app.parent where code = 'PH707'$$, '23514', null, 'Báo giá có cả cơ hội và phiếu bị chặn');

set local role authenticated;
-- ---- Quyền ----
select pg_temp.claims(pg_temp.uid('ke1'), 'aal2');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.tid('TT917071'), pg_temp.qline())$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không tạo báo giá từ phiếu');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.tid('TT917071'), pg_temp.qline())$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở chưa có Phiếu tái tục · Sửa: không tạo báo giá từ phiếu');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.save_quotation(null, gen_random_uuid(), pg_temp.qline())$$), 'HMT_KHONG_TIM_THAY', 'Mã nguồn không phải cơ hội hay phiếu');

-- ---- Tạo, đọc, liệt kê ----
select is((app.preview_quotation_lines(pg_temp.tid('TT917071'), pg_temp.qline()) ->> 'total_amount')::bigint > 0, true, 'Xem thử giá theo phiếu, không cần chọn học sinh');
select is((app.list_sellable_packages(pg_temp.tid('TT917071')) is not null), true, 'Danh sách gói bán theo phiếu');
select is((app.save_quotation(null, pg_temp.tid('TT917071'), pg_temp.qline()) ->> 'code') ~ '^BG-', true, 'R-GD-13: phiếu ở L5 vẫn tạo được báo giá');
select is((select count(*)::int from app.quotation q join app.upsale_ticket t on t.id = q.upsale_ticket_id
            where q.upsale_ticket_id = pg_temp.tid('TT917071') and q.opportunity_id is null and q.branch_id = t.branch_id and q.parent_id = t.parent_id), 1,
          'Cơ sở và phụ huynh của báo giá lấy từ phiếu');
select is((select count(*)::int from app.quotation_line l where l.quotation_id = pg_temp.qid('TT917071')
            and l.prospect_student_id is null and l.student_id = (select id from app.student where code = 'HS707A')), 1, 'Dòng báo giá là em của phiếu');
select is((app.save_quotation(pg_temp.qid('TT917071'), null, pg_temp.qline()) ->> 'code') ~ '^BG-', true, 'Sửa báo giá Nháp của phiếu');
select is(app.get_quotation(pg_temp.qid('TT917071')) ->> 'upsale_ticket_code', 'TT917071', 'Bản ghi báo giá có mã phiếu');
select is(app.get_quotation(pg_temp.qid('TT917071')) -> 'lines' -> 0 ->> 'student_name', 'Em A', 'Bản ghi báo giá có tên em');
select is(app.list_quotations(jsonb_build_object('upsale_ticket_id', pg_temp.tid('TT917071'))) ->> 'total', '1', 'Lọc báo giá của phiếu');
select is(app.list_quotations(jsonb_build_object('upsale_ticket_id', pg_temp.tid('TT917071'))) -> 'rows' -> 0 ->> 'student_name', 'Em A', 'Danh sách: báo giá của phiếu không bị rớt, có tên em');
select is((app.export_quotations(jsonb_build_object('upsale_ticket_id', pg_temp.tid('TT917071')))::text) like '%TT917071%', true, 'Xuất: báo giá của phiếu có mã phiếu');

-- ---- Gửi rồi tạo đơn ----
select app.send_quotation(pg_temp.qid('TT917071'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.qid('TT917071'))$$), 'HMT_KHONG_CO_QUYEN', 'Thiếu quyền thì không tạo đơn từ báo giá của phiếu');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.create_order_from_quotation(pg_temp.qid('TT917071')) ->> 'code') ~ '^DH-', true, 'Tạo đơn từ báo giá của phiếu, không cần cơ hội L8');
select is((select count(*)::int from app.sales_order o join app.sales_order_line l on l.order_id = o.id
            where o.renewal_ticket_id = pg_temp.tid('TT917071') and o.opportunity_id is null and o.quotation_id = pg_temp.qid('TT917071')
              and l.class_id = (select id from app.class where code = 'LOP707') and l.enrol_start_date is not null), 1,
          'Đơn gắn phiếu, dòng gắn lớp và ngày vào lớp');
select is((pg_temp.tk('TT917071')).stage_code, 'L5', 'Gửi báo giá và tạo đơn không đổi giai đoạn');
select is(app.get_upsale_ticket(pg_temp.tid('TT917071')) -> 'actions' @> '["tao_bao_gia", "tao_don"]'::jsonb, true, 'Phiếu ở L5 vẫn có Tạo báo giá, Tạo đơn');

select * from finish();
rollback;
