-- TT-D2a (migration 417): tạo ĐƠN từ phiếu tái tục, đối soát đơn đóng đủ, đơn huỷ. Luật R-GD-13, Đ187; mỗi bước tiền kiểm quyền riêng (Chat 13:20). Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p417.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p417.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('cskh1', 'CSKH'), ('ke1', 'ACCOUNTANT'), ('bm1', 'BRANCH_MANAGER')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH417', 'Phụ huynh giả 417', '0900417001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS417A', 'Em A'), ('HS417B', 'Em B'), ('HS417C', 'Em C')) s (code, name) where p.code = 'PH417'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code, max_students)
  select 'LOP417', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10, 'DA_DUYET', 0 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code, delivery_mode_code)
  select 'GD417' || right(s.code, 1), s.id, s.parent_id, s.branch_id, 'DANG_HOC', 'OFF' from app.student s where s.code in ('HS417A', 'HS417B')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date - 30 from app.enrollment e, app.class c where e.code in ('GD417A', 'GD417B') and c.code = 'LOP417'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select c.id, c.branch_id, current_date + n, '18:00', '19:30' from app.class c, generate_series(1, 3) n where c.code = 'LOP417'$$);
-- Phiếu: A ở L6, B ở L1, C ở L6 nhưng không còn học ở lớp.
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  select v.code, s.branch_id, s.id, s.parent_id, c.id, v.st, null, 'TAY'
    from (values ('TT917001', 'HS417A', 'L6'), ('TT917002', 'HS417B', 'L1'), ('TT917003', 'HS417C', 'L6')) v (code, sc, st)
    join app.student s on s.code = v.sc, app.class c where c.code = 'LOP417'$$);

set local role authenticated;
-- ---- Quyền: mỗi bước kiểm riêng ----
select pg_temp.claims(pg_temp.uid('ke1'), 'aal2');
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), pg_temp.lines())$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không tạo đơn từ phiếu');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), pg_temp.lines())$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở chỉ Xem, Giao việc phiếu tái tục: không đủ quyền Sửa phiếu để tạo đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- ---- Luật ----
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), '[]'::jsonb)$$), 'HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng');
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917002'), pg_temp.lines())$$), 'HMT_PHIEU_CHUA_DONG_Y', 'R-GD-13: phiếu chưa L6 không tạo được đơn');
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917003'), pg_temp.lines())$$), 'HMT_HOC_SINH_KHONG_O_LOP', 'R-GD-13: học sinh không còn học ở lớp thì không tạo được đơn');
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), pg_temp.lines(), null, current_date + 30)$$), 'HMT_NGAY_VAO_LOP_SAI', 'Ngày vào lớp không phải buổi của lớp: báo ngay lúc tạo đơn');
-- ---- Tạo đúng ----
select is((app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), pg_temp.lines()) ->> 'code') ~ '^DH-', true, 'Tạo đơn từ phiếu L6: ra mã đơn DH');
select is((pg_temp.tk('TT917001')).stage_code || (pg_temp.tk('TT917001')).substage_code, 'L7L7B', 'Phiếu sang L7B trong cùng giao dịch');
select is((select count(*)::int from app.sales_order where renewal_ticket_id = pg_temp.tid('TT917001') and opportunity_id is null and status_code = 'NHAP'), 1, 'Đơn Nháp gốc là phiếu (không có cơ hội)');
select is((select count(*)::int from app.sales_order_line l join app.sales_order o on o.id = l.order_id
            where o.renewal_ticket_id = pg_temp.tid('TT917001') and l.student_id = (select id from app.student where code = 'HS417A')
              and l.class_id = (select id from app.class where code = 'LOP417') and l.delivery_mode_code = 'OFF' and l.prospect_student_id is null), 1,
          'Dòng đơn: đúng học sinh, lớp của phiếu, hình thức học giữ như ghi danh cũ');
