-- C16 cụm 1: dòng chặn trình của PHIẾU THU (canvas abea TC02_nhap_xem_ql_khoa, _ql_thieu_quyen, _chua_ql; GHI_CHU mục 9). Code C, 18/11/2026.
-- app.receipt_expected_approver(phiếu): người duyệt dự kiến của phiếu thu NHÁP, cùng cách như expected_* của app.get_order (migration 083): đúng hàm app.approval_route mà
-- submit_receipt dùng lúc trình. Chỉ đọc, không chặn việc mở màn (tra lỗi thì để trống, luật chặn thật vẫn ở submit_receipt). Phiếu không Nháp hoặc phiếu thu nợ đầu kỳ
-- (không qua quản lý, R-V2-15) trả {}. Ai gọi: người có quyền Phiếu thu · Xem ở cơ sở của phiếu.
-- Kết quả: {expected_route, expected_approver_name, expected_approver_can_approve, expected_block, created_by_name};
-- expected_block: KHONG_CO_QUAN_LY, NGUOI_DUYET_BI_KHOA, NGUOI_DUYET_THIEU_QUYEN hoặc null (trùng mã lỗi của submit_receipt).
select set_config('hmt.migration', 'on', false);

create or replace function app.receipt_expected_approver(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_route text;
  v_approver uuid;
  v_hint text;
begin
  select * into r from app.receipt where id = p_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'XEM', r.branch_id);
  if r.status_code <> 'NHAP' or r.is_opening_debt then
    return '{}'::jsonb;
  end if;
  begin
    select x.route, x.approver_id into v_route, v_approver from app.approval_route(r.created_by, r.branch_id, 'PHIEU_THU') x;
  exception when others then
    -- Chủ ý bắt mọi lỗi: chỉ để hiển thị. Chưa có quản lý và cơ sở chưa có Trưởng cơ sở thì THIEU; lỗi khác để trống.
    get stacked diagnostics v_hint = pg_exception_hint;
    v_route := case when v_hint = 'HMT_KHONG_CO_QUAN_LY' then 'THIEU' end;
    v_approver := null;
  end;
  return jsonb_build_object(
    'expected_route', v_route,
    'expected_approver_name', app.staff_display_name(v_approver),
    'expected_approver_can_approve', case when v_approver is null then null else app.user_can_at_branch(v_approver, 'RECEIPT', 'DUYET', r.branch_id) end,
    'expected_block', case when v_route = 'THIEU' then 'KHONG_CO_QUAN_LY'
                           when v_approver is null then null
                           when exists (select from app.user_account a where a.id = v_approver and a.is_locked) then 'NGUOI_DUYET_BI_KHOA'
                           when not app.user_can_at_branch(v_approver, 'RECEIPT', 'DUYET', r.branch_id) then 'NGUOI_DUYET_THIEU_QUYEN'
                           else null end,
    'created_by_name', app.staff_display_name(r.created_by));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.receipt_expected_approver(uuid) from public, anon;
grant execute on function app.receipt_expected_approver(uuid) to authenticated;
