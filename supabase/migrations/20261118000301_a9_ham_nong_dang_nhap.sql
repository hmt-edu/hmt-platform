-- A9 Hâm nóng Edge Function login (Code A, 18/11/2026; Chat duyệt đề xuất A3 mục 2): lần đăng nhập đầu sau lúc im ắng mất ~2 giây vì Function khởi động lạnh (so với ~0,45 giây khi ấm).
-- Cách làm: pg_cron mỗi phút gọi app.login_warm_tick(); hàm kiểm tham số rồi (chỉ khi bật, trong giờ làm việc, đúng chu kỳ) gửi GET ?ping=1 tới Function login bằng pg_net.
-- Đường ?ping=1 của Function trả 204, không đọc thân, không captcha, không chạm DB, không ghi nhật ký (supabase/functions/login). Miễn phí: vài trăm lần gọi vài byte mỗi ngày.
-- Cấu hình, MẶC ĐỊNH TẮT (không viết cứng địa chỉ, giờ, chu kỳ): login_warm_url = TAT (hoặc rỗng) là tắt; chu kỳ mặc định 4 phút; giờ làm việc 06:30 đến 21:30 giờ Việt Nam.
-- An toàn: chỉ gọi địa chỉ có đuôi đúng /functions/v1/login (không gọi địa chỉ khác dù ai đó đặt tham số sai); hàm không cấp quyền cho người dùng đăng nhập, chỉ pg_cron (vai trò postgres) chạy.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- Khai báo tham số chỉ qua migration (cờ hmt.migration).
select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('login_warm_url', 'Địa chỉ Function đăng nhập để hâm nóng', 'TEXT', null, null, null, 'TAT', false, null, null,
   'TAT là TẮT hâm nóng (mặc định). Điền đúng địa chỉ dạng https://<mã dự án>.supabase.co/functions/v1/login (phải kết thúc bằng /functions/v1/login). Hệ thống gọi thưa trong giờ làm việc để lần đăng nhập đầu không bị chậm.'),
  ('login_warm_interval_minutes', 'Chu kỳ hâm nóng đăng nhập', 'INT', 'phút', 1, 30, '4', false, null, null,
   'Cứ mỗi bấy nhiêu phút gọi hâm nóng một lần trong giờ làm việc (khi login_warm_url đã điền).'),
  ('login_warm_from_minute', 'Giờ bắt đầu hâm nóng đăng nhập', 'INT', 'phút từ 00:00', 0, 1439, '390', false, null, null,
   'Số phút kể từ 00:00 giờ Việt Nam; 390 là 06:30.'),
  ('login_warm_to_minute', 'Giờ kết thúc hâm nóng đăng nhập', 'INT', 'phút từ 00:00', 1, 1440, '1290', false, null, null,
   'Số phút kể từ 00:00 giờ Việt Nam; 1290 là 21:30. Ngoài khoảng từ đến này thì không gọi.');

-- app.login_warm_tick(p_now): một nhịp hâm nóng. Ai gọi: pg_cron (postgres), không ai khác. Kết quả (chữ, để thử và đọc nhật ký cron):
--   'TAT' (chưa điền địa chỉ), 'DIA_CHI_SAI' (không kết thúc bằng /functions/v1/login), 'NGOAI_GIO', 'CHUA_DEN_LUOT' (không đúng chu kỳ), 'DA_GOI'.
-- Luật từng bước nằm ở chú thích bên dưới; không SQL động.
create or replace function app.login_warm_tick(p_now timestamptz default now())
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text := btrim(coalesce(app.get_setting('login_warm_url'), ''));
  v_every integer := app.get_setting_int('login_warm_interval_minutes');
  v_from integer := app.get_setting_int('login_warm_from_minute');
  v_to integer := app.get_setting_int('login_warm_to_minute');
  v_local timestamp := p_now at time zone 'Asia/Ho_Chi_Minh';
  v_minute integer := extract(hour from v_local)::integer * 60 + extract(minute from v_local)::integer; -- allow-number: đổi giờ sang phút
begin
  -- Luật: chưa điền địa chỉ (còn TAT hoặc rỗng) thì tắt, không gọi gì.
  if v_url = '' or upper(v_url) = 'TAT' then
    return 'TAT';
  end if;
  -- Luật: chỉ gọi đúng địa chỉ Function login của dự án (kết thúc /functions/v1/login), không có tham số kèm theo.
  if v_url !~ '^https?://[^/?#[:space:]]+/functions/v1/login$' then
    return 'DIA_CHI_SAI';
  end if;
  -- Luật: chỉ trong giờ làm việc giờ Việt Nam (từ phút bắt đầu đến trước phút kết thúc).
  if v_minute < v_from or v_minute >= v_to then
    return 'NGOAI_GIO';
  end if;
  -- Luật: chỉ đúng chu kỳ (phút trong ngày chia hết cho chu kỳ); pg_cron chạy mỗi phút nên đổi chu kỳ trong Cài đặt có hiệu lực ngay.
  if v_minute % v_every <> 0 then
    return 'CHUA_DEN_LUOT';
  end if;
  perform net.http_get(url := v_url || '?ping=1', timeout_milliseconds := 5000); -- allow-number: hạn chờ kỹ thuật của yêu cầu hâm nóng (mili giây)
  return 'DA_GOI';
end;
$$;
revoke execute on function app.login_warm_tick(timestamptz) from public, anon, authenticated;

select set_config('hmt.migration', '', false);

-- Lịch: mỗi phút một nhịp (hàm tự bỏ qua khi tắt, ngoài giờ hay chưa đến lượt). Dọn nhật ký cron mỗi ngày để không phình DB (gói Free 500 MB).
select cron.schedule('login-warm', '* * * * *', 'select app.login_warm_tick()');
select cron.schedule('login-warm-don-nhat-ky', '15 3 * * *', $$delete from cron.job_run_details where end_time < now() - interval '2 days'$$);
