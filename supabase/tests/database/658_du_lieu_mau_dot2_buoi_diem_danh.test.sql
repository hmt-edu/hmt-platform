-- Dữ liệu mẫu đợt 2, mảnh buổi học, điểm danh, nội dung, bài tập, nhận xét (migration 658; E-23-31, E-23-33). Dữ liệu giả.
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

create temp table u (key text primary key, role_code text not null, id uuid not null default gen_random_uuid());
insert into u (key, role_code) values ('admin', 'ADMIN'), ('cskh5', 'CSKH'), ('ketoan', 'ACCOUNTANT'), ('gv5', 'TEACHER'), ('tg5', 'TA');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@dm.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@dm.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, role_code from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create temp table s1 (id uuid);
grant all on s1 to public;
create temp table s2 (id uuid);
grant all on s2 to public;
create temp table s3 (id uuid);
grant all on s3 to public;
-- Đếm bản ghi của một bộ theo loại (đọc trực tiếp, không qua RLS).
create function pg_temp.items(p_set uuid, p_type text) returns bigint language sql security definer as $$
  select count(*) from app.demo_data_item where set_id = p_set and entity_type = p_type $$;
create function pg_temp.sql_count(p_sql text) returns bigint language plpgsql security definer as $$
declare v bigint; begin execute p_sql into v; return v; end $$;
grant execute on function pg_temp.items(uuid, text), pg_temp.sql_count(text) to public;

-- Gói nhanh: số dòng theo bộ qua lớp đã duyệt của bộ (đọc trực tiếp, không qua RLS).
create function pg_temp.n(p_set uuid, p_what text) returns bigint language plpgsql security definer as $$
declare v bigint; v_where text;
begin
  v_where := case p_what
    when 'att' then 'select count(*) from app.session_attendance a where a.session_id in (select id from ses)'
    when 'content' then 'select count(*) from app.session_content c where c.session_id in (select id from ses)'
    when 'lines' then 'select count(*) from app.session_content_line c where c.session_id in (select id from ses)'
    when 'score' then 'select count(*) from app.session_review_score r where r.session_id in (select id from ses)'
    when 'sent' then 'select count(*) from app.session_student_review r where r.parent_sent_at is not null and r.session_id in (select id from ses)'
    when 'hw' then 'select count(*) from app.homework_result h where h.session_id in (select id from ses)'
    when 'done' then 'select count(*) from ses where status_code = ''DONE'''
    when 'chot' then 'select count(*) from ses where status_code = ''DA_CHOT'''
    when 'att_vang' then 'select count(*) from app.session_attendance a where a.session_id in (select id from ses) and a.teacher_status_code = ''VANG_CO_PHEP'''
    when 'att_notdemo' then 'select count(*) from app.session_attendance a join app.class_session s on s.id = a.session_id where s.id in (select id from ses) and not s.is_demo'
    when 'tru' then 'select count(*) from app.hour_ledger h where h.entry_type = ''TRU_BUOI'' and h.enrollment_id in (select entity_id from app.demo_data_item where set_id = $1 and entity_type = ''ENROLLMENT'')'
    when 'past' then 'select count(*) from app.class_session s where s.id in (select id from ses) and s.session_date < current_date'
  end;
  execute 'with cls as (select entity_id as id from app.demo_data_item where set_id = $1 and entity_type = ''CLASS''), '
       || 'ses as (select s.id, s.status_code from app.class_session s where s.class_id in (select id from cls)) ' || v_where
    into v using p_set;
  return v;
end $$;
grant execute on function pg_temp.n(uuid, text) to public;
-- Trạng thái của học viên ở cổng Học tập: số nhận xét đã gửi phụ huynh nhìn thấy được qua hàm cổng cho em đầu tiên.
create function pg_temp.reviews_visible(p_set uuid) returns bigint language plpgsql security definer as $$
declare v bigint;
begin
  select count(*) into v from app.session_student_review r
    join app.session_attendance a on a.id = r.attendance_id
    join app.class_session s on s.id = r.session_id
   where a.is_active and r.parent_sent_at is not null and s.status_code = 'DONE' and nullif(btrim(coalesce(r.teacher_comment, '')), '') is not null
     and s.class_id in (select entity_id from app.demo_data_item where set_id = p_set and entity_type = 'CLASS');
  return v;
end $$;
grant execute on function pg_temp.reviews_visible(uuid) to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
-- Aftersale bật rõ ràng cho CS5 (không phụ thuộc công tắc mặc định): bộ mẫu có phần ticket.
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$update app.setting_def set value = '5' where key = 'demo_data_max_per_user'$$);
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'demo_data_max_per_branch'$$);

