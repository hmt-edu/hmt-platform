-- KIỂM staging, CHỈ ĐỌC (phiếu dieu-phoi-kit#274). Chỉ có câu SELECT và lệnh \echo của psql; không ghi gì.
-- Chạy bằng workflow `kiem-staging.yml` (tay) hoặc: psql "$STAGING_DB_URL" -X -v ON_ERROR_STOP=1 -f scripts/staging/kiem-chi-doc.sql
-- In ra: migration cuối, các lịch pg_cron và 10 lần chạy gần nhất. Chỉ in số, mã, tên job, trạng thái: không in câu lệnh của job, không in thông điệp lỗi.
\pset pager off
\echo === 1. Migration cuối đã áp
select max(version) as migration_cuoi, count(*) as so_migration_da_ap from supabase_migrations.schema_migrations;

\echo === 2. Phần mở rộng pg_cron
select to_regclass('cron.job') is not null as co_pg_cron \gset
select :'co_pg_cron' as co_pg_cron;

\if :co_pg_cron
\echo === 3. Lịch pg_cron (cron.job)
select jobname, schedule, active from cron.job order by jobname;

\echo === 4. 10 lần chạy gần nhất (cron.job_run_details)
select j.jobname, d.status, d.start_time
  from cron.job_run_details d
  join cron.job j on j.jobid = d.jobid
 order by d.start_time desc
 limit 10;
\else
\echo === 3 và 4. Chưa có pg_cron: buổi học KHÔNG tự chốt, tự Done (xem docs/van-hanh/bat-pg-cron.md)
\endif
