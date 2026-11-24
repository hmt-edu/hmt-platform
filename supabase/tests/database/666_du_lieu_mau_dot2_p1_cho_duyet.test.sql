-- Dữ liệu mẫu đợt 2, phần P1 chờ xử lý (migration 666; E-23-39 phần 2, E-23-43). Dữ liệu giả.
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
create function pg_temp.items(p_set uuid, p_type text) returns bigint language sql security definer as $$
  select count(*) from app.demo_data_item where set_id = p_set and entity_type = p_type $$;
create function pg_temp.sql_count(p_sql text) returns bigint language plpgsql security definer as $$
declare v bigint; begin execute p_sql into v; return v; end $$;
create function pg_temp.sql_text(p_sql text) returns text language plpgsql security definer as $$
declare v text; begin execute p_sql into v; return v; end $$;
grant execute on function pg_temp.items(uuid, text), pg_temp.sql_count(text), pg_temp.sql_text(text) to public;

-- Hạn mức mặc định sau migration 666 (đọc trước khi bài test đặt lại).
select is(pg_temp.sql_text($$select value from app.setting_def where key = 'demo_data_max_per_user'$$), '6', 'Cấu hình: hạn mức mặc định 6 bộ mỗi người (nâng từ 3)');
select is(pg_temp.sql_text($$select value from app.setting_def where key = 'demo_data_max_per_branch'$$), '30', 'Cấu hình: hạn mức mặc định 30 bộ mỗi cơ sở (nâng từ 10)');

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, b.id, true from app.branch b, unnest(array['AFTERSALE', 'VAN_HANH_LOP', 'BAO_LUU', 'HOAN_PHI', 'BAN_HANG']) m where b.code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);

insert into s1 select app.create_demo_data_set();

-- (1) Phiếu kiểm tra đầu vào Nháp, gắn bộ.
select is(pg_temp.items((select id from s1), 'STUDENT_TEST'), 1::bigint, 'Đúng: bộ có 1 phiếu kiểm tra đầu vào');
select is(pg_temp.sql_count(format($$select count(*) from app.student_test t join app.demo_data_item i on i.entity_id = t.id and i.entity_type = 'STUDENT_TEST' and i.set_id = %L where t.is_demo and t.status_code = 'DRAFT' and t.scheduled_at > now()$$, (select id from s1))), 1::bigint,
  'Đúng: phiếu kiểm tra mẫu ở trạng thái Nháp, giờ test ở tương lai, mang cờ is_demo');
-- (2) Cơ hội L8 (từ 656).
select cmp_ok(pg_temp.sql_count(format($$select count(*) from app.opportunity o join app.demo_data_item i on i.entity_id = o.id and i.entity_type = 'OPPORTUNITY' and i.set_id = %L where o.stage_code = 'L8'$$, (select id from s1))), '>=', 1::bigint,
  'Đúng: bộ có cơ hội ở L8');
-- (3) Ghi danh Chờ xếp lớp thêm, không lớp.
select is(pg_temp.sql_count(format($$select count(*) from app.enrollment e join app.demo_data_item i on i.entity_id = e.id and i.entity_type = 'ENROLLMENT' and i.set_id = %L where e.status_code = 'CHO_XEP_LOP' and e.is_demo$$, (select id from s1))), 2::bigint,
  'Đúng: 2 ghi danh mẫu Chờ xếp lớp (chưa vào lớp nào)');
select is(pg_temp.items((select id from s1), 'ENROLLMENT'), 5::bigint, 'Đúng: 3 ghi danh đã xếp lớp và 2 ghi danh chờ xếp lớp');
-- (4) Bảo lưu Chờ duyệt (hàm thật).
select is(pg_temp.sql_count(format($$select count(*) from app.enrollment_hold h join app.demo_data_item i on i.entity_id = h.id and i.entity_type = 'ENROLLMENT_HOLD' and i.set_id = %L where h.is_demo and h.status_code = 'CHO_DUYET'$$, (select id from s1))), 1::bigint,
  'Đúng: 1 yêu cầu bảo lưu mẫu ở Chờ duyệt');
-- (5) Hoàn phí Chờ quản lý.
select is(pg_temp.sql_count(format($$select count(*) from app.refund_request r join app.demo_data_item i on i.entity_id = r.id and i.entity_type = 'REFUND_REQUEST' and i.set_id = %L where r.is_demo and r.status_code = 'CHO_QL' and r.refund_amount > 0$$, (select id from s1))), 1::bigint,
  'Đúng: 1 yêu cầu hoàn phí mẫu Chờ quản lý, số tiền hoàn dương');
select is(pg_temp.sql_count(format($$select count(*) from app.refund_request r join app.enrollment e on e.id = r.enrollment_id where r.is_demo and not e.is_demo and r.id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'REFUND_REQUEST')$$, (select id from s1))), 0::bigint,
  'Luật ẩn: hoàn phí mẫu chỉ gắn ghi danh mẫu');
-- (6) Nhận xét chờ gửi phụ huynh: đúng 1 nhận xét ở buổi Done chưa gửi.
select is(pg_temp.sql_count(format($$select count(*) from app.session_student_review r join app.class_session s on s.id = r.session_id where s.is_demo and s.status_code = 'DONE' and r.parent_sent_at is null and s.class_id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'CLASS')$$, (select id from s1))), 1::bigint,
  'Đúng: 1 nhận xét ở buổi Done chờ gửi phụ huynh');
-- Mục lỗi không làm hỏng bộ: nếu có bỏ qua thì ghi chú nói rõ, và các mục chính ở trên không nằm trong ghi chú.
select ok(coalesce(pg_temp.sql_text(format($$select notice from app.demo_data_set where id = %L$$, (select id from s1))), '') !~ '(phiếu kiểm tra|ghi danh chờ xếp lớp|bảo lưu|nhận xét chờ gửi)',
  'Đúng: các mục kiểm tra, ghi danh chờ, bảo lưu/hoàn phí, nhận xét không bị bỏ qua');

-- Luật: hàm con không cấp cho giao diện.
select is(pg_temp.err(format($$select app.demo_make_p1(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501',
  'Luật: hàm con demo_make_p1 không cấp cho người dùng');
select is(pg_temp.err($$select app.demo_make_student_test(gen_random_uuid(), gen_random_uuid())$$), '42501',
  'Luật: hàm con demo_make_student_test không cấp cho người dùng');

-- Luật khoá: tắt công tắc thì không tạo bộ (HMT_DEMO_TAT), bộ mới không đổ dữ liệu P1.
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'demo_data_enabled'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT', 'Luật khoá: công tắc tắt thì từ chối tạo bộ');

select * from finish();
rollback;
