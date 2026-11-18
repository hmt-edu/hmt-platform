-- PR 6d: phiên bản ma trận quyền (mỗi lần Lưu một phiên bản, hiệu lực ngay, lịch sử chỉ xem).
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

-- Một ô quyền cho hàm lưu.
create function pg_temp.cell(p_role text, p_module text, p_action text, p_scope text) returns jsonb language sql as $$
  select jsonb_build_object('role', p_role, 'module', p_module, 'action', p_action, 'scope', p_scope);
$$;
-- Lưu một mảng ô, dựa trên phiên bản hiện hành.
create function pg_temp.save(p_cells jsonb) returns integer language sql as $$
  select app.save_permission_matrix(app.permission_current_version(), p_cells);
$$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email)
select id, 'authenticated', 'authenticated', key || '@pb.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@pb.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales', 'SALES')) as v (key, role) on v.key = u.key;

-- Phiên bản hiện hành lúc bắt đầu bài (đã có các phiên bản do migration nạp); các phiên bản mới của bài tính từ đây.
create temp table base as select app.permission_current_version() as v;
grant select on base to authenticated;

-- Phiên bản khởi tạo.
select is((select version_no from app.permission_version order by version_no limit 1), 1, 'Phiên bản 1 có sẵn');
select is((select note from app.permission_version where version_no = 1), 'Khởi tạo', 'Phiên bản 1 là bản khởi tạo');
select ok((select v from base) >= 1, 'Có phiên bản hiện hành');

-- Admin (đã xác thực hai bước) lưu.
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');

select is(pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'HUY', 'CO_SO'))), (select v + 1 from base),
          'Lưu một ô: tạo phiên bản mới');
select is((select scope_code from app.permission where role_code = 'SALES' and module_code = 'LEAD' and action_code = 'HUY' and is_active),
          'CO_SO', 'Có hiệu lực ngay: ô quyền đã đổi');
select is((select changed_count from app.permission_version where version_no = (select v + 1 from base)), 1, 'Phiên bản mới ghi đúng số ô đổi');
select is((select saved_by from app.permission_version where version_no = (select v + 1 from base)), (select id from u where key = 'admin'),
          'Phiên bản ghi người lưu');
select is((select array[from_scope, to_scope] from app.permission_change c
           join app.permission_version v on v.id = c.version_id where v.version_no = (select v + 1 from base) and c.role_code = 'SALES'),
          array[null, 'CO_SO'], 'Ô đã đổi ghi từ (chưa có quyền) sang CO_SO');

-- Luật: phiên bản đang xem phải là hiện hành.
select is(pg_temp.err($$select app.save_permission_matrix((select v - 1 from base), jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'HUY', 'CHINH_MINH')))$$),
          'HMT_PHIEN_BAN_CU', 'Đang xem phiên bản cũ: báo có người vừa lưu, không ghi đè');
select is(app.permission_current_version(), (select v + 1 from base), 'Lưu bị từ chối thì không tạo phiên bản');

-- Luật: phải có ô đổi thật.
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'HUY', 'CO_SO')))$$),
          'HMT_KHONG_CO_THAY_DOI', 'Lưu ô giữ nguyên: không có thay đổi, không tạo phiên bản');
select is(pg_temp.err($$select pg_temp.save('[]'::jsonb)$$), 'HMT_KHONG_CO_THAY_DOI', 'Lưu danh sách rỗng: không có thay đổi');
select is(app.permission_current_version(), (select v + 1 from base), 'Không đổi thật thì không có phiên bản mới');

-- Nhiều ô một lần: bỏ quyền, thêm quyền; ô giữ nguyên bị bỏ qua, không tính.
select is(pg_temp.save(jsonb_build_array(
            pg_temp.cell('SALES', 'LEAD', 'HUY', null),
            pg_temp.cell('SALES', 'LEAD', 'GIAO_VIEC', 'CUA_TOI'),
            pg_temp.cell('SALES', 'LEAD', 'XEM', 'CO_SO'))), (select v + 2 from base), 'Lưu nhiều ô: một phiên bản mới');
select is((select changed_count from app.permission_version where version_no = (select v + 2 from base)), 2,
          'Chỉ tính ô đổi thật (ô giữ nguyên bị bỏ qua)');
select is((select is_active from app.permission where role_code = 'SALES' and module_code = 'LEAD' and action_code = 'HUY'), false,
          'Bỏ quyền: dòng tắt, không xoá');
