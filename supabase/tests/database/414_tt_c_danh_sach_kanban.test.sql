-- TT-C (migration 414): danh sách, Kanban, xem trước và tạo tay theo mã ghi danh. Luật R-GD-13; RLS theo quyền UPSALE · Xem. Dữ liệu giả.
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
create function pg_temp.anyt() returns uuid language sql stable security definer as $$ select id from app.upsale_ticket order by code limit 1 $$;
create function pg_temp.ticket_of(p_code text) returns uuid language sql stable security definer as $$ select t.id from app.upsale_ticket t join app.student s on s.id = t.student_id where s.code = p_code $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('cskh1'), ('cskh5'), ('ke1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p414.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p414.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('cskh1', 'CS1'), ('cskh5', 'CS5'), ('ke1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('cskh1', 'CSKH'), ('cskh5', 'CSKH'), ('ke1', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);

select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH414', 'Phụ huynh giả 414', '0900414001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS414A', 'Nguyễn Hà My'), ('HS414B', 'Trần Thị Mai')) s (code, name) where p.code = 'PH414'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP414', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id)
  select 'GD414' || right(s.code, 1), s.id, s.parent_id, s.branch_id from app.student s where s.code in ('HS414A', 'HS414B')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where e.code in ('GD414A', 'GD414B') and c.code = 'LOP414'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
-- ---- Xem trước và tạo theo mã ghi danh ----
select is(app.preview_upsale_enrollment('gd414a') ->> 'student_name', 'Nguyễn Hà My', 'Xem trước: mã ghi danh (không phân biệt hoa thường) ra học sinh');
select is(app.preview_upsale_enrollment('GD414A') ->> 'open_ticket_code', null, 'Xem trước: chưa có phiếu đang mở');
select is(app.preview_upsale_enrollment('KHONG-CO') ->> 'found', 'false', 'Xem trước: mã không có thì found = false');
select matches(app.create_upsale_ticket_from_enrollment('GD414A', 'Hỏi học tiếp') ->> 'code', '^TT[0-9]{6}$', 'Tạo tay theo mã ghi danh: ra mã TT');
select is(app.preview_upsale_enrollment('GD414A') ->> 'open_ticket_code' is not null, true, 'Xem trước sau khi tạo: báo phiếu đang mở');
select is(pg_temp.err($$select app.create_upsale_ticket_from_enrollment('GD414A')$$), 'HMT_DA_CO_PHIEU_TAI_TUC', 'R-GD-13: ghi danh đã có phiếu mở thì không tạo thêm');
select is(pg_temp.err($$select app.create_upsale_ticket_from_enrollment('KHONG-CO')$$), 'HMT_KHONG_TIM_THAY', 'Mã ghi danh sai bị chặn');
select app.create_upsale_ticket_from_enrollment('GD414B');

-- ---- Danh sách ----
select is((app.list_upsale_tickets() ->> 'total')::int, 2, 'Danh sách: 2 phiếu');
select is((app.list_upsale_tickets('{"q": "my"}') ->> 'total')::int, 1, 'Tìm theo tên học sinh');
select is((app.list_upsale_tickets('{"q": "LOP414"}') ->> 'total')::int, 2, 'Tìm theo mã lớp');
select is((app.list_upsale_tickets('{"owner": "unassigned"}') ->> 'total')::int, 2, 'Lọc chưa giao');
select is((app.list_upsale_tickets('{"owner": "mine"}') ->> 'total')::int, 0, 'Lọc của tôi: chưa có');
select is((app.list_upsale_tickets('{"stage_code": "L1"}') ->> 'total')::int, 2, 'Lọc giai đoạn L1');
select is((app.list_upsale_tickets('{"stage_code": "L2"}') ->> 'total')::int, 0, 'Lọc giai đoạn L2: trống');
select is((app.list_upsale_tickets('{}', 1, 0) -> 'rows' -> 0 ->> 'enrollment_count')::int, 1, 'Dòng ghi danh (n) = 1');
select is(jsonb_array_length(app.list_upsale_tickets('{}', 1, 0) -> 'rows'), 1, 'Phân trang: một dòng');
select is((app.list_upsale_tickets('{}', 1, 0) -> 'rows' -> 0 ->> 'stage_code'), 'L1', 'Dòng có giai đoạn');

