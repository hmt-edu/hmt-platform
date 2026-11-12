-- Migration 125: bật công tắc BAN_HANG cho cơ sở CS5 bằng migration (không dựa vào supabase/seed.sql). Chỉ CS5; chạy lại không lỗi, không nhân đôi dòng.
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
grant execute on all functions in schema pg_temp to public;

create temp table b as select code, id from app.branch;

-- Sau migration: BAN_HANG bật ở CS5; hàm nghiệp vụ không còn bị chặn ở CS5.
select ok(app.feature_enabled('BAN_HANG', (select id from b where code = 'CS5')), 'Sau migration 125: BAN_HANG bật ở CS5');
select is(pg_temp.err($$select app.require_feature('BAN_HANG', (select id from app.branch where code = 'CS5'))$$), null, 'CS5: require_feature(BAN_HANG) chạy được');

-- Cơ sở khác KHÔNG được bật bởi migration (trên dữ liệu thật chưa có dòng nào khác).
select is((select count(*)::int from app.feature_flag f join b on b.id = f.branch_id where f.module_code = 'BAN_HANG' and f.enabled and b.code <> 'CS5'), 0, 'Không cơ sở nào khác ngoài CS5 được bật BAN_HANG');
select ok(not app.feature_enabled('BAN_HANG', (select id from b where code = 'CS1')), 'CS1: BAN_HANG vẫn tắt');
select is(pg_temp.err($$select app.require_feature('BAN_HANG', (select id from app.branch where code = 'CS1'))$$), 'HMT_TINH_NANG_TAT', 'CS1: hàm nghiệp vụ vẫn bị chặn');

-- Không bật CONG_GIAO_VIEN (không có hàm/màn nào kiểm phân hệ này).
select ok(not app.feature_enabled('CONG_GIAO_VIEN', (select id from b where code = 'CS5')), 'CONG_GIAO_VIEN không bị bật ở CS5');

-- Đúng MỘT dòng BAN_HANG cho CS5; chạy lại đúng câu lệnh của migration (kể cả khi đang tắt) thì bật lại, không nhân đôi, không lỗi.
select is((select count(*)::int from app.feature_flag f join b on b.id = f.branch_id where f.module_code = 'BAN_HANG' and b.code = 'CS5'), 1, 'Đúng một dòng BAN_HANG cho CS5');
select app.set_feature('BAN_HANG', (select id from b where code = 'CS5'), false);
select ok(not app.feature_enabled('BAN_HANG', (select id from b where code = 'CS5')), 'Tắt thử ở CS5');
insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', b.id, true from app.branch b where b.code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true;
select ok(app.feature_enabled('BAN_HANG', (select id from b where code = 'CS5')), 'Chạy lại câu lệnh của migration: bật lại');
select is((select count(*)::int from app.feature_flag f join b on b.id = f.branch_id where f.module_code = 'BAN_HANG' and b.code = 'CS5'), 1, 'Chạy lại không nhân đôi dòng');

select * from finish();
rollback;
