-- Dữ liệu GIẢ LỚN chỉ để thử tốc độ ở máy local (CLAUDE.md, Hiệu năng). KHÔNG chạy ở thử nghiệm hay chạy thật,
-- KHÔNG nằm trong seed.sql thường, KHÔNG dùng dữ liệu thật: tên ghép từ danh sách giả, SĐT dạng 0999xxxxxx giả.
-- Cần tài khoản giả đã có: npm run db:seed-users (dùng sale.cs1, sale.cs5).
-- Chạy: npm run db:seed-lon. Tạo 50.000 lead (mã LDL000001…), 30.000 phụ huynh (mã PHL…), 100.000 lịch hẹn, 20.000 cơ hội, 10.000 học sinh, 15.000 phiếu kiểm tra.
-- Cơ hội giả (20.000, mã COL…) và 20.000 lịch hẹn của cơ hội thêm ở P3b2a; 10.000 học sinh (HSL…) và 15.000 phiếu kiểm tra (PKL…) ở P3b2b.
-- Mã tiền tố LDL/PHL để không đụng mã thật. Chạy lại sẽ báo lỗi (đã có), muốn làm lại thì npm run db:reset.
\set ON_ERROR_STOP on
\timing on

do $$
begin
  if exists (select from app.lead where code like 'LDL%') then
    raise exception 'Đã có dữ liệu giả lớn. Dựng lại DB bằng npm run db:reset rồi chạy lại.';
  end if;
  if (select count(*) from app.user_account where login_name like 'sale.cs1@%' or login_name like 'sale.cs5@%') < 2 then
    raise exception 'Chưa có tài khoản giả sale.cs1, sale.cs5. Chạy npm run db:seed-users trước.';
  end if;
end $$;

select setseed(0.42);

-- Tắt trigger điền cột chuẩn và nhật ký trong lúc nạp (giữ created_at rải đều, không ghi 150.000 dòng nhật ký).
alter table app.parent disable trigger parent_fill_standard;
alter table app.parent disable trigger parent_audit;
alter table app.lead disable trigger lead_fill_standard;
alter table app.lead disable trigger lead_audit;
alter table app.appointment disable trigger appointment_fill_standard;
alter table app.appointment disable trigger appointment_audit;
alter table app.appointment disable trigger appointment_refresh_next;
alter table app.opportunity disable trigger opportunity_fill_standard;
alter table app.opportunity disable trigger opportunity_audit;
alter table app.student disable trigger student_fill_standard;
alter table app.prospect_student disable trigger prospect_student_fill_standard;
alter table app.prospect_student disable trigger prospect_student_audit;
alter table app.prospect_student disable trigger prospect_student_refresh_search;
alter table app.student disable trigger student_audit;
alter table app.student_test disable trigger student_test_fill_standard;
alter table app.student_test disable trigger student_test_audit;

create temp table seed_names as
select * from (values
  (1, 'Nguyễn'), (2, 'Trần'), (3, 'Lê'), (4, 'Phạm'), (5, 'Hoàng'), (6, 'Vũ'), (7, 'Đặng'), (8, 'Bùi'), (9, 'Đỗ'), (10, 'Hồ')
) as t(n, family);
create temp table seed_given as
select * from (values
  (1, 'Minh Châu'), (2, 'Gia Huy'), (3, 'Thu Hà'), (4, 'Anh Tuấn'), (5, 'Bảo Ngọc'), (6, 'Đức Long'),
  (7, 'Khánh Linh'), (8, 'Quang Vinh'), (9, 'Mai Anh'), (10, 'Hải Đăng'), (11, 'Thanh Vân'), (12, 'Văn Nam')
) as t(n, given);
create temp table seed_source as
select * from (values
  (1, 'MARKETING', 'FACEBOOK_ADS', 'FACEBOOK_ADS_LEAD_FORM'), (2, 'MARKETING', 'FACEBOOK_ADS', 'FACEBOOK_ADS_INBOX'),
  (3, 'MARKETING', 'WEBSITE', null), (4, 'MARKETING', 'HOTLINE', null), (5, 'MARKETING', 'ZALO', null),
  (6, 'MARKETING', 'WALK_IN', null), (7, 'REFERRAL', 'REFERRAL', 'REFERRAL_BY_CUSTOMER'), (8, 'EVENT', 'EVENT', 'EVENT_INDOOR')
) as t(n, type_code, source_code, channel_code);
create temp table seed_branch as
select row_number() over (order by b.code) as n, b.id as branch_id,
       (select a.id from app.user_account a where a.login_name = case b.code when 'CS1' then 'sale.cs1@thu.hoamatoan.invalid'
                                                                              else 'sale.cs5@thu.hoamatoan.invalid' end) as owner_id
  from app.branch b where b.code in ('CS1', 'CS5');