select is((select total_amount > 0 from app.sales_order where renewal_ticket_id = pg_temp.tid('TT917001')), true, 'Tổng tiền tính bằng bảng giá');
select is((select string_agg(event_type, ',' order by seq) from app.upsale_ticket_event where ticket_id = pg_temp.tid('TT917001')), 'DOI_GIAI_DOAN', 'Nhật ký phiếu ghi bước sang L7');
select is(pg_temp.err($$select app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), pg_temp.lines())$$), 'HMT_PHIEU_CHUA_DONG_Y', 'Phiếu đã sang L7 không tạo đơn thứ hai');
select is(jsonb_array_length(app.list_upsale_orders(pg_temp.tid('TT917001'))), 1, 'Tab Báo giá và đơn: một đơn');
-- ---- Đối soát ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.reconcile_upsale_orders()$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không chạy đối soát');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.reconcile_upsale_orders() ->> 'completed', '0', 'Đối soát: đơn Nháp chưa thu đủ thì phiếu giữ L7B');
-- Đơn Huỷ: phiếu về L6.
reset role;
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.sales_order set status_code = 'HUY' where renewal_ticket_id = (select id from app.upsale_ticket where code = 'TT917001')$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.reconcile_upsale_orders() ->> 'reopened', '1', 'Đối soát: đơn Huỷ thì phiếu về L6');
select is((pg_temp.tk('TT917001')).stage_code, 'L6', 'Phiếu về L6 để tạo đơn khác');
-- Tạo đơn mới rồi cho đóng đủ (tổng 0 coi như đã thu đủ): phiếu sang L8A.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_order_from_upsale_ticket(pg_temp.tid('TT917001'), pg_temp.lines());
reset role;
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.sales_order set status_code = 'DA_DUYET', total_amount = 0 where renewal_ticket_id = (select id from app.upsale_ticket where code = 'TT917001') and status_code = 'NHAP'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.reconcile_upsale_orders() ->> 'completed', '1', 'Đối soát: đơn Đã duyệt đã thu đủ thì phiếu hoàn thành');
select is((pg_temp.tk('TT917001')).stage_code || (pg_temp.tk('TT917001')).substage_code, 'L8L8A', 'Phiếu ở L8A Đã đóng đủ');
select isnt((pg_temp.tk('TT917001')).closed_at, null, 'L8 ghi thời điểm kết thúc');

-- ---- Ghi danh mới vào đúng lớp của phiếu (hàm sẵn có create_enrollments_for_order): không vào hàng chờ xếp lớp ----
reset role;
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.setting_def set value = '0', min_value = 0 where key = 'deposit_min_amount'$$);
create function pg_temp.enr(p_ticket text) returns jsonb language plpgsql security definer as $$
begin return app.create_enrollments_for_order((select id from app.sales_order where renewal_ticket_id = pg_temp.tid(p_ticket) and status_code = 'DA_DUYET')); end $$;
grant execute on function pg_temp.enr(text) to public;
select is(pg_temp.enr('TT917001') ->> 'queued', '0', 'Ghi danh từ đơn tái tục: không vào hàng chờ xếp lớp');
select is((select count(*)::int from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
            where e.student_id = (select id from app.student where code = 'HS417A') and e.status_code = 'DA_XEP_LOP'
              and ec.class_id = (select id from app.class where code = 'LOP417') and e.order_id is not null), 1, 'Ghi danh mới Đã xếp lớp đúng lớp của phiếu');

-- ---- Tuỳ chọn cho hộp Tạo đơn (migration 418) ----
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.list_upsale_order_options(pg_temp.tid('TT917001')) ->> 'delivery_mode_code', 'OFF', 'Tuỳ chọn: hình thức học giữ như ghi danh cũ');
select is(jsonb_array_length(app.list_upsale_order_options(pg_temp.tid('TT917001')) -> 'sessions') >= 1, true, 'Tuỳ chọn: có buổi sắp tới của lớp để chọn ngày vào lớp');
select is(app.list_upsale_order_options(pg_temp.tid('TT917001')) -> 'packages' @> '[{"code": "LC-TOAN-K09"}]'::jsonb, true, 'Tuỳ chọn: có gói đúng môn của lớp');
select pg_temp.claims(pg_temp.uid('ke1'), 'aal2');
select is(pg_temp.err($$select app.list_upsale_order_options(pg_temp.tid('TT917001'))$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không xem tuỳ chọn tạo đơn');

-- ---- Nhắc nhỏ Chat 13:20 (thẻ C3): người không có quyền Tạo phiếu tái tục nhận lỗi quyền, không biết mã ghi danh có hay không ----
select pg_temp.claims(pg_temp.uid('ke1'), 'aal2');
select is(pg_temp.err($$select app.preview_upsale_enrollment('GD417A')$$), 'HMT_KHONG_CO_QUYEN', 'preview_upsale_enrollment: người không có quyền Tạo bị chặn, mã có thật');
select is(pg_temp.err($$select app.preview_upsale_enrollment('KHONG-CO')$$), 'HMT_KHONG_CO_QUYEN', 'preview_upsale_enrollment: cùng một lỗi với mã không có (không dò được mã)');

select * from finish();
rollback;
