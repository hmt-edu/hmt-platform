-- CHUNG-15 (migration 556): app.list_my_approvals, việc chờ tôi duyệt gộp mọi loại. Luật R-V2-12, R-HT-01 (Admin không duyệt tiền), R-LOP-02, R-BUOI-03, R-CS-07: chỉ việc ĐẾN LƯỢT vai của người gọi,
-- người tạo không tự duyệt, ngoài phạm vi cơ sở bị chặn. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('bm1'), ('bm2'), ('acc'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p556.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p556.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'bm2' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'bm1' then 'BRANCH_MANAGER' when 'bm2' then 'BRANCH_MANAGER' when 'acc' then 'ACCOUNTANT' else 'SALES' end from u;
grant execute on all functions in schema pg_temp to public;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, b.id, true from app.branch b, unnest(array['BAN_HANG','AFTERSALE','HOAN_PHI','VAN_HANH_LOP']) m where b.code in ('CS1', 'CS2')
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Dữ liệu CS1: phụ huynh, học sinh, ghi danh, lớp, đơn DA_TRINH (do sales1 lập, quản lý bm1), phiếu thu DA_GUI và CHO_KE_TOAN, lớp DA_TRINH và DA_XAC_NHAN,
-- yêu cầu buổi, hoàn phí CHO_QL và CHO_KE_TOAN, dừng học CHO_QL, bảo lưu CHO_DUYET, chuyển lớp CHO_DUYET, phiếu nghiệp vụ CHO_DUYET (KE_TOAN).
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH556', 'Phụ huynh giả 556', '0900556001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS556', p.id, 'Em giả 556', 2012, p.branch_id from app.parent p where p.code = 'PH556'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD556' || n, s.id, s.parent_id, s.branch_id, 'DANG_HOC' from app.student s, generate_series(1, 5) n where s.code = 'HS556'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10, c.st from app.branch b,
    (values ('LOP556A', 'DA_TRINH'), ('LOP556B', 'DA_XAC_NHAN'), ('LOP556C', 'DA_DUYET')) c (code, st) where b.code = 'CS1'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code)
  select 'LOP556X', b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10, 'DA_TRINH' from app.branch b where b.code = 'CS2'$$);
-- Ràng buộc nguồn đơn (cơ hội hoặc phiếu tái tục) bỏ trong giao dịch kiểm thử để khỏi dựng cả chuỗi tuyển sinh.
select pg_temp.sudo($$alter table app.sales_order drop constraint sales_order_check$$);
select pg_temp.sudo($$insert into app.sales_order (code, branch_id, parent_id, priced_on, status_code, approval_route, assigned_approver_id, submitted_at, created_by)
  select 'DH556', p.branch_id, p.id, current_date, 'DA_TRINH', 'QUAN_LY', pg_temp.uid('bm1'), now() - interval '2 days', pg_temp.uid('sales1') from app.parent p where p.code = 'PH556'$$);
select pg_temp.sudo($$insert into app.receipt (code, parent_id, branch_id, collect_branch_id, amount, payment_method_code, is_opening_debt, status_code, approval_route, assigned_approver_id, submitted_at, created_by)
  select v.code, p.id, p.branch_id, p.branch_id, 100000, 'TIEN_MAT', true, v.st, 'QUAN_LY', pg_temp.uid('bm1'), now() - interval '1 day', pg_temp.uid('sales1')
    from app.parent p, (values ('PT556A', 'DA_GUI'), ('PT556B', 'CHO_KE_TOAN')) v (code, st) where p.code = 'PH556'$$);
select pg_temp.sudo($$insert into app.session_request (code, branch_id, kind, class_id, session_date, start_time, end_time, status_code, created_by, submitted_at)
  select 'YC556', c.branch_id, 'CUNG_CO', c.id, current_date + 3, '18:00', '19:30', 'CHO_DUYET', pg_temp.uid('sales1'), now() - interval '5 hours' from app.class c where c.code = 'LOP556C'$$);
select pg_temp.sudo($$insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net, base_amount, fee_percent, fee_amount, refund_amount, status_code, created_by)
  select e.id, e.student_id, e.branch_id, 'TOAN_BO', 'KHAC', 1, 1000, 0, 1000, 1000, 1000, 0, 0, 1000, v.st, pg_temp.uid('sales1')
    from app.enrollment e join (values ('GD5561', 'CHO_QL'), ('GD5562', 'CHO_KE_TOAN')) v (code, st) on v.code = e.code$$);
