-- P3b1: ma trận quyền phiên bản 3 (15 ô cho Tuyển sinh, CSKH; anh Trường duyệt 17/10).
-- Phiên bản 4 (021) đã đổi Phụ huynh, Học sinh sau đó: các bài về hai phân hệ này kiểm giá trị sau phiên bản 4.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
-- Migration 182 (QT-05): lưu ma trận qua API chỉ khi tham số permission_matrix_edit_enabled bật; các bài này thử luật lưu nên bật trong giao dịch của bài (hoàn tác khi kết thúc).
update app.setting_def set value = 'true' where key = 'permission_matrix_edit_enabled';

create function pg_temp.perms(p_role text, p_modules text[]) returns text[] language sql as $$
  select array_agg(module_code || ':' || action_code || ':' || scope_code order by module_code, action_code)
    from app.permission where role_code = p_role and is_active and module_code = any (p_modules);
$$;

select is((select changed_count from app.permission_version where version_no = 3), 15, 'Phiên bản 3 đổi đúng 15 ô');
select is((select note from app.permission_version where version_no = 3),
          'Duyệt trên Lead, Cơ hội, Phụ huynh, Học sinh = gộp trùng (R-CRM-22)', 'Phiên bản 3 có ghi chú: Duyệt = gộp trùng');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id where v.version_no = 3),
          15, 'Phiên bản 3 liệt kê đủ 15 ô');
select is((select count(distinct to_scope)::int from app.permission_change c join app.permission_version v on v.id = c.version_id
           where v.version_no = 3), 1, 'Cả 15 ô cùng một phạm vi');
select is((select min(to_scope) from app.permission_change c join app.permission_version v on v.id = c.version_id where v.version_no = 3),
          'CO_SO', 'Phạm vi cơ sở mình');

select is(pg_temp.perms('SALES', array['LEAD', 'OPPORTUNITY']),
          array['LEAD:DUYET:CO_SO', 'LEAD:GIAO_VIEC:CO_SO', 'LEAD:SUA:CO_SO', 'LEAD:TAO:CO_SO', 'LEAD:XEM:CO_SO',
                'OPPORTUNITY:DUYET:CO_SO', 'OPPORTUNITY:GIAO_VIEC:CO_SO', 'OPPORTUNITY:SUA:CO_SO', 'OPPORTUNITY:TAO:CO_SO',
                'OPPORTUNITY:XEM:CO_SO'], 'Tuyển sinh: Lead, Cơ hội có thêm Giao việc và Duyệt (gộp trùng)');
select is(pg_temp.perms('SALES', array['PARENT', 'STUDENT']),
          array['PARENT:DUYET:CO_SO', 'PARENT:SUA:CO_SO', 'PARENT:XEM:TOAN_HE_THONG',
                'STUDENT:DUYET:CO_SO', 'STUDENT:SUA:CO_SO', 'STUDENT:XEM:TOAN_HE_THONG'],
          'Tuyển sinh: Phụ huynh, Học sinh có Duyệt (gộp trùng); phiên bản 4 bỏ Tạo, Xem toàn hệ thống');
select is(pg_temp.perms('SALES', array['STUDENT_TEST']),
          array['STUDENT_TEST:GIAO_VIEC:CO_SO', 'STUDENT_TEST:HUY:CO_SO', 'STUDENT_TEST:SUA:CO_SO', 'STUDENT_TEST:TAO:CO_SO', 'STUDENT_TEST:XEM:CO_SO'],
          'Tuyển sinh: Kiểm tra đầu vào có thêm Huỷ');
select is(pg_temp.perms('CSKH', array['LEAD', 'OPPORTUNITY']),
          array['LEAD:DUYET:CO_SO', 'LEAD:GIAO_VIEC:CO_SO', 'LEAD:SUA:CO_SO', 'LEAD:TAO:CO_SO', 'LEAD:XEM:CO_SO',
                'OPPORTUNITY:DUYET:CO_SO', 'OPPORTUNITY:GIAO_VIEC:CO_SO', 'OPPORTUNITY:SUA:CO_SO', 'OPPORTUNITY:TAO:CO_SO',
                'OPPORTUNITY:XEM:CO_SO'], 'CSKH: Lead, Cơ hội có thêm Giao việc và Duyệt (gộp trùng)');
