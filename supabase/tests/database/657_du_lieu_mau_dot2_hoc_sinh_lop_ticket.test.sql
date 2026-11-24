-- Dữ liệu mẫu đợt 2, mảnh học sinh, lớp, ghi danh, ticket (migration 657; C-23-41, C-23-42). Dữ liệu giả.
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

-- Số lượng đủ.
select is(pg_temp.items((select id from s1), 'PARENT'), 4::bigint, 'Đúng: bộ có 4 phụ huynh mẫu');
select is(pg_temp.sql_count(format($$select count(*) from app.demo_data_item i join app.student s on s.id = i.entity_id join app.parent pa on pa.id = s.parent_id and pa.is_demo where i.set_id = %L and i.entity_type = 'STUDENT' and s.full_name like '[MẪU]%%' and s.code ~ '^HS'$$, (select id from s1))), 6::bigint,
  'Đúng: bộ có 6 học sinh mẫu của mảnh này (ngoài học sinh do duyệt đơn), mã cấp như bản thật, tên có nhãn [MẪU]');
select is(pg_temp.items((select id from s1), 'CLASS'), 2::bigint, 'Đúng: bộ có 2 lớp mẫu');
select is(pg_temp.items((select id from s1), 'TICKET'), 3::bigint, 'Đúng: bộ có 3 ticket mẫu');
select is(pg_temp.items((select id from s1), 'ENROLLMENT'), 5::bigint, 'Đúng: 3 em ghi danh vào lớp đã duyệt và 2 em Chờ xếp lớp (migration 666)');
select is(pg_temp.items((select id from s1), 'HOUR_LEDGER'), 5::bigint, 'Đúng: giờ mẫu ghi ở sổ giờ có cờ is_demo (5 dòng, kể 2 ghi danh chờ xếp lớp của 666)');

-- Hai cặp anh chị em: hai phụ huynh có đúng hai con.
select is(pg_temp.sql_count(format($$select count(*) from (select s.parent_id from app.student s join app.parent pa on pa.id = s.parent_id and pa.is_demo join app.demo_data_item i on i.entity_id = s.id and i.entity_type = 'STUDENT' and i.set_id = %L group by s.parent_id having count(*) = 2) x$$, (select id from s1))), 2::bigint,
  'Đúng: có hai cặp anh chị em (hai phụ huynh mỗi người hai con)');

-- Lớp: Toán đã duyệt có buổi (R-LOP-03), Tiếng Anh dừng ở Đã trình, không có buổi.
select is(pg_temp.sql_count(format($$select count(*) from app.class c join app.demo_data_item i on i.entity_id = c.id and i.entity_type = 'CLASS' and i.set_id = %L where c.subject_code = 'TOAN' and c.status_code = 'DA_DUYET' and c.is_demo$$, (select id from s1))), 1::bigint,
  'Đúng: lớp Toán mẫu đã duyệt bằng hàm chuyển trạng thái thật');
select is(pg_temp.sql_count(format($$select count(*) from app.class c join app.demo_data_item i on i.entity_id = c.id and i.entity_type = 'CLASS' and i.set_id = %L where c.subject_code = 'ANH' and c.status_code = 'DA_TRINH'$$, (select id from s1))), 1::bigint,
  'Đúng: lớp Tiếng Anh mẫu dừng ở Đã trình để người duyệt có việc thử');
select is(pg_temp.sql_count(format($$select count(*) from app.class_session s join app.class c on c.id = s.class_id where c.is_demo and c.status_code = 'DA_TRINH' and c.id in (select entity_id from app.demo_data_item where set_id = %L)$$, (select id from s1))), 0::bigint,
  'Luật R-LOP-03: lớp chưa duyệt không có buổi (không chèn buổi tay)');
select ok(pg_temp.sql_count(format($$select count(*) from app.class_session s where s.is_demo and s.class_id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'CLASS')$$, (select id from s1))) = 8::bigint
  and pg_temp.items((select id from s1), 'SESSION') = 8::bigint, 'Đúng: 8 buổi sinh khi duyệt lớp Toán đều mang cờ is_demo và thuộc bộ');
