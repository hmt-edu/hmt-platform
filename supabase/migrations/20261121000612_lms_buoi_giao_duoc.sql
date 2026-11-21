-- Migration 612 (Code E, 21/11/2026): GV-17, danh sách «buổi giao» mà người gọi giao bài được.
-- Lỗi gốc (Tester, e2e gv-lms-giao-bai): ô «Buổi giao» liệt kê MỌI buổi của lớp (từ app.teacher_class_overview), nên giáo viên có thể chọn buổi của
-- người khác; bấm Giao bài thì máy chủ từ chối «Bạn không có quyền thực hiện thao tác này với buổi này» (app.lms_create_assignment dùng ATTENDANCE Sửa theo buổi).
-- Hàm này trả đúng các buổi mà lms_create_assignment sẽ nhận, để giao diện chỉ cho chọn những buổi đó.
-- Luật: R-GV-08 (giáo viên, trợ giảng chỉ thao tác buổi được phân công), Q14 (quyền sẵn có ATTENDANCE Sửa), R-LMS-01 (buổi thật của lớp: không huỷ, không bị thay).

-- app.lms_giveable_sessions(p_class_id uuid) -> jsonb [{id, session_no, session_date, start_time, end_time, status_code}]
-- Ai được gọi: người có quyền ATTENDANCE Sửa với lớp (giáo viên, trợ giảng của lớp; vận hành theo cơ sở), phân hệ HOC_TAP bật.
-- Kết quả: buổi mới nhất trước, tối đa 100 buổi (quy ước hiệu năng). Giáo viên chỉ thấy buổi mình dạy hoặc trợ giảng; Trưởng cơ sở thấy mọi buổi trong cơ sở.
create or replace function app.lms_giveable_sessions(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_scope text;
begin
  select * into c from app.class where id = p_class_id;
  v_scope := app.permission_scope('ATTENDANCE', 'SUA');
  -- Luật R-GV-08: lớp không tồn tại, lớp của người khác, thiếu quyền: cùng một lỗi (không lộ sự tồn tại).
  if c.id is null or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền giao bài cho lớp này.');
  end if;
  perform app.require_feature('HOC_TAP', c.branch_id);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', x.id, 'session_no', x.session_no, 'session_date', x.session_date, 'start_time', x.start_time,
             'end_time', x.end_time, 'status_code', x.status_code) order by x.session_date desc, x.start_time desc, x.id)
      from (
        select s.id, s.session_no, s.session_date, s.start_time, s.end_time, s.status_code
          from app.class_session s
         where s.class_id = c.id and s.status_code in ('NHAP', 'DA_CHOT', 'DONE')
           and (v_scope <> 'DUOC_PHAN_CONG' or (select auth.uid()) in (s.teacher_id, s.assistant_id))
         order by s.session_date desc, s.start_time desc, s.id
         limit 100 -- allow-number: tối đa 100 buổi hiện trong ô chọn (như hồ sơ lớp)
      ) x), '[]'::jsonb);
end;
$$;

revoke execute on function app.lms_giveable_sessions(uuid) from public, anon, authenticated;
grant execute on function app.lms_giveable_sessions(uuid) to authenticated;
