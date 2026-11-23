-- Code B (23/11/2026), thẻ B-23-06 CS-16 Nhận xét chờ gửi phụ huynh (anh Trường chốt 23/11: CS-16 sống lại, CSKH gửi tay qua Zalo rồi đánh dấu đã gửi).
-- Luật: R-V2-39 (lời nhắn là chữ giáo viên: session_student_review.teacher_comment), R-GV-04 (em vắng không có nhận xét), R-CS-13 (CSKH không tự sửa chữ giáo viên; chỉ đánh dấu đã gửi), QĐ-Đ291 (gửi tay, không tự gửi).
-- Làm gì: (1) hai cột parent_sent_at, parent_sent_by trên app.session_student_review (CSKH đánh dấu, KHÁC cờ exported của giáo viên, R-V2-38);
-- (2) app.list_parent_messages(bộ lọc, limit, offset): danh sách phân trang ở máy chủ, kèm đếm hai chip Chờ gửi / Đã gửi; (3) app.mark_parent_message_sent(mã điểm danh): đánh dấu đã gửi.
-- Quyền: phải có TICKET/SUA trong phạm vi cơ sở (CSKH, Admin; giáo viên chỉ có TICKET/XEM,TAO nên không thấy). Hàm security definer, kiểm quyền bên trong.

-- (1) Cột đánh dấu đã gửi. Chỉ mục (lý do): danh sách lọc theo cơ sở và trạng thái đã gửi, sắp theo buổi.
alter table app.session_student_review
  add column parent_sent_at timestamptz,
  add column parent_sent_by uuid;
comment on column app.session_student_review.parent_sent_at is 'Lúc CSKH đánh dấu đã gửi lời nhắn cho phụ huynh (CS-16). Null = chờ gửi. Không phải cờ Đã xuất của giáo viên.';
create index session_student_review_sent_idx on app.session_student_review (branch_id, parent_sent_at);

-- (2) app.list_parent_messages(p_filters, p_limit, p_offset). Ai gọi: người có TICKET/SUA (CSKH, Admin). Lọc: status = CHO_GUI | DA_GUI (mặc định CHO_GUI), q (tên em hoặc mã lớp), branch_id.
-- Kết quả {total, counts:{cho_gui, da_gui}, rows[]}; chỉ gồm em có mặt trong buổi, có lời nhắn không trống (R-GV-04, R-V2-39).
create or replace function app.list_parent_messages(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text := coalesce(nullif(p_filters ->> 'status', ''), 'CHO_GUI');
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_cho bigint;
  v_da bigint;
  v_rows jsonb;
begin
  -- Quyền: không có TICKET/SUA thì chặn (giáo viên không vào được).
  if not app.has_permission('TICKET', 'SUA') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chưa có quyền xem nhận xét chờ gửi.');
  end if;
  if v_status not in ('CHO_GUI', 'DA_GUI') then
    perform app.raise_error('HMT_DU_LIEU_SAI', 'Trạng thái không hợp lệ.');
  end if;
  -- Tập dòng thuộc phạm vi cơ sở và bộ lọc (trừ trạng thái), dùng chung cho đếm chip và danh sách.
  with f as (
    select r.attendance_id, r.parent_sent_at is not null as sent, s.session_date
      from app.session_student_review r
      join app.session_attendance a on a.id = r.attendance_id
      join app.class_session s on s.id = r.session_id
      join app.student st on st.id = a.student_id
      join app.class c on c.id = s.class_id
     where a.is_active
       and a.teacher_status_code in ('CO_MAT', 'DI_MUON')
       and nullif(btrim(coalesce(r.teacher_comment, '')), '') is not null
       and app.can_see_branch('TICKET', 'SUA', r.branch_id)
       and (v_branch is null or r.branch_id = v_branch)
       and (v_q is null or app.fold_text(st.full_name || ' ' || c.code) like '%' || app.fold_text(v_q) || '%')
  )
  select (select count(*) from f where not sent),
         (select count(*) from f where sent),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'attendance_id', r.attendance_id,
                    'student_name', st.full_name,
                    'class_code', c.code,
                    'session_no', s.session_no,
                    'session_date', s.session_date,
                    'parent_name', p.full_name,
                    'message', r.teacher_comment,
                    'sent', r.parent_sent_at is not null,
                    'sent_at', r.parent_sent_at) order by x.session_date desc, x.attendance_id)
                   from (select f.attendance_id, f.session_date from f
                          where f.sent = (v_status = 'DA_GUI')
                          order by f.session_date desc, f.attendance_id limit v_limit offset v_offset) x
                   join app.session_student_review r on r.attendance_id = x.attendance_id
                   join app.session_attendance a on a.id = r.attendance_id
                   join app.class_session s on s.id = r.session_id
                   join app.class c on c.id = s.class_id
                   join app.student st on st.id = a.student_id
                   join app.parent p on p.id = st.parent_id), '[]'::jsonb)
    into v_cho, v_da, v_rows;
  return jsonb_build_object(
    'total', case when v_status = 'DA_GUI' then v_da else v_cho end,
    'counts', jsonb_build_object('cho_gui', v_cho, 'da_gui', v_da),
    'rows', v_rows);
end;
$$;

-- (3) app.mark_parent_message_sent(p_attendance_id). Ai gọi: người có TICKET/SUA ở cơ sở của buổi. Chỉ ghi dấu «đã gửi»; không sửa chữ giáo viên (R-CS-13). Gọi lại không đổi lúc đã ghi.
create or replace function app.mark_parent_message_sent(p_attendance_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_student_review;
begin
  select * into r from app.session_student_review where attendance_id = p_attendance_id;
  if r.attendance_id is null or nullif(btrim(coalesce(r.teacher_comment, '')), '') is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lời nhắn của em trong buổi này.');
  end if;
  -- Luật quyền: cùng điều kiện với danh sách.
  if not app.can_see_branch('TICKET', 'SUA', r.branch_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chưa có quyền đánh dấu đã gửi lời nhắn này.');
  end if;
  update app.session_student_review
     set parent_sent_at = coalesce(parent_sent_at, now()), parent_sent_by = coalesce(parent_sent_by, auth.uid())
   where attendance_id = p_attendance_id;
end;
$$;

revoke execute on function app.list_parent_messages(jsonb, integer, integer), app.mark_parent_message_sent(uuid) from public, anon;
grant execute on function app.list_parent_messages(jsonb, integer, integer), app.mark_parent_message_sent(uuid) to authenticated;