-- ---- Kanban ----
select is(jsonb_array_length(app.upsale_board()), 8, 'Kanban: đủ 8 cột L1 đến L8');
select is((app.upsale_board() -> 0 ->> 'total')::int, 2, 'Kanban: cột L1 có 2 phiếu');
select is(jsonb_array_length(app.upsale_board() -> 0 -> 'rows'), 2, 'Kanban: cột L1 trả 2 thẻ');

-- ---- Người nhận giao ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.list_upsale_assignees((select id from app.upsale_ticket limit 1))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không có quyền Giao việc: không xem danh sách người nhận');

-- ---- RLS và quyền ----
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is((app.list_upsale_tickets() ->> 'total')::int, 0, 'CSKH cơ sở khác không thấy phiếu cơ sở này');
select is(app.preview_upsale_enrollment('GD414A') ->> 'found', 'false', 'CSKH cơ sở khác: mã ghi danh cơ sở này báo như không có (không dò được)');
select is(pg_temp.err($$select app.create_upsale_ticket_from_enrollment('GD414A')$$), 'HMT_KHONG_CO_QUYEN', 'CSKH cơ sở khác không tạo phiếu cơ sở này');
select pg_temp.claims(pg_temp.uid('ke1'), 'aal2');
select is(pg_temp.err($$select app.create_upsale_ticket_from_enrollment('GD414A')$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không tạo phiếu tái tục');
select is(pg_temp.err($$select app.upsale_target_of_enrollment('GD414A')$$), '42501', 'Người dùng không gọi trực tiếp hàm tra ghi danh');

-- ---- Bản ghi TT-02 (migration 416) ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.get_upsale_ticket((select id from app.upsale_ticket order by code limit 1)) -> 'student' ->> 'name', 'Nguyễn Hà My', 'Bản ghi: học sinh');
select is(jsonb_array_length(app.get_upsale_ticket((select id from app.upsale_ticket order by code limit 1)) -> 'enrollments'), 1, 'Bản ghi: một ghi danh liên quan');
select is(app.get_upsale_ticket((select id from app.upsale_ticket order by code limit 1)) -> 'actions', '["doi_giai_doan", "sua_ghi_chu", "tao_bao_gia", "tao_don"]'::jsonb, 'Bản ghi: CSKH đổi giai đoạn, sửa ghi chú, tạo báo giá và đơn (R-GD-13); không có Giao việc');
select is(app.get_upsale_ticket((select id from app.upsale_ticket order by code limit 1)) -> 'hours' ->> 'window_days', '30', 'Bản ghi: cửa sổ xét vắng 30 ngày');
select is(jsonb_array_length(app.get_upsale_ticket((select id from app.upsale_ticket order by code limit 1)) -> 'events'), 1, 'Bản ghi: một sự kiện Tạo');

-- TT-02 «Đã mua gần nhất» (migration 623): lần cấp giờ mua (CAP_MUA) mới nhất của em ở lớp; chưa mua thì null; giờ tặng không tính.
select is(app.get_upsale_ticket(pg_temp.ticket_of('HS414A')) -> 'hours' -> 'last_purchase', 'null'::jsonb, 'Đã mua gần nhất: chưa có lần mua thì null');
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, created_at)
  select e.id, e.branch_id, v.t, v.h, v.at from app.enrollment e,
  (values ('CAP_MUA', 40, now() - interval '60 days'), ('CAP_MUA', 30, now() - interval '10 days'), ('CAP_TANG', 5, now())) v (t, h, at) where e.code = 'GD414A'$$);
select is((app.get_upsale_ticket(pg_temp.ticket_of('HS414A')) -> 'hours' -> 'last_purchase' ->> 'hours')::numeric, 30::numeric, 'Đã mua gần nhất: lấy lần CAP_MUA mới nhất, không lấy giờ tặng');
select is(app.get_upsale_ticket(pg_temp.ticket_of('HS414B')) -> 'hours' -> 'last_purchase', 'null'::jsonb, 'Đã mua gần nhất: không lẫn sang em khác');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.get_upsale_ticket(pg_temp.anyt())$$), 'HMT_KHONG_CO_QUYEN', 'Cơ sở khác: không xem được bản ghi phiếu');

select * from finish();
rollback;
