-- Migration 702 (Code C, 27/11/2026, C-27-07 mục 4b): «Gán cùng lúc» trên màn Điểm danh: ghi cột Vận hành cho nhiều học sinh ở nhiều buổi
-- trong MỘT giao dịch. R-DD-02, R-DD-03, R-DD-05. Không có luật ghi mới: gom theo buổi rồi gọi app.set_attendance_ops, nên quyền, phạm vi cơ sở,
-- khoá buổi Done, «không xoá ô đã tích» và tự Done (R-GIO-06, R-GIO-01) giữ y như ghi từng buổi.

-- app.set_attendance_ops_bulk: Ai gọi: người có Điểm danh · Sửa phía vận hành (kiểm ở từng buổi).
-- Vào: [{session_id, student_id, status_code}]; trạng thái bắt buộc. Tối đa bằng số dòng một trang lớn nhất (list_page_size_max).
-- Một dòng bị chặn thì không ghi dòng nào. Ra: số dòng đã ghi.
create or replace function app.set_attendance_ops_bulk(p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_max integer := app.get_setting_int('list_page_size_max');
  v_count integer := jsonb_array_length(coalesce(p_entries, '[]'::jsonb));
  v_n integer := 0;
begin
  if v_count = 0 then
    perform app.raise_error('HMT_CHUA_CHON_EM', 'Chưa chọn học sinh nào.');
  end if;
  if v_count > v_max then
    perform app.raise_error('HMT_QUA_SO_DONG', format('Mỗi lượt tối đa %s học sinh.', v_max));
  end if;
  if exists (select 1 from jsonb_array_elements(p_entries) e
              where nullif(e ->> 'status_code', '') is null or nullif(e ->> 'session_id', '') is null or nullif(e ->> 'student_id', '') is null) then
    perform app.raise_error('HMT_THIEU_TRANG_THAI', 'Mỗi dòng cần buổi, học sinh và trạng thái điểm danh.');
  end if;
  -- Khoá các buổi theo thứ tự mã để hai lượt gán cùng lúc không khoá chéo nhau.
  for r in select (e ->> 'session_id')::uuid as session_id,
                  jsonb_agg(jsonb_build_object('student_id', e ->> 'student_id', 'status_code', e ->> 'status_code')) as entries
             from jsonb_array_elements(p_entries) e
            group by 1 order by 1 loop
    v_n := v_n + app.set_attendance_ops(r.session_id, r.entries);
  end loop;
  return v_n;
end;
$$;

revoke execute on function app.set_attendance_ops_bulk(jsonb) from public, anon;
grant execute on function app.set_attendance_ops_bulk(jsonb) to authenticated;
