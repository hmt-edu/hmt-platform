-- HT-1 lane 2 (docs/ke-hoach/cong-hoc-tap-phu-huynh.md mục 3, 4): nền DB cho cổng Học tập (/hoc) và cổng Phụ huynh (/ph).
-- Nguyên tắc: học sinh chỉ thấy dữ liệu của chính mình, phụ huynh chỉ thấy dữ liệu của con mình. KHÔNG mở RLS cho vai HS/PH
-- trên bảng nghiệp vụ; mọi màn của cổng đọc qua hàm security definer riêng, mỗi hàm gọi app.portal_require_student ở đầu.
-- Nhận diện người gọi: học sinh qua user_account.student_code, phụ huynh qua user_account.parent_code (đã có, migration 616).

-- 1. Danh sách học sinh người gọi được thấy: học sinh = chính mình; phụ huynh = các con; nhân viên và người khác = rỗng.
-- Ai gọi: các hàm cổng bên dưới (không cấp trực tiếp cho giao diện). Tài khoản bị khoá hoặc bị thu hồi phiên (token cũ) thì rỗng (app.current_user_ready).
create or replace function app.portal_student_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
    from app.user_account a
    join app.student s
      on (a.student_code is not null and s.code = a.student_code)
      or (a.parent_code is not null and s.parent_id = (select p.id from app.parent p where p.code = a.parent_code))
   where a.id = (select auth.uid()) and (select app.current_user_ready());
$$;
comment on function app.portal_student_ids() is 'Học sinh người gọi được thấy ở cổng: HS = chính mình, PH = các con, còn lại rỗng. Dùng làm nền cho mọi hàm hs_*, ph_*.';

-- 2. Kiểm quyền theo một học sinh + công tắc phân hệ HOC_TAP ở cơ sở của học sinh đó (CLAUDE.md: công tắc kiểm cả trong hàm DB).
-- Lỗi: HMT_KHONG_CO_QUYEN (không phải học sinh của mình/con mình), HMT_TINH_NANG_TAT (cơ sở chưa bật Học tập).
create or replace function app.portal_require_student(p_student_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
begin
  -- Luật quyền riêng: không thấy học sinh này thì báo chung một lỗi, không tiết lộ học sinh có tồn tại hay không.
  if p_student_id is null or p_student_id not in (select app.portal_student_ids()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  select branch_id into v_branch_id from app.student where id = p_student_id;
  -- Luật công tắc: phân hệ Học tập phải bật ở cơ sở của học sinh.
  perform app.require_feature('HOC_TAP', v_branch_id);
  return v_branch_id;
end;
$$;
comment on function app.portal_require_student(uuid) is 'Đầu mọi hàm cổng: kiểm học sinh thuộc người gọi và Học tập đã bật ở cơ sở. Trả cơ sở của học sinh.';

-- 3. Danh sách con để dựng chip chọn con (PH) và nhận diện học sinh (HS). Chỉ trả học sinh ở cơ sở đã bật Học tập.
-- Kết quả: mảng {id, code, full_name}, sắp theo tên. Giao diện ẩn chip khi chỉ có một con.
create or replace function app.portal_children()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'full_name', s.full_name) order by s.full_name, s.code), '[]'::jsonb)
    from app.student s
   where s.id in (select app.portal_student_ids())
     and app.feature_enabled('HOC_TAP', s.branch_id);
$$;
comment on function app.portal_children() is 'Học sinh (HS: chính mình, PH: các con) ở cơ sở đã bật Học tập, cho cổng /hoc và /ph.';

revoke execute on function app.portal_student_ids(), app.portal_require_student(uuid), app.portal_children() from public, anon;
grant execute on function app.portal_student_ids(), app.portal_require_student(uuid), app.portal_children() to authenticated;
