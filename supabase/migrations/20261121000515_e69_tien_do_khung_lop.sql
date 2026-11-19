-- E69 / GV-11 (canvas 9189, GV11_pc, GV11_dt): khối «Tiến độ khung chương trình». Chat 22:52: TẠM = số buổi đã chốt ÷ số buổi dự kiến, nhãn «ước tính»
-- (lớp chưa có khung chương trình theo bài; thay bằng số bài khi có khung). Hàm riêng, không sửa app.teacher_class_overview.
-- app.teacher_class_progress(p_class_id): chỉ đọc. Ai gọi: giáo viên, trợ giảng được phân công lớp (R-GV-08), cùng cổng với teacher_class_overview.
-- Kết quả: {done_sessions, planned_sessions}: done = buổi Đã chốt hoặc Hoàn thành của lớp (không tính buổi bị thay, buổi huỷ); planned = tổng số buổi dự kiến của lớp (null nếu chưa đặt).
create or replace function app.teacher_class_progress(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật R-GV-08: chỉ lớp được phân công cho người gọi (lớp không tồn tại cũng trả cùng một lỗi).
  if c.id is null or app.permission_scope('CLASS', 'XEM') is null or not app.is_assigned_to_class(c.id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  return jsonb_build_object(
    'done_sessions', (select count(*)::int from app.class_session s where s.class_id = c.id and s.status_code in ('DA_CHOT', 'DONE')),
    'planned_sessions', c.total_sessions);
end;
$$;
revoke execute on function app.teacher_class_progress(uuid) from public, anon;
grant execute on function app.teacher_class_progress(uuid) to authenticated;
