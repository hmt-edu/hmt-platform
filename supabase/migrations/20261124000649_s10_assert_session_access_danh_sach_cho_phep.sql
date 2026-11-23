-- A-23-31 S10 (BAO-CAO-TONG-HOP N9, mức VỪA; CAO vì chạm quyền): app.assert_session_access kiểm phạm vi theo DANH SÁCH CẤM
-- (chỉ chặn CO_SO khác cơ sở và DUOC_PHAN_CONG sai người); mọi phạm vi khác (CUA_TOI, CHINH_MINH, phạm vi mới thêm sau này) lọt qua cho MỌI buổi mọi cơ sở.
-- Hiện ma trận mặc định chưa gán CUA_TOI/CHINH_MINH cho SESSION/ATTENDANCE, nhưng Admin sửa được ma trận (QT-05) nên đây là lỗ hổng tiềm ẩn.
-- Làm gì: viết lại theo danh sách CHO PHÉP: TOAN_HE_THONG (mọi cơ sở); CO_SO (đúng cơ sở của buổi); DUOC_PHAN_CONG (đúng giáo viên hoặc trợ giảng của buổi, và thao tác không dành riêng vận hành);
--   phạm vi khác: chặn HMT_KHONG_CO_QUYEN. Thân hàm giữ nguyên bản migration 102, chỉ đổi điều kiện chặn. Chữ lỗi, tham số, quyền gọi không đổi.
-- Luật: R-HT (ma trận quyền), R-BUOI-09, R-GV-08.
create or replace function app.assert_session_access(p_session_id uuid, p_module text, p_action text, p_staff_only boolean default false)
returns app.class_session
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_scope text;
  v_ok boolean;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  v_scope := app.permission_scope(p_module, p_action);
  -- Danh sách cho phép: phạm vi nào không có trong danh sách này thì chặn (kể cả phạm vi thêm sau).
  v_ok := case v_scope
    when 'TOAN_HE_THONG' then true
    when 'CO_SO' then s.branch_id is not distinct from app.current_branch_id()
    -- Phạm vi "được phân công": đúng giáo viên hoặc trợ giảng của buổi, và thao tác không dành riêng cho vận hành.
    when 'DUOC_PHAN_CONG' then not p_staff_only and (auth.uid() = s.teacher_id or auth.uid() = s.assistant_id)
    else false
  end;
  if v_ok is not true then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này với buổi này.');
  end if;
  return s;
end;
$$;
