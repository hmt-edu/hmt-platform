-- F-23-23 (anh Trường chốt 23/11/2026 16:49): tên hiển thị của vai trò SALES đổi từ «Tuyển sinh» thành «Tư vấn tuyển sinh». Chỉ đổi tên hiển thị; mã SALES, quyền, cổng không đổi.
-- Chỉ đổi khi tên còn là giá trị mặc định cũ (Admin đã tự đặt tên khác ở QT-04 thì giữ). Mức rủi ro thấp (không tiền, không quyền).
select set_config('hmt.migration', 'on', false);
update app.role set name = 'Tư vấn tuyển sinh' where code = 'SALES' and name = 'Tuyển sinh';
