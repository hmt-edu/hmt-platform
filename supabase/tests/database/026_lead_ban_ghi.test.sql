-- P3c-2: get_lead (TS-02) và dời lịch hẹn (docs/spec/04 R-CRM-04, R-CRM-38; TS-13).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò nhập trong và ngoài cơ sở.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
select pg_temp.sudo($$insert into app.campaign (name) values ('Chiến dịch thử bản ghi')$$);
select pg_temp.sudo($$create function pg_temp.camp() returns uuid language sql stable security definer as 'select id from app.campaign where name = ''Chiến dịch thử bản ghi'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.camp() to public$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create temp table ld (k text primary key, id uuid);
grant select on ld to public;
insert into ld select 'A', (app.create_lead(pg_temp.lead_data('0900000801', jsonb_build_object('parent_name', 'Chị Bản Ghi A', 'campaign_id', pg_temp.camp()))) ->> 'id')::uuid;
insert into ld select 'B', (app.create_lead(pg_temp.lead_data('0900000802', '{"parent_name": "Chị Bản Ghi B"}')) ->> 'id')::uuid;
-- Ba lịch hẹn của lead A: chưa làm, hoàn thành, huỷ.
create temp table ap (k text primary key, id uuid);
grant select on ap to public;
insert into ap select 'chua', app.create_appointment((select id from ld where k = 'A'), 'GOI_DIEN', now() + interval '2 days', 'Gọi lại A');
insert into ap select 'xong', app.create_appointment((select id from ld where k = 'A'), 'GOI_DIEN', now() + interval '3 days', 'Lịch xong A');
insert into ap select 'huy', app.create_appointment((select id from ld where k = 'A'), 'GOI_DIEN', now() + interval '4 days', 'Lịch huỷ A');
select app.complete_appointment((select id from ap where k = 'xong'));
select app.cancel_appointment((select id from ap where k = 'huy'), (select code from app.catalog_item where catalog_code = 'APPOINTMENT_CANCEL_REASON' and not requires_note order by sort_order limit 1));
create function pg_temp.lead(p_k text) returns jsonb language sql stable as $$ select app.get_lead((select id from ld where k = p_k)) $$;
grant execute on function pg_temp.lead(text) to public;

-- ================= get_lead (TS-02) =================
select is(pg_temp.lead('A') ->> 'parent_name', 'Chị Bản Ghi A', 'Người thấy được cơ sở của lead đọc được lead');
select is(pg_temp.lead('A') ->> 'owner_name', 'Giả sales1', 'Có tên người phụ trách (người xem có thể không đọc được bảng tài khoản)');
select is(pg_temp.lead('A') ->> 'branch_code', 'CS1', 'Có mã cơ sở');
select is(pg_temp.lead('A') ->> 'campaign_name', 'Chiến dịch thử bản ghi', 'Có tên chiến dịch');
select is(pg_temp.lead('B') ->> 'campaign_name', null, 'Lead không chiến dịch: tên chiến dịch rỗng');
select is(pg_temp.lead('A') ->> 'stage_code', 'C1', 'Có giai đoạn');
select is((pg_temp.lead('A') -> 'search_text'), null, 'Không trả cột tìm kiếm');
select is((pg_temp.lead('A') ->> 'appointments_total')::int, 3, 'Đếm tổng lịch hẹn (mọi trạng thái)');
select is((pg_temp.lead('A') ->> 'appointments_open')::int, 1, 'Đếm lịch hẹn chưa làm');
select is((pg_temp.lead('B') ->> 'appointments_total')::int, 0, 'Lead chưa có lịch hẹn: 0');
select is((pg_temp.lead('A') ->> 'opportunities_total')::int, 0, 'Lead chưa có cơ hội: 0');
select is(pg_temp.lead('A') ->> 'merged_into_code', null, 'Lead đang dùng không có mã bản giữ lại');
select isnt(pg_temp.lead('A') ->> 'created_by_name', null, 'Có tên người tạo');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.lead('A') ->> 'parent_name', 'Chị Bản Ghi A', 'Đồng nghiệp cùng cơ sở đọc được (phạm vi cơ sở)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.lead('A') ->> 'parent_name', 'Chị Bản Ghi A', 'CSKH cùng cơ sở đọc được');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.lead('A') ->> 'parent_name', 'Chị Bản Ghi A', 'Trưởng cơ sở đọc được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.lead('A') ->> 'parent_name', 'Chị Bản Ghi A', 'Admin đọc được mọi cơ sở');
-- Ngoài phạm vi và không có quyền.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select pg_temp.lead('A')$$), 'HMT_KHONG_CO_QUYEN', 'Tuyển sinh CS5 không đọc được lead của CS1');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select pg_temp.lead('A')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên (không có quyền Lead) không đọc được');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select pg_temp.lead('A')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không đọc được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.get_lead(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Không có lead: báo không tìm thấy');
-- Bản đã gộp trả mã bản giữ lại (R-CRM-22).
reset role;
update app.lead set record_status = 'DA_GOP', merged_into_id = (select id from ld where k = 'A') where id = (select id from ld where k = 'B');
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.lead('B') ->> 'record_status', 'DA_GOP', 'Bản đã gộp vẫn đọc được, mang trạng thái Đã gộp');
select is(pg_temp.lead('B') ->> 'merged_into_code', (select code from app.lead where id = (select id from ld where k = 'A')), 'Bản đã gộp trả đúng mã bản giữ lại');
select is(pg_temp.err($$select app.update_lead((select id from ld where k = 'B'), '{"need": "x"}')$$), 'HMT_BAN_GHI_DA_GOP', 'Bản đã gộp chỉ đọc');

