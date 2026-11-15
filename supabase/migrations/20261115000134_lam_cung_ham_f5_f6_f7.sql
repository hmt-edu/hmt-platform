-- Làm cứng hàm (F5, F6, F7; Tester 15/11, Chat giao Code A): chỉ thêm kiểm đầu vào, không đổi hành vi cũ. Quyền gọi giữ nguyên (create or replace).
--  F5: app.change_session_staff chặn người MỚI không phải giáo viên (hoặc trợ giảng) của cơ sở buổi (HMT_GIAO_VIEN_KHONG_HOP_LE, HMT_TRO_GIANG_KHONG_HOP_LE); người giữ nguyên thì cho qua.
--  F6: trợ giảng không tồn tại hoặc bị khoá báo HMT_NHAN_SU_KHONG_CO (trước đây lỗi khoá ngoại 23503 thô).
--  F7: app.adjust_enrollment_hours chặn |giờ| > 9999 hoặc làm tròn 2 số lẻ ra 0 bằng HMT_GIO_DIEU_CHINH_SAI (trước đây lỗi 22003, 23514 thô).
--  Thân hàm giữ nguyên bản migration 102 (change_session_staff) và 101 (adjust_enrollment_hours).

create or replace function app.change_session_staff(p_session_id uuid, p_teacher_id uuid, p_assistant_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA_DUOC', 'Chỉ đổi người dạy buổi chưa Done và chưa huỷ.');
  end if;
  -- Luật F6: người được chọn phải tồn tại và chưa bị khoá (giáo viên và trợ giảng đều báo mã HMT, không để lọt lỗi khoá ngoại của DB).
  if p_teacher_id is not null and not exists (select from app.user_account where id = p_teacher_id and not is_locked) then
    perform app.raise_error('HMT_NHAN_SU_KHONG_CO', 'Giáo viên không tồn tại hoặc đã bị khoá.');
  end if;
  if p_assistant_id is not null and p_assistant_id is distinct from s.assistant_id
     and not exists (select from app.user_account where id = p_assistant_id and not is_locked) then
    perform app.raise_error('HMT_NHAN_SU_KHONG_CO', 'Trợ giảng không tồn tại hoặc đã bị khoá.');
  end if;
  -- Luật F5: giáo viên phải có vai trò Giáo viên và thuộc cơ sở của buổi; trợ giảng phải có vai trò Trợ giảng và thuộc cơ sở của buổi
  -- (cùng điều kiện với danh sách chọn của app.list_class_form_options). Chỉ kiểm người MỚI: giữ nguyên giáo viên hoặc trợ giảng hiện tại của buổi thì cho qua
  -- (Tester 15/11: buổi dựng sẵn hoặc nạp từ dữ liệu cũ có thể đang có người không đủ vai trò, đổi riêng người kia không được bị chặn oan).
  if p_teacher_id is not null and p_teacher_id is distinct from s.teacher_id and not exists (
       select from app.user_account u
        where u.id = p_teacher_id and u.branch_id = s.branch_id
          and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TEACHER')) then
    perform app.raise_error('HMT_GIAO_VIEN_KHONG_HOP_LE', 'Người được chọn không phải giáo viên của cơ sở này.');
  end if;
  if p_assistant_id is not null and p_assistant_id is distinct from s.assistant_id and not exists (
       select from app.user_account u
        where u.id = p_assistant_id and u.branch_id = s.branch_id
          and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TA')) then
    perform app.raise_error('HMT_TRO_GIANG_KHONG_HOP_LE', 'Người được chọn không phải trợ giảng của cơ sở này.');
  end if;
  update app.class_session set teacher_id = p_teacher_id, assistant_id = p_assistant_id, is_manual = true where id = s.id;
  return jsonb_build_object('warnings', app.class_clash_warnings(s.class_id));
end;
$$;

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
  perform app.assert_can('ENROLLMENT', 'DUYET', e.branch_id);
  if p_hours is null or p_hours = 0 then
    perform app.raise_error('HMT_GIO_DIEU_CHINH_SAI', 'Số giờ điều chỉnh phải khác 0.');
  end if;
  -- Luật F7: số giờ nhập tự do phải nằm trong khoảng cột sổ giờ chứa được (|giờ| <= 9999) và không làm tròn về 0 (2 số lẻ),
  -- để không lọt lỗi tràn số hay vi phạm ràng buộc của bảng.
  if abs(p_hours) > 9999 or round(p_hours, 2) = 0 then -- allow-number: giới hạn kiểu cột numeric(6,2) của sổ giờ, không phải luật nghiệp vụ
    perform app.raise_error('HMT_GIO_DIEU_CHINH_SAI', 'Số giờ điều chỉnh phải từ 0,01 đến 9999 giờ (tối đa 2 số lẻ).');
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
