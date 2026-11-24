-- F-24-04 (CAO, ra-soat 00:08): Edge Function file-upload ghi sổ tệp bằng khoá dịch vụ (service_role) nhưng service_role CHƯA có quyền bảng nào
-- trong schema app (chỉ có usage trên schema, mig 012) nên mọi lần tải lên trượt ở bước ghi sổ (HMT_LOI «Chưa ghi được sổ tệp»).
-- Cấp ĐÚNG quyền tối thiểu cho việc Edge Function làm (file-deps.ts), không cấp xoá:
--  - app.stored_file: select (tra lại sau khi sửa), insert (dòng CHO_TAI), update (đổi sang DANG_DUNG hoặc DA_XOA, dọn).
--  - app.setting_def: select (đọc file_storage_min_free_gb cho chặn mềm theo dung lượng trống).
--  - app.current_actor(): trigger khung chung (tg_fill_standard_columns, chạy bằng quyền người gọi) gọi hàm này để điền người sửa; thiếu quyền chạy
--    thì insert/update trượt «permission denied for function current_actor» (bài kiểm 669 bắt được). Hàm chỉ trả auth.uid(), không lộ gì.
-- RLS vẫn bật; service_role bỏ qua RLS theo thiết kế Supabase, nên chỉ Edge Function (khoá nằm ở máy chủ) ghi được. Người đăng nhập thường vẫn không ghi (664).
-- Xoá cứng vẫn bị trigger tg_block_delete chặn (không cấp quyền delete).
select set_config('hmt.migration', 'on', false);

grant select, insert, update on app.stored_file to service_role;
grant select on app.setting_def to service_role;
grant execute on function app.current_actor() to service_role;