select pg_temp.sudo($$insert into app.enrollment_stop (enrollment_id, student_id, parent_id, branch_id, reason_code, hours_left, hours_paid_left, hours_cancelled, unit_price_net, balance_amount, status_code, created_by)
  select e.id, e.student_id, e.parent_id, e.branch_id, 'KHAC', 1, 1, 0, 1000, 1000, 'CHO_QL', pg_temp.uid('sales1') from app.enrollment e where e.code = 'GD5563'$$);
select pg_temp.sudo($$insert into app.enrollment_hold (enrollment_id, student_id, branch_id, kind_code, months, reason_code, status_code, created_by)
  select e.id, e.student_id, e.branch_id, 'MOI', 1, 'KHAC', 'CHO_DUYET', pg_temp.uid('sales1') from app.enrollment e where e.code = 'GD5564'$$);
select pg_temp.sudo($$insert into app.class_transfer (enrollment_id, student_id, from_class_id, to_class_id, from_branch_id, to_branch_id, start_date, kind_code, reason_code, hours_snapshot, status_code, created_by)
  select e.id, e.student_id, (select id from app.class where code = 'LOP556C'), (select id from app.class where code = 'LOP556B'), e.branch_id, e.branch_id, current_date, 'DOI_GIO', 'KHAC', 1, 'CHO_DUYET', pg_temp.uid('sales1')
    from app.enrollment e where e.code = 'GD5565'$$);
select pg_temp.sudo($$insert into app.ticket (code, ticket_type, branch_id, parent_id, title, description, channel_code, category_code, priority_code, response_due_at, resolve_due_at)
  select 'TK556', 'DN', b.id, p.id, 'Giả', 'Giả', 'EMAIL', 'DN_01', 'THUONG', now() + interval '1 day', now() + interval '2 days' from app.branch b, app.parent p where b.code = 'CS1' and p.code = 'PH556'$$);
-- D-23-30: dữ liệu phiếu giả chưa có ghi danh thật; dựng bằng cờ di chuyển dữ liệu (luật phạm vi bỏ qua), việc thử ở đây không phải payload.
select set_config('hmt.migration', 'on', true);
select pg_temp.sudo($$insert into app.ticket_task (code, ticket_id, branch_id, task_type, status_code, reason, levels, current_level, created_by, submitted_at)
  select 'PN556', t.id, t.branch_id, 'CHUYEN_PHI', 'CHO_DUYET', 'Giả', array['KE_TOAN'], 1, pg_temp.uid('sales1'), now() - interval '3 hours' from app.ticket t where t.code = 'TK556'$$);
select set_config('hmt.migration', 'off', true);

-- Bảng dùng chung cho các lần gọi.
create function pg_temp.items(p_filters jsonb default '{}') returns jsonb language sql stable as $$ select app.list_my_approvals(p_filters) $$;
create function pg_temp.kinds(p_j jsonb) returns text language sql immutable as $$ select coalesce(string_agg(distinct x ->> 'kind', ',' order by x ->> 'kind'), '') from jsonb_array_elements(p_j -> 'rows') x $$;
grant execute on function pg_temp.items(jsonb), pg_temp.kinds(jsonb) to public;

