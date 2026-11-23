-- D-23-22 (migration 628): Hoàn thành lịch hẹn kèm Kết quả cuộc gọi và Hẹn lần sau (TS-13, R-CRM-04). Mỗi luật có ca đúng và ca bị chặn; hàm cũ một tham số vẫn chạy.
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
select app.create_lead(pg_temp.lead_data('0900006001', '{"parent_name": "Chị Kết Quả A", "student_name": "Em Một", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900006001'));
select app.create_appointment(pg_temp.lid('0900006001'), 'GOI_DIEN', now() + interval '1 day', 'Gọi T1');
select app.create_appointment(pg_temp.lid('0900006001'), 'GOI_DIEN', now() + interval '1 day', 'Gọi T2');
select app.create_appointment(pg_temp.lid('0900006001'), 'ZALO', now() + interval '1 day', 'Zalo T3');
select app.create_appointment(pg_temp.lid('0900006001'), 'GOI_DIEN', now() + interval '1 day', 'Gọi T4 tự nhắc');
select app.create_appointment(pg_temp.lid('0900006001'), 'GOI_DIEN', now() + interval '1 day', 'Gọi T5 hẹn lại');
select app.create_appointment(null, 'GOI_DIEN', now() + interval '1 day', 'Gọi T6 cơ hội', null, null, pg_temp.oid('0900006001'));

-- ================= Tương thích: tham số TẮT (mặc định), hàm cũ một tham số =================
select is((select value from app.setting_def where key = 'appointment_call_result_required'), 'false', 'Tham số bắt buộc kết quả mặc định TẮT');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T1'))$$), null, 'Tham số tắt: hoàn thành gọi điện không kết quả (hàm cũ một tham số) vẫn được');
select is((select result_code from app.appointment where title = 'Gọi T1'), null, 'Không kết quả thì result_code trống');

-- ================= Tham số BẬT: Gọi điện bắt buộc kết quả =================
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'appointment_call_result_required'$$);
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T2'))$$), 'HMT_THIEU_KET_QUA', 'Chặn: gọi điện thiếu kết quả khi tham số bật');
select is((select status from app.appointment where title = 'Gọi T2'), 'CHUA_LAM', 'Lỗi thì không hoàn thành');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T2'), 'BITCOIN')$$), 'HMT_KET_QUA_KHONG_HOP_LE', 'Chặn: kết quả ngoài danh mục');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T2'), 'KHONG_NGHE_MAY', repeat('x', 1001))$$), 'HMT_GHI_CHU_DAI', 'Chặn: ghi chú quá 1000 ký tự');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T2'), 'KHONG_NGHE_MAY', '  Gọi hai lần  ')$$), null, 'Đúng: gọi điện có kết quả và ghi chú');
select is((select result_code || '|' || result_note from app.appointment where title = 'Gọi T2'), 'KHONG_NGHE_MAY|Gọi hai lần', 'Lưu kết quả, ghi chú đã cắt khoảng trắng');
select is(pg_temp.notes('LEAD', pg_temp.lid('0900006001'), '%Hoàn thành lịch hẹn "Gọi T2"%Kết quả: Không nghe máy.%Ghi chú: Gọi hai lần.%'), 1, 'Lịch sử ghi kết quả và ghi chú');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Zalo T3'))$$), null, 'Loại khác Gọi điện: kết quả tuỳ chọn');
select pg_temp.sudo($$update app.appointment set is_auto_reminder = true where title = 'Gọi T4 tự nhắc'$$);
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T4 tự nhắc'))$$), null, 'Lịch tự nhắc bỏ qua yêu cầu kết quả');
select is((select stage_code from app.lead where id = pg_temp.lid('0900006001')), 'C4', 'R-CRM-04: kết quả không đổi giai đoạn');

-- ================= Hẹn lần sau =================
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T5 hẹn lại'), 'HEN_GOI_LAI', null, now() - interval '1 hour')$$), 'HMT_HEN_LAN_SAU_QUA_KHU', 'Chặn: hẹn lần sau ở quá khứ');
select is((select status from app.appointment where title = 'Gọi T5 hẹn lại'), 'CHUA_LAM', 'Lỗi hẹn lần sau thì không hoàn thành');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T5 hẹn lại'), 'HEN_GOI_LAI', null, now() + interval '3 days')$$), null, 'Đúng: hoàn thành kèm hẹn lần sau');
select is((select count(*)::int from app.appointment where title = 'Gọi lại: Gọi T5 hẹn lại' and status = 'CHUA_LAM' and lead_id = pg_temp.lid('0900006001') and activity_code = 'GOI_DIEN' and owner_id = pg_temp.uid('sales1')), 1,
  'Lịch kế: cùng lead, cùng loại, chủ là người hoàn thành, tiêu đề mặc định');
select is((select count(*)::int from app.appointment p join app.appointment n on n.id = p.next_appointment_id where p.title = 'Gọi T5 hẹn lại'), 1, 'Lịch cũ nhớ lịch kế');
select is(pg_temp.notes('LEAD', pg_temp.lid('0900006001'), '%Hoàn thành lịch hẹn "Gọi T5 hẹn lại"%Hẹn lần sau lúc%'), 1, 'Lịch sử nêu hẹn lần sau');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T6 cơ hội'), 'DA_CHOT_DANG_KY', null, now() + interval '2 days', 'ZALO', 'Nhắn Zalo gửi báo giá')$$), null, 'Đúng: cơ hội, chọn loại và tiêu đề lịch kế');
select is((select count(*)::int from app.appointment where title = 'Nhắn Zalo gửi báo giá' and activity_code = 'ZALO' and opportunity_id = pg_temp.oid('0900006001')), 1, 'Lịch kế của cơ hội đúng loại, tiêu đề và hồ sơ');

-- ================= Mở lại xoá kết quả =================
select is(pg_temp.err($$select app.reopen_appointment(pg_temp.apid('Gọi T2'))$$), null, 'Mở lại lịch hẹn đã có kết quả: được');
select is((select coalesce(result_code, '-') || '|' || coalesce(result_note, '-') from app.appointment where title = 'Gọi T2'), '-|-', 'Mở lại xoá kết quả và ghi chú');
select is((select next_appointment_id is not null from app.appointment where title = 'Gọi T5 hẹn lại'), true, 'Mở lại giữ liên kết lịch kế ở lịch khác (không bị xoá lan)');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.complete_appointment(pg_temp.apid('Gọi T2'), 'SAI_SO')$$) is not null, true, 'Chặn: sale cơ sở khác không hoàn thành được lịch hẹn');
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'appointment_call_result_required'$$);

select * from finish();
rollback;
