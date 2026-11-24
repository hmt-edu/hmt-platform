-- F-23-46 (a), migration 664: sổ tệp stored_file. Luật: chỉ lưu khoá và cờ; RLS bật, không ai ghi trực tiếp; chặn nộp trùng bằng mã băm (thiết kế mục nén ảnh);
-- loại tệp và trạng thái hợp lệ; tham số mặc định (file_retention_days 90, sau Dừng học 30, dọn chạy thử bật). Dữ liệu giả; khoá ngoại tắt bằng replica chỉ để thử ràng buộc.
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

select ok((select relrowsecurity from pg_class where oid = 'app.stored_file'::regclass), 'Luật RLS: bảng stored_file bật RLS');
select ok(not has_table_privilege('authenticated', 'app.stored_file', 'insert') and not has_table_privilege('authenticated', 'app.stored_file', 'update')
          and not has_table_privilege('authenticated', 'app.stored_file', 'delete'), 'Luật chỉ Edge Function ghi: đăng nhập thường không ghi, sửa, xoá được');
select ok(not has_table_privilege('anon', 'app.stored_file', 'select'), 'Luật RLS: khách chưa đăng nhập không đọc được sổ tệp');
select is((select count(*)::int from pg_policies where schemaname = 'app' and tablename = 'stored_file' and cmd = 'SELECT'), 1, 'Luật đọc: một chính sách đọc theo quyền xem bài giao');

select is((select value from app.setting_def where key = 'file_retention_days'), '90', 'Tham số: hạn giữ mặc định 90 ngày');
select is((select value from app.setting_def where key = 'file_retention_after_leave_days'), '30', 'Tham số: 30 ngày sau Dừng học');
select is((select value from app.setting_def where key = 'file_cleanup_dry_run'), 'true', 'Tham số: việc dọn chạy thử lúc đầu');
select is((select array_agg(value order by key) from app.setting_def where key in ('file_max_mb', 'file_max_count_per_upload', 'file_max_total_mb_per_upload')),
          array['10', '20', '50'], 'Tham số: giới hạn anh chốt 20 MB mỗi tệp, 10 tệp mỗi lần, 50 MB tổng');

select is((select value from app.setting_def where key = 'file_log_keep_days'), '180', 'Tham số: giữ dòng sổ tệp đã xoá 180 ngày rồi dọn');
select is((select count(*)::int from pg_indexes where schemaname = 'app' and tablename = 'stored_file' and indexname ~ '_(idx|uq)$'), 5,
          'Hiệu năng: chỉ giữ 5 chỉ mục cần (bài giao, bài nộp, chặn trùng, tới hạn, dọn dòng đã xoá), mỗi cái có lý do trong migration');

-- Ràng buộc: dựng dòng giả, bỏ kiểm khoá ngoại (replica) chỉ để thử check và chỉ mục duy nhất.
set local session_replication_role = replica;
create temp table ids as select gen_random_uuid() as branch, gen_random_uuid() as cls, gen_random_uuid() as asg, gen_random_uuid() as stu;
grant select on ids to public;
create function pg_temp.ins(p_kind text, p_sha text, p_mime text default 'image/webp', p_student boolean default true, p_status text default 'DANG_DUNG') returns text language plpgsql as $$
begin
  return pg_temp.err(format($f$insert into app.stored_file (storage_key, sha256, kind, branch_id, class_id, assignment_id, student_id, mime_type, size_bytes, delete_after, status)
    select gen_random_uuid()::text, %L, %L, branch, cls, asg, %s, %L, 150000, current_date + 90, %L from ids$f$,
    p_sha, p_kind, case when p_student then 'stu' else 'null::uuid' end, p_mime, p_status));
end $$;
grant execute on all functions in schema pg_temp to public;

select is(pg_temp.ins('BAI_NOP', repeat('a', 64)), null, 'Đúng: một ảnh bài nộp hợp lệ');
select is(pg_temp.ins('BAI_NOP', repeat('a', 64)), '23505', 'Luật chặn nộp trùng: cùng em, cùng bài, cùng mã băm bị chặn');
select is(pg_temp.ins('BAI_NOP', repeat('b', 64)), null, 'Đúng: mã băm khác thì nộp được');
select is(pg_temp.ins('BAI_NOP', repeat('a', 64), 'image/webp', true, 'DA_XOA'), null, 'Đúng: tệp đã xoá không cản nộp lại cùng ảnh');
select is(pg_temp.ins('BAI_NOP', 'khong-phai-ma-bam'), '23514', 'Chặn: mã băm sai định dạng');
select is(pg_temp.ins('BAI_NOP', repeat('c', 64), 'application/zip'), '23514', 'Chặn: loại tệp ngoài JPG, PNG, WebP, HEIC, PDF');
select is(pg_temp.ins('BAI_NOP', repeat('d', 64), 'image/webp', false), '23514', 'Chặn: bài nộp phải có học sinh chủ ảnh');
select is(pg_temp.ins('DINH_KEM_GV', repeat('e', 64), 'image/webp', true), '23514', 'Chặn: tệp giáo viên đính kèm không gắn học sinh');
select is(pg_temp.ins('DINH_KEM_GV', repeat('e', 64), 'image/webp', false), null, 'Đúng: tệp giáo viên đính kèm không có học sinh');
select is(pg_temp.ins('BAI_NOP', repeat('f', 64), 'image/webp', true, 'XOA_TAY'), '23514', 'Chặn: trạng thái ngoài CHO_TAI, DANG_DUNG, DA_XOA');
select * from finish();
rollback;