select is(pg_temp.sql_count(format($$select count(*) from app.class c where c.is_demo and c.id in (select entity_id from app.demo_data_item where set_id = %L) and c.start_date < current_date + 7$$, (select id from s1))), 0::bigint,
  'Đúng: khai giảng sau hôm nay ít nhất một tuần');

-- Ghi danh: xếp lớp bằng hàm thật; không đơn, không phiếu thu; giờ mẫu is_demo.
select is(pg_temp.sql_count(format($$select count(*) from app.enrollment e join app.demo_data_item i on i.entity_id = e.id and i.entity_type = 'ENROLLMENT' and i.set_id = %L where e.status_code = 'DA_XEP_LOP' and e.order_id is null and e.is_demo$$, (select id from s1))), 3::bigint,
  'Đúng: ghi danh mẫu Đã xếp lớp, không gắn đơn thật');
select is(pg_temp.sql_count(format($$select count(*) from app.hour_ledger h where h.is_demo and h.enrollment_id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'ENROLLMENT') and h.entry_type = 'CAP_MUA'$$, (select id from s1))), 5::bigint,
  'Đúng: giờ mẫu chỉ ở sổ giờ is_demo, loại cấp mua');
select is(pg_temp.sql_count(format($$select count(*) from app.hour_ledger h where h.enrollment_id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'ENROLLMENT') and not h.is_demo$$, (select id from s1))), 0::bigint,
  'Luật: không có dòng sổ giờ thật lẫn vào ghi danh mẫu');

-- Số điện thoại dải 0999 000 xxx.
select is(pg_temp.sql_count(format($$select count(*) from app.parent p join app.demo_data_item i on i.entity_id = p.id and i.entity_type = 'PARENT' and i.set_id = %L where p.phone !~ '^0999000[0-9]{3}$' or p.full_name !~ '^\[MẪU\]'$$, (select id from s1))), 0::bigint,
  'Luật: phụ huynh mẫu có SĐT dải 0999 000 001-999 và nhãn [MẪU]');

-- Ticket: 3 ticket, 1 phiếu Cập nhật hồ sơ chờ duyệt, không tự duyệt.
select is(pg_temp.sql_count(format($$select count(*) from app.ticket t where t.is_demo and t.id in (select entity_id from app.demo_data_item where set_id = %L) and t.ticket_type = 'DN'$$, (select id from s1))), 2::bigint,
  'Đúng: 2 Đề nghị, 1 Khiếu nại');
select is(pg_temp.sql_count(format($$select count(*) from app.ticket t where t.is_demo and t.id in (select entity_id from app.demo_data_item where set_id = %L) and t.ticket_type = 'KN'$$, (select id from s1))), 1::bigint,
  'Đúng: có 1 Khiếu nại');
select is(pg_temp.sql_count(format($$select count(*) from app.ticket t where t.id in (select entity_id from app.demo_data_item where set_id = %L) and t.class_id is not null$$, (select id from s1))), 1::bigint,
  'Đúng: một ticket gắn lớp');
select is(pg_temp.sql_count(format($$select count(*) from app.ticket_task k where k.task_type = 'CAP_NHAT_HO_SO' and k.status_code = 'CHO_DUYET' and k.ticket_id in (select entity_id from app.demo_data_item where set_id = %L)$$, (select id from s1))), 1::bigint,
  'Đúng: một phiếu Cập nhật hồ sơ ở Chờ duyệt, không tự duyệt');
select is(pg_temp.sql_count(format($$select count(*) from app.ticket t where t.id in (select entity_id from app.demo_data_item where set_id = %L) and t.code !~ '^(DN|KN)-CS5-'$$, (select id from s1))), 0::bigint,
  'Luật mã: ticket cấp mã như bản thật');

-- Cờ không rò.
select is(coalesce(current_setting('hmt.demo_sales', true), ''), '', 'Luật: sau khi tạo bộ, cờ hmt.demo_sales không còn');

