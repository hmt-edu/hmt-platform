-- Code B (15/11/2026), nạp dữ liệu CS5, bước 4: báo cáo đối soát sau nạp (so với tab DOI_SOAT của script anh Trường).
-- Luật: R-V2-29, R-V2-30 (chỉ Admin), không in dữ liệu cá nhân: chỉ các số tổng, không tên, không số điện thoại.
-- Làm gì: hàm app.import_reconciliation_report(mã cơ sở) trả một đối tượng jsonb gồm số phụ huynh, học sinh, ghi danh Đang học, lớp, tổng giờ còn lại,
-- số cơ hội theo giai đoạn. Tổng công nợ và tiền thu thừa (đồng) thêm ở PR Số dư tiền khi có Sổ số dư. Chỉ đếm hồ sơ do nạp dữ liệu cũ (có mã cũ legacy_ref). Chỉ đọc, không đổi gì.
-- Chỉ mục: không thêm (đếm một lần sau nạp; cột legacy_ref và khoá ngoại đã có chỉ mục).
select set_config('hmt.migration', 'on', false);

-- app.import_reconciliation_report(p_branch_code): p_branch_code trống là mọi cơ sở. Ai gọi: Admin (ADMIN · Tạo, đã xác thực hai bước).
-- Kết quả: {branch, parents, students, enrollments_active, classes, hours_left, opportunities_by_stage {L1..L8: số}, opportunities_total}. Giờ còn lại là tổng sổ giờ của các ghi danh nạp (hour_ledger).
create or replace function app.import_reconciliation_report(p_branch_code text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  -- Luật: chỉ Admin đối soát dữ liệu nạp.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên xem được báo cáo đối soát sau nạp.');
  end if;
  if p_branch_code is not null then
    select id into v_branch from app.branch where code = upper(btrim(p_branch_code));
    if v_branch is null then
      perform app.raise_error('HMT_NAP_CO_SO_SAI', 'Mã cơ sở không đúng (ví dụ CS5).');
    end if;
  end if;
  return jsonb_build_object(
    'branch', upper(btrim(p_branch_code)),
    'parents', (select count(*) from app.parent p where p.legacy_ref is not null and (v_branch is null or p.branch_id = v_branch)),
    'students', (select count(*) from app.student s where s.legacy_ref is not null and (v_branch is null or s.branch_id = v_branch)),
    'enrollments_active', (select count(*) from app.enrollment e
                            where e.legacy_ref is not null and e.status_code = 'DANG_HOC' and (v_branch is null or e.branch_id = v_branch)),
    'classes', (select count(*) from app.class c where c.legacy_ref is not null and (v_branch is null or c.branch_id = v_branch)),
    'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                             where e.legacy_ref is not null and (v_branch is null or e.branch_id = v_branch)), 0),
    'opportunities_by_stage', coalesce((select jsonb_object_agg(x.stage_code, x.n) from (
                                select o.stage_code, count(*) n from app.opportunity o
                                 where o.legacy_ref is not null and (v_branch is null or o.branch_id = v_branch)
                                 group by o.stage_code) x), '{}'::jsonb),
    'opportunities_total', (select count(*) from app.opportunity o where o.legacy_ref is not null and (v_branch is null or o.branch_id = v_branch)));
end;
$$;
revoke execute on function app.import_reconciliation_report(text) from public, anon;
grant execute on function app.import_reconciliation_report(text) to authenticated;

select set_config('hmt.migration', '', false);
