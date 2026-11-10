-- GV-05 Điểm danh (cổng giáo viên): đọc bảng điểm danh của một buổi và lưu điểm danh có phát hiện hai người cùng sửa một ô.
-- Luật: R-DD-01 (4 trạng thái, trống = chưa điểm danh), R-DD-02 (ô của giáo viên là trạng thái chính thức), R-GV-08 (giáo viên chỉ ghi
-- trạng thái, không tạo dòng, không đổi tình trạng buổi, chỉ thấy buổi mình), R-GV-09 (trợ giảng như giáo viên; hai người sửa cùng ô thì hỏi),
-- R-GV-13 (không số điện thoại, phụ huynh, học phí), R-GIO-08 (chưa Đã chốt thì không hiện danh sách), R-GIO-07 (Done rồi giáo viên không sửa),
-- R-V2-36 (hộp xác nhận Có mặt → Vắng ở giao diện; điểm đã nhập giữ trong dữ liệu nhưng không tính, do D2 đảm nhiệm).
-- Không sửa app.set_attendance_teacher (migration 102): hàm lưu mới gọi lại nó để mọi kiểm tra buổi, quyền, danh mục vẫn ở một chỗ.
-- Không hiện "lý do liên hệ" và ghi chú của vận hành cho giáo viên (luật không nói rõ; chờ quyết).

-- app.teacher_attendance_sheet(buổi): ai được xem buổi (Điểm danh · Xem, kiểu "được phân công") gọi được.
-- Kết quả: {session: {...tiêu đề buổi}, statuses: [{code, name}] (danh mục Điểm danh đang bật, theo thứ tự), listed, students: [{student_id, student_code, full_name, is_trial, teacher_status_code,
--   teacher_marked_at, has_review}]}. Buổi chưa Đã chốt: listed = false, danh sách rỗng (R-GIO-08). has_review: em đã có điểm nhận xét hoặc
-- điểm kiểm tra (để giao diện hỏi trước khi đổi sang Vắng, R-V2-36).
create or replace function app.teacher_attendance_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_session jsonb;
  v_statuses jsonb;
begin
  -- Luật R-GV-08, R-GV-13: chỉ người được phân công vào buổi (hoặc người có quyền rộng hơn) xem được.
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');

  select jsonb_build_object(
           'id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'session_no', s.session_no,
           'session_date', s.session_date, 'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'),
           'class_code', c.code, 'subject_name', sub.name, 'class_type_name', ct.name, 'level_name', lv.name)
    into v_session
    from app.class c
    join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
    join app.catalog_item ct on ct.catalog_code = c.class_type_catalog and ct.code = c.class_type_code
    left join app.catalog_item lv on lv.catalog_code = c.level_catalog and lv.code = c.level_code
   where c.id = s.class_id;

  -- Luật R-DD-01: các trạng thái lấy từ danh mục (đổi tên được), không viết cứng ở giao diện.
  select coalesce(jsonb_agg(jsonb_build_object('code', ci.code, 'name', ci.name) order by ci.sort_order), '[]'::jsonb) into v_statuses
    from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.is_active;

  -- Luật R-GIO-08: chưa Đã chốt thì chưa có danh sách.
  if s.status_code not in ('DA_CHOT', 'DONE') then
    return jsonb_build_object('session', v_session, 'statuses', v_statuses, 'listed', false, 'students', '[]'::jsonb);
  end if;

  return jsonb_build_object('session', v_session, 'statuses', v_statuses, 'listed', true, 'students', coalesce((
    select jsonb_agg(jsonb_build_object(
             'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name, 'is_trial', sa.is_trial,
             'teacher_status_code', sa.teacher_status_code, 'teacher_marked_at', sa.teacher_marked_at,
             'has_review', exists (select from app.session_review_score sc where sc.attendance_id = sa.id and sc.state = 'DA_DANH_GIA')
                           or exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded))
           order by st.full_name, st.id)
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

-- app.save_attendance_teacher(buổi, [{student_id, status_code, base_marked_at}]): giáo viên, trợ giảng lưu điểm danh (nút Lưu, không tự lưu).
-- base_marked_at: giờ ghi của ô lúc người dùng mở màn (teacher_marked_at đã đọc, null nếu ô trống).
-- Luật R-GV-09: nếu ô đã bị người khác sửa từ lúc đó (giờ ghi khác lúc mở VÀ trạng thái hiện tại khác trạng thái định lưu) thì KHÔNG ghi gì cả,
-- trả danh sách ô vênh để giao diện hỏi "Giữ của tôi" hoặc "Lấy của [tên]". Chọn "Giữ của tôi": gọi lại với base_marked_at mới; "Lấy của": bỏ ô đó khỏi lần gọi.
-- Mọi kiểm tra khác (quyền, buổi chưa chốt, Done rồi, em không trong danh sách, trạng thái hợp lệ) do app.set_attendance_teacher quyết.
-- Kết quả: {saved, conflicts: [{student_id, full_name, current_status_code, marked_by_name, marked_at}]}.
create or replace function app.save_attendance_teacher(p_session_id uuid, p_entries jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  e jsonb;
  r record;
  v_conflicts jsonb := '[]'::jsonb;
  v_saved integer;
begin
  -- Kiểm quyền và tình trạng buổi trước (cùng lỗi với app.set_attendance_teacher): gọi với danh sách rỗng.
  perform app.set_attendance_teacher(p_session_id, '[]'::jsonb);

  -- Luật R-GV-09: khoá các dòng rồi so giờ ghi lúc mở màn với giờ ghi hiện tại.
  for e in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) loop
    select sa.teacher_status_code, sa.teacher_marked_at, sa.teacher_marked_by, st.full_name, ua.display_name as marked_by_name
      into r
      from app.session_attendance sa
      join app.student st on st.id = sa.student_id
      left join app.user_account ua on ua.id = sa.teacher_marked_by
     where sa.session_id = p_session_id and sa.student_id = (e ->> 'student_id')::uuid and sa.is_active
     for update of sa;
    -- Em không trong danh sách: để app.set_attendance_teacher báo lỗi ở bước ghi.
    continue when not found;
    if r.teacher_marked_at is distinct from nullif(e ->> 'base_marked_at', '')::timestamptz
       and r.teacher_status_code is distinct from nullif(e ->> 'status_code', '') then
      v_conflicts := v_conflicts || jsonb_build_object(
        'student_id', e ->> 'student_id', 'full_name', r.full_name, 'current_status_code', r.teacher_status_code,
        'marked_by_name', r.marked_by_name, 'marked_at', r.teacher_marked_at);
    end if;
  end loop;
  if jsonb_array_length(v_conflicts) > 0 then
    return jsonb_build_object('saved', 0, 'conflicts', v_conflicts);
  end if;

  v_saved := app.set_attendance_teacher(p_session_id, p_entries);
  return jsonb_build_object('saved', v_saved, 'conflicts', '[]'::jsonb);
end;
$$;

revoke all on function app.teacher_attendance_sheet(uuid), app.save_attendance_teacher(uuid, jsonb) from public, anon;
grant execute on function app.teacher_attendance_sheet(uuid), app.save_attendance_teacher(uuid, jsonb) to authenticated;

-- Chỉ mục: không thêm. Truy vấn dùng unique (session_id, student_id) của app.session_attendance và session_review_score_attendance_idx,
-- exam_score_session_idx đã có (migration 102, 103).