-- Phụ huynh giả: 30.000.
insert into app.parent (code, full_name, phone, branch_id, created_at, updated_at)
select 'PHL' || lpad(g::text, 6, '0'),
       (select family from seed_names where n = 1 + (g % 10)) || ' ' || (select given from seed_given where n = 1 + (g % 12)),
       '0998' || lpad(g::text, 6, '0'), (select branch_id from seed_branch where n = 1 + (g % 2)),
       now() - ((g % 200) || ' days')::interval, now()
  from generate_series(1, 30000) g;

-- Lead giả: 50.000, rải 200 ngày, 4 giai đoạn, 8 kiểu nguồn, hai cơ sở.
insert into app.lead (code, parent_name, parent_phone, branch_id, owner_id,
                      source_type_code, source_code, channel_code, stage_code, parent_id, created_at, updated_at, assigned_at)
select 'LDL' || lpad(g::text, 6, '0'),
       (select family from seed_names where n = 1 + (g % 10)) || ' ' || (select given from seed_given where n = 1 + ((g / 3) % 12)),
       '0999' || lpad(g::text, 6, '0'),
       (select branch_id from seed_branch where n = 1 + (g % 2)), (select owner_id from seed_branch where n = 1 + (g % 2)),
       s.type_code, s.source_code, s.channel_code,
       case when g % 10 < 4 then 'C1' when g % 10 < 6 then 'C2' when g % 10 < 8 then 'C3' else 'C4' end,
       case when g % 5 = 0 then (select id from app.parent where code = 'PHL' || lpad((1 + g % 30000)::text, 6, '0')) end,
       now() - ((g % 200) || ' days')::interval - ((g % 1440) || ' minutes')::interval, now(),
       now() - ((g % 200) || ' days')::interval
  from generate_series(1, 50000) g
  join seed_source s on s.n = 1 + (g % 8);

-- Danh sách em giả của lead: mỗi lead một em, 30% lead thêm em thứ hai (khoảng 1,3 em mỗi hồ sơ).
insert into app.prospect_student (lead_id, branch_id, position, full_name, birth_year, school, created_at, updated_at)
select l.id, l.branch_id, k.k,
       (select family from seed_names where n = 1 + ((g / 7 + k.k) % 10)) || ' ' || (select given from seed_given where n = 1 + ((g / 5 + k.k) % 12)),
       2008 + ((g + k.k) % 9), 'THCS Thử ' || (g % 40), l.created_at, now()
  from generate_series(1, 50000) g
  join app.lead l on l.code = 'LDL' || lpad(g::text, 6, '0')
  cross join lateral (select 1 as k union all select 2 where g % 10 < 3) k;

-- Lịch hẹn giả: 2 lịch mỗi lead, rải ±30 ngày quanh hôm nay; một phần Hoàn thành, một phần Huỷ.
insert into app.appointment (lead_id, activity_code, scheduled_at, title, owner_id, branch_id, status, cancel_reason_code,
                             completed_at, created_at, updated_at)
select l.id, (array['GOI_DIEN', 'ZALO', 'EMAIL', 'GAP_TRUC_TIEP'])[1 + (k + g) % 4],
       now() + (((g * 7 + k * 13) % 61) - 30 || ' days')::interval + ((g % 600) || ' minutes')::interval,
       'Lịch hẹn giả ' || g || '-' || k, l.owner_id, l.branch_id,
       case when (g + k) % 5 = 0 then 'HOAN_THANH' when (g + k) % 7 = 0 then 'HUY' else 'CHUA_LAM' end,
       case when (g + k) % 5 <> 0 and (g + k) % 7 = 0 then 'TAO_NHAM' end,
       case when (g + k) % 5 = 0 then now() end, now(), now()
  from generate_series(1, 50000) g
  cross join generate_series(1, 2) k
  join app.lead l on l.code = 'LDL' || lpad(g::text, 6, '0');