-- Người không có quyền tạo lớp: gọi thẳng create_class vẫn bị chặn.
select pg_temp.claims(pg_temp.uid('tg5'), 'aal1');
select is(pg_temp.err($$select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5')))$$), 'HMT_KHONG_CO_QUYEN',
  'Luật quyền: Trợ giảng gọi thẳng create_class vẫn bị chặn (cờ không rò)');

-- Kế toán, Giáo viên, Trợ giảng tạo được bộ đủ (quyết định 5).
select pg_temp.claims(pg_temp.uid('ketoan'), 'aal2');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Quyết định 5: Kế toán tạo được bộ có học sinh, lớp, ticket');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Quyết định 5: Giáo viên tạo được bộ');
select pg_temp.claims(pg_temp.uid('tg5'), 'aal1');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Quyết định 5: Trợ giảng tạo được bộ');
select is(pg_temp.sql_count($$select count(*) from app.demo_data_item where entity_type = 'CLASS'$$), 8::bigint, 'Đúng: bốn bộ, mỗi bộ 2 lớp');
select is(pg_temp.sql_count($$select count(distinct phone) from app.parent where is_demo$$), 16::bigint, 'Luật: SĐT mẫu không trùng giữa các bộ (16 phụ huynh, 16 số)');
select is(coalesce(current_setting('hmt.demo_sales', true), ''), '', 'Luật: sau mọi lần tạo bộ, cờ không còn');

-- Luật khoá: công tắc tắt thì không tạo bộ, không phát sinh gì.
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'demo_data_enabled'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT', 'Luật khoá: công tắc tắt thì không tạo bộ');
select is(pg_temp.sql_count($$select count(*) from app.demo_data_item where entity_type = 'CLASS'$$), 8::bigint, 'Luật khoá: không phát sinh lớp mẫu khi công tắc tắt');

-- Hàm con không cấp cho giao diện.
select is(pg_temp.err(format($$select app.demo_make_parents(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501',
  'Luật: hàm con demo_make_parents không cấp cho người dùng');
select is(pg_temp.err(format($$select app.demo_make_education(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501',
  'Luật: hàm gom demo_make_education không cấp cho người dùng');

-- Luật AS-13: Aftersale tắt thì bộ vẫn tạo, bỏ qua phần ticket, có ghi chú tiếng Việt; không tự bật công tắc.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'AFTERSALE' and branch_id = (select id from app.branch where code = 'CS5')$$);
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$insert into s3 select app.create_demo_data_set()$$), null, 'Luật AS-13: Aftersale tắt thì bộ vẫn tạo được, không báo lỗi cả bộ');
select is(pg_temp.items((select id from s3), 'TICKET'), 0::bigint, 'Luật AS-13: Aftersale tắt thì không có ticket mẫu');
select is(pg_temp.items((select id from s3), 'CLASS'), 2::bigint, 'Luật AS-13: phần lớp vẫn tạo đủ khi bỏ qua ticket');
select is(pg_temp.sql_count(format($$select count(*) from app.demo_data_set where id = %L and notice like 'Đã bỏ qua phần ticket vì Aftersale đang tắt ở cơ sở này.%%'$$, (select id from s3))), 1::bigint,
  'Luật AS-13: bộ ghi chú «đã bỏ qua phần ticket vì Aftersale đang tắt»');
select is(pg_temp.sql_count($$select count(*) from app.feature_flag where module_code = 'AFTERSALE' and enabled and branch_id = (select id from app.branch where code = 'CS5')$$), 0::bigint,
  'Luật AS-13: tạo bộ không tự bật công tắc Aftersale');
select is(pg_temp.sql_count(format($$select count(*) from app.demo_data_set where id = %L and notice like '%%ticket%%'$$, (select id from s1))), 0::bigint, 'Đúng: bộ có Aftersale bật không có ghi chú bỏ qua phần ticket');
select is((select left(notice, 56) from app.list_demo_data_sets(50, 0) where id = (select id from s3)), 'Đã bỏ qua phần ticket vì Aftersale đang tắt ở cơ sở này.', 'Đúng: danh sách bộ trả ghi chú để trang Dữ liệu mẫu hiện');

select * from finish();
rollback;
