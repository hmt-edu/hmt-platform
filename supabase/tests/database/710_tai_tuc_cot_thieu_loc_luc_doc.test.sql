-- C-27-17 (migration 710): phiếu tái tục trả thêm phụ huynh, môn, liên hệ, nhận xét; lọc, sắp, nhóm theo ngày hết giờ tính lúc đọc. Luật R-GD-13, R-GIO-04. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p710.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p710.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('cskh1', 'CS1'), ('cskh5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code) select id, 'CSKH' from u;

select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH710', 'Phụ huynh giả 710', '0900710001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS710A', 'Em A'), ('HS710B', 'Em B')) s (code, name) where p.code = 'PH710'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP710', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date - 60, 40 from app.branch where code = 'CS1'$$);
-- Một khung giờ 1,5 giờ mỗi tuần.
select pg_temp.sudo($$insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
  select c.id, c.branch_id, extract(isodow from current_date)::int, '18:00', '19:30', current_date from app.class c where c.code = 'LOP710'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, status_code)
  select c.id, c.branch_id, current_date + v.n, '18:00', '19:30', v.st from app.class c, (values (-7, 'NHAP'), (7, 'HUY_KHONG_PHI'), (14, 'NHAP'), (21, 'NHAP'), (28, 'NHAP'), (35, 'NHAP'), (42, 'NHAP'), (49, 'NHAP')) v (n, st) where c.code = 'LOP710'$$);
-- Em A: ghi danh cũ A (mua 24, còn học), ghi danh mới B bị đảo hết tiền (4,55 rồi -4,55), ghi danh C đang bảo lưu (không tính giờ còn).
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select v.code, s.id, s.parent_id, s.branch_id, v.st
    from (values ('GD710A', 'HS710A', 'DANG_HOC'), ('GD710B', 'HS710A', 'DANG_HOC'), ('GD710C', 'HS710A', 'BAO_LUU')) v (code, sc, st)
    join app.student s on s.code = v.sc$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date - 30 from app.enrollment e, app.class c where e.code like 'GD710%' and c.code = 'LOP710'$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, created_at, reason_code)
  select e.id, e.branch_id, v.t, v.h, now() - make_interval(days => v.d), case when v.t = 'DIEU_CHINH' then
           (select code from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' order by sort_order limit 1) end
    from (values ('GD710A', 'CAP_MUA', 24, 40), ('GD710A', 'CAP_TANG', 2, 40), ('GD710A', 'DIEU_CHINH', -21.5, 20),
                 ('GD710B', 'CAP_MUA', 4.55, 10), ('GD710B', 'CAP_MUA', -4.55, 1), ('GD710C', 'DAU_KY', 10, 5)) v (code, t, h, d)
    join app.enrollment e on e.code = v.code$$);
-- Phiếu tạo tay ở L7: hai cột giờ để trống (đợt quét đêm không ghi cho L7). Em B không có ghi danh.
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, origin_code)
  select v.code, s.branch_id, s.id, s.parent_id, c.id, 'L7', 'TAY'
    from (values ('TT917101', 'HS710A'), ('TT917102', 'HS710B')) v (code, sc) join app.student s on s.code = v.sc, app.class c where c.code = 'LOP710'$$);
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body, contact_channel_code, contact_result_code, created_at)
  select 'PARENT', id, 'Gọi giả', 'GOI_DIEN', 'HEN_GOI_LAI', now() - interval '2 days' from app.parent where code = 'PH710'$$);

-- Ghi danh D vào lớp sau A: 3 giờ. Phiếu của em B (không ghi danh) mang cột ghi sẵn cũ; cột đó không được dùng để lọc, sắp, nhóm.
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD710D', id, parent_id, branch_id, 'DANG_HOC' from app.student where code = 'HS710A'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date - 10 from app.enrollment e, app.class c where e.code = 'GD710D' and c.code = 'LOP710'$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
  select id, branch_id, 'CAP_MUA', 3 from app.enrollment where code = 'GD710D'$$);
select pg_temp.sudo($$update app.upsale_ticket set expected_end_date = current_date + 1 where code = 'TT917102'$$);
-- Nhận xét ở buổi đã Done; buổi chưa Done mới hơn không được lấy.
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, status_code)
  select c.id, c.branch_id, current_date + v.n, '08:00', '09:30', v.st from app.class c, (values (-3, 'DONE'), (-2, 'DA_CHOT')) v (n, st) where c.code = 'LOP710'$$);
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id)
  select s.id, s.class_id, s.branch_id, st.id from app.class_session s join app.class c on c.id = s.class_id and c.code = 'LOP710', app.student st
   where st.code = 'HS710A' and s.start_time = '08:00'$$);