-- "Lịch hẹn kế tiếp" cho lead giả (trigger đã tắt lúc nạp).
update app.lead l set next_appointment_at = a.next
  from (select lead_id, min(scheduled_at) as next from app.appointment where status = 'CHUA_LAM' group by lead_id) a
 where a.lead_id = l.id and l.code like 'LDL%';

-- Cơ hội giả: 20.000, từ 20.000 lead đầu (lead đã có học sinh nên hợp luật R-CRM-03); 8 giai đoạn L1–L8, phụ huynh giả theo vòng.
-- Cơ hội L7, L8 ghi lý do bỏ qua test (R-CRM-14) cho hợp luật.
-- Cơ hội L5 trở lên được tạo trước khi có dòng em: tắt kiểm R-CRM-03 của trigger trong lúc nạp (như lúc chuyển dữ liệu).
select set_config('hmt.migration', 'on', false);
insert into app.opportunity (code, lead_id, parent_id, branch_id, owner_id,
                             source_type_code, source_code, channel_code, stage_code, skip_reason_code,
                             assigned_at, created_at, updated_at)
select 'COL' || lpad(g::text, 6, '0'), l.id,
       (select id from app.parent where code = 'PHL' || lpad((1 + g % 30000)::text, 6, '0')),
       l.branch_id, l.owner_id,
       l.source_type_code, l.source_code, l.channel_code, 'L' || (1 + g % 8),
       case when g % 8 in (6, 7) then 'HOC_SINH_CU' end,
       now() - ((g % 200) || ' days')::interval, now() - ((g % 200) || ' days')::interval - ((g % 1440) || ' minutes')::interval, now()
  from generate_series(1, 20000) g
  join app.lead l on l.code = 'LDL' || lpad(g::text, 6, '0');

select set_config('hmt.migration', '', false);

-- Danh sách em của cơ hội: chép các em của lead.
insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year, school, created_at, updated_at)
select o.id, o.branch_id, ps.position, ps.full_name, ps.birth_year, ps.school, o.created_at, now()
  from app.opportunity o
  join app.prospect_student ps on ps.lead_id = o.lead_id
 where o.code like 'COL%';

-- Lịch hẹn giả của cơ hội: một lịch mỗi cơ hội, rải ±30 ngày quanh hôm nay.
insert into app.appointment (opportunity_id, activity_code, scheduled_at, title, owner_id, branch_id, status, created_at, updated_at)
select o.id, (array['GOI_DIEN', 'ZALO', 'EMAIL', 'GAP_TRUC_TIEP'])[1 + g % 4],
       now() + (((g * 11) % 61) - 30 || ' days')::interval + ((g % 600) || ' minutes')::interval,
       'Lịch hẹn cơ hội giả ' || g, o.owner_id, o.branch_id, case when g % 6 = 0 then 'HOAN_THANH' else 'CHUA_LAM' end, now(), now()
  from generate_series(1, 20000) g
  join app.opportunity o on o.code = 'COL' || lpad(g::text, 6, '0');
update app.opportunity o set next_appointment_at = a.next
  from (select opportunity_id, min(scheduled_at) as next from app.appointment
         where status = 'CHUA_LAM' and opportunity_id is not null group by opportunity_id) a
 where a.opportunity_id = o.id and o.code like 'COL%';

-- Học sinh giả cho 10.000 cơ hội ở L5–L8 (cơ hội có phiếu phải có học sinh), gắn vào cơ hội.
insert into app.student (code, parent_id, full_name, birth_year, school, branch_id, created_at, updated_at)
select 'HSL' || lpad(g::text, 6, '0'), o.parent_id, ps.full_name, ps.birth_year, ps.school, o.branch_id, o.created_at, now()
  from generate_series(1, 20000) g
  join app.opportunity o on o.code = 'COL' || lpad(g::text, 6, '0')
  join app.prospect_student ps on ps.opportunity_id = o.id and ps.position = 1
 where o.stage_code in ('L5', 'L6', 'L7', 'L8');
-- Em đầu của các cơ hội đó gắn hồ sơ học sinh và đọc thẳng từ hồ sơ (Đ86).
update app.prospect_student ps set student_id = s.id, full_name = null, birth_date = null, birth_year = null,
       school = null, self_rating = null, goal = null
  from app.opportunity o, app.student s
 where ps.opportunity_id = o.id and ps.position = 1 and o.code like 'COL%' and o.stage_code in ('L5', 'L6', 'L7', 'L8')
   and s.code = 'HSL' || substr(o.code, 4);