-- Bộ đầu do CSKH tạo: lead, cơ hội, báo giá, đơn (mảnh F, B) rồi học sinh, lớp, ghi danh, ticket (mảnh C).
insert into s1 select app.create_demo_data_set();


-- Điểm danh: 3 em x 2 buổi; buổi 2 một em vắng có phép.
select is(pg_temp.n((select id from s1), 'att'), 6::bigint, 'Đúng: 2 buổi mẫu có điểm danh cho 3 em (6 dòng)');
select is(pg_temp.n((select id from s1), 'att_vang'), 1::bigint, 'Đúng: một em vắng có phép ở buổi 2');
-- Trạng thái buổi.
select is(pg_temp.n((select id from s1), 'done'), 1::bigint, 'Đúng: buổi 1 mẫu ở trạng thái Done');
select is(pg_temp.n((select id from s1), 'chot'), 1::bigint, 'Đúng: buổi 2 mẫu ở trạng thái Đã chốt (chưa Done)');
select is(pg_temp.n((select id from s1), 'past'), 2::bigint, 'Đúng: đúng 2 buổi mẫu có dữ liệu được dời về quá khứ, các buổi còn lại ở tương lai');
-- Nội dung, bài tập, nhận xét.
select is(pg_temp.n((select id from s1), 'content'), 2::bigint, 'Đúng: hai buổi có nội dung và bài tập về nhà');
select is(pg_temp.n((select id from s1), 'lines'), 4::bigint, 'Đúng: mỗi buổi có hai dòng nội dung');
select cmp_ok(pg_temp.n((select id from s1), 'score'), '>', 0::bigint, 'Đúng: buổi 1 có điểm nhận xét theo tiêu chí');
select is(pg_temp.n((select id from s1), 'sent'), 3::bigint, 'Đúng: nhận xét 3 em ở buổi Done đã gửi phụ huynh');
select is(pg_temp.reviews_visible((select id from s1)), 3::bigint, 'Đúng: cổng Học tập và Phụ huynh thấy được 3 nhận xét (buổi Done, đã gửi, có nhận xét)');
select is(pg_temp.n((select id from s1), 'hw'), 3::bigint, 'Đúng: bài tập về nhà buổi 1 được chấm ở buổi 2 cho 3 em');
-- Luật giờ: không trừ giờ thật.
select is(pg_temp.n((select id from s1), 'tru'), 0::bigint, 'Luật giờ: dữ liệu mẫu không trừ giờ học sinh (không có dòng TRU_BUOI)');
select is(pg_temp.n((select id from s1), 'att_notdemo'), 0::bigint, 'Luật ẩn: mọi điểm danh mẫu nằm ở buổi is_demo');

-- Hàm con không cấp cho giao diện.
select is(pg_temp.err(format($$select app.demo_make_sessions(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501',
  'Luật: hàm con demo_make_sessions không cấp cho người dùng');

-- Mỗi bộ đổ một lần: hai bộ khác nhau có số dòng độc lập (bộ thứ hai do Kế toán tạo).
select pg_temp.claims(pg_temp.uid('ketoan'), 'aal2');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Quyết định 5: Kế toán tạo được bộ có buổi và điểm danh');
select is(pg_temp.n((select id from s2), 'att'), 6::bigint, 'Đúng: bộ của Kế toán cũng có 6 dòng điểm danh');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Quyết định 5: Giáo viên (không được phân công lớp mẫu) vẫn tạo được bộ');
select is(pg_temp.n((select id from s1), 'att'), 6::bigint, 'Đúng: bộ đầu không bị đổi thêm khi tạo bộ khác');

-- Luật khoá: công tắc tắt thì không tạo bộ, không phát sinh điểm danh mới.
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'demo_data_enabled'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT', 'Luật khoá: công tắc tắt thì không tạo bộ');
select is(pg_temp.sql_count($$select count(*) from app.session_attendance a join app.class_session s on s.id = a.session_id where s.is_demo$$), 18::bigint,
  'Luật khoá: không phát sinh điểm danh mẫu khi công tắc tắt (ba bộ, 6 dòng mỗi bộ)');
-- Khoá môi trường: không có dòng STAGING cũng từ chối.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$delete from app.deployment_env$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT', 'Luật khoá môi trường: chạy thật (không có dòng STAGING) thì không tạo bộ');

select * from finish();
rollback;
