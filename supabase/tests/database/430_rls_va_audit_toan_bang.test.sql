-- C27 (CLAUDE.md, Kiến trúc): «RLS bật cho mọi bảng» và «bảng nghiệp vụ có trigger ghi audit_log». Quét danh mục hệ thống, không dựng dữ liệu.
-- Bảng thiếu thì bài báo đúng tên bảng trong phần thông báo lỗi; KHÔNG tự bật hay tắt gì (báo Chat).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Bảng thường (kể cả bảng chia) của schema app và public: ngoại trừ bảng phụ của tiện ích mở rộng.
create temp view v_tables as
  select n.nspname as schema_name, c.relname as table_name, c.oid, c.relrowsecurity
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname in ('app', 'public') and c.relkind in ('r', 'p') and not c.relispartition
     and not exists (select from pg_depend d where d.objid = c.oid and d.deptype = 'e');

select is((select count(*)::int from v_tables) > 0, true, 'Có bảng để kiểm (schema app, public)');
select is((select string_agg(schema_name || '.' || table_name, ', ' order by schema_name, table_name) from v_tables where not relrowsecurity),
          null, 'Mọi bảng schema app và public đều bật RLS (CLAUDE.md: RLS bật cho mọi bảng)');

-- Bảng nghiệp vụ = bảng schema app có cột created_by (khuôn chuẩn của app.apply_standard); phải có trigger gọi app.tg_audit (phiếu chi: app.tg_audit_payment_voucher, che tài khoản nhận, migration 617).
-- Ngoại lệ: chính bảng nhật ký (app.audit_log), không tự ghi nhật ký của nhật ký.
select is((select string_agg(t.table_name, ', ' order by t.table_name)
             from v_tables t
            where t.schema_name = 'app' and t.table_name <> 'audit_log'
              and exists (select from pg_attribute a where a.attrelid = t.oid and a.attname = 'created_by' and not a.attisdropped)
              and not exists (select from pg_trigger g where g.tgrelid = t.oid and not g.tgisinternal and g.tgfoid in ('app.tg_audit'::regproc, 'app.tg_audit_payment_voucher'::regproc))),
          null, 'Mọi bảng nghiệp vụ schema app (có created_by) có trigger ghi audit_log (app.tg_audit)');

select * from finish();
rollback;
