-- Q-154 (b): app.order_flexible_note chỉ là hàm trợ giúp bên trong ba hàm tạo, sửa đơn (create_order_from_opportunity,
-- create_order_from_quotation, edit_order). Cả ba đều security definer nên chạy bằng quyền chủ hàm, không cần cấp thực thi cho
-- người dùng đăng nhập. Thu lại quyền để không ai gọi trực tiếp qua API (hàm đọc dòng đơn của bất kỳ đơn nào, không kiểm quyền).
revoke execute on function app.order_flexible_note(uuid, boolean) from public, anon, authenticated;
