-- Migration 458 (Code D, 18/11/2026): sửa T8 của Soát (CAO). Chat duyệt 18/11 15:35: bỏ ngoại lệ «Admin tự duyệt».
-- Luật: R-HT-01 (Admin không duyệt tiền), R-CS-07 (người tạo không tự duyệt bước quản lý của chính mình, kể cả Admin; giống phiếu thu).
-- Chỉ đổi hai hàm duyệt bước quản lý của hoàn phí (migration 231) và dừng học (migration 232): bỏ điều kiện «trừ ADMIN». Mọi luật khác giữ nguyên.

-- app.approve_refund_manager: quản lý cơ sở duyệt bước đầu (R-CS-07). Ai: Ghi danh · Duyệt ở cơ sở của yêu cầu; người tạo (kể cả Admin) không tự duyệt.
create or replace function app.approve_refund_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['CHO_QL']);
  perform app.assert_can('ENROLLMENT', 'DUYET', r.branch_id);
  perform app.require_feature('HOAN_PHI', r.branch_id);
  -- Luật R-CS-07, R-HT-01 (T8): người tạo không tự duyệt, KHÔNG có ngoại lệ cho Admin.
  if r.created_by = (select auth.uid()) then
    perform app.raise_error('HMT_HOAN_PHI_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  update app.refund_request set status_code = 'CHO_KE_TOAN', manager_by = (select auth.uid()), manager_at = now() where id = r.id;
end;
$$;

-- app.approve_stop_manager: như trên cho dừng học (migration 232).
create or replace function app.approve_stop_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_QL']);
  perform app.assert_can('ENROLLMENT', 'DUYET', s.branch_id);
  perform app.require_feature('DUNG_HOC', s.branch_id);
  -- Luật R-CS-07, R-HT-01 (T8): người tạo không tự duyệt, KHÔNG có ngoại lệ cho Admin.
  if s.created_by = (select auth.uid()) then
    perform app.raise_error('HMT_DUNG_HOC_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  update app.enrollment_stop set status_code = 'CHO_KE_TOAN', manager_by = (select auth.uid()), manager_at = now() where id = s.id;
end;
$$;
