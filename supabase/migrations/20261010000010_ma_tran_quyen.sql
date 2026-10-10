-- GĐ0 bước 3: nạp ma trận quyền mặc định từ docs/seed/old_permission_matrix.csv, đã sửa theo
-- chốt với anh Trường 10/10/2026 (đối chiếu: docs/nghiep-vu/phan-quyen.md):
-- - "Delete" cũ → Huỷ; phạm vi cũ BRANCH → Cơ sở mình, ALL → Toàn hệ thống.
-- - L1: Trưởng cơ sở được Xuất file mọi phân hệ trong cơ sở (mỗi lần xuất ghi nhật ký xuất file).
-- - L2: CSKH giữ quyền lead, cơ hội như cũ.
-- - Giáo viên, trợ giảng: phạm vi Được phân công; chỉ thấy, chấm phiếu test được giao (SALES, BM giao).
-- - Thêm TA (= giáo viên, R-GV-09), STUDENT (học tập, chính mình); PARENT chưa cấp quyền (GĐ4).
-- - Phân hệ Quản trị chỉ ADMIN.
-- - Tách quyền tiền (R-TIEN-01): chỉ ACCOUNTANT Duyệt phiếu thu (RECEIPT) và kế toán (ACCOUNTING:
--   khoản tiền vào, đảo khoản, phiếu chi); ADMIN, Trưởng cơ sở không duyệt. Kế toán vắng: Admin tạm gán
--   vai trò ACCOUNTANT cho người làm thay (có nhật ký). Trưởng cơ sở chỉ Xem phân hệ Kế toán.
-- - Phiếu tái tục (UPSALE) không có bước Duyệt; Trưởng cơ sở chỉ Xem, Giao việc. Đơn hàng sinh từ tái tục
--   thì duyệt như đơn thường (SALES_ORDER).

select set_config('hmt.migration', 'on', false);

-- ADMIN: mọi phân hệ, mọi hành động, toàn hệ thống,
-- trừ Duyệt tiền (R-TIEN-01, chỉ Kế toán) và Duyệt phiếu tái tục (không có bước này).
insert into app.permission (role_code, module_code, action_code, scope_code)
select 'ADMIN', m.code, a.code, 'TOAN_HE_THONG'
  from app.catalog_item m cross join app.catalog_item a
 where m.catalog_code = 'PERM_MODULE' and a.catalog_code = 'PERM_ACTION'
   and not (m.code in ('RECEIPT', 'ACCOUNTING', 'UPSALE') and a.code = 'DUYET');

-- BRANCH_MANAGER: mọi việc trong cơ sở (cả Xuất file, Duyệt), trừ Quản trị và Học tập.
insert into app.permission (role_code, module_code, action_code, scope_code)
select 'BRANCH_MANAGER', m.code, a.code, 'CO_SO'
  from app.catalog_item m cross join app.catalog_item a
 where m.catalog_code = 'PERM_MODULE' and a.catalog_code = 'PERM_ACTION'
   and m.code not in ('ADMIN', 'LEARNING')
   -- Luật R-TIEN-01: không Duyệt phiếu thu (chỉ Kế toán duyệt).
   and not (m.code = 'RECEIPT' and a.code = 'DUYET')
   -- Phân hệ Kế toán: chỉ Xem.
   and not (m.code = 'ACCOUNTING' and a.code <> 'XEM')
   -- Phiếu tái tục: chỉ Xem, Giao việc.
   and not (m.code = 'UPSALE' and a.code not in ('XEM', 'GIAO_VIEC'));