select is((select array[from_scope, to_scope] from app.permission_change c
           join app.permission_version v on v.id = c.version_id
           where v.version_no = (select v + 2 from base) and c.action_code = 'HUY'), array['CO_SO', null], 'Ô bỏ quyền ghi từ CO_SO sang rỗng');

-- Hoàn tác cả lần lưu khi một ô sai.
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(
            pg_temp.cell('SALES', 'LEAD', 'SUA', 'CUA_TOI'), pg_temp.cell('SALES', 'ADMIN', 'XEM', 'CO_SO')))$$),
          'HMT_QUYEN_QUAN_TRI', 'Cấp phân hệ Quản trị cho vai trò khác ADMIN: bị chặn');
select is((select scope_code from app.permission where role_code = 'SALES' and module_code = 'LEAD' and action_code = 'SUA'),
          'CO_SO', 'Một ô sai thì cả lần lưu hoàn tác: ô hợp lệ cùng lần không đổi');
select is(app.permission_current_version(), (select v + 2 from base), 'Lưu hỏng thì không tạo phiên bản');
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('KHONG_CO', 'LEAD', 'XEM', 'CO_SO')))$$),
          'HMT_O_QUYEN_SAI', 'Vai trò không có: báo ô sai');
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'XEM', 'KHONG_CO')))$$),
          'HMT_O_QUYEN_SAI', 'Phạm vi không có: báo ô sai');
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(
            pg_temp.cell('SALES', 'LEAD', 'SUA', 'CUA_TOI'), pg_temp.cell('SALES', 'LEAD', 'SUA', 'CO_SO')))$$),
          'HMT_O_QUYEN_SAI', 'Một ô lặp hai lần trong cùng lần lưu: báo ô sai');

-- Hàm sửa từng ô không còn cho giao diện gọi.
select is(pg_temp.err($$select app.set_permission('SALES', 'LEAD', 'SUA', 'CUA_TOI')$$), '42501',
          'Giao diện không gọi được hàm sửa từng ô (chỉ qua lưu phiên bản)');

-- Admin đọc được lịch sử.
select is((select count(*)::int from app.permission_version), (select v + 2 from base), 'Admin đọc được danh sách phiên bản');
select ok((select count(*) from app.permission_change) >= 1, 'Admin đọc được ô đã đổi');

-- Người không phải Admin: không lưu được, không đọc được lịch sử.
select pg_temp.claims((select id from u where key = 'sales'), 'aal1');
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'SUA', 'CUA_TOI')))$$),
          'HMT_KHONG_CO_QUYEN', 'Vai trò khác Admin: không lưu được ma trận');
select is((select count(*)::int from app.permission_version), 0, 'Vai trò khác Admin: không thấy lịch sử phiên bản');
select is((select count(*)::int from app.permission_change), 0, 'Vai trò khác Admin: không thấy ô đã đổi');
select is(pg_temp.err($$insert into app.permission_version (version_no, changed_count) values (99, 0)$$), '42501',
          'Không ai ghi thẳng bảng phiên bản');

-- Lịch sử chỉ thêm: ngay cả chủ DB cũng không sửa, không xoá.
reset role;
select set_config('request.jwt.claims', '', true);
select is(pg_temp.err($$update app.permission_version set changed_count = 9 where version_no = 2$$), 'HMT_LICH_SU_QUYEN_CHI_THEM',
          'Lịch sử phiên bản không sửa được');
select is(pg_temp.err($$update app.permission_change set to_scope = 'TOAN_HE_THONG'$$), 'HMT_LICH_SU_QUYEN_CHI_THEM',
          'Ô đã đổi không sửa được');
select is(pg_temp.err($$delete from app.permission_version where version_no = 2$$), 'HMT_LICH_SU_QUYEN_CHI_THEM', 'Phiên bản không xoá được');
select is(pg_temp.err($$delete from app.permission_change$$), 'HMT_LICH_SU_QUYEN_CHI_THEM', 'Ô đã đổi không xoá được');
select is(pg_temp.err($$truncate app.permission_version cascade$$), 'HMT_LICH_SU_QUYEN_CHI_THEM', 'Không xoá sạch được bảng phiên bản');
select is(pg_temp.err($$truncate app.permission_change$$), 'HMT_LICH_SU_QUYEN_CHI_THEM', 'Không xoá sạch được bảng ô đã đổi');
select is((select array_agg(version_no order by version_no) from app.permission_version),
          (select array_agg(g order by g) from generate_series(1, (select v + 2 from base)) g),
          'Số phiên bản liền nhau');

select * from finish();
rollback;