-- ---- Trưởng cơ sở CS1: việc quản lý, không có tiền cấp Kế toán, lớp, yêu cầu buổi, aftersale cấp quản lý ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is(pg_temp.kinds(pg_temp.items()), 'BAO_LUU,CHUYEN_LOP,DON_HANG,DUNG_HOC,HOAN_PHI,LOP,PHIEU_THU,YEU_CAU_BUOI', 'CHUNG-15: Trưởng cơ sở thấy đơn, phiếu thu (cấp quản lý), lớp, yêu cầu buổi, hoàn phí, dừng học, bảo lưu, chuyển lớp');
select is((pg_temp.items() -> 'counts' ->> 'LOP')::int, 2, 'CHUNG-15: hai lớp chờ (Đã trình và Đã xác nhận) của CS1; lớp CS2 không thấy');
select is((pg_temp.items() -> 'counts' ->> 'PHIEU_THU')::int, 1, 'CHUNG-15: Trưởng cơ sở chỉ thấy phiếu thu cấp quản lý (DA_GUI), không thấy cấp Kế toán');
select is((pg_temp.items() -> 'counts' ->> 'HOAN_PHI')::int, 1, 'CHUNG-15: hoàn phí: Trưởng cơ sở chỉ thấy cấp CHO_QL');
select is((select (x ->> 'level_total')::int from jsonb_array_elements(pg_temp.items('{"kind": "PHIEU_THU"}') -> 'rows') x limit 1), 2, 'CHUNG-15: phiếu thu có hai cấp duyệt');
select is((pg_temp.items('{"kind": "DON_HANG"}') ->> 'total')::int, 1, 'CHUNG-15: lọc theo loại việc');
select is((pg_temp.items() -> 'rows' -> 0 ->> 'kind'), 'DON_HANG', 'CHUNG-15: chờ lâu nhất lên đầu (đơn nộp 2 ngày trước)');
select is(jsonb_array_length(pg_temp.items() -> 'rows'), (pg_temp.items() ->> 'total')::int, 'CHUNG-15: số dòng khớp tổng khi một trang');
select is((pg_temp.items('{"kind": "HOAN_PHI"}') -> 'rows' -> 0 ->> 'open_id')::uuid, (select id from app.enrollment where code = 'GD5561'), 'CHUNG-15: dòng hoàn phí mở bản ghi ghi danh (open_id là id ghi danh)');
select is((pg_temp.items('{"kind": "DON_HANG"}') -> 'rows' -> 0 ->> 'open_id')::uuid, (select id from app.sales_order where code = 'DH556'), 'CHUNG-15: dòng đơn hàng mở chính đơn (open_id là id đơn)');
select is(jsonb_array_length(app.list_my_approvals('{}', 2, 0) -> 'rows'), 2, 'CHUNG-15: phân trang theo số dòng');
reset role;

-- ---- Trưởng cơ sở CS2: không thấy việc CS1, thấy lớp CS2 ----
select pg_temp.claims(pg_temp.uid('bm2'), 'aal1');
set local role authenticated;
select is(pg_temp.kinds(pg_temp.items()), 'LOP', 'CHUNG-15: Trưởng cơ sở CS2 chỉ thấy lớp của CS2 (đọc ngoài phạm vi bị chặn)');
reset role;

-- ---- Kế toán: tiền cấp Kế toán ----
select pg_temp.claims(pg_temp.uid('acc'), 'aal2');
set local role authenticated;
select is(pg_temp.kinds(pg_temp.items()), 'HOAN_PHI,PHIEU_NGHIEP_VU,PHIEU_THU', 'CHUNG-15: Kế toán thấy phiếu thu, hoàn phí và phiếu nghiệp vụ cấp Kế toán');
select is((pg_temp.items('{"kind": "PHIEU_THU"}') -> 'rows' -> 0 ->> 'code'), 'PT556B', 'CHUNG-15: Kế toán chỉ thấy phiếu thu đã qua cấp quản lý');
reset role;

-- ---- Admin: duyệt được cả việc tiền (R-HT-01, 26/11) ----
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select ok(pg_temp.kinds(pg_temp.items()) like '%PHIEU_THU%', 'CHUNG-15: Admin thấy phiếu thu chờ duyệt (R-HT-01, 26/11)');
select is((pg_temp.items('{"kind": "HOAN_PHI"}') ->> 'total')::int, 2, 'CHUNG-15: Admin thấy hoàn phí cả cấp quản lý và cấp Kế toán (như hàm duyệt)');
select ok(pg_temp.kinds(pg_temp.items()) like '%DON_HANG%' and pg_temp.kinds(pg_temp.items()) like '%LOP%', 'CHUNG-15: Admin duyệt thay đơn và thấy lớp');
select is((pg_temp.items('{"branch_id": null}') ->> 'total')::int > 0, true, 'CHUNG-15: Admin thấy việc nhiều cơ sở');
select is((pg_temp.items(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS2'))) ->> 'total')::int, 1, 'CHUNG-15: lọc cơ sở CS2');
reset role;

-- ---- Người tạo không tự duyệt; người không có quyền duyệt không thấy gì ----
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is((pg_temp.items() ->> 'total')::int, 0, 'CHUNG-15: nhân viên bán hàng không có quyền duyệt nên không thấy việc nào');
reset role;
select * from finish();
rollback;
