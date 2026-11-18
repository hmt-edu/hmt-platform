-- Migration 455 (Code D, 18/11/2026): sửa Q1 của Soát (CAO). Luật R-HT-01: Admin không duyệt tiền; chỉ người có Kế toán · Duyệt (vai trò Kế toán) duyệt.
-- Lỗ: hiện chỉ là DỮ LIỆU ma trận. Khi cờ permission_matrix_edit_enabled bật, Admin lưu được ô ADMIN × ACCOUNTING × DUYET = Toàn hệ thống rồi tự gọi
-- approve_receipt_accounting (phiếu sang DA_DUYET, accountant_approved_by = Admin).
-- Chốt chặn trong DB: trigger trên bảng quyền chặn mọi đường ghi (hàm lưu ma trận, set_permission, SQL) ô ADMIN × ACCOUNTING × DUYET đang bật.
-- Không đổi: việc Admin tạm gán vai trò Kế toán cho người khác hoặc cho mình khi Kế toán vắng là cố ý (R-HT-01, bài 007), không nằm trong ma trận ADMIN.

create or replace function app.tg_permission_admin_no_money_approval()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Luật R-HT-01: vai trò ADMIN không bao giờ có quyền Kế toán · Duyệt (duyệt phiếu thu, hoàn tác, phiếu chi).
  if new.role_code = 'ADMIN' and new.module_code = 'ACCOUNTING' and new.action_code = 'DUYET' and new.is_active then
    perform app.raise_error('HMT_ADMIN_KHONG_DUYET_TIEN',
      'Vai trò Admin không được cấp quyền Kế toán · Duyệt (Admin không duyệt tiền). Gán vai trò Kế toán cho người cụ thể khi cần.');
  end if;
  return new;
end;
$$;
create trigger permission_admin_no_money_approval before insert or update on app.permission
  for each row execute function app.tg_permission_admin_no_money_approval();
