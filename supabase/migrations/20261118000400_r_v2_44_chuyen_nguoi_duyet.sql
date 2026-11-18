-- R-V2-44 «Chuyển người duyệt» (Code C, 18/11/2026; anh chốt qua Chat 10:10 ngày 18/11): Admin đổi người được giao duyệt bước quản lý của đơn đã trình (DA_TRINH)
-- hoặc phiếu thu đã gửi (DA_GUI) khi người đã chốt lúc trình không duyệt được. Admin KHÔNG duyệt, KHÔNG từ chối thay (R-HT-01: Admin không duyệt tiền).
-- Chốt: (a) giữ điều kiện «quá hạn xử lý» cùng với khoá và nghỉ; (b) tham số approver_reassign_after_hours mặc định 48. Cờ approver_reassign_enabled TẮT mặc định.
-- Hàm: app.reassign_approver (thao tác), app.list_approver_candidates (người nhận hợp lệ cho hộp chọn). Mức CAO (tiền, quyền).

select set_config('hmt.migration', 'on', false);

-- 1. Cờ và tham số (không viết cứng số trong code).
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('approver_reassign_enabled', 'Cho phép Admin «Chuyển người duyệt»', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-V2-44',
   'Tắt: Admin không chuyển được người duyệt bước quản lý của đơn và phiếu thu. Bật: chỉ khi người đã chốt bị khoá, không còn quyền Duyệt hoặc quá hạn xử lý.'),
  ('approver_reassign_after_hours', 'Quá hạn xử lý của người duyệt (giờ)', 'INT', 'giờ', 1, 720, '48', true, 'BAN_HANG', 'R-V2-44',
   'Người duyệt đã chốt còn hoạt động nhưng để chứng từ chờ quá số giờ này (tính từ lúc trình hoặc lần chuyển gần nhất) thì Admin chuyển người duyệt được.');

-- 2. Danh mục lý do chuyển.
insert into app.catalog (code, name, kind, description, sort_order) values
  ('REASSIGN_REASON', 'Lý do chuyển người duyệt', 'MO',
   'Chọn khi Admin chuyển người duyệt (R-V2-44). Luôn có «Khác» bắt buộc ghi chú (R-HT-04).', 63);
insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  ('REASSIGN_REASON', 'NGHI_VIEC', 'Nghỉ việc', 1, false),
  ('REASSIGN_REASON', 'NGHI_PHEP_DAI', 'Nghỉ phép dài', 2, false),
  ('REASSIGN_REASON', 'BI_KHOA', 'Bị khoá tài khoản', 3, false),
  ('REASSIGN_REASON', 'QUA_HAN_XU_LY', 'Quá hạn xử lý', 4, false),
  ('REASSIGN_REASON', 'KHAC', 'Khác', 5, true);

-- 3. Lịch sử: thêm sự kiện CHUYEN_NGUOI_DUYET cho đơn và phiếu thu (chỉ thêm, giữ nguyên các sự kiện cũ).
alter table app.sales_order_event drop constraint sales_order_event_event_code_check;
alter table app.sales_order_event add constraint sales_order_event_event_code_check
  check (event_code in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'HUY', 'SUA', 'CANH_BAO_XEP_LOP', 'CHO_HOC_TRUOC', 'CHUYEN_NGUOI_DUYET'));
alter table app.receipt_event drop constraint receipt_event_event_code_check;
alter table app.receipt_event add constraint receipt_event_event_code_check
  check (event_code in ('TAO', 'SUA', 'GUI', 'DUYET_QL', 'TU_DUYET_QL', 'DUYET_KT', 'TU_CHOI', 'HUY', 'CHUYEN_NGUOI_DUYET'));