select is(pg_temp.perms('CSKH', array['PARENT', 'STUDENT']),
          array['PARENT:DUYET:CO_SO', 'PARENT:SUA:CO_SO', 'PARENT:XEM:TOAN_HE_THONG',
                'STUDENT:DUYET:CO_SO', 'STUDENT:SUA:CO_SO', 'STUDENT:XEM:TOAN_HE_THONG'],
          'CSKH: Phụ huynh, Học sinh có Duyệt (gộp trùng); phiên bản 4 bỏ Tạo, Xem toàn hệ thống');
select is(pg_temp.perms('CSKH', array['STUDENT_TEST']),
          array['STUDENT_TEST:GIAO_VIEC:CO_SO', 'STUDENT_TEST:HUY:CO_SO', 'STUDENT_TEST:SUA:CO_SO', 'STUDENT_TEST:TAO:CO_SO', 'STUDENT_TEST:XEM:CO_SO'],
          'CSKH: Kiểm tra đầu vào có thêm Giao việc và Huỷ');

-- Vai trò khác không đổi.
select is(pg_temp.perms('TEACHER', array['LEAD', 'OPPORTUNITY', 'PARENT', 'STUDENT']), array['STUDENT:XEM:DUOC_PHAN_CONG'], 'Giáo viên không đổi');
select is(pg_temp.perms('TA', array['LEAD', 'OPPORTUNITY', 'PARENT', 'STUDENT']), array['STUDENT:XEM:DUOC_PHAN_CONG'], 'Trợ giảng không đổi');
select is((select count(*)::int from app.permission where role_code = 'ACCOUNTANT' and is_active
           and module_code in ('LEAD', 'OPPORTUNITY')), 0, 'Kế toán không có quyền ở Lead, Cơ hội (Phụ huynh: xem 021)');
select is((select count(*)::int from app.permission where role_code = 'BRANCH_MANAGER' and is_active and action_code = 'DUYET'
           and module_code in ('LEAD', 'OPPORTUNITY', 'PARENT', 'STUDENT')), 4, 'Trưởng cơ sở vẫn có Duyệt (gộp trùng) cả bốn phân hệ');
select is((select count(*)::int from app.permission where role_code = 'ADMIN' and is_active and action_code = 'DUYET'
           and module_code in ('LEAD', 'OPPORTUNITY', 'PARENT', 'STUDENT')), 4, 'ADMIN vẫn có Duyệt (gộp trùng) cả bốn phân hệ');

-- Hàm lưu: ghi chú tuỳ chọn, lời gọi hai tham số vẫn chạy. Số phiên bản tính theo phiên bản hiện hành (các migration sau thêm phiên bản).
create temp table ver0 as select app.permission_current_version() as v;
select is(app.save_permission_matrix(app.permission_current_version(),
          jsonb_build_array(jsonb_build_object('role', 'TEACHER', 'module', 'HOLIDAY', 'action', 'XEM', 'scope', 'CO_SO'))), (select v + 1 from ver0),
          'Lưu hai tham số (không ghi chú) vẫn chạy: phiên bản kế tiếp');
select is((select note from app.permission_version where version_no = (select v + 1 from ver0)), null, 'Không ghi chú thì để trống');
select is(app.save_permission_matrix(app.permission_current_version(),
          jsonb_build_array(jsonb_build_object('role', 'TEACHER', 'module', 'HOLIDAY', 'action', 'XEM', 'scope', null)), '  Thu hồi thử  '), (select v + 2 from ver0),
          'Lưu có ghi chú: phiên bản kế tiếp nữa');
select is((select note from app.permission_version where version_no = (select v + 2 from ver0)), 'Thu hồi thử', 'Ghi chú được cắt khoảng trắng đầu cuối');

select * from finish();
rollback;
