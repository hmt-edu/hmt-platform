-- TT-A Phiếu tái tục (migration 410): mã TT, tạo tay, giao việc, đổi giai đoạn, sửa ghi chú, RLS. Luật R-GD-13, R-V2-25 (chốt lại 18/11). Dữ liệu giả.
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
create function pg_temp.sid(p_code text) returns uuid language sql stable security definer as $$ select id from app.student where code = p_code $$;
create function pg_temp.cid(p_code text) returns uuid language sql stable security definer as $$ select id from app.class where code = p_code $$;
create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as $$ select id from app.upsale_ticket where code = p_code $$;
create function pg_temp.stage(p_code text) returns text language sql stable security definer as $$ select stage_code from app.upsale_ticket where code = p_code $$;
create function pg_temp.evs(p_code text) returns text language sql stable security definer as $$
  select string_agg(event_type, ',' order by seq) from app.upsale_ticket_event where ticket_id = pg_temp.tid(p_code) $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('cskh5'), ('bm1'), ('ke1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p410.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p410.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('cskh1', 'CS1'), ('cskh5', 'CS5'), ('bm1', 'CS1'), ('ke1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh1', 'CSKH'), ('cskh5', 'CSKH'), ('bm1', 'BRANCH_MANAGER'), ('ke1', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Dữ liệu: hai học sinh học lớp L1 ở CS1; một học sinh không có dòng xếp lớp.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH410', 'Phụ huynh giả 410', '0900410001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS410A', 'Em A'), ('HS410B', 'Em B'), ('HS410C', 'Em C')) s (code, name) where p.code = 'PH410'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP410', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id)
  select 'GD410' || right(s.code, 1), s.id, s.parent_id, s.branch_id from app.student s where s.code in ('HS410A', 'HS410B')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where e.code in ('GD410A', 'GD410B') and c.code = 'LOP410'$$);

-- Mã phiếu: TT + 6 số (spec 02).
select is((select prefix || ':' || pad_width from app.code_format where code = 'TT'), 'TT:6', 'Mã phiếu tái tục: tiền tố TT, 6 số');

