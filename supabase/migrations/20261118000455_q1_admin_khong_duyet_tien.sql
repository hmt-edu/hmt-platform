-- Migration 455 (Code D, 18/11/2026): sửa Q1 và Q1b của Soát (CAO). Luật R-HT-01: Admin không duyệt tiền; bước kế toán chỉ Kế toán duyệt; R-TIEN-01: hai người duyệt khác nhau.
-- Q1: cờ permission_matrix_edit_enabled bật thì Admin lưu được ô ADMIN × ACCOUNTING × DUYET rồi tự duyệt phiếu thu.
-- Q1b (Soát tái hiện 15:45): trigger chỉ chặn vai trò ADMIN nên Admin cấp được Kế toán · Duyệt cho BRANCH_MANAGER, rồi một người duyệt cả hai bước.
-- Chốt chặn trong DB, hai lớp:
--   (1) DANH SÁCH CHO PHÉP: ô ACCOUNTING × DUYET đang bật chỉ được thuộc vai trò ACCOUNTANT (mọi đường ghi bảng quyền: hàm lưu ma trận, set_permission, SQL).
--   (2) Cùng một người không duyệt cả hai bước: trigger trên phiếu thu, yêu cầu hoàn phí, yêu cầu dừng học chặn khi người duyệt kế toán trùng người duyệt quản lý.
-- Không đổi: Admin tạm gán vai trò Kế toán cho người cụ thể (R-HT-01, bài 007) vẫn đúng; vai trò đó là ACCOUNTANT nên qua danh sách cho phép.

create or replace function app.tg_permission_admin_no_money_approval()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Luật R-HT-01 (Q1, Q1b): chỉ vai trò ACCOUNTANT được có Kế toán · Duyệt (duyệt phiếu thu, hoàn tác, phiếu chi).
  if new.module_code = 'ACCOUNTING' and new.action_code = 'DUYET' and new.is_active and new.role_code <> 'ACCOUNTANT' then
    perform app.raise_error('HMT_CHI_KE_TOAN_DUYET_TIEN',
      'Chỉ vai trò Kế toán được có quyền Kế toán · Duyệt (Admin và các vai trò khác không duyệt tiền). Gán vai trò Kế toán cho người cụ thể khi cần.');
  end if;
  return new;
end;
$$;
create trigger permission_admin_no_money_approval before insert or update on app.permission
  for each row execute function app.tg_permission_admin_no_money_approval();

-- (2) Hai bước duyệt phải là hai người khác nhau (R-TIEN-01). Phiếu thu: bước quản lý có thể không có người (tự duyệt theo tuyến), khi đó không so.
create or replace function app.tg_receipt_two_approvers()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.accountant_approved_by is not null and new.manager_approved_by is not null
     and new.accountant_approved_by = new.manager_approved_by then
    perform app.raise_error('HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'Một người không duyệt cả bước quản lý và bước kế toán của cùng một phiếu thu.');
  end if;
  return new;
end;
$$;
create trigger receipt_two_approvers before insert or update on app.receipt
  for each row execute function app.tg_receipt_two_approvers();

create or replace function app.tg_refund_two_approvers()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.accountant_by is not null and new.manager_by is not null and new.accountant_by = new.manager_by then
    perform app.raise_error('HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'Một người không duyệt cả bước quản lý và bước kế toán của cùng một yêu cầu.');
  end if;
  return new;
end;
$$;
create trigger refund_request_two_approvers before insert or update on app.refund_request
  for each row execute function app.tg_refund_two_approvers();
create trigger enrollment_stop_two_approvers before insert or update on app.enrollment_stop
  for each row execute function app.tg_refund_two_approvers();
