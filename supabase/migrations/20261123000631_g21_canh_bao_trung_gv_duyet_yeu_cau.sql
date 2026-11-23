-- A-23-18 PR 2 / G21 (anh chốt 23/11, Chat duyệt 16:57): duyệt yêu cầu buổi học bù, bổ trợ (và củng cố, kiểm tra) trùng giờ giáo viên: CẢNH BÁO trước khi duyệt, KHÔNG chặn.
-- app.session_request_clash_check(yêu cầu): CHỈ ĐỌC. Ai gọi: người có Buổi học · Duyệt ở cơ sở của yêu cầu (cùng quyền hàm duyệt). Chỉ yêu cầu đang Chờ duyệt.
-- Giáo viên dự kiến xác định như app.approve_session_request (yêu cầu có giáo viên thì lấy, học bù không chọn thì giáo viên khung giờ lớp, khác thì giáo viên khung ngày đó).
-- Trùng = buổi KHÁC còn sống (Nháp, Đã chốt, Done) cùng ngày, giờ giao nhau, cùng giáo viên (hoặc cùng phòng). Buổi huỷ không tính. Luật R-LOP-08: chỉ cảnh báo.
-- Kết quả {teacher_clash: [chữ], room_clash: [chữ]} cùng kiểu app.session_move_check. Không đổi hàm duyệt, không bảng mới, không chỉ mục mới (dùng chỉ mục lớp, ngày có sẵn).
create or replace function app.session_request_clash_check(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.session_request;
  v_teacher uuid;
  v_teachers jsonb;
  v_rooms jsonb;
begin
  select * into r from app.session_request where id = p_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'DUYET', r.branch_id);
  if r.kind in ('BO_TRO', 'HOC_BU') then
    v_teacher := coalesce(r.teacher_id, (select sl.teacher_id from app.class_slot sl where sl.class_id = r.class_id and sl.is_active order by sl.weekday, sl.start_time limit 1));
  else
    select sl.teacher_id into v_teacher
      from app.class_slot sl
     where sl.class_id = r.class_id and sl.is_active
     order by (sl.weekday = extract(isodow from r.session_date)::integer) desc, sl.weekday, sl.start_time
     limit 1;
  end if;
  select coalesce(jsonb_agg(format('Giáo viên %s đã có buổi %s · %s ngày %s %s–%s', coalesce(t.display_name, ''), c.code,
           case when b.session_no is null then coalesce(ty.name, 'buổi khác') else 'Buổi ' || b.session_no end,
           to_char(b.session_date, 'DD/MM/YYYY'), to_char(b.start_time, 'HH24:MI'), to_char(b.end_time, 'HH24:MI'))
           order by b.start_time), '[]'::jsonb)
    into v_teachers
    from app.class_session b join app.class c on c.id = b.class_id
    left join app.user_account t on t.id = b.teacher_id
    left join app.catalog_item ty on ty.catalog_code = 'SESSION_TYPE' and ty.code = b.type_code
   where v_teacher is not null and b.teacher_id = v_teacher and b.session_date = r.session_date
     and b.start_time < r.end_time and r.start_time < b.end_time and b.status_code in ('NHAP', 'DA_CHOT', 'DONE');
  select coalesce(jsonb_agg(format('Phòng %s ngày %s %s–%s đã có buổi %s', rm.code, to_char(b.session_date, 'DD/MM/YYYY'),
           to_char(b.start_time, 'HH24:MI'), to_char(b.end_time, 'HH24:MI'), c.code) order by b.start_time), '[]'::jsonb)
    into v_rooms
    from app.class_session b join app.class c on c.id = b.class_id join app.room rm on rm.id = b.room_id
   where r.room_id is not null and b.room_id = r.room_id and b.session_date = r.session_date
     and b.start_time < r.end_time and r.start_time < b.end_time and b.status_code in ('NHAP', 'DA_CHOT', 'DONE');
  return jsonb_build_object('teacher_clash', v_teachers, 'room_clash', v_rooms);
end;
$$;
comment on function app.session_request_clash_check(uuid) is 'G21: cảnh báo trùng giờ giáo viên, phòng trước khi duyệt yêu cầu buổi (chỉ đọc, không chặn).';
revoke execute on function app.session_request_clash_check(uuid) from public, anon;
grant execute on function app.session_request_clash_check(uuid) to authenticated;
