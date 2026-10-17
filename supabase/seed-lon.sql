-- Dữ liệu GIẢ LỚN chỉ để thử tốc độ ở máy local (CLAUDE.md, Hiệu năng). KHÔNG chạy ở thử nghiệm hay chạy thật,
-- KHÔNG nằm trong seed.sql thường, KHÔNG dùng dữ liệu thật: tên ghép từ danh sách giả, SĐT dạng 0999xxxxxx giả.
-- Cần tài khoản giả đã có: npm run db:seed-users (dùng sale.cs1, sale.cs5).
-- Chạy: npm run db:seed-lon. Tạo 50.000 lead (mã LDL000001…), 30.000 phụ huynh (mã PHL…), 100.000 lịch hẹn.
-- Cơ hội (20.000) và phiếu kiểm tra thêm ở P3b2.
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
insert into app.lead (code, parent_name, parent_phone, student_name, student_birth_year, school, branch_id, owner_id,
                      source_type_code, source_code, channel_code, stage_code, parent_id, created_at, updated_at, assigned_at)
select 'LDL' || lpad(g::text, 6, '0'),
       (select family from seed_names where n = 1 + (g % 10)) || ' ' || (select given from seed_given where n = 1 + ((g / 3) % 12)),
       '0999' || lpad(g::text, 6, '0'),
       (select family from seed_names where n = 1 + ((g / 7) % 10)) || ' ' || (select given from seed_given where n = 1 + ((g / 5) % 12)),
       2008 + (g % 9), 'THCS Thử ' || (g % 40),
       (select branch_id from seed_branch where n = 1 + (g % 2)), (select owner_id from seed_branch where n = 1 + (g % 2)),
       s.type_code, s.source_code, s.channel_code,
       case when g % 10 < 4 then 'C1' when g % 10 < 6 then 'C2' when g % 10 < 8 then 'C3' else 'C4' end,
       case when g % 5 = 0 then (select id from app.parent where code = 'PHL' || lpad((1 + g % 30000)::text, 6, '0')) end,
       now() - ((g % 200) || ' days')::interval - ((g % 1440) || ' minutes')::interval, now(),
       now() - ((g % 200) || ' days')::interval
  from generate_series(1, 50000) g
  join seed_source s on s.n = 1 + (g % 8);

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

alter table app.parent enable trigger parent_fill_standard;
alter table app.parent enable trigger parent_audit;
alter table app.lead enable trigger lead_fill_standard;
alter table app.lead enable trigger lead_audit;
alter table app.appointment enable trigger appointment_fill_standard;
alter table app.appointment enable trigger appointment_audit;
alter table app.appointment enable trigger appointment_refresh_next;

-- Đặt đếm mã để mã thật (LD…) không đụng mã giả (LDL…): mã giả có tiền tố khác nên không cần; chỉ cập nhật thống kê.
analyze app.parent;
analyze app.lead;
analyze app.appointment;

select (select count(*) from app.lead) as leads, (select count(*) from app.parent) as parents,
       (select count(*) from app.appointment) as appointments;