-- ================= Dời lịch hẹn (R-CRM-38, R-CRM-04) =================
create function pg_temp.when(p_k text) returns timestamptz language sql stable as $$ select scheduled_at from app.appointment where id = (select id from ap where k = p_k) $$;
create function pg_temp.notes(p_like text) returns bigint language sql stable as $$
  select count(*) from app.note where entity_type = 'LEAD' and entity_id = (select id from ld where k = 'A') and body like p_like $$;
grant execute on function pg_temp.when(text), pg_temp.notes(text) to public;

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-01 03:00:00+00');
select is(pg_temp.when('chua'), '2026-12-01 03:00:00+00'::timestamptz, 'R-CRM-38: dời lịch Chưa làm (gọi hai tham số như cũ vẫn chạy)');
select is(pg_temp.notes('Dời lịch hẹn "Gọi lại A" từ % sang 01/12/2026 10:00.%'), 1::bigint, 'R-CRM-38: mỗi lần dời ghi một ghi chú trên hồ sơ gắn, giờ theo giờ Việt Nam');
select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-02 03:00:00+00', null, 'Phụ huynh bận, hẹn lại buổi sáng');
select is(pg_temp.notes('%Ghi chú: Phụ huynh bận, hẹn lại buổi sáng'), 1::bigint, 'R-CRM-38: ghi chú dời nằm trong ghi chú của hồ sơ gắn');
select is((select note from app.appointment where id = (select id from ap where k = 'chua')), null, 'Ghi chú dời không ghi đè cột note của lịch hẹn');
select is(pg_temp.notes('%Người phụ trách mới%'), 0::bigint, 'Không đổi người phụ trách thì không nêu người phụ trách mới');
-- Truyền chính người phụ trách hiện tại: không phải đổi nên không cần quyền Giao việc.
select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-03 03:00:00+00', pg_temp.uid('sales1'));
select is(pg_temp.when('chua'), '2026-12-03 03:00:00+00'::timestamptz, 'Truyền lại chính người phụ trách hiện tại: dời được, không cần Giao việc');
-- Lịch không còn Chưa làm.
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'xong'), '2026-12-05 03:00:00+00')$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'R-CRM-38: lịch Hoàn thành không dời được');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'huy'), '2026-12-05 03:00:00+00')$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'R-CRM-38: lịch Huỷ không dời được');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'chua'), null)$$), 'HMT_THIEU_THONG_TIN', 'Phải chọn giờ mới');
-- Đổi người phụ trách cần quyền Giao việc.
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-04 03:00:00+00', pg_temp.uid('sales1b'))$$), 'HMT_KHONG_CO_QUYEN', 'R-CRM-38: Tuyển sinh không có Giao việc thì không đổi được người phụ trách');
select is(pg_temp.when('chua'), '2026-12-03 03:00:00+00'::timestamptz, 'Bị chặn thì giờ cũng không đổi (một giao dịch)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-04 03:00:00+00', pg_temp.uid('sales1b'))$$), 'HMT_KHONG_CO_QUYEN', 'R-CRM-38: CSKH không có Giao việc thì không đổi được người phụ trách');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-04 03:00:00+00', pg_temp.uid('sales1b'), 'Giao lại cho đồng nghiệp');
select is((select owner_id from app.appointment where id = (select id from ap where k = 'chua')), pg_temp.uid('sales1b'), 'R-CRM-38: Trưởng cơ sở (có Giao việc) đổi người phụ trách khi dời');
select is(pg_temp.notes('%Người phụ trách mới: Giả sales1b. Ghi chú: Giao lại cho đồng nghiệp'), 1::bigint, 'Ghi chú nêu người phụ trách mới và ghi chú dời');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-06 03:00:00+00', pg_temp.uid('sales5'))$$), 'HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách mới phải thuộc cơ sở của lịch hẹn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok((select count(*) from app.audit_log l join app.audited_table a on a.id = l.table_id
            where a.table_name = 'app.appointment' and l.record_id = (select id from ap where k = 'chua') and l.action = 'U') >= 3,
          'R-CRM-38: mọi lần dời ghi nhật ký của lịch hẹn');
-- Ngoài cơ sở.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-07 03:00:00+00')$$), 'HMT_KHONG_CO_QUYEN', 'Tuyển sinh CS5 không dời được lịch của CS1');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select app.reschedule_appointment((select id from ap where k = 'chua'), '2026-12-07 03:00:00+00')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không dời được lịch hẹn tuyển sinh');

select * from finish();
rollback;