-- Các vai trò còn lại: liệt kê từng dòng.
insert into app.permission (role_code, module_code, action_code, scope_code)
select v.role_code, v.module_code, a.action_code, v.scope_code
  from (values
    -- SALES (cơ sở mình)
    ('SALES', 'LEAD', 'CO_SO', '{XEM,TAO,SUA}'),
    ('SALES', 'OPPORTUNITY', 'CO_SO', '{XEM,TAO,SUA}'),
    ('SALES', 'STUDENT_TEST', 'CO_SO', '{XEM,TAO,SUA,GIAO_VIEC}'),
    ('SALES', 'PARENT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('SALES', 'STUDENT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('SALES', 'QUOTATION', 'CO_SO', '{XEM,TAO,SUA,XUAT}'),
    ('SALES', 'SALES_ORDER', 'CO_SO', '{XEM,TAO,SUA}'),
    ('SALES', 'RECEIPT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('SALES', 'UPSALE', 'CO_SO', '{XEM,TAO,SUA,XUAT}'),
    ('SALES', 'ENROLLMENT', 'CO_SO', '{XEM}'),
    ('SALES', 'CLASS', 'CO_SO', '{XEM}'),
    ('SALES', 'SESSION', 'CO_SO', '{XEM}'),
    ('SALES', 'ATTENDANCE', 'CO_SO', '{XEM}'),
    ('SALES', 'TICKET', 'CO_SO', '{XEM,TAO,SUA}'),
    -- CSKH (cơ sở mình); giữ lead, cơ hội như cũ (L2)
    ('CSKH', 'LEAD', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'OPPORTUNITY', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'STUDENT_TEST', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'PARENT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'STUDENT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'QUOTATION', 'CO_SO', '{XEM,TAO,SUA,XUAT}'),
    ('CSKH', 'SALES_ORDER', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'RECEIPT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'UPSALE', 'CO_SO', '{XEM,TAO,SUA,XUAT}'),
    ('CSKH', 'ENROLLMENT', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'CLASS', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'SESSION', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'ATTENDANCE', 'CO_SO', '{XEM,TAO,SUA}'),
    ('CSKH', 'TICKET', 'CO_SO', '{XEM,TAO,SUA}'),
    -- ACCOUNTANT (toàn hệ thống)
    ('ACCOUNTANT', 'RECEIPT', 'TOAN_HE_THONG', '{XEM,TAO,SUA,XUAT,DUYET}'),
    ('ACCOUNTANT', 'SALES_ORDER', 'TOAN_HE_THONG', '{XEM,XUAT}'),
    ('ACCOUNTANT', 'ACCOUNTING', 'TOAN_HE_THONG', '{XEM,XUAT,DUYET}'),
    ('ACCOUNTANT', 'STUDENT', 'TOAN_HE_THONG', '{XEM}'),
    ('ACCOUNTANT', 'REPORT', 'TOAN_HE_THONG', '{XEM,XUAT}'),
    ('ACCOUNTANT', 'TICKET', 'TOAN_HE_THONG', '{XEM,DUYET}'),
    -- TEACHER, TA (được phân công; R-GV-08: không tạo dòng điểm danh, không đổi tình trạng buổi)
    ('TEACHER', 'STUDENT_TEST', 'DUOC_PHAN_CONG', '{XEM,SUA}'),
    ('TEACHER', 'STUDENT', 'DUOC_PHAN_CONG', '{XEM}'),
    ('TEACHER', 'ENROLLMENT', 'DUOC_PHAN_CONG', '{XEM}'),
    ('TEACHER', 'CLASS', 'DUOC_PHAN_CONG', '{XEM}'),
    ('TEACHER', 'SESSION', 'DUOC_PHAN_CONG', '{XEM,SUA}'),
    ('TEACHER', 'ATTENDANCE', 'DUOC_PHAN_CONG', '{XEM,SUA}'),
    ('TEACHER', 'GRADING', 'DUOC_PHAN_CONG', '{XEM,TAO,SUA}'),
    ('TEACHER', 'TICKET', 'DUOC_PHAN_CONG', '{XEM,TAO}'),
    ('TA', 'STUDENT_TEST', 'DUOC_PHAN_CONG', '{XEM,SUA}'),
    ('TA', 'STUDENT', 'DUOC_PHAN_CONG', '{XEM}'),
    ('TA', 'ENROLLMENT', 'DUOC_PHAN_CONG', '{XEM}'),
    ('TA', 'CLASS', 'DUOC_PHAN_CONG', '{XEM}'),
    ('TA', 'SESSION', 'DUOC_PHAN_CONG', '{XEM,SUA}'),
    ('TA', 'ATTENDANCE', 'DUOC_PHAN_CONG', '{XEM,SUA}'),
    ('TA', 'GRADING', 'DUOC_PHAN_CONG', '{XEM,TAO,SUA}'),
    ('TA', 'TICKET', 'DUOC_PHAN_CONG', '{XEM,TAO}'),
    -- STUDENT (chính mình; dùng thật từ GĐ4)
    ('STUDENT', 'LEARNING', 'CHINH_MINH', '{XEM,SUA}'),
    ('STUDENT', 'GRADING', 'CHINH_MINH', '{XEM}')
  ) as v (role_code, module_code, scope_code, actions)
 cross join lateral unnest(v.actions::text[]) as a (action_code);

select set_config('hmt.migration', '', false);
