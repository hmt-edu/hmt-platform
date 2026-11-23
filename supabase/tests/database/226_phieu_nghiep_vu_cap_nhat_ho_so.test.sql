-- Phiếu nghiệp vụ A1 (migration 226): tạo, trình, duyệt, từ chối, thực hiện, huỷ; phiếu Cập nhật hồ sơ; luật chặn; RLS; ticket tự sang Đã xử lý. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

-- Ticket DN_04_01 (Cập nhật thông tin HS, PH) có học sinh; CSKH tạo.
create temp table pt1 (j jsonb);
grant all on pt1 to public;
insert into pt1 select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create function pg_temp.tid() returns uuid language sql as $$ select (j ->> 'id')::uuid from pt1 $$;
grant execute on function pg_temp.tid() to public;
create temp table k1 (j jsonb);
grant all on k1 to public;
create function pg_temp.kid() returns uuid language sql as $$ select (j ->> 'id')::uuid from k1 $$;
grant execute on function pg_temp.kid() to public;

-- ================= Tạo phiếu (Nháp) =================
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', '', '{}'::jsonb)$$), 'HMT_THIEU_THONG_TIN', 'Chặn: thiếu lý do');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'LOAI_LA', 'Lý do', '{}'::jsonb)$$), 'HMT_PHIEU_LOAI_SAI', 'Chặn: loại phiếu không có');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'DOI_LICH', 'Lý do', '{}'::jsonb)$$), 'HMT_PHIEU_KHAC_NHOM', 'Chặn: nhóm con của ticket dùng phiếu Cập nhật hồ sơ, không phải Đổi lịch (R-V2-24)');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', 'Lý do', '{}'::jsonb)$$), 'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: phiếu Cập nhật hồ sơ không có hồ sơ và trường cần sửa');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', 'Lý do', '{"entity":"STUDENT","changes":{"full_name":"Tên mới"}}'::jsonb)$$), 'HMT_PHIEU_TRUONG_SAI', 'Chặn: trường không được sửa bằng phiếu (họ tên học sinh không nằm trong cấu hình)');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', 'Lý do', '{"entity":"PARENT","changes":{"phone":"0900000000"}}'::jsonb)$$), 'HMT_PHIEU_TRUONG_SAI', 'Chặn: không sửa SĐT bằng phiếu (danh tính hồ sơ)');
insert into k1 select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', 'Phụ huynh báo đổi trường', '{"entity":"STUDENT","changes":{"school":"Trường Thử A","grade":"9"}}'::jsonb);
select alike((select j ->> 'code' from k1), 'PNV-CS5-____-0001', 'Mã phiếu PNV-CS5-YYMM-0001');
select is((select status_code from app.ticket_task where id = pg_temp.kid()), 'NHAP', 'Phiếu mới ở bước Nháp');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', 'Lý do khác', '{"entity":"STUDENT","changes":{"goal":"x"}}'::jsonb)$$), 'HMT_PHIEU_DA_CO', 'Chặn: ticket đã có một phiếu đang mở (AS-10)');
select is((select count(*)::int from app.ticket_task_event where task_id = pg_temp.kid()), 1, 'Nhật ký phiếu có dòng Tạo');

