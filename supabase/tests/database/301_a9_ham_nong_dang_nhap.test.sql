-- A9 Hâm nóng Edge Function login (migration 301): tắt mặc định thì không gọi; chỉ đúng địa chỉ /functions/v1/login; chỉ trong giờ làm việc giờ Việt Nam; chỉ đúng chu kỳ; người dùng không gọi được; có lịch cron.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create temp table before_q (n bigint);
insert into before_q select count(*) from net.http_request_queue;
create function pg_temp.queued() returns bigint language sql as $$ select count(*) - (select n from before_q) from net.http_request_queue $$;
create function pg_temp.seturl(p text) returns void language sql as $$ update app.setting_def set value = p where key = 'login_warm_url' $$;

-- 03:00 UTC ngày 18/11/2026 = 10:00 giờ Việt Nam (phút 600, trong 390..1290; 600 chia hết cho 4).
-- ================= Tắt mặc định =================
select is(app.login_warm_tick('2026-11-18T03:00:00Z'), 'TAT', 'Mặc định TẮT: chưa điền địa chỉ thì không gọi');
select is(pg_temp.queued(), 0::bigint, 'Mặc định TẮT: không có yêu cầu nào được xếp hàng');

-- ================= Địa chỉ =================
select pg_temp.seturl('https://evil.example.com/anything');
select is(app.login_warm_tick('2026-11-18T03:00:00Z'), 'DIA_CHI_SAI', 'Địa chỉ không kết thúc /functions/v1/login bị chặn');
select pg_temp.seturl('https://abc.supabase.co/functions/v1/login?x=1');
select is(app.login_warm_tick('2026-11-18T03:00:00Z'), 'DIA_CHI_SAI', 'Địa chỉ có tham số kèm theo bị chặn');
select is(pg_temp.queued(), 0::bigint, 'Địa chỉ sai: không gọi');

-- ================= Giờ làm việc và chu kỳ =================
select pg_temp.seturl('https://abc.supabase.co/functions/v1/login');
select is(app.login_warm_tick('2026-11-17T22:00:00Z'), 'NGOAI_GIO', 'Ngoài giờ: 05:00 giờ Việt Nam không gọi');
select is(app.login_warm_tick('2026-11-18T15:00:00Z'), 'NGOAI_GIO', 'Ngoài giờ: 22:00 giờ Việt Nam không gọi');
select is(app.login_warm_tick('2026-11-18T14:30:00Z'), 'NGOAI_GIO', 'Đúng 21:30 (phút kết thúc) thì dừng, không gọi');
select is(app.login_warm_tick('2026-11-18T03:01:00Z'), 'CHUA_DEN_LUOT', 'Chưa đến lượt: 10:01 không chia hết chu kỳ 4 phút');
select is(app.login_warm_tick('2026-11-17T23:30:00Z'), 'CHUA_DEN_LUOT', 'Đúng 06:30 (phút 390) không chia hết 4 nên chưa đến lượt');
select is(pg_temp.queued(), 0::bigint, 'Ngoài giờ hoặc chưa đến lượt: không gọi');

-- ================= Đúng giờ, đúng lượt =================
select is(app.login_warm_tick('2026-11-18T03:00:00Z'), 'DA_GOI', 'Trong giờ, đúng chu kỳ (10:00) thì gọi');
select is(pg_temp.queued(), 1::bigint, 'Gọi: một yêu cầu xếp hàng');
select is(app.login_warm_tick('2026-11-17T23:32:00Z'), 'DA_GOI', 'Đúng 06:32 (phút 392, chia hết 4, từ 390) thì gọi');
select is((select count(*) from net.http_request_queue where url = 'https://abc.supabase.co/functions/v1/login?ping=1'), 2::bigint, 'Địa chỉ gọi kèm ?ping=1');

-- Đổi chu kỳ trong Cài đặt có hiệu lực ngay.
update app.setting_def set value = '5' where key = 'login_warm_interval_minutes';
select is(app.login_warm_tick('2026-11-18T03:04:00Z'), 'CHUA_DEN_LUOT', 'Chu kỳ 5 phút: 10:04 chưa đến lượt');
select is(app.login_warm_tick('2026-11-18T03:05:00Z'), 'DA_GOI', 'Chu kỳ 5 phút: 10:05 gọi');

-- ================= Quyền và lịch =================
select is(has_function_privilege('authenticated', 'app.login_warm_tick(timestamptz)', 'execute'), false, 'Người dùng đăng nhập không gọi được hàm hâm nóng');
select is(has_function_privilege('anon', 'app.login_warm_tick(timestamptz)', 'execute'), false, 'Khách chưa đăng nhập không gọi được hàm hâm nóng');
select is((select count(*) from cron.job where jobname = 'login-warm' and schedule = '* * * * *'), 1::bigint, 'Có lịch cron login-warm mỗi phút');
select is((select count(*) from app.setting_def where key in ('login_warm_url', 'login_warm_interval_minutes', 'login_warm_from_minute', 'login_warm_to_minute') and (key <> 'login_warm_url' or value = 'https://abc.supabase.co/functions/v1/login' or true)), 4::bigint, 'Bốn tham số đã khai báo');

select * from finish();
rollback;
