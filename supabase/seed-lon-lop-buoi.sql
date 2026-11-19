-- Dữ liệu GIẢ LỚN chỉ để thử tốc độ danh sách Lớp, Buổi, Ghi danh ở máy local (CLAUDE.md, Hiệu năng; thẻ A28).
-- KHÔNG chạy ở thử nghiệm hay chạy thật, KHÔNG nằm trong seed.sql thường, KHÔNG dùng dữ liệu thật: tên ghép giả, SĐT 0998xxxxxx giả.
-- Tạo 600 lớp (mã LPL…), 30.000 buổi (50 buổi/lớp, trải 2 năm), 20.000 học sinh (HSB…) và 20.000 ghi danh (GDB…), 15.000 dòng điểm danh.
-- Chạy: npm run db:seed-lon-lop-buoi (sau db:reset). Chạy lại sẽ báo lỗi (đã có); muốn làm lại thì npm run db:reset.
\set ON_ERROR_STOP on
\timing on

do $$
begin
  if exists (select from app.class where code like 'LPL%') then
    raise exception 'Đã có dữ liệu giả lớp/buổi (LPL…). Muốn làm lại thì npm run db:reset.';
  end if;
end $$;

insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, status_code, max_students, start_date, total_sessions)
select 'LPL' || lpad(n::text, 5, '0'), (select id from app.branch order by code offset (n % 3) limit 1), '2026',
       (array['TOAN','ANH','VAN','LY','HOA','KHTN'])[1 + n % 6], (array['K06','K07','K08','K09','K10','K11'])[1 + n % 6],
       (array['CB','NC'])[1 + n % 2], (array['S','A','B','C'])[1 + n % 4], 'DA_DUYET', 12, date '2025-01-01' + (n % 30), 50
  from generate_series(1, 600) n;

insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, type_code, status_code)
select c.id, c.branch_id, s, date '2025-01-01' + (s * 14 + (substr(c.code, 4)::int % 7)),
       time '17:00' + ((substr(c.code, 4)::int % 4) * interval '1 hour'), time '18:30' + ((substr(c.code, 4)::int % 4) * interval '1 hour'),
       'CHINH', case when s < 35 then 'DONE' when s < 40 then 'DA_CHOT' else 'NHAP' end
  from app.class c cross join generate_series(1, 50) s where c.code like 'LPL%';

insert into app.parent (code, full_name, phone, branch_id)
select 'PHB' || lpad(n::text, 6, '0'), 'Phụ huynh giả B ' || n, '0998' || lpad(n::text, 6, '0'), (select id from app.branch order by code offset (n % 3) limit 1)
  from generate_series(1, 20000) n;
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select 'HSB' || lpad(substr(p.code, 4)::int::text, 6, '0'), p.id, 'Em giả B ' || substr(p.code, 4)::int, 2010 + substr(p.code, 4)::int % 6, p.branch_id
  from app.parent p where p.code like 'PHB%';
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code, purchased_hours, gifted_hours, start_date)
select 'GDB' || lpad(substr(s.code, 4)::int::text, 6, '0'), s.id, s.parent_id, s.branch_id, (array['TOAN','ANH','VAN','LY','HOA','KHTN'])[1 + substr(s.code, 4)::int % 6],
       (array['DANG_HOC','DA_XEP_LOP','CHO_XEP_LOP'])[1 + substr(s.code, 4)::int % 3], 40, 0, date '2025-01-01'
  from app.student s where s.code like 'HSB%';

-- 15.000 dòng điểm danh: mỗi buổi Đã chốt của 300 lớp đầu, mỗi em một dòng.
insert into app.session_attendance (session_id, class_id, branch_id, student_id, enrollment_id, is_active)
select cs.id, cs.class_id, cs.branch_id, e.student_id, e.id, true
  from app.class_session cs
  join app.class c on c.id = cs.class_id and c.code like 'LPL%'
  join app.enrollment e on e.code = 'GDB' || lpad((substr(c.code, 4)::int * 20 + (cs.session_no % 3))::text, 6, '0')
 where cs.status_code = 'DA_CHOT' and substr(c.code, 4)::int <= 300
 limit 15000;
analyze;
