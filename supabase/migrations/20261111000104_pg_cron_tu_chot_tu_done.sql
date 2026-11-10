-- Lịch tự chạy của buổi học (Code 2, 10/11/2026): tự chốt danh sách và tự Done bằng pg_cron.
-- Luật: R-GIO-05 (tự chốt), R-GIO-06 (tự Done), Q-180 (anh OK ĐƯA VÀO LUẬT 10/11).
-- Làm gì: bật pg_cron; thêm tham số session_autocomplete_minutes (mặc định 15, khoảng 5 đến 60); hàm app.sync_session_cron()
-- đăng ký hai lịch từ Cài đặt: tự chốt mỗi session_autoclose_before_minutes phút (mặc định 30), tự Done mỗi session_autocomplete_minutes phút.
-- Cần các hàm auto_close_sessions, auto_complete_sessions của migration 102 (đã có trên main). Tiền tố 20261111000104 lớn hơn mọi file trên main.
select set_config('hmt.migration', 'on', false);

-- pg_cron chạy trong DB `postgres`. Trên Supabase (gói Free có sẵn) bật bằng lệnh này. Nếu môi trường chưa cho bật (db push không đủ quyền), migration KHÔNG dừng:
-- chỉ báo NOTICE, các hàm vẫn tạo; bật pg_cron theo hướng dẫn trong file kiểm của PR rồi gọi select app.sync_session_cron();
do $$
begin
  create extension if not exists pg_cron;
exception when others then
  raise notice 'Chưa bật được pg_cron (%). Bật tay rồi chạy: select app.sync_session_cron();', sqlerrm;
end;
$$;

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('session_autocomplete_minutes', 'Chu kỳ tự Done buổi', 'INT', 'phút', 5, 60, '15', false, 'VAN_HANH_LOP', null,
   'Cứ sau chừng này phút hệ thống thử Done các buổi Đã chốt đủ điều kiện (R-GIO-06, Q-180). Đổi giá trị rồi gọi app.sync_session_cron().');

-- app.sync_session_cron(): đăng ký (hoặc đăng ký lại) hai lịch theo Cài đặt. Gọi lại nhiều lần không nhân đôi: lịch có tên cố định.
-- Ai gọi: Admin (đã xác thực hai bước) hoặc migration. Kết quả: văn bản biểu thức cron của hai lịch.
-- Chu kỳ phút chung toàn hệ thống (lấy giá trị chung, không ghi đè theo cơ sở) vì pg_cron chạy một lịch cho cả DB.
create or replace function app.sync_session_cron()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_close integer := app.get_setting_int('session_autoclose_before_minutes');
  v_done integer := app.get_setting_int('session_autocomplete_minutes');
  v_close_expr text;
  v_done_expr text;
begin
  -- Chưa bật pg_cron thì báo rõ, không để lỗi lạ.
  if to_regnamespace('cron') is null then
    perform app.raise_error('HMT_PG_CRON_CHUA_BAT', 'pg_cron chưa được bật trên cơ sở dữ liệu này. Bật pg_cron rồi gọi lại.');
  end if;
  if auth.uid() is not null and not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên đổi lịch tự chạy.');
  end if;
  -- Luật Q-180: chu kỳ tính bằng phút nguyên, từ 1 đến 59 (lịch theo phút của cron).
  if v_close < 1 or v_close > 59 or v_done < 1 or v_done > 59 then -- allow-number: giới hạn phút trong một giờ của biểu thức cron
    perform app.raise_error('HMT_LICH_SAI', 'Chu kỳ tự chốt và tự Done phải từ 1 đến 59 phút.');
  end if;
  v_close_expr := format('*/%s * * * *', v_close);
  v_done_expr := format('*/%s * * * *', v_done);
  perform cron.schedule('hmt-auto-close-sessions', v_close_expr, 'select app.auto_close_sessions()');
  perform cron.schedule('hmt-auto-complete-sessions', v_done_expr, 'select app.auto_complete_sessions()');
  return format('tự chốt: %s; tự Done: %s', v_close_expr, v_done_expr);
end;
$$;

revoke execute on function app.sync_session_cron() from public, anon;
grant execute on function app.sync_session_cron() to authenticated;

-- Đăng ký lịch ngay nếu pg_cron đã có; chưa có thì bỏ qua (xem trên).
do $$
begin
  if to_regnamespace('cron') is not null then
    perform app.sync_session_cron();
  else
    raise notice 'Bỏ qua đăng ký lịch vì pg_cron chưa bật.';
  end if;
end;
$$;

select set_config('hmt.migration', '', false);
