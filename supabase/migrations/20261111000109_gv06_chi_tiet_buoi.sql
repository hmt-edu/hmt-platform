-- GV-06 (Code 2, 10/11/2026): thêm thông tin buổi và các dòng nội dung vào app.session_overview để màn GV-04, GV-06 tải bằng một lần gọi;
-- chặn ghi đè khi hai người cùng sửa nội dung buổi (Q-243: từ chối lưu nếu đã có người sửa từ lúc mở màn).
-- Luật: R-GV-08 (chỉ buổi của mình), R-GV-13 (không thông tin phụ huynh, học phí), R-V2-35 (BTVN trống = không giao).
-- Chạy sau migration 107 (thay hàm của 107, giữ nguyên các trường cũ).

-- Số phiên bản của nội dung buổi: tăng 1 mỗi lần lưu, để phát hiện hai người cùng sửa (Q-243). Không dùng mốc giờ vì cùng một giao dịch có thể trùng giờ.
alter table app.session_content add column version integer not null default 1;
comment on column app.session_content.version is 'Số phiên bản nội dung buổi, tăng 1 mỗi lần lưu qua app.save_session_content (chặn ghi đè, Q-243).';

-- app.session_overview(buổi): tiến độ các bước của một buổi cho GV-04, GV-06.
-- Ai gọi: giáo viên, trợ giảng của buổi, hoặc vận hành có quyền Điểm danh · Xem. Kết quả: json gồm
-- thông tin buổi (lớp, môn, số buổi, ngày, giờ, loại), tiến độ điểm danh, các dòng nội dung đang dùng, BTVN, hạn hoàn tất, lý do chưa Done.
create or replace function app.session_overview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_total integer;
  v_marked integer;
  v_homework text;
  v_lines jsonb;
  v_scored integer;
  v_exam jsonb;
  v_present integer;
  v_graded integer;
  v_missing jsonb;
  v_prev app.class_session;
  v_prev_homework text;
  v_prev_state text;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  select count(*), count(teacher_status_code) into v_total, v_marked
    from app.session_attendance where session_id = s.id and is_active;
  select coalesce(jsonb_agg(l.line_text order by l.sort_order), '[]'::jsonb) into v_lines
    from app.session_content_line l where l.session_id = s.id and l.is_active;
  select homework_text into v_homework from app.session_content where session_id = s.id;
  -- Buổi Kiểm tra: phạm vi kiến thức, điểm tối đa, cách nhập điểm do vận hành đặt (set_exam_config); giáo viên chỉ xem. Chưa đặt thì null.
  select jsonb_build_object('scope_text', e.scope_text, 'max_score', e.max_score, 'entry_mode', e.entry_mode,
                            'max_memory', e.max_memory, 'max_understand', e.max_understand, 'max_apply', e.max_apply)
    into v_exam from app.session_exam e where e.session_id = s.id;
  -- Số ô nhận xét đã chấm: màn GV-06 báo "sửa nội dung sau khi đã chấm" (điểm 9 tiêu chí không đổi khi sửa dòng nội dung, Q-245).
  select count(*) into v_scored from app.session_review_score where session_id = s.id and state <> 'CHUA_DANH_GIA';
  -- Bước chấm của GV-04 (R-GV-04, R-V2-20): em có mặt (Có mặt, Đi muộn) đã chấm đủ. Buổi thường: mọi tiêu chí đang bật đều có điểm hoặc trạng thái khác "Chưa đánh giá".
  -- Buổi Kiểm tra: đã chấm điểm. Kèm tên tối đa 10 em còn thiếu (giáo viên được thấy tên em trong lớp mình, R-GV-13).
  with present as (
    select sa.id, st.full_name,
           case when s.type_code = 'KIEM_TRA' then exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded)
                else exists (select from app.session_review_criterion rc where rc.session_id = sa.session_id and rc.enabled)
                     and not exists (select from app.session_review_criterion rc
                                      where rc.session_id = sa.session_id and rc.enabled
                                        and not exists (select from app.session_review_score sc
                                                         where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA')) end as complete
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  )
  select count(*), count(*) filter (where complete),
         coalesce((select jsonb_agg(m.full_name) from (select full_name from present where not complete order by full_name limit 10) m), '[]'::jsonb) -- allow-number: tối đa 10 tên em còn thiếu hiện trên màn
    into v_present, v_graded, v_missing from present;
  -- Bước chấm BTVN buổi trước (GV-04, R-V2-35, R-GV-11): 'DAU_LOP' = buổi đầu của lớp, 'KHONG_GIAO' = buổi trước không giao BTVN (cả hai: bỏ qua, không chặn),
  -- 'CAN_CHAM' = buổi trước có giao BTVN. Chức năng chấm BTVN (GV-08) chưa có nên chưa có dữ liệu "đã chấm".
  select * into v_prev from app.class_session ps
   where ps.class_id = s.class_id and ps.status_code in ('NHAP', 'DA_CHOT', 'DONE') and (ps.session_date, ps.start_time, ps.id) < (s.session_date, s.start_time, s.id)
   order by ps.session_date desc, ps.start_time desc, ps.id desc limit 1;
  if v_prev.id is null then
    v_prev_state := 'DAU_LOP';
  else
    select homework_text into v_prev_homework from app.session_content where session_id = v_prev.id;
    v_prev_state := case when v_prev_homework is null then 'KHONG_GIAO' else 'CAN_CHAM' end;
  end if;
  return jsonb_build_object(
    'session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code,
    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = s.type_code),
    'class_code', c.code,
    'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'session_no', s.session_no, 'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time,
    'attendance_total', v_total, 'attendance_marked', v_marked,
    'content_lines', jsonb_array_length(v_lines), 'has_content', jsonb_array_length(v_lines) > 0,
    'lines', v_lines, 'homework_text', v_homework, 'review_scored', v_scored, 'exam', v_exam,
    'grading_present', v_present, 'grading_done', v_graded, 'grading_missing', v_missing, 'prev_homework_state', v_prev_state,
    -- Số phiên bản để chặn ghi đè (Q-243): giao diện gửi lại giá trị này khi lưu; 0 = chưa có nội dung nào.
    'content_version', coalesce((select sc.version from app.session_content sc where sc.session_id = s.id), 0),
    'deadline_at', app.session_ends_at(s.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer),
    'pending_reason', case when s.status_code = 'DONE' then null else app.session_pending_reason(s.id) end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Chặn ghi đè khi lưu nội dung buổi (Q-243)
-- ---------------------------------------------------------------------------
-- app.save_session_content(buổi, các dòng, BTVN, phiên bản đã mở): như bản của migration 107, thêm tham số phiên bản.
-- p_expected_version: null = không kiểm (nơi gọi nội bộ); 0 = lúc mở màn chưa có nội dung; còn lại là content_version lấy từ session_overview.
-- Luật Q-243 (trước 17/11 chỉ bảo vệ dữ liệu): nếu nội dung đã bị người khác sửa kể từ lúc mở màn thì TỪ CHỐI lưu, báo HMT_XUNG_DOT, không ghi đè lặng lẽ.
drop function app.save_session_content(uuid, text[], text);
create or replace function app.save_session_content(p_session_id uuid, p_lines text[], p_homework text default null,
                                                    p_expected_version integer default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_lines text[];
  v_homework text := nullif(btrim(coalesce(p_homework, '')), '');
  v_current integer;
  v_has_row boolean;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  -- Luật R-GV-08: buổi Done, huỷ hoặc đã bị thay thì không sửa nội dung (sửa qua ticket cho vận hành).
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nội dung buổi. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA', 'Buổi đã huỷ hoặc đã được thay bằng lịch mới nên không lưu nội dung.');
  end if;
  -- Luật R-V2-35: buổi thường cần ít nhất một dòng nội dung (bỏ dòng trống).
  -- Q-252: buổi Kiểm tra không đòi dòng nội dung (khung GV-06 kiểm tra: phạm vi kiến thức và BTVN tuỳ giáo viên); BTVN luôn tuỳ giáo viên.
  select coalesce(array_agg(btrim(t) order by o), '{}') into v_lines
    from unnest(coalesce(p_lines, '{}')) with ordinality as x (t, o) where btrim(coalesce(t, '')) <> '';
  if cardinality(v_lines) = 0 and s.type_code <> 'KIEM_TRA' then
    perform app.raise_error('HMT_THIEU_NOI_DUNG', 'Cần ít nhất một dòng nội dung buổi.');
  end if;
  -- Luật Q-243: khoá dòng nội dung của buổi rồi so phiên bản; hai người lưu cùng lúc thì người sau bị từ chối.
  select version into v_current from app.session_content where session_id = s.id for update;
  v_has_row := found;
  if p_expected_version is not null
     and ((v_has_row and p_expected_version is distinct from v_current) or (not v_has_row and p_expected_version <> 0)) then
    perform app.raise_error('HMT_XUNG_DOT', 'Ô này vừa được người khác sửa, tải lại để xem.');
  end if;
  insert into app.session_content (session_id, branch_id, homework_text) values (s.id, s.branch_id, v_homework)
  on conflict (session_id) do update set homework_text = excluded.homework_text, version = app.session_content.version + 1, updated_at = now(), updated_by = auth.uid();
  -- Không xoá cứng: tắt cả bộ dòng cũ rồi ghi đè theo số thứ tự (dòng nào còn thì bật lại).
  update app.session_content_line set is_active = false where session_id = s.id and is_active;
  insert into app.session_content_line (session_id, branch_id, sort_order, line_text)
  select s.id, s.branch_id, o::integer, t from unnest(v_lines) with ordinality as x (t, o)
  on conflict (session_id, sort_order) do update set line_text = excluded.line_text, is_active = true, updated_at = now(), updated_by = auth.uid();
  return cardinality(v_lines);
end;
$$;
revoke execute on function app.save_session_content(uuid, text[], text, integer) from public, anon, authenticated;
grant execute on function app.save_session_content(uuid, text[], text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Cột bổ sung cho GV-02 (Chat chốt 10/11: GV-02 dùng teacher_my_sessions('NGAY'))
-- ---------------------------------------------------------------------------
-- app.teacher_my_sessions(chế độ, từ ngày, đến ngày, số dòng, bỏ qua): buổi mà người đang đăng nhập là giáo viên hoặc trợ giảng.
-- Chế độ 'NGAY': buổi có ngày trong khoảng (GV-02 Hôm nay, GV-03 Lịch: không hiện buổi huỷ hay đã bị thay; R-V2-37 chỉ trong ngày).
-- Chế độ 'CAN_LAM': buổi đã kết thúc mà chưa Done và không huỷ, kể cả quá hạn (GV-12 Cần làm, R-V2-37).
-- Kết quả: json gồm tổng và các dòng; mỗi dòng có hạn hoàn tất (R-GV-05) và lý do chưa Done. Phân trang ở máy chủ, mặc định 50, tối đa 100.
-- Luật: R-GV-08 chỉ buổi của mình; R-GV-13 không có thông tin phụ huynh, học phí.
-- Migration 109 thêm cột cho khung GV-02: room_name (phòng của buổi, không có thì phòng của khung giờ, không có nữa thì null), level_code/level_name (trình độ),
-- class_type_code/class_type_name (phân loại lớp), session_type_name (tên loại buổi từ danh mục). Các cột cũ giữ nguyên.
create or replace function app.teacher_my_sessions(p_mode text default 'NGAY', p_from date default null, p_to date default null,
                                                   p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_from date := coalesce(p_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_to date := coalesce(p_to, coalesce(p_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date));
  v_total bigint;
  v_rows jsonb;
begin
  if app.permission_scope('ATTENDANCE', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem buổi dạy.');
  end if;
  if p_mode not in ('NGAY', 'CAN_LAM') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Chế độ xem buổi không hợp lệ.');
  end if;
  with mine as (
    select s.* from app.class_session s
     where auth.uid() in (s.teacher_id, s.assistant_id)
       and s.status_code <> 'DA_THAY'
       and case p_mode
             when 'NGAY' then s.session_date between v_from and v_to and s.status_code in ('NHAP', 'DA_CHOT', 'DONE')
             else s.status_code in ('NHAP', 'DA_CHOT') and app.session_ends_at(s.id) <= now()
           end
  ), page as (
    select * from mine order by session_date, start_time, id limit v_limit offset v_offset
  )
  select (select count(*) from mine),
         coalesce(jsonb_agg(jsonb_build_object(
           'session_id', p.id, 'class_id', p.class_id, 'class_code', c.code,
           'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
           'session_no', p.session_no, 'session_date', p.session_date, 'start_time', p.start_time, 'end_time', p.end_time,
           'type_code', p.type_code, 'status_code', p.status_code,
           'room_name', (select r.name from app.room r where r.id = coalesce(p.room_id, (select sl.room_id from app.class_slot sl where sl.id = p.slot_id))),
           'level_code', c.level_code,
           'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'LEVEL' and ci.code = c.level_code),
           'class_type_code', c.class_type_code,
           'class_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = c.class_type_code),
           'session_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = p.type_code),
           'my_role', case when p.teacher_id = auth.uid() then 'GIAO_VIEN' else 'TRO_GIANG' end,
           'has_content', app.session_has_content(p.id),
           'deadline_at', app.session_ends_at(p.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', p.branch_id)::integer),
           'pending_reason', case when p.status_code = 'DONE' then null else app.session_pending_reason(p.id) end)
           order by p.session_date, p.start_time, p.id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