-- ================= Thực hiện khi chưa duyệt, trình, tự duyệt =================
select is(pg_temp.err($$select app.execute_ticket_task(pg_temp.kid())$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: thực hiện phiếu chưa duyệt');
select is(pg_temp.err($$select app.approve_ticket_task(pg_temp.kid())$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: duyệt phiếu chưa trình');
select app.submit_ticket_task(pg_temp.kid());
select is((select status_code || '/' || current_level from app.ticket_task where id = pg_temp.kid()), 'CHO_DUYET/1', 'Trình duyệt: Chờ duyệt, cấp 1');
select is(pg_temp.err($$select app.submit_ticket_task(pg_temp.kid())$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: trình lại phiếu đã trình');
select is(pg_temp.err($$select app.approve_ticket_task(pg_temp.kid())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không có quyền duyệt (Ticket · Duyệt)');

-- ================= Duyệt bởi quản lý cơ sở =================
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select app.approve_ticket_task(pg_temp.kid(), ' Đồng ý ');
select is((select status_code from app.ticket_task where id = pg_temp.kid()), 'DA_DUYET', 'Quản lý cơ sở duyệt (một cấp): Đã duyệt');
select is((select note from app.ticket_task_event where task_id = pg_temp.kid() and event_type = 'DUYET'), 'Đồng ý', 'Nhật ký duyệt lưu ghi chú đã cắt khoảng trắng');
select is((select count(*)::int from app.ticket_task where id = pg_temp.kid()), 1, 'Quản lý cơ sở thấy phiếu (RLS theo ticket)');
-- Thực hiện: Ticket · Sửa (CSKH hoặc quản lý đều có)
select app.execute_ticket_task(pg_temp.kid());
select is((select status_code from app.ticket_task where id = pg_temp.kid()), 'DA_THUC_HIEN', 'Thực hiện: Đã thực hiện');
select is((select school || '/' || grade from app.student where code = 'HSAS501'), 'Trường Thử A/9', 'Thực hiện: hồ sơ học sinh đã cập nhật');
select is((select result #>> '{before,school}' from app.ticket_task where id = pg_temp.kid()), null, 'Kết quả phiếu giữ giá trị trước (trường trước đó chưa có)');
select is((select status_code from app.ticket where id = pg_temp.tid()), 'DA_XU_LY', 'Ticket có nghiệp vụ tự sang Đã xử lý khi phiếu xong (AS-03)');
select ok((select resolution like 'Phiếu PNV-%' from app.ticket where id = pg_temp.tid()), 'Ticket ghi kết quả theo mã phiếu');
select is(pg_temp.err($$select app.execute_ticket_task(pg_temp.kid())$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: thực hiện lại phiếu đã thực hiện');
select is(pg_temp.err($$select app.cancel_ticket_task(pg_temp.kid(), 'Muộn')$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: huỷ phiếu đã thực hiện');

-- ================= Từ chối, huỷ, người tạo không tự duyệt =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t2 (j jsonb);
grant all on t2 to public;
insert into t2 select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create temp table k2 (j jsonb);
grant all on k2 to public;
insert into k2 select app.create_ticket_task((select (j ->> 'id')::uuid from t2), 'CAP_NHAT_HO_SO', 'Sửa mục tiêu', '{"entity":"STUDENT","changes":{"goal":"Thi chuyên"}}'::jsonb);
select app.submit_ticket_task((select (j ->> 'id')::uuid from k2));
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select is(pg_temp.err($$select app.reject_ticket_task((select (j ->> 'id')::uuid from k2), '  ')$$), 'HMT_PHIEU_THIEU_LY_DO', 'Chặn: từ chối không lý do');
select app.reject_ticket_task((select (j ->> 'id')::uuid from k2), 'Thiếu giấy tờ');
select is((select status_code || '|' || reject_reason from app.ticket_task where id = (select (j ->> 'id')::uuid from k2)), 'TU_CHOI|Thiếu giấy tờ', 'Từ chối: lưu lý do');
select is((select status_code from app.ticket where id = (select (j ->> 'id')::uuid from t2)), 'DA_XU_LY', 'Từ chối cũng đưa ticket sang Đã xử lý (AS-03)');
select is((select goal from app.student where code = 'HSAS501') is null, true, 'Từ chối thì hồ sơ không đổi');
-- Quản lý tạo phiếu rồi tự duyệt: chặn.
create temp table t3 (j jsonb);
grant all on t3 to public;
insert into t3 select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create temp table k3 (j jsonb);
grant all on k3 to public;
insert into k3 select app.create_ticket_task((select (j ->> 'id')::uuid from t3), 'CAP_NHAT_HO_SO', 'Tự tạo', '{"entity":"PARENT","changes":{"address":"Số 1 phố Thử"}}'::jsonb);
select app.submit_ticket_task((select (j ->> 'id')::uuid from k3));
select is(pg_temp.err($$select app.approve_ticket_task((select (j ->> 'id')::uuid from k3))$$), 'HMT_PHIEU_TU_DUYET', 'Chặn: người tạo phiếu không tự duyệt');
select is(pg_temp.err($$select app.cancel_ticket_task((select (j ->> 'id')::uuid from k3), '')$$), 'HMT_PHIEU_THIEU_LY_DO', 'Chặn: huỷ phiếu không lý do');
select app.cancel_ticket_task((select (j ->> 'id')::uuid from k3), 'Nhập nhầm');
select is((select status_code from app.ticket_task where id = (select (j ->> 'id')::uuid from k3)), 'DA_HUY', 'Huỷ phiếu có lý do');
select is((select status_code from app.ticket where id = (select (j ->> 'id')::uuid from t3)), 'MOI', 'Huỷ phiếu không tự đổi trạng thái ticket');

-- ================= Phiếu hai cấp (Hoàn học phí): cấp kế toán =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t4 (j jsonb);
grant all on t4 to public;
insert into t4 select app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create temp table k4 (j jsonb);
grant all on k4 to public;
-- D-23-30: dữ liệu phiếu giả chưa có ghi danh thật; dựng bằng cờ di chuyển dữ liệu (luật phạm vi bỏ qua), việc thử ở đây không phải payload.
select set_config('hmt.migration', 'on', true);
insert into k4 select app.create_ticket_task((select (j ->> 'id')::uuid from t4), 'HOAN_PHI', 'Gia đình chuyển nhà', '{}'::jsonb);
select app.submit_ticket_task((select (j ->> 'id')::uuid from k4));
select set_config('hmt.migration', 'off', true);
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select app.approve_ticket_task((select (j ->> 'id')::uuid from k4));
select is((select status_code || '/' || current_level from app.ticket_task where id = (select (j ->> 'id')::uuid from k4)), 'CHO_DUYET/2', 'Hoàn học phí: duyệt cấp 1 xong còn chờ cấp 2 (kế toán)');
select is(pg_temp.err($$select app.approve_ticket_task((select (j ->> 'id')::uuid from k4))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: cấp kế toán, quản lý cơ sở không duyệt thay');
select is(pg_temp.err($$select app.execute_ticket_task((select (j ->> 'id')::uuid from k4))$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: chưa đủ cấp duyệt thì chưa thực hiện');

-- ================= Cơ sở khác, giáo viên, công tắc =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.ticket_task), 0, 'CSKH cơ sở khác không thấy phiếu (RLS)');
select is(pg_temp.err($$select app.submit_ticket_task((select (j ->> 'id')::uuid from k4))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH cơ sở khác không trình phiếu');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is((select count(*)::int from app.ticket_task), 0, 'Giáo viên không thấy phiếu không thuộc ticket của mình');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.tid(), 'CAP_NHAT_HO_SO', 'x', '{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không tạo phiếu (không có Ticket · Sửa)');
select is(has_function_privilege('anon', 'app.create_ticket_task(uuid,text,text,jsonb)', 'execute'), false, 'anon không gọi được hàm phiếu');

select * from finish();
rollback;
