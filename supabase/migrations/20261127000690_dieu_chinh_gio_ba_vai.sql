-- Migration 690 (Code A, 27/11/2026, thẻ A-27-02): anh Trường chốt 27/11 02:30 về «Điều chỉnh giờ» (R-GD-04).
-- (1) Trưởng cơ sở, Admin, Kế toán cùng được CỘNG và BỚT giờ: bỏ điều kiện riêng «cộng giờ cần Kế toán · Duyệt» của migration 471.
--     Giữ nguyên: trần mỗi lần (hours_adjust_max_per_call), chặn ghi danh không còn hiệu lực, chặn quỹ âm (R-GD-18), lý do bắt buộc;
--     mỗi lần là một dòng sổ giờ (chỉ thêm) và được ghi nhật ký qua trigger chuẩn của app.hour_ledger.
-- (2) Kế toán được Xem ghi danh mọi cơ sở để mở màn (KHÔNG thêm Tạo, Sửa, Duyệt).
-- Chỉ mục: không thêm; không đổi câu truy vấn.

select set_config('hmt.migration', 'on', false);
insert into app.permission (role_code, module_code, action_code, scope_code)
values ('ACCOUNTANT', 'ENROLLMENT', 'XEM', 'TOAN_HE_THONG')
on conflict (role_code, module_code, action_code) do update set scope_code = excluded.scope_code, is_active = true;
update app.setting_def
   set description = 'Mỗi lần điều chỉnh giờ tay của một ghi danh không quá chừng này giờ (cộng hoặc bớt). Đổi theo cơ sở được.'
 where key = 'hours_adjust_max_per_call';
select set_config('hmt.migration', '', false);

-- app.adjust_enrollment_hours(ghi danh, giờ, lý do, ghi chú): thêm một dòng điều chỉnh vào sổ giờ (GD-05).
-- Ai gọi: người có Ghi danh · Duyệt hoặc Kế toán · Duyệt ở cơ sở của ghi danh. Đầu vào: giờ dương là cộng, âm là bớt; mã lý do; ghi chú.
-- Kết quả: số dư giờ mới. Luật: R-GD-04, R-GD-18 (docs/spec/04-luat-nghiep-vu.md).
create or replace function app.adjust_enrollment_hours(p_enrollment_id uuid, p_hours numeric, p_reason_code text, p_note text default null)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v_requires_note boolean;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  -- Quyền (anh chốt 27/11): Ghi danh · Duyệt (Trưởng cơ sở, Admin) hoặc Kế toán · Duyệt (Kế toán) ở cơ sở của ghi danh, được CẢ cộng và bớt;
  -- còn lại báo không có quyền.
  if not (app.can_see_branch('ENROLLMENT', 'DUYET', e.branch_id) or app.can_see_branch('ACCOUNTING', 'DUYET', e.branch_id)) then
    perform app.assert_can('ENROLLMENT', 'DUYET', e.branch_id);
  end if;
  -- Luật G2 (a) (R-GIO-01, R-GIO-04): chỉ điều chỉnh giờ cho ghi danh còn hiệu lực; ghi danh Dừng, Hoàn phí, Hoàn thành, Chuyển lớp, Huỷ thì giờ đã chốt, giờ là tiền.
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_GIO_DIEU_CHINH_GHI_DANH_DONG', 'Ghi danh này không còn hiệu lực (đã dừng, hoàn phí, hoàn thành, chuyển lớp hoặc huỷ) nên không điều chỉnh giờ được.');
  end if;
  if p_hours is null or p_hours = 0 then
    perform app.raise_error('HMT_GIO_DIEU_CHINH_SAI', 'Số giờ điều chỉnh phải khác 0.');
  end if;
  -- Luật F7: số giờ nhập tự do phải nằm trong khoảng cột sổ giờ chứa được (|giờ| <= 9999) và không làm tròn về 0 (2 số lẻ),
  -- để không lọt lỗi tràn số hay vi phạm ràng buộc của bảng.
  if abs(p_hours) > 9999 or round(p_hours, 2) = 0 then -- allow-number: giới hạn kiểu cột numeric(6,2) của sổ giờ, không phải luật nghiệp vụ
    perform app.raise_error('HMT_GIO_DIEU_CHINH_SAI', 'Số giờ điều chỉnh phải từ 0,01 đến 9999 giờ (tối đa 2 số lẻ).');
  end if;
  -- Luật G2 (b): trần mỗi lần điều chỉnh là tham số cấu hình hours_adjust_max_per_call (theo cơ sở).
  if abs(p_hours) > app.get_setting_numeric('hours_adjust_max_per_call', e.branch_id) then
    perform app.raise_error('HMT_GIO_DIEU_CHINH_VUOT_TRAN', format('Mỗi lần chỉ điều chỉnh tối đa %s giờ (tham số hours_adjust_max_per_call).', app.get_setting('hours_adjust_max_per_call', e.branch_id)));
  end if;
  perform app.assert_catalog_code_active('HOURS_ADJUST_REASON', p_reason_code);
  select requires_note into v_requires_note from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' and code = p_reason_code;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  -- Luật R-GD-18: không cho quỹ âm bằng điều chỉnh tay.
  if p_hours < 0 and app.enrollment_hours_balance(e.id) + p_hours < 0 then
    perform app.raise_error('HMT_QUY_GIO_AM', 'Quỹ giờ của ghi danh không đủ để bớt số giờ này.');
  end if;
  insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note)
  values (e.id, e.branch_id, 'DIEU_CHINH', p_hours, p_reason_code, nullif(btrim(p_note), ''));
  return app.enrollment_hours_balance(e.id);
end;
$$;
