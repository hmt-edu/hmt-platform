-- GV-12 Cần làm (bổ sung): mục «Phiếu test chờ chấm» của giáo viên.
-- Luật: R-CRM-11 (giáo viên chấm kiểm tra đầu vào trong cổng giáo viên), R-GV-08 (chỉ thấy việc được giao cho mình),
-- R-GV-13 (giáo viên không thấy số điện thoại, phụ huynh, học phí: hàm chỉ trả tên em, môn, tên đề, giờ làm bài).
--
-- app.teacher_my_pending_tests(p_limit) -> jsonb {total, rows: [{test_id, code, student_name, subject_name, exam_name, scheduled_at}]}
-- Ai được gọi: người có quyền Xem phiếu kiểm tra ở phạm vi được phân công (giáo viên). Chỉ phiếu Chờ giáo viên chấm mà người gọi là giáo viên chấm.
-- Cũ nhất trước (làm bài trước chấm trước); tối đa 100 dòng một lần (quy ước phân trang). Chỉ đọc, không đổi gì.
create or replace function app.teacher_my_pending_tests(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_total bigint;
  v_rows jsonb;
begin
  -- Luật R-CRM-11, R-GV-08: phải có quyền xem phiếu kiểm tra; chỉ phiếu giao cho chính người gọi.
  if auth.uid() is null or app.permission_scope('STUDENT_TEST', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu kiểm tra.');
  end if;
  select count(*) into v_total
    from app.student_test t
   where t.grader_id = auth.uid() and t.status_code = 'TEACHER_REVIEW';
  select coalesce(jsonb_agg(jsonb_build_object(
           'test_id', x.id, 'code', x.code, 'student_name', x.full_name, 'subject_name', x.subject_name,
           'exam_name', x.exam_name, 'scheduled_at', x.scheduled_at) order by x.scheduled_at, x.code), '[]'::jsonb)
    into v_rows
    from (
      select t.id, t.code, st.full_name, t.exam_name, t.scheduled_at,
             (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = t.subject_code) as subject_name
        from app.student_test t
        join app.student st on st.id = t.student_id
       where t.grader_id = auth.uid() and t.status_code = 'TEACHER_REVIEW'
       order by t.scheduled_at, t.code
       limit v_limit
    ) x;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.teacher_my_pending_tests(integer) from public, anon, authenticated;
grant execute on function app.teacher_my_pending_tests(integer) to authenticated;

-- GV-15 Chấm kiểm tra đầu vào (cổng giáo viên): MỘT hàm đọc phiếu cho giáo viên chấm.
-- Luật: R-CRM-11 (giáo viên chấm trong cổng giáo viên), R-GV-08 (chỉ phiếu giao cho mình), R-GV-13 (không lộ điện thoại, phụ huynh, học phí:
-- khác get_student_test, hàm này chỉ trả tên em, môn, khối, hình thức, cấp độ đề, giờ làm bài, phòng, kết quả đã nhập).
-- app.teacher_test_sheet(p_id) -> jsonb {test: {...}, levels: [{code, name}], frameworks: [{code, name}]}
-- Ai được gọi: giáo viên chấm của phiếu (grader_id = người gọi) có quyền Xem phiếu. Phiếu không có, hoặc không phải của mình, trả cùng một lỗi
-- HMT_KHONG_CO_QUYEN (không lộ sự tồn tại). Phiếu Nháp, Đang test, Đã huỷ chưa tới lượt chấm nên cũng chặn. Chỉ đọc.
-- Ghi kết quả dùng lại app.enter_test_result (Lưu nháp) và app.complete_student_test (Trả về sale); hai hàm đó tự kiểm quyền Sửa và trạng thái.
create or replace function app.teacher_test_sheet(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.student_test;
begin
  select * into t from app.student_test where id = p_id;
  -- Luật R-GV-08, R-CRM-11: chỉ giáo viên chấm của phiếu, phiếu đã tới lượt chấm (Chờ giáo viên chấm) hoặc đã Hoàn thành (chỉ xem).
  if t.id is null or auth.uid() is null or t.grader_id is distinct from auth.uid()
     or app.permission_scope('STUDENT_TEST', 'XEM') is null
     or t.status_code not in ('TEACHER_REVIEW', 'COMPLETED') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu kiểm tra này.');
  end if;
  return jsonb_build_object(
    -- Luật R-GV-13: không có số điện thoại, phụ huynh, học phí.
    'test', jsonb_build_object(
      'id', t.id, 'code', t.code, 'status_code', t.status_code,
      'status_name', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_STATUS' and c.code = t.status_code),
      'student_name', (select s.full_name from app.student s where s.id = t.student_id),
      'subject_name', (select c.name from app.catalog_item c where c.catalog_code = 'SUBJECT' and c.code = t.subject_code),
      'grade_name', (select c.name from app.catalog_item c where c.catalog_code = 'GRADE' and c.code = t.grade_code),
      'mode_name', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_MODE' and c.code = t.mode_code),
      'level_name', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_LEVEL' and c.code = t.level_code),
      'exam_name', t.exam_name, 'scheduled_at', t.scheduled_at,
      'room_name', (select r.name from app.room r where r.id = t.room_id),
      'score', t.score, 'result_note', t.result_note,
      'suggested_level_code', t.suggested_level_code, 'suggested_framework_code', t.suggested_framework_code),
    'levels', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name) order by c.sort_order, c.code)
                          from app.catalog_item c where c.catalog_code = 'LEVEL' and c.is_active), '[]'::jsonb),
    'frameworks', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name) order by c.sort_order, c.code)
                              from app.catalog_item c where c.catalog_code = 'FRAMEWORK_LEVEL' and c.is_active), '[]'::jsonb));
end;
$$;

revoke execute on function app.teacher_test_sheet(uuid) from public, anon, authenticated;
grant execute on function app.teacher_test_sheet(uuid) to authenticated;
