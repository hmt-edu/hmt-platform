-- Lịch hẹn: Hoàn thành, Mở lại, Huỷ ghi dòng vào dòng thời gian của lead, cơ hội, phiếu kiểm tra (R-CRM-04). Mỗi luật có ca đúng và ca bị chặn.
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



select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.apid(p_title text) returns uuid language sql stable security definer as 'select id from app.appointment where title = p_title'$$);
select pg_temp.sudo($$create function pg_temp.tid(p_phone text) returns uuid language sql stable security definer as 'select t.id from app.student_test t where t.opportunity_id = pg_temp.oid(p_phone) order by t.code limit 1'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text), pg_temp.lid(text), pg_temp.apid(text), pg_temp.tid(text) to public$$);
-- Số dòng ghi chú hệ thống chứa một đoạn chữ ở một hồ sơ.
create function pg_temp.notes(p_type text, p_id uuid, p_like text) returns integer language sql stable as $$
  select count(*)::int from app.record_notes(p_type, p_id) n where n.body like p_like $$;
grant execute on function pg_temp.notes(text, uuid, text) to public;

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900005001', '{"parent_name": "Chị Ghi Chú A", "student_name": "Em Một", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900005001'));
select app.change_opportunity_stage(pg_temp.oid('0900005001'), 'L5');
select app.create_student_test(pg_temp.oid('0900005001'),
  jsonb_build_object('subject_code', 'TOAN', 'grade_code', (select code from app.catalog_item where catalog_code = 'GRADE' order by sort_order limit 1),
                     'mode_code', 'OFFLINE', 'level_code', 'CO_BAN', 'scheduled_at', now() + interval '3 days'));
select app.create_lead(pg_temp.lead_data('0900005002', '{"parent_name": "Chị Ghi Chú B", "student_name": "Em Hai", "student_birth_year": 2013}'));
select app.create_appointment(pg_temp.lid('0900005002'), 'GOI_DIEN', now() + interval '2 days', 'Hẹn lead B');
select app.create_appointment(null, 'GOI_DIEN', now() + interval '2 days', 'Hẹn cơ hội A', null, null, pg_temp.oid('0900005001'));
select app.create_appointment(null, 'GOI_DIEN', now() + interval '3 days', 'Hẹn cơ hội A huỷ', null, null, pg_temp.oid('0900005001'));

-- ================= Hoàn thành ghi lịch sử (R-CRM-04) =================
select is(pg_temp.notes('LEAD', pg_temp.lid('0900005002'), '%Hoàn thành lịch hẹn%'), 0, 'Trước khi hoàn thành: chưa có dòng nào');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Hẹn lead B'))$$), null, 'Hoàn thành lịch hẹn của lead: được');
select is(pg_temp.notes('LEAD', pg_temp.lid('0900005002'), '%Hoàn thành lịch hẹn "Hẹn lead B"%'), 1, 'R-CRM-04: hoàn thành ghi một dòng vào dòng thời gian của lead');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Hẹn cơ hội A'))$$), null, 'Hoàn thành lịch hẹn của cơ hội: được');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Hoàn thành lịch hẹn "Hẹn cơ hội A"%'), 1, 'Hoàn thành ghi một dòng vào dòng thời gian của cơ hội');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Hẹn cơ hội A'))$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'Hoàn thành lần hai bị chặn');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Hoàn thành lịch hẹn "Hẹn cơ hội A"%'), 1, 'Lần bị chặn không ghi thêm dòng');
select is((select stage_code from app.opportunity where id = pg_temp.oid('0900005001')), 'L5', 'R-CRM-04: hoàn thành không đổi giai đoạn cơ hội');
select ok(exists (select from app.record_notes('OPPORTUNITY', pg_temp.oid('0900005001')) n where n.body like '%Hoàn thành lịch hẹn%' and n.author_name <> ''), 'Dòng ghi tên người thao tác');

-- ================= Mở lại =================
select is(pg_temp.err($$select app.reopen_appointment(pg_temp.apid('Hẹn cơ hội A'))$$), null, 'Mở lại lịch hẹn đã hoàn thành: được');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Mở lại lịch hẹn "Hẹn cơ hội A"%trước đó đã hoàn thành%'), 1, 'R-CRM-04: mở lại ghi một dòng, nêu trạng thái trước đó');
select is(pg_temp.err($$select app.reopen_appointment(pg_temp.apid('Hẹn cơ hội A'))$$), 'HMT_LICH_HEN_TRANG_THAI_SAI', 'Mở lại lịch đang chưa làm bị chặn');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Mở lại lịch hẹn%'), 1, 'Lần bị chặn không ghi thêm dòng');

-- ================= Huỷ =================
select is(pg_temp.err($$select app.cancel_appointment(pg_temp.apid('Hẹn cơ hội A huỷ'), null)$$), 'HMT_THIEU_LY_DO', 'Huỷ không chọn lý do bị chặn');
select is(pg_temp.err($$select app.cancel_appointment(pg_temp.apid('Hẹn cơ hội A huỷ'), 'KHAC')$$), 'HMT_THIEU_GHI_CHU', 'Huỷ "Khác" không ghi chú bị chặn');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Huỷ lịch hẹn%'), 0, 'Huỷ bị chặn thì không ghi dòng nào');
select is(pg_temp.err($$select app.cancel_appointment(pg_temp.apid('Hẹn cơ hội A huỷ'), 'PH_BAO_BAN', 'Phụ huynh đổi lịch')$$), null, 'Huỷ có lý do: được');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Huỷ lịch hẹn "Hẹn cơ hội A huỷ"%Lý do: PH báo bận%Ghi chú: Phụ huynh đổi lịch%'), 1, 'R-CRM-04: huỷ ghi một dòng kèm lý do và ghi chú');
select is(pg_temp.err($$select app.reopen_appointment(pg_temp.apid('Hẹn cơ hội A huỷ'))$$), null, 'Mở lại lịch hẹn đã huỷ: được');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('0900005001'), '%Mở lại lịch hẹn "Hẹn cơ hội A huỷ"%trước đó đã huỷ%'), 1, 'Mở lại lịch đã huỷ ghi trạng thái trước đó là đã huỷ');

-- ================= Lịch nhắc của phiếu kiểm tra: dòng ghi vào phiếu =================
select is(pg_temp.err($$select app.complete_appointment((select id from app.appointment where student_test_id = pg_temp.tid('0900005001') limit 1))$$), null, 'Hoàn thành lịch nhắc tự sinh của phiếu: được');
select is(pg_temp.notes('STUDENT_TEST', pg_temp.tid('0900005001'), '%Hoàn thành lịch hẹn%'), 1, 'Lịch nhắc của phiếu: dòng ghi vào dòng thời gian của phiếu');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Hẹn lead B'))$$) is not null, true, 'Sale cơ sở khác không thao tác được lịch hẹn');
select is(pg_temp.err($$select app.reopen_appointment(pg_temp.apid('Hẹn lead B'))$$) is not null, true, 'Sale cơ sở khác không mở lại được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.notes('LEAD', pg_temp.lid('0900005002'), '%Mở lại%'), 0, 'Thao tác bị từ chối không ghi dòng');

select * from finish();
rollback;
