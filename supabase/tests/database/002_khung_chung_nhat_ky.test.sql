-- Luật khung chung và nhật ký thao tác (docs/nghiep-vu/nen-du-lieu.md).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Trả về mã lỗi HMT_* (HINT) của câu lệnh, hoặc SQLSTATE nếu lỗi khác, NULL nếu chạy được.
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;

-- ---------- Tự điền người, giờ tạo/sửa ----------
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select app.catalog_add_item('SUBJECT', 'TEST_MON', 'Môn thử');
select is((select created_by from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON'),
          '11111111-1111-1111-1111-111111111111'::uuid,
          'Tạo mới: tự điền người tạo từ người đăng nhập');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
update app.catalog_item set name = 'Môn thử đổi tên', created_by = null
 where catalog_code = 'SUBJECT' and code = 'TEST_MON';
select is((select created_by from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON'),
          '11111111-1111-1111-1111-111111111111'::uuid,
          'Sửa: không đổi được người tạo');
select is((select updated_by from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON'),
          '22222222-2222-2222-2222-222222222222'::uuid,
          'Sửa: tự điền người sửa');

-- ---------- Nhật ký chỉ ghi trường đổi ----------
select is((select changes from app.audit_log
            where record_id = (select id from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON')
              and action = 'U' order by id desc limit 1),
          '{"name": ["Môn thử", "Môn thử đổi tên"]}'::jsonb,
          'Nhật ký sửa chỉ ghi trường đổi (cũ → mới), không ghi updated_*');

select is((select actor from app.audit_log
            where record_id = (select id from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON')
              and action = 'U' order by id desc limit 1),
          '22222222-2222-2222-2222-222222222222'::uuid,
          'Nhật ký ghi đúng người sửa');

select is((select changes from app.audit_log
            where record_id = (select id from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON')
              and action = 'I'),
          null,
          'Nhật ký tạo mới không chép dữ liệu');

select is((select count(*)::int from app.audit_log
            where record_id = (select id from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON')),
          2, 'Mỗi thao tác một dòng nhật ký (1 tạo + 1 sửa)');

-- Sửa mà không đổi gì thật thì không ghi nhật ký.
update app.catalog_item set name = name where catalog_code = 'SUBJECT' and code = 'TEST_MON';
select is((select count(*)::int from app.audit_log
            where record_id = (select id from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON')),
          2, 'Sửa không đổi giá trị thì không ghi nhật ký');

-- ---------- Nhật ký không sửa, không xoá được ----------
select is(pg_temp.err('update app.audit_log set actor = null'), 'HMT_NHAT_KY_CHI_THEM',
          'Không sửa được nhật ký (kể cả chủ DB)');
select is(pg_temp.err('delete from app.audit_log'), 'HMT_NHAT_KY_CHI_THEM',
          'Không xoá được nhật ký (kể cả chủ DB)');
select is(pg_temp.err('truncate app.audit_log'), 'HMT_NHAT_KY_CHI_THEM',
          'Không truncate được nhật ký');

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(pg_temp.err('select count(*) from app.audit_log'), '42501',
          'Người dùng qua API không đọc được nhật ký (bước 2)');
select is(pg_temp.err('insert into app.audit_log (table_id, record_id, action) values (1, gen_random_uuid(), ''I'')'), '42501',
          'Người dùng qua API không tự ghi được nhật ký');
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------- Chặn xoá ----------
select is(pg_temp.err($$delete from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TEST_MON'$$),
          'HMT_KHONG_XOA', 'Không xoá được bản ghi (huỷ/Ngừng thay cho xoá)');

-- ---------- RLS bật cho mọi bảng trong schema app ----------
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'app' and c.relkind = 'r' and not c.relrowsecurity),
          0, 'Mọi bảng trong schema app đều bật RLS');

select * from finish();
rollback;