-- ---------------------------------------------------------------------------
-- Người này có nhận được bước quản lý của chứng từ không (R-V2-44, điều kiện người nhận).
-- Đầu vào: người nhận, loại ('DON' hoặc 'PHIEU_THU'), người lập, cơ sở chứng từ. Kết quả: null nếu hợp lệ, hoặc câu tiếng Việt nêu lý do không hợp lệ.
-- Luật: còn hoạt động và không bị khoá; không phải người lập; không phải Admin, không phải Kế toán (tách quyền tiền, R-TIEN-01); có quyền Duyệt ở cơ sở;
-- là quản lý trực tiếp của người lập hoặc Trưởng cơ sở của cơ sở đó (R-V2-41). Ai gọi: hàm nghiệp vụ.
-- ---------------------------------------------------------------------------
create or replace function app.approver_candidate_problem(p_user_id uuid, p_kind text, p_creator_id uuid, p_branch_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_module text := case when p_kind = 'PHIEU_THU' then 'RECEIPT' else 'SALES_ORDER' end;
  a app.user_account;
begin
  select * into a from app.user_account where id = p_user_id and student_code is null;
  if a.id is null then
    return 'Không tìm thấy nhân viên nhận.';
  end if;
  if a.is_locked or not exists (select from app.user_role ur where ur.user_id = a.id and ur.is_active) then
    return 'Người nhận đang bị khoá hoặc không còn hoạt động.';
  end if;
  if p_user_id = p_creator_id then
    return 'Không chuyển cho chính người lập.';
  end if;
  if exists (select from app.user_role ur where ur.user_id = a.id and ur.is_active and ur.role_code in ('ADMIN', 'ACCOUNTANT')) then
    return 'Không chuyển cho Admin hoặc Kế toán (tách quyền duyệt tiền).';
  end if;
  if not app.user_can_at_branch(p_user_id, v_module, 'DUYET', p_branch_id) then
    return 'Người nhận chưa có quyền Duyệt ở cơ sở này.';
  end if;
  if not (a.id = (select manager_id from app.user_account where id = p_creator_id)
          or app.is_branch_manager_at(a.id, v_module, p_branch_id)) then
    return 'Người nhận phải là quản lý trực tiếp của người lập hoặc Trưởng cơ sở của cơ sở này.';
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Người đã chốt hiện có duyệt được không (R-V2-44, điều kiện «người đã chốt không duyệt được»).
-- Kết quả: lý do tiếng Việt (mã) nếu KHÔNG duyệt được: 'BI_KHOA', 'MAT_QUYEN', 'QUA_HAN'; null nếu còn hiệu lực.
-- Quá hạn: now() > mốc + approver_reassign_after_hours; mốc là lúc trình hoặc lần chuyển gần nhất (muộn hơn).
-- ---------------------------------------------------------------------------
create or replace function app.approver_unavailable_reason(p_kind text, p_approver uuid, p_branch_id uuid, p_since timestamptz)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_module text := case when p_kind = 'PHIEU_THU' then 'RECEIPT' else 'SALES_ORDER' end;
begin
  if p_approver is null or exists (select from app.user_account a where a.id = p_approver and a.is_locked) then
    return 'BI_KHOA';
  end if;
  if not exists (select from app.user_role ur where ur.user_id = p_approver and ur.is_active)
     or not app.user_can_at_branch(p_approver, v_module, 'DUYET', p_branch_id) then
    return 'MAT_QUYEN';
  end if;
  if now() > p_since + make_interval(hours => app.get_setting_int('approver_reassign_after_hours', p_branch_id)) then
    return 'QUA_HAN';
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin chuyển người duyệt bước quản lý (R-V2-44).
-- Ai gọi: Admin (đã xác thực hai bước, R-HT-01). Đầu vào: loại ('DON' hoặc 'PHIEU_THU'), id chứng từ, người nhận, mã lý do (REASSIGN_REASON), ghi chú.
-- Kết quả: jsonb {id, from_approver_id, to_approver_id}. Chỉ đổi assigned_approver_id; KHÔNG đổi trạng thái, KHÔNG đổi approval_route; ghi lịch sử và nhật ký.
-- Lỗi: HMT_KHONG_CO_QUYEN, HMT_TINH_NANG_TAT, HMT_KHONG_TIM_THAY, HMT_SAI_TRANG_THAI, HMT_KHONG_CAN_CHUYEN, HMT_LY_DO_THIEU,
-- HMT_NGUOI_NHAN_KHONG_HOP_LE, HMT_NGUOI_DUYET_CON_HIEU_LUC.
-- ---------------------------------------------------------------------------
create or replace function app.reassign_approver(
  p_kind text, p_id uuid, p_new_approver uuid, p_reason_code text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_creator uuid;
  v_branch uuid;
  v_status text;
  v_route text;
  v_old uuid;
  v_since timestamptz;
  v_item app.catalog_item;
  v_problem text;
  v_why text;
  v_text text;
begin
  -- Luật R-HT-01: chỉ Admin (đã qua hai bước) chuyển người duyệt.
  if p_kind not in ('DON', 'PHIEU_THU') then
    perform app.raise_error('HMT_LOAI_CHUNG_TU_SAI', 'Chỉ chuyển người duyệt cho đơn hàng và phiếu thu.');
  end if;
  if not app.current_user_ready() or not ('ADMIN' = any (app.current_roles())) or not app.mfa_satisfied() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin (đã xác thực hai bước) chuyển được người duyệt.');
  end if;
  -- Đọc và khoá chứng từ.
  if p_kind = 'PHIEU_THU' then
    select r.created_by, r.branch_id, r.status_code, r.approval_route, r.assigned_approver_id,
           greatest(r.submitted_at, (select max(e.created_at) from app.receipt_event e where e.receipt_id = r.id and e.event_code = 'CHUYEN_NGUOI_DUYET'))
      into v_creator, v_branch, v_status, v_route, v_old, v_since
      from app.receipt r where r.id = p_id for update;
  else
    select o.created_by, o.branch_id, o.status_code, o.approval_route, o.assigned_approver_id,
           greatest(o.submitted_at, (select max(e.created_at) from app.sales_order_event e where e.order_id = o.id and e.event_code = 'CHUYEN_NGUOI_DUYET'))
      into v_creator, v_branch, v_status, v_route, v_old, v_since
      from app.sales_order o where o.id = p_id for update;
  end if;
  if v_creator is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chứng từ.');
  end if;
  perform app.require_feature('BAN_HANG', v_branch);
  -- Luật R-V2-44 (6): cờ tắt mặc định, kiểm cả trong hàm.
  if not app.get_setting_bool('approver_reassign_enabled', v_branch) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Chuyển người duyệt chưa được bật cho cơ sở này.');
  end if;
  -- Luật R-V2-44 (1): chỉ khi đang chờ bước quản lý.
  if v_status <> case when p_kind = 'PHIEU_THU' then 'DA_GUI' else 'DA_TRINH' end then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ chuyển được khi chứng từ đang chờ quản lý duyệt.');
  end if;
  -- Luật R-V2-44 (5): route TRUONG_CS (mọi Trưởng cơ sở duyệt được) và TU_DUYET không cần chuyển.
  if v_route is distinct from 'QUAN_LY' then
    perform app.raise_error('HMT_KHONG_CAN_CHUYEN', 'Chứng từ này không có một người duyệt đã chốt nên không cần chuyển.');
  end if;
  -- Luật R-V2-44 (4): bắt buộc lý do từ danh mục; «Khác» cần ghi chú.
  select * into v_item from app.catalog_item where catalog_code = 'REASSIGN_REASON' and code = p_reason_code and is_active;
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do chuyển người duyệt.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  -- Luật R-V2-44 (2): người nhận đủ điều kiện.
  if p_new_approver is not distinct from v_old then
    perform app.raise_error('HMT_NGUOI_NHAN_KHONG_HOP_LE', 'Người nhận trùng với người đang được giao duyệt.');
  end if;
  v_problem := app.approver_candidate_problem(p_new_approver, p_kind, v_creator, v_branch);
  if v_problem is not null then
    perform app.raise_error('HMT_NGUOI_NHAN_KHONG_HOP_LE', v_problem);
  end if;
  -- Luật R-V2-44 (3): chỉ khi người đã chốt không duyệt được (khoá, mất quyền hoặc quá hạn).
  v_why := app.approver_unavailable_reason(p_kind, v_old, v_branch, v_since);
  if v_why is null then
    perform app.raise_error('HMT_NGUOI_DUYET_CON_HIEU_LUC',
      'Người duyệt hiện tại còn hoạt động và chưa quá hạn xử lý nên chưa chuyển được.');
  end if;
  v_text := 'Chuyển từ ' || coalesce(app.staff_display_name(v_old), '(chưa rõ)') || ' sang ' || app.staff_display_name(p_new_approver)
            || '. Lý do: ' || v_item.name || coalesce('. ' || nullif(btrim(coalesce(p_note, '')), ''), '');
  -- Đổi người được giao (chỉ cột này).
  if p_kind = 'PHIEU_THU' then
    update app.receipt set assigned_approver_id = p_new_approver where id = p_id;
    perform app.receipt_add_event(p_id, 'CHUYEN_NGUOI_DUYET', v_status, v_status, v_text);
  else
    update app.sales_order set assigned_approver_id = p_new_approver where id = p_id;
    perform app.order_add_event(p_id, 'CHUYEN_NGUOI_DUYET', v_status, v_status, 'REASSIGN_REASON', p_reason_code, v_text, true);
  end if;
  return jsonb_build_object('id', p_id, 'from_approver_id', v_old, 'to_approver_id', p_new_approver);
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách người nhận hợp lệ cho hộp chọn «Chuyển người duyệt» (Admin). Kết quả: tối đa 50 người {id, name}, đã lọc theo luật R-V2-44 (2).
-- ---------------------------------------------------------------------------
create or replace function app.list_approver_candidates(p_kind text, p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_creator uuid;
  v_branch uuid;
  v_old uuid;
begin
  if p_kind not in ('DON', 'PHIEU_THU') then
    perform app.raise_error('HMT_LOAI_CHUNG_TU_SAI', 'Chỉ chuyển người duyệt cho đơn hàng và phiếu thu.');
  end if;
  if not app.current_user_ready() or not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin chuyển được người duyệt.');
  end if;
  if p_kind = 'PHIEU_THU' then
    select created_by, branch_id, assigned_approver_id into v_creator, v_branch, v_old from app.receipt where id = p_id;
  else
    select created_by, branch_id, assigned_approver_id into v_creator, v_branch, v_old from app.sales_order where id = p_id;
  end if;
  if v_creator is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chứng từ.');
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.display_name) order by x.display_name)
                     from (select a.id, a.display_name from app.user_account a
                            where a.student_code is null and a.id is distinct from v_old
                              and app.approver_candidate_problem(a.id, p_kind, v_creator, v_branch) is null
                            order by a.display_name limit 50) x), '[]'::jsonb); -- allow-number: giới hạn số dòng của hộp chọn, không phải luật nghiệp vụ