set local role authenticated;
-- ---- Tạo tay (TT-03) ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select matches(app.create_upsale_ticket(pg_temp.sid('HS410A'), pg_temp.cid('LOP410'), 'Phụ huynh hỏi học tiếp') ->> 'code', '^TT[0-9]{6}$', 'CSKH tạo phiếu tay: mã TT + 6 số');
select is(pg_temp.stage((select code from app.upsale_ticket where student_id = pg_temp.sid('HS410A'))), 'L1', 'Phiếu tạo tay ở L1');
select is((select substage_code from app.upsale_ticket where student_id = pg_temp.sid('HS410A')), 'L1B', 'Phiếu tạo tay ở nhóm con L1B');
select is(pg_temp.err($$select app.create_upsale_ticket(pg_temp.sid('HS410A'), pg_temp.cid('LOP410'))$$), 'HMT_DA_CO_PHIEU_TAI_TUC', 'R-GD-13: mỗi học sinh ở mỗi lớp tối đa một phiếu đang mở');
select is(pg_temp.err($$select app.create_upsale_ticket(pg_temp.sid('HS410C'), pg_temp.cid('LOP410'))$$), 'HMT_HOC_SINH_KHONG_O_LOP', 'R-GD-13: học sinh không học ở lớp thì không tạo được');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.create_upsale_ticket(pg_temp.sid('HS410B'), pg_temp.cid('LOP410'))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH cơ sở khác không tạo phiếu ở cơ sở này');
select is((select count(*)::int from app.upsale_ticket), 0, 'RLS: CSKH cơ sở khác không thấy phiếu cơ sở này');
select pg_temp.claims(pg_temp.uid('ke1'), 'aal2');
select is(pg_temp.err($$select app.create_upsale_ticket(pg_temp.sid('HS410B'), pg_temp.cid('LOP410'))$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không tạo phiếu tái tục');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.upsale_ticket), 1, 'RLS: CSKH cùng cơ sở thấy phiếu');

-- ---- Giao việc ----
select is(pg_temp.err($$select app.assign_upsale_ticket((select id from app.upsale_ticket limit 1), pg_temp.uid('cskh1'))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không có quyền Giao việc (chỉ Xem, Tạo, Sửa)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.assign_upsale_ticket((select id from app.upsale_ticket limit 1), pg_temp.uid('cskh1')) ->> 'owner_id')::uuid, pg_temp.uid('cskh1'), 'Trưởng cơ sở giao phiếu cho CSKH');
select is(pg_temp.err($$select app.assign_upsale_ticket((select id from app.upsale_ticket limit 1), pg_temp.uid('cskh5'))$$), 'HMT_NGUOI_PHU_TRACH_SAI', 'Giao cho người cơ sở khác bị chặn');
select is(pg_temp.err($$select app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L2')$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở chỉ Xem, Giao việc: không đổi giai đoạn');

-- ---- Đổi giai đoạn ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L2') ->> 'stage_code', 'L2', 'L1 sang L2');
select is((select substage_code from app.upsale_ticket limit 1), null, 'Rời L1 thì bỏ nhóm con');
select is(pg_temp.err($$select app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L7')$$), 'HMT_GIAI_DOAN_KHONG_HOP_LE', 'L7 không đặt tay (do báo giá, đơn)');
select is(pg_temp.err($$select app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L8')$$), 'HMT_GIAI_DOAN_KHONG_HOP_LE', 'L8 không đặt tay');
select is(pg_temp.err($$select app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L5')$$), 'HMT_LY_DO_THIEU', 'L5 bắt buộc lý do');
select is(pg_temp.err($$select app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L5', 'KHAC')$$), 'HMT_LY_DO_THIEU', 'L5 lý do Khác bắt buộc ghi chú');
select is(app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L1') ->> 'stage_code', 'L1', 'Quay về L1');
select is((select substage_code from app.upsale_ticket limit 1), 'L1B', 'Về L1: nhóm con L1B (tạo tay)');

-- ---- Sửa hai ô tự do ----
select is(app.update_upsale_notes((select id from app.upsale_ticket limit 1), 'Muốn lên lớp nâng cao', null) ->> 'changed', 'true', 'Sửa mục tiêu: có đổi');
select is(app.update_upsale_notes((select id from app.upsale_ticket limit 1), 'Muốn lên lớp nâng cao', null) ->> 'changed', 'false', 'Sửa giống cũ: không đổi, không ghi nhật ký');
select is((select next_goal from app.upsale_ticket limit 1), 'Muốn lên lớp nâng cao', 'Mục tiêu đã lưu');

-- ---- Kết thúc L5 ----
select is(app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L5', 'HOC_PHI') ->> 'stage_code', 'L5', 'L5 Không tái tục kèm lý do Học phí');
select is((select lost_reason_code from app.upsale_ticket limit 1), 'HOC_PHI', 'Lý do đã lưu');
select isnt((select closed_at from app.upsale_ticket limit 1), null, 'L5 ghi thời điểm kết thúc');
select is(pg_temp.err($$select app.change_upsale_stage((select id from app.upsale_ticket limit 1), 'L2')$$), 'HMT_PHIEU_KHONG_DOI_TAY', 'Phiếu đã L5 không đổi tay');
select is(pg_temp.err($$select app.update_upsale_notes((select id from app.upsale_ticket limit 1), 'x', null)$$), null, 'Sửa ghi chú vẫn được sau L5 (chỉ ghi nhật ký)');
-- Phiếu L5 không chặn tạo tay phiếu mới (CSKH tạo tay L1B khi cần).
select matches(app.create_upsale_ticket(pg_temp.sid('HS410A'), pg_temp.cid('LOP410')) ->> 'code', '^TT[0-9]{6}$', 'Sau L5 vẫn tạo tay được phiếu mới');
select is(pg_temp.evs((select code from app.upsale_ticket where stage_code = 'L5')), 'TAO,GIAO,DOI_GIAI_DOAN,DOI_GIAI_DOAN,SUA_GHI_CHU,DOI_GIAI_DOAN,SUA_GHI_CHU', 'Nhật ký ghi đủ các bước');

-- ---- Nhật ký chỉ thêm, bảng không ghi trực tiếp ----
select is(pg_temp.err($$update app.upsale_ticket_event set note = 'sửa'$$), '42501', 'Người dùng không ghi trực tiếp nhật ký');
select is(pg_temp.err($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, origin_code) select 'TT999999', branch_id, id, parent_id, pg_temp.cid('LOP410'), 'TAY' from app.student limit 1$$), '42501', 'Người dùng không ghi trực tiếp bảng phiếu');
select is(pg_temp.err($$select app.issue_upsale_code()$$), '42501', 'Người dùng không gọi trực tiếp hàm cấp mã');

select * from finish();
rollback;
