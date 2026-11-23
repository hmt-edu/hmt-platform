-- A-23-27 (anh Trường chốt 24/11/2026 00:56, Chat duyệt 01:08): bắt xác thực hai bước CHỈ cho vai ADMIN; Kế toán (ACCOUNTANT) không còn bắt buộc. CAO (quyền, bảo mật).
-- Làm gì: đặt cờ app.role.require_mfa = false cho ACCOUNTANT. Cờ này là «vai trò nào thuộc diện bắt hai bước» (D41, migration 472): bắt thật chỉ khi tham số mfa_required_enabled bật,
--   qua một hàm duy nhất app.mfa_required_for_role. Không đổi hàm nào, không đổi giá trị tham số mfa_required_enabled (giữ TẮT; công tắc do Admin bật ở QT-09 sau khi Tester ĐẠT, prod bật riêng).
-- Hệ quả khi tham số bật: ADMIN đăng nhập mật khẩu chỉ ở aal1, chưa có quyền cho tới khi nhập mã TOTP (aal2), kể cả máy đã có thiết bị (Supabase không có «nhớ thiết bị»);
--   ADMIN chưa có thiết bị thì vào luồng đăng ký lần đầu (/thiet-lap-hai-buoc). Kế toán đăng nhập mật khẩu là đủ, không có bước hai bước.
-- Tham số tắt (mặc định): không đổi hành vi nào. Luật: R-HT, docs/nghiep-vu/phan-quyen.md mục «Hai bước Admin».
-- Hook token (app.custom_access_token_hook) giữ nguyên: hmt_mfa_optional chỉ còn cho vai có cờ (Admin) khi tham số tắt; Kế toán không còn mục «Hai bước» ở Hồ sơ.
select set_config('hmt.migration', 'on', false);
update app.role set require_mfa = false where code = 'ACCOUNTANT';
select set_config('hmt.migration', '', false);