end;
$$;

-- ---------------------------------------------------------------------------
-- Trạng thái «Chuyển người duyệt» của một chứng từ cho giao diện (Admin): hiện nút hay không và vì sao người đã chốt không duyệt được.
-- Kết quả: {can: bool, reason: 'BI_KHOA'|'MAT_QUYEN'|'QUA_HAN'|null, approver_name}. can = cờ bật, đang chờ bước quản lý route QUAN_LY,
-- người đã chốt không duyệt được. Không phải Admin hoặc không đủ điều kiện thì can = false (không báo lỗi). Điều kiện đầy đủ vẫn kiểm lại trong reassign_approver.
-- ---------------------------------------------------------------------------
create or replace function app.get_reassign_state(p_kind text, p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
  v_status text;
  v_route text;
  v_old uuid;
  v_since timestamptz;
  v_why text;
begin
  if p_kind not in ('DON', 'PHIEU_THU') or not app.current_user_ready() or not ('ADMIN' = any (app.current_roles())) then
    return jsonb_build_object('can', false);
  end if;
  if p_kind = 'PHIEU_THU' then
    select r.branch_id, r.status_code, r.approval_route, r.assigned_approver_id,
           greatest(r.submitted_at, (select max(e.created_at) from app.receipt_event e where e.receipt_id = r.id and e.event_code = 'CHUYEN_NGUOI_DUYET'))
      into v_branch, v_status, v_route, v_old, v_since from app.receipt r where r.id = p_id;
  else
    select o.branch_id, o.status_code, o.approval_route, o.assigned_approver_id,
           greatest(o.submitted_at, (select max(e.created_at) from app.sales_order_event e where e.order_id = o.id and e.event_code = 'CHUYEN_NGUOI_DUYET'))
      into v_branch, v_status, v_route, v_old, v_since from app.sales_order o where o.id = p_id;
  end if;
  if v_branch is null or v_route is distinct from 'QUAN_LY'
     or v_status <> case when p_kind = 'PHIEU_THU' then 'DA_GUI' else 'DA_TRINH' end
     or not app.get_setting_bool('approver_reassign_enabled', v_branch) then
    return jsonb_build_object('can', false);
  end if;
  v_why := app.approver_unavailable_reason(p_kind, v_old, v_branch, v_since);
  return jsonb_build_object('can', v_why is not null, 'reason', v_why, 'approver_name', app.staff_display_name(v_old));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.approver_candidate_problem(uuid, text, uuid, uuid), app.approver_unavailable_reason(text, uuid, uuid, timestamptz),
  app.reassign_approver(text, uuid, uuid, text, text), app.list_approver_candidates(text, uuid), app.get_reassign_state(text, uuid) from public, anon;
grant execute on function app.reassign_approver(text, uuid, uuid, text, text), app.list_approver_candidates(text, uuid), app.get_reassign_state(text, uuid) to authenticated;