-- Phiếu kiểm tra giả: 15.000 (cơ hội L5–L8: một phiếu, cơ hội số chẵn thêm phiếu thứ hai), 5 trạng thái, rải ±30 ngày,
-- hai cơ sở, một phần có giáo viên chấm (gv.cs5) và điểm.
insert into app.student_test (code, opportunity_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code,
                              grade_code, mode_code, level_code, exam_name, scheduled_at, grader_id, owner_id, status_code,
                              cancel_reason_code, cancelled_at, score, result_note, completed_at, created_at, updated_at,
                              prospect_student_id)
select 'PKL' || lpad((row_number() over (order by o.code, k.k))::text, 6, '0'), o.id, p1.student_id, o.branch_id, o.branch_id, o.branch_id,
       (array['TOAN', 'VAN', 'ANH'])[1 + (g + k.k) % 3],
       (select code from app.catalog_item where catalog_code = 'GRADE' order by sort_order offset ((g + k.k) % 6) limit 1),
       (array['OFFLINE', 'ONLINE'])[1 + (g + k.k) % 2], (array['CO_BAN', 'NANG_CAO'])[1 + (g + k.k) % 2],
       'Đề giả ' || g || '-' || k.k,
       now() + (((g * 7 + k.k * 13) % 61) - 30 || ' days')::interval + ((g % 600) || ' minutes')::interval,
       case when (g + k.k) % 5 in (2, 3) then (select id from app.user_account where login_name like 'gv.cs5@%') end,
       o.owner_id,
       (array['DRAFT', 'TESTING', 'TEACHER_REVIEW', 'COMPLETED', 'CANCELLED'])[1 + (g + k.k) % 5],
       case when (g + k.k) % 5 = 4 then (array['L5C', 'L5D', 'L5E', 'L5F', 'TAO_PHIEU_SAI'])[1 + g % 5] end,
       case when (g + k.k) % 5 = 4 then now() - ((g % 30) || ' days')::interval end,
       case when (g + k.k) % 5 in (2, 3) then round(((g % 100) / 10.0)::numeric, 1) end,
       case when (g + k.k) % 5 = 3 then 'Nhận xét giả' end,
       case when (g + k.k) % 5 = 3 then now() end,
       o.created_at, now(), p1.id
  from generate_series(1, 20000) g
  join app.opportunity o on o.code = 'COL' || lpad(g::text, 6, '0') and o.stage_code in ('L5', 'L6', 'L7', 'L8')
  join app.prospect_student p1 on p1.opportunity_id = o.id and p1.position = 1
  cross join lateral (select 1 as k union all select 2 where g % 2 = 0) k;

alter table app.parent enable trigger parent_fill_standard;
alter table app.parent enable trigger parent_audit;
alter table app.lead enable trigger lead_fill_standard;
alter table app.lead enable trigger lead_audit;
alter table app.appointment enable trigger appointment_fill_standard;
alter table app.appointment enable trigger appointment_audit;
alter table app.appointment enable trigger appointment_refresh_next;
alter table app.opportunity enable trigger opportunity_fill_standard;
alter table app.opportunity enable trigger opportunity_audit;
alter table app.student enable trigger student_fill_standard;
alter table app.prospect_student enable trigger prospect_student_fill_standard;
alter table app.prospect_student enable trigger prospect_student_audit;
alter table app.prospect_student enable trigger prospect_student_refresh_search;
alter table app.student enable trigger student_audit;
alter table app.student_test enable trigger student_test_fill_standard;
alter table app.student_test enable trigger student_test_audit;

-- Cấu hình bán hàng giả lớn (EXPLAIN của P5a-DB0): 4 loại gói x môn x khối (khoảng 440 gói) và 6 dòng giá mỗi gói
-- (hai hình thức, ba ngày hiệu lực).
insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code)
select t.code || '-' || s.code || '-' || g.code, 'Gói giả ' || t.code || ' ' || s.code || ' ' || g.code, t.code, s.code, g.code
  from (values ('LC'), ('VIP'), ('VNN'), ('KR')) t(code)
  cross join (select code from app.catalog_item where catalog_code = 'SUBJECT' and code not in ('DAI', 'HINH')) s
  cross join (select code from app.catalog_item where catalog_code = 'GRADE') g
