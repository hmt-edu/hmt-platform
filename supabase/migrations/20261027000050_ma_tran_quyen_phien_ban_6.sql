-- Ma trận quyền phiên bản 6 (QĐ-Đ204; Đ202): Sale và CSKH có quyền Huỷ đơn hàng (phạm vi cơ sở).
-- So với phiên bản 5: ĐÚNG HAI Ô đổi: (SALES, SALES_ORDER, HUY) và (CSKH, SALES_ORDER, HUY) từ Không sang Có, phạm vi CO_SO.
-- Vì sao hai ô mà không phải một: Sale và CSKH là hai vai trò, mỗi vai một ô của ma trận. Việc giới hạn "chỉ huỷ đơn Nháp do chính
-- mình lập" nằm trong hàm huỷ đơn của P5a-DB1b, không nằm trong ma trận. Duyệt và Xuất không đổi.
select set_config('hmt.migration', 'on', false);

select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', v.role, 'module', v.module, 'action', v.action, 'scope', v.scope))
   from (values
     ('SALES', 'SALES_ORDER', 'HUY', 'CO_SO'), ('CSKH', 'SALES_ORDER', 'HUY', 'CO_SO')
   ) as v(role, module, action, scope)),
  'Đ204: Sale và CSKH có quyền Huỷ đơn hàng (cơ sở mình); hàm huỷ đơn chỉ cho huỷ đơn Nháp do chính mình lập');

select set_config('hmt.migration', '', false);
