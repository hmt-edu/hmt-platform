-- PH-04 «Không đồng ý phương án» (migration 643): app.ph_reject_proposal. Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('ph1'), ('ph2'), ('bm1'), ('cskh1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f643.hoamatoan.invalid' from u;
insert into app.parent (code, full_name, phone, branch_id)
select v.code, 'Phụ huynh giả ' || v.code, v.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH643001', '0900643001'), ('PH643002', '0900643002')) v (code, phone);
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, parent_code)
select u.id, 'Giả ' || u.key, u.key || '@f643.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false,
       case u.key when 'ph1' then 'PH643001' when 'ph2' then 'PH643002' end
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('ph1', 'PARENT'), ('ph2', 'PARENT'), ('bm1', 'BRANCH_MANAGER'), ('cskh1', 'CSKH')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
-- Ticket gốc giả: phương án đang chờ (Đã xử lý) của ph1; ticket khác đang Đang xử lý.
create function pg_temp.mkticket(p_code text, p_parent text, p_status text) returns uuid language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, status_code, parent_id,
                          resolution, response_due_at, resolve_due_at)
  values (p_code, 'DN', (select id from app.branch where code = 'CS1'), 'Đổi giờ học giả', 'Xin đổi ca', 'ZALO', 'DN_01_05', 'THUONG', p_status,
          (select id from app.parent where code = p_parent), case when p_status = 'DA_XU_LY' then 'Chuyển sang ca khác' end, now() + interval '1 day', now() + interval '2 days')
  returning id into v_id;
  return v_id;
end $$;
create temp table tk (key text primary key, id uuid);
grant all on tk to public;
create function pg_temp.k(p_key text) returns uuid language sql stable as $$ select id from tk where key = p_key $$;
insert into tk values ('cho', pg_temp.mkticket('DN-F643-1', 'PH643001', 'DA_XU_LY')),
                      ('dang', pg_temp.mkticket('DN-F643-2', 'PH643001', 'DANG_XU_LY')),
                      ('khac', pg_temp.mkticket('DN-F643-3', 'PH643002', 'DA_XU_LY'));
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
create temp table r (key text primary key, j jsonb);
grant all on r to public;

-- Đúng: lần đầu tạo ticket theo dõi nguồn «Phụ huynh không đồng ý», giao đội CSKH, báo Trưởng cơ sở.
select pg_temp.claims(pg_temp.uid('ph1'), 'aal1');
insert into r select 'a', app.ph_reject_proposal(pg_temp.k('cho'), 'Ca mới trùng giờ học thêm');
select is((select j ->> 'reopened' from r where key = 'a'), 'false', 'Đúng: lần đầu «Không đồng ý» tạo ticket mới');
select is((select count(*)::int from app.notification where kind = 'PH_KHONG_DONG_Y' and user_id = pg_temp.uid('bm1')), 0, 'Phụ huynh không đọc được thông báo của người khác (RLS)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from app.ticket where related_ticket_id = pg_temp.k('cho') and channel_code = 'PH_KHONG_DONG_Y' and team_code = 'CSKH' and description = 'Ca mới trùng giờ học thêm'), 1,
          'Đúng: ticket theo dõi có nguồn Phụ huynh không đồng ý, đội CSKH, kèm lý do');
select is((select count(*)::int from app.notification where kind = 'PH_KHONG_DONG_Y'), 1, 'Đúng: Trưởng cơ sở nhận một thông báo');

-- Đúng: «đã có» (cùng ticket gốc) thì không tạo thêm; ghi thêm vào ticket đó.
select pg_temp.claims(pg_temp.uid('ph1'), 'aal1');
insert into r select 'b', app.ph_reject_proposal(pg_temp.k('cho'), 'Vẫn chưa ổn');
select is((select j ->> 'id' from r where key = 'b'), (select j ->> 'id' from r where key = 'a'), 'Đúng: lần hai dùng lại ticket theo dõi, không tạo thêm');

-- Đúng: ticket theo dõi đã Đã xử lý thì mở lại về Đang xử lý.
select pg_temp.sudo(format($$update app.ticket set status_code = 'DA_XU_LY', resolved_at = now() where id = %L$$, (select j ->> 'id' from r where key = 'a')));
insert into r select 'c', app.ph_reject_proposal(pg_temp.k('cho'), 'Lại không đồng ý');
select is((select j ->> 'reopened' from r where key = 'c'), 'true', 'Đúng: ticket theo dõi đã xử lý được mở lại');

-- Chặn: thiếu lý do.
select is(pg_temp.err(format($$select app.ph_reject_proposal(%L, '  ')$$, pg_temp.k('cho'))), 'HMT_PH_THIEU_LY_DO', 'Chặn: lý do bắt buộc');
-- Chặn: ticket của phụ huynh khác.
select is(pg_temp.err(format($$select app.ph_reject_proposal(%L, 'x')$$, pg_temp.k('khac'))), 'HMT_KHONG_TIM_THAY', 'Chặn: phụ huynh không thao tác trên ticket của người khác');
-- Chặn: ticket chưa có phương án chờ.
select is(pg_temp.err(format($$select app.ph_reject_proposal(%L, 'x')$$, pg_temp.k('dang'))), 'HMT_PH_KHONG_CO_PHUONG_AN', 'Chặn: ticket chưa ở Đã xử lý thì chưa có phương án');
-- Chặn: không phải tài khoản phụ huynh.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err(format($$select app.ph_reject_proposal(%L, 'x')$$, pg_temp.k('cho'))), 'HMT_PH_KHONG_PHAI_PHU_HUYNH', 'Chặn: nhân viên không dùng hàm của phụ huynh');

select * from finish();
rollback;
