-- Phòng học tạm mỗi cơ sở (migration 071, anh chốt 05/11/2026): 5 phòng CSx-T1-01 ... CSx-T3-01.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is((select count(*)::int from app.room r join app.branch b on b.id = r.branch_id
            where b.code in ('CS1', 'CS2', 'CS3', 'CS4', 'CS5') and r.code like b.code || '\_T%'), 25,
  'Năm cơ sở dạy học (CS1 đến CS5) mỗi nơi 5 phòng tạm');
select is((select string_agg(r.name, ',' order by r.sort_order) from app.room r join app.branch b on b.id = r.branch_id
            where b.code = 'CS5' and r.code like 'CS5\_T%'),
  'CS5-T1-01,CS5-T1-02,CS5-T2-01,CS5-T2-02,CS5-T3-01', 'Tên phòng theo [Cơ sở]-[Tầng]-[Số phòng]');
select is((select count(*)::int from app.room r join app.branch b on b.id = r.branch_id where b.is_office), 0,
  'Cơ sở văn phòng (Hội sở) không có phòng');
select is((select count(*)::int from app.room where code in ('P101', 'P102', 'ONL1') and is_active), 0,
  'Phòng giả cũ không còn hoạt động');

select * from finish();
rollback;