on conflict (code) do nothing;
insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
select p.id, m.mode, 100000 + (row_number() over (order by p.code, m.mode, d.d)) % 400 * 1000, d.d
  from app.sales_package p
  cross join (values ('OFF'), ('ONL')) m(mode)
  cross join (values (date '2025-09-01'), (date '2026-03-01'), (date '2026-09-01')) d(d)
 where p.code like 'LC-%' or p.code like 'VIP-%' or p.code like 'VNN-%' or p.code like 'KR-%'
on conflict (package_id, delivery_mode_code, effective_from) do nothing;
analyze app.sales_package;
analyze app.package_price;

-- Ô tìm kiếm của lead, cơ hội (trigger cập nhật theo dòng em đã tắt lúc nạp).
update app.lead l set search_text = app.lead_search_text(l) where l.code like 'LDL%';
update app.opportunity o set search_text = app.opportunity_search_text(o) where o.code like 'COL%';

-- Báo giá giả lớn (EXPLAIN của P5a-DB1a): 15.000 báo giá (mỗi cơ hội COL000001..015000 một báo giá), 1 đến 3 dòng mỗi báo giá, 4 trạng thái.
alter table app.quotation disable trigger quotation_fill_standard;
alter table app.quotation disable trigger quotation_audit;
alter table app.quotation_line disable trigger quotation_line_fill_standard;
alter table app.quotation_line disable trigger quotation_line_audit;
insert into app.quotation (code, branch_id, opportunity_id, parent_id, status_code, priced_on, valid_until, sent_at, total_amount,
                           created_at, updated_at)
select 'BGL' || lpad(g::text, 6, '0'), o.branch_id, o.id, o.parent_id,
       case when g % 10 < 4 then 'NHAP' when g % 10 < 8 then 'DA_GUI' when g % 10 < 9 then 'TU_CHOI' else 'HUY' end,
       current_date - (g % 120), case when g % 10 between 4 and 7 then current_date + (g % 30) - 15 end,
       case when g % 10 between 4 and 8 then now() - ((g % 120) || ' days')::interval end, 0,
       now() - ((g % 120) || ' days')::interval, now()
  from generate_series(1, 15000) g
  join app.opportunity o on o.code = 'COL' || lpad(g::text, 6, '0');
insert into app.quotation_line (quotation_id, branch_id, line_no, prospect_student_id, package_id, package_code, package_name,
                                package_type_code, delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total)
select q.id, q.branch_id, k.k, ps.id, p.id, p.code, p.name, p.package_type_code, 'OFF', 'GIO', 12 + (g % 5) * 12,
       100000 + (g % 200) * 1000, (12 + (g % 5) * 12) * (100000 + (g % 200) * 1000), (12 + (g % 5) * 12) * (100000 + (g % 200) * 1000)
  from generate_series(1, 15000) g
  join app.quotation q on q.code = 'BGL' || lpad(g::text, 6, '0')
  join app.prospect_student ps on ps.opportunity_id = q.opportunity_id and ps.position = 1
  cross join lateral generate_series(1, 1 + g % 3) k(k)
  join (select id, code, name, package_type_code, row_number() over (order by code) as rn
          from app.sales_package where package_type_code = 'LC') p on p.rn = 1 + (g * k.k) % (select count(*) from app.sales_package where package_type_code = 'LC');
update app.quotation q set total_amount = t.total
  from (select quotation_id, sum(line_total) as total from app.quotation_line group by quotation_id) t
 where t.quotation_id = q.id and q.code like 'BGL%';
update app.quotation q set search_text = app.quotation_search_text(q) where q.code like 'BGL%';
alter table app.quotation enable trigger quotation_fill_standard;
alter table app.quotation enable trigger quotation_audit;
alter table app.quotation_line enable trigger quotation_line_fill_standard;
alter table app.quotation_line enable trigger quotation_line_audit;
analyze app.quotation;
analyze app.quotation_line;

-- Đặt đếm mã để mã thật (LD…) không đụng mã giả (LDL…): mã giả có tiền tố khác nên không cần; chỉ cập nhật thống kê.
analyze app.parent;
analyze app.lead;
analyze app.appointment;
analyze app.opportunity;
analyze app.student;
analyze app.student_test;
analyze app.prospect_student;

select (select count(*) from app.lead) as leads, (select count(*) from app.parent) as parents,
       (select count(*) from app.appointment) as appointments, (select count(*) from app.opportunity) as opportunities,
       (select count(*) from app.student_test) as tests;
