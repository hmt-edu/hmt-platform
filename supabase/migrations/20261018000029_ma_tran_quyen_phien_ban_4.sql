-- Ma trận quyền phiên bản 4 (anh Trường duyệt TRƯỚC / SAU 18/10): 17 ô trên Phụ huynh, Học sinh theo R-CRM-26, 27, 29.
--   - R-CRM-27: không có thao tác Tạo tay phụ huynh, học sinh (hồ sơ sinh trong hàm nghiệp vụ): bỏ Tạo của Tuyển sinh,
--     CSKH, Trưởng cơ sở, Admin trên Phụ huynh và Học sinh (8 ô).
--   - R-CRM-29: chỉ Admin xuất file hai phân hệ này: bỏ Xuất của Trưởng cơ sở (2 ô).
--   - R-CRM-26: hồ sơ phụ huynh, học sinh dùng chung toàn hệ thống: Xem toàn hệ thống cho Tuyển sinh, CSKH, Trưởng cơ sở
--     (Sửa, Duyệt giữ cơ sở mình) (6 ô).
--   - Kế toán thêm Xem Phụ huynh toàn hệ thống (1 ô; đã có Xem Học sinh).
-- Nạp bằng hàm lưu của PR 6d nên là phiên bản 4, có danh sách từng ô và ghi chú. Phiên bản hiện hành trước đó là 3.

select set_config('hmt.migration', 'on', false);

select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', v.role, 'module', v.module, 'action', v.action, 'scope', v.scope))
   from (values
     -- Bỏ Tạo (R-CRM-27)
     ('SALES', 'PARENT', 'TAO', null), ('SALES', 'STUDENT', 'TAO', null),
     ('CSKH', 'PARENT', 'TAO', null), ('CSKH', 'STUDENT', 'TAO', null),
     ('BRANCH_MANAGER', 'PARENT', 'TAO', null), ('BRANCH_MANAGER', 'STUDENT', 'TAO', null),
     ('ADMIN', 'PARENT', 'TAO', null), ('ADMIN', 'STUDENT', 'TAO', null),
     -- Bỏ Xuất của Trưởng cơ sở (R-CRM-29)
     ('BRANCH_MANAGER', 'PARENT', 'XUAT', null), ('BRANCH_MANAGER', 'STUDENT', 'XUAT', null),
     -- Xem toàn hệ thống (R-CRM-26)
     ('SALES', 'PARENT', 'XEM', 'TOAN_HE_THONG'), ('SALES', 'STUDENT', 'XEM', 'TOAN_HE_THONG'),
     ('CSKH', 'PARENT', 'XEM', 'TOAN_HE_THONG'), ('CSKH', 'STUDENT', 'XEM', 'TOAN_HE_THONG'),
     ('BRANCH_MANAGER', 'PARENT', 'XEM', 'TOAN_HE_THONG'), ('BRANCH_MANAGER', 'STUDENT', 'XEM', 'TOAN_HE_THONG'),
     -- Kế toán xem Phụ huynh
     ('ACCOUNTANT', 'PARENT', 'XEM', 'TOAN_HE_THONG')
   ) as v(role, module, action, scope)),
  'R-CRM-26, 27, 29: hồ sơ phụ huynh, học sinh dùng chung toàn hệ thống, không Tạo tay, chỉ Admin Xuất');

select set_config('hmt.migration', '', false);