select pg_temp.sudo($$insert into app.session_student_review (attendance_id, session_id, branch_id, teacher_comment)
  select a.id, a.session_id, a.branch_id, case when s.status_code = 'DONE' then 'Nhận xét giả đã Done' else 'Nhận xét giả chưa Done' end
    from app.session_attendance a join app.class_session s on s.id = a.session_id join app.class c on c.id = s.class_id and c.code = 'LOP710'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Asia/Ho_Chi_Minh')::date $$;
create function pg_temp.codes(p_filters jsonb) returns text[] language sql stable as $$
  select array(select r ->> 'code' from jsonb_array_elements(app.list_upsale_tickets(p_filters) -> 'rows') with ordinality as t (r, o)
                where r ->> 'code' like 'TT91710%' order by o) $$;
-- Giờ còn 4,5 (A) + 3 (D) = 7,5 giờ, mỗi buổi 1,5 giờ từ ngày +14: hết 4,5 giờ ở buổi +28, hết 7,5 giờ ở buổi +42.
-- ---- Dòng danh sách và bản ghi ----
select is(pg_temp.row_of('TT917101') ->> 'parent_name', 'Phụ huynh giả 710', 'TT-01: dòng có phụ huynh');
select is(pg_temp.row_of('TT917101') ->> 'subject_code', 'TOAN', 'TT-01: dòng có môn của lớp');
select is(pg_temp.row_of('TT917101') -> 'last_contact' ->> 'result_code', 'HEN_GOI_LAI', 'TT-01: dòng có lần liên hệ gần nhất');
select is(pg_temp.row_of('TT917101') -> 'last_contact' ->> 'body', null, 'Liên hệ không kèm nội dung ghi chú');
select is((select e ->> 'subject_code' from jsonb_array_elements(pg_temp.get('TT917101') -> 'enrollments') e where e ->> 'code' = 'GD710A'),
          'TOAN', 'Ghi danh không ghi môn thì lấy môn của lớp');
select is((select (e ->> 'expected_end_date')::date from jsonb_array_elements(pg_temp.get('TT917101') -> 'enrollments') e where e ->> 'code' = 'GD710A'),
          pg_temp.today() + 28, 'R-GIO-04: ghi danh vào lớp sớm hết trước (4,5 giờ)');
select is((select (e ->> 'expected_end_date')::date from jsonb_array_elements(pg_temp.get('TT917101') -> 'enrollments') e where e ->> 'code' = 'GD710D'),
          pg_temp.today() + 42, 'R-GIO-04: ghi danh sau hết sau khi trừ xong ghi danh trước (7,5 giờ)');
select is((select e -> 'expected_end_date' from jsonb_array_elements(pg_temp.get('TT917101') -> 'enrollments') e where e ->> 'code' = 'GD710C'),
          'null'::jsonb, 'Ghi danh bảo lưu không có ngày hết');
select is(pg_temp.get('TT917101') -> 'last_review' ->> 'comment', 'Nhận xét giả đã Done', 'Nhận xét gần nhất chỉ lấy buổi đã Done');
select is(pg_temp.get('TT917102') -> 'last_review', 'null'::jsonb, 'Chưa có nhận xét thì để trống');
-- ---- Lọc, sắp, nhóm theo ngày tính lúc đọc ----
select is(pg_temp.codes(jsonb_build_object('campaign_month', to_char(pg_temp.today() + 42, 'YYYY-MM'))), array['TT917101'],
          'Lọc Campaign theo ngày tính lúc đọc, phiếu tạo tay không bị sót');
select is(pg_temp.codes('{}'), array['TT917101', 'TT917102'], 'Sắp theo hết giờ dùng ngày tính lúc đọc: phiếu không còn giờ xuống cuối dù cột ghi sẵn sớm hơn');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.upsale_group_counts('{"q": "TT91710"}', array['campaign']) -> 'groups') g
            where g ->> 'k1' = to_char(pg_temp.today() + 42, 'YYYY-MM')), 1, 'Nhóm theo đợt tái tục dùng ngày tính lúc đọc');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.upsale_group_counts('{"q": "TT91710"}', array['campaign']) -> 'groups') g
            where g ->> 'k1' = ''), 1, 'Phiếu không còn giờ vào nhóm Chưa có');
select is((select count(*)::int from app.upsale_live(null) v where v.ticket_id in (pg_temp.tid('TT917101'), pg_temp.tid('TT917102'))), 2,
          'Cơ sở mình đọc được số tính lúc đọc');
-- ---- Quyền ----
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is((select count(*)::int from app.upsale_live(null) v where v.ticket_id = pg_temp.tid('TT917101')), 0, 'Cơ sở khác không đọc được giờ còn qua hàm tính');
select is(app.upsale_row_extra(pg_temp.tid('TT917101')), null, 'Cơ sở khác không đọc được phụ huynh, liên hệ qua hàm phụ');
select is(pg_temp.codes('{}'), array[]::text[], 'Cơ sở khác không thấy phiếu');
select is(pg_temp.err($$select app.upsale_enrollments(null)$$), '42501', 'Hàm con ghi danh không gọi trực tiếp được');
select is(pg_temp.err($$select app.upsale_last_review(null)$$), '42501', 'Hàm con nhận xét không gọi trực tiếp được');

select * from finish();
rollback;
