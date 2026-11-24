-- F-24-04, migration 669: Edge Function ghi sổ tệp bằng service_role. Luật: service_role đọc, thêm, sửa sổ tệp và đọc tham số dung lượng; KHÔNG xoá;
-- người đăng nhập thường và khách vẫn không ghi. Thử bằng vai service_role thật (lỗi staging 25/11: bài kiểm cũ giả lập nên không bắt được). Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_state = returned_sqlstate;
  return v_state;
end $$;
grant execute on all functions in schema pg_temp to public;

select ok(has_table_privilege('service_role', 'app.stored_file', 'select')
          and has_table_privilege('service_role', 'app.stored_file', 'insert')
          and has_table_privilege('service_role', 'app.stored_file', 'update'), 'Đúng: service_role đọc, thêm, sửa được sổ tệp');
select ok(not has_table_privilege('service_role', 'app.stored_file', 'delete'), 'Luật không xoá cứng: service_role không có quyền xoá sổ tệp');
select ok(has_table_privilege('service_role', 'app.setting_def', 'select') and not has_table_privilege('service_role', 'app.setting_def', 'update'),
          'Đúng: service_role đọc tham số dung lượng nhưng không sửa cấu hình');
select ok(not has_table_privilege('authenticated', 'app.stored_file', 'insert') and not has_table_privilege('anon', 'app.stored_file', 'select'),
          'Luật cũ giữ: đăng nhập thường không ghi, khách không đọc sổ tệp');

select ok(has_function_privilege('service_role', 'app.current_actor()', 'execute'), 'Đúng: service_role chạy được hàm điền người sửa của trigger khung chung');

-- Dựng dòng giả bằng quyền chủ; gỡ khoá ngoại của bảng (trong giao dịch này, rollback cuối bài) chỉ để khỏi dựng cả chuỗi lớp, bài giao.
do $$ declare r record; begin
  for r in select conname from pg_constraint where conrelid = 'app.stored_file'::regclass and contype = 'f' loop
    execute format('alter table app.stored_file drop constraint %I', r.conname);
  end loop;
end $$;
create temp table ids as select gen_random_uuid() as branch, gen_random_uuid() as cls, gen_random_uuid() as asg, gen_random_uuid() as stu;
grant select on ids to public;
set local role service_role;

select is(pg_temp.err($f$insert into app.stored_file (storage_key, sha256, kind, branch_id, class_id, assignment_id, student_id, mime_type, size_bytes, delete_after, status)
  select gen_random_uuid()::text, repeat('c', 64), 'BAI_NOP', branch, cls, asg, stu, 'image/webp', 150000, current_date + 60, 'CHO_TAI' from ids$f$), null,
  'Đúng: service_role thêm được dòng CHO_TAI (đường insertPending của Edge Function)');
-- Trigger khung chung (điền người/giờ, nhật ký) chạy thật dưới service_role ở cả thêm lẫn sửa.
select is(pg_temp.err($f$update app.stored_file set status = 'DANG_DUNG', storage_key = 'k-' || gen_random_uuid()::text where sha256 = repeat('c', 64)$f$), null,
  'Đúng: service_role đổi sang DANG_DUNG (đường markReady), trigger khung chung và nhật ký chạy được');
select is((select count(*)::int from app.stored_file where sha256 = repeat('c', 64) and status = 'DANG_DUNG'), 1, 'Đúng: service_role đọc lại được dòng vừa sửa');
select is((select value from app.setting_def where key = 'file_storage_min_free_gb'), '3', 'Đúng: service_role đọc được tham số chặn mềm theo dung lượng trống');
select is(pg_temp.err($f$delete from app.stored_file where sha256 = repeat('c', 64)$f$), '42501', 'Luật không xoá cứng: service_role xoá sổ tệp bị chặn');
select is(pg_temp.err($f$update app.setting_def set value = '0' where key = 'file_storage_min_free_gb'$f$), '42501', 'Luật cấu hình: service_role không sửa tham số');

reset role;
select * from finish();
rollback;
