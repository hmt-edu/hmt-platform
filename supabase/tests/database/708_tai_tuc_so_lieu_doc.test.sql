-- C-27-12 (migration 708): số liệu phiếu tái tục tính lúc đọc; «Đã mua gần nhất» không ra giờ âm; liên hệ, buổi còn, buổi tới. Luật R-GD-13, R-TIEN-26. Dữ liệu giả.
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
create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as $$ select id from app.upsale_ticket where code = p_code $$;
create function pg_temp.get(p_code text) returns jsonb language sql stable as $$ select app.get_upsale_ticket(pg_temp.tid(p_code)) $$;
create function pg_temp.row_of(p_code text) returns jsonb language sql stable as $$
  select r from jsonb_array_elements(app.list_upsale_tickets() -> 'rows') r where r ->> 'code' = p_code $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('cskh1'), ('cskh5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p708.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p708.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('cskh1', 'CS1'), ('cskh5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code) select id, 'CSKH' from u;

select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH708', 'Phụ huynh giả 708', '0900708001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS708A', 'Em A'), ('HS708B', 'Em B')) s (code, name) where p.code = 'PH708'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP708', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date - 60, 40 from app.branch where code = 'CS1'$$);
-- Một khung giờ 1,5 giờ mỗi tuần.
select pg_temp.sudo($$insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
  select c.id, c.branch_id, extract(isodow from current_date)::int, '18:00', '19:30', current_date from app.class c where c.code = 'LOP708'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, status_code)
  select c.id, c.branch_id, current_date + v.n, '18:00', '19:30', v.st from app.class c, (values (-7, 'NHAP'), (7, 'HUY_KHONG_PHI'), (14, 'NHAP'), (21, 'NHAP'), (28, 'NHAP')) v (n, st) where c.code = 'LOP708'$$);
-- Em A: ghi danh cũ A (mua 24, còn học), ghi danh mới B bị đảo hết tiền (4,55 rồi -4,55), ghi danh C đang bảo lưu (không tính giờ còn).
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select v.code, s.id, s.parent_id, s.branch_id, v.st
    from (values ('GD708A', 'HS708A', 'DANG_HOC'), ('GD708B', 'HS708A', 'DANG_HOC'), ('GD708C', 'HS708A', 'BAO_LUU')) v (code, sc, st)
    join app.student s on s.code = v.sc$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date - 30 from app.enrollment e, app.class c where e.code like 'GD708%' and c.code = 'LOP708'$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, created_at, reason_code)
  select e.id, e.branch_id, v.t, v.h, now() - make_interval(days => v.d), case when v.t = 'DIEU_CHINH' then
           (select code from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' order by sort_order limit 1) end
    from (values ('GD708A', 'CAP_MUA', 24, 40), ('GD708A', 'CAP_TANG', 2, 40), ('GD708A', 'DIEU_CHINH', -21.5, 20),
                 ('GD708B', 'CAP_MUA', 4.55, 10), ('GD708B', 'CAP_MUA', -4.55, 1), ('GD708C', 'DAU_KY', 10, 5)) v (code, t, h, d)
    join app.enrollment e on e.code = v.code$$);
-- Phiếu tạo tay ở L7: hai cột giờ để trống (đợt quét đêm không ghi cho L7). Em B không có ghi danh.
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, origin_code)
  select v.code, s.branch_id, s.id, s.parent_id, c.id, 'L7', 'TAY'
    from (values ('TT917081', 'HS708A'), ('TT917082', 'HS708B')) v (code, sc) join app.student s on s.code = v.sc, app.class c where c.code = 'LOP708'$$);
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body, contact_channel_code, contact_result_code, created_at)
  select 'PARENT', id, 'Gọi giả', 'GOI_DIEN', 'HEN_GOI_LAI', now() - interval '2 days' from app.parent where code = 'PH708'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
-- ---- Giờ còn, ngày hết giờ tính lúc đọc ----
select is((pg_temp.get('TT917081') -> 'ticket' ->> 'hours_left')::numeric, 4.5, 'R-GD-13: giờ còn tính lúc đọc, kể cả giờ tặng, không tính ghi danh bảo lưu');
select is((pg_temp.get('TT917081') -> 'ticket' ->> 'expected_end_date')::date, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 28, 'Ngày hết giờ dự kiến theo buổi thật: 4,5 giờ, buổi huỷ không tính, hết ở buổi ngày +28');
select is(pg_temp.get('TT917081') -> 'ticket' ->> 'campaign_label',
          'Tái tục ' || to_char((now() at time zone 'Asia/Ho_Chi_Minh')::date + 28, 'MM/YYYY'), 'Campaign theo ngày hết giờ tính lúc đọc');
select is((pg_temp.row_of('TT917081') ->> 'hours_left')::numeric, 4.5, 'Danh sách trả cùng giờ còn với bản ghi');
select is(app.upsale_board() -> 6 -> 'rows' -> 0 ->> 'hours_left' is not null or app.upsale_board() -> 6 -> 'rows' -> 1 ->> 'hours_left' is not null, true, 'Kanban L7 có giờ còn');
select is(pg_temp.get('TT917082') -> 'ticket' -> 'hours_left', 'null'::jsonb, 'Không còn ghi danh hiệu lực: giờ còn để trống, không ghi 0');
-- ---- Đã mua gần nhất, buổi còn, giờ tặng ----
select is((pg_temp.get('TT917081') -> 'hours' -> 'last_purchase' ->> 'hours')::numeric, 24::numeric, 'R-TIEN-26: lần mua bị đảo hết không được lấy làm lần mua; không ra giờ âm');
select is((pg_temp.get('TT917081') -> 'hours' ->> 'gifted')::numeric, 2::numeric, 'Giờ tặng tách riêng');
select is((pg_temp.get('TT917081') -> 'hours' ->> 'sessions_left')::int, 3, 'Buổi còn: 4,5 giờ, mỗi buổi 1,5 giờ');
select is((pg_temp.get('TT917081') -> 'class' -> 'next_session' ->> 'date')::date, current_date + 14, 'Buổi tới: bỏ buổi đã qua và buổi huỷ');
select is(jsonb_array_length(pg_temp.get('TT917081') -> 'class' -> 'slots'), 1, 'Lịch tuần của lớp');
-- ---- Liên hệ ----
select is(pg_temp.get('TT917081') -> 'contact' -> 'last' ->> 'result_code', 'HEN_GOI_LAI', 'Lần liên hệ gần nhất lấy từ hồ sơ phụ huynh');
select is(pg_temp.get('TT917081') -> 'contact' -> 'last' ->> 'body', null, 'Không kèm nội dung ghi chú');
-- ---- Quyền ----
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select pg_temp.get('TT917081')$$), 'HMT_KHONG_CO_QUYEN', 'Cơ sở khác không xem được bản ghi');
select is((select hours_left from app.upsale_ticket_live(pg_temp.tid('TT917081'))), null, 'Cơ sở khác không đọc được giờ còn qua hàm tính');
select is(pg_temp.err($$select app.upsale_hours_info(null)$$), '42501', 'Hàm con không gọi trực tiếp được');
select is(pg_temp.err($$select app.upsale_contact_info(null)$$), '42501', 'Hàm con liên hệ không gọi trực tiếp được');

select * from finish();
rollback;
