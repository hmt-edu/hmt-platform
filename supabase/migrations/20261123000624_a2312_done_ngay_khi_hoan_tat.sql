-- A-23-12 (Done ngay khi giáo viên lưu bước cuối) và A-23-13 (hai ghi danh cùng lớp: một dòng mỗi em ở LOP-09), Chat duyệt 14:21 ngày 23/11/2026.
-- A-23-12: hàm nội bộ app.complete_session_if_ready(buổi): khoá buổi; nếu buổi Đã chốt và app.session_pending_reason trả null thì gọi app.mark_session_done
-- (trừ giờ một lần nhờ chỉ mục duy nhất của sổ giờ, đóng dấu Đúng/Trễ hạn, ghi danh Đã xếp lớp thành Đang học). Buổi đã Done hoặc chưa đủ điều kiện (kể cả chưa hết giờ kết thúc) thì không làm gì:
-- cron app.auto_complete_sessions vẫn giữ cho buổi không được giáo viên lưu tới bước cuối. Quỹ giờ âm (HMT_QUY_GIO_AM) hoặc lỗi khác: BẮT lại, lưu của giáo viên vẫn thành công, buổi giữ Đã chốt,
-- lỗi ghi vào app.session_auto_done_error (như P7) để vận hành xử lý. Năm hàm lưu của giáo viên gọi hàm này ở cuối (thân giữ nguyên bản mới nhất, chỉ thêm một dòng perform).
-- Luật: R-GIO-01, R-GIO-06, R-GD-18, R-GV-05, QĐ-Đ21. Không đổi bảng.
create or replace function app.complete_session_if_ready(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_state text;
  v_msg text;
  v_hint text;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.id is null or s.status_code <> 'DA_CHOT' then
    return false;
  end if;
  if app.session_pending_reason(p_session_id) is not null then
    return false;
  end if;
  begin
    perform app.mark_session_done(p_session_id);
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text, v_hint = pg_exception_hint;
    -- Luật quyết định 23/11: lưu của giáo viên vẫn thành công; buổi giữ Đã chốt; ghi lỗi để vận hành xử lý (P7).
    insert into app.session_auto_done_error as t (session_id, class_id, branch_id, error_code, error_sqlstate, error_message)
    values (s.id, s.class_id, s.branch_id, case when v_hint like 'HMT\_%' then v_hint else v_state end, v_state, coalesce(v_msg, ''))
    on conflict (session_id) do update
      set error_code = excluded.error_code, error_sqlstate = excluded.error_sqlstate, error_message = excluded.error_message,
          attempts = t.attempts + 1, last_error_at = now(), resolved_at = null;
    return false;
  end;
  update app.session_auto_done_error set resolved_at = now() where session_id = s.id and resolved_at is null;
  return true;
end;
$$;
revoke all on function app.complete_session_if_ready(uuid) from public, anon, authenticated;


create or replace function app.set_attendance_teacher(p_session_id uuid, p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_status text;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa điểm danh. Nhờ quản lý cơ sở sửa kèm lý do.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa điểm danh được.');
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) loop
    v_status := nullif(e ->> 'status_code', '');
    if v_status is not null then
      perform app.assert_catalog_code_active('ATTENDANCE_STATUS', v_status);
    end if;
    update app.session_attendance set teacher_status_code = v_status,
           teacher_marked_by = case when v_status is null then null else auth.uid() end,
           teacher_marked_at = case when v_status is null then null else now() end
     where session_id = p_session_id and student_id = (e ->> 'student_id')::uuid and is_active;
    if not found then
      perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Có em không nằm trong danh sách buổi này.');
    end if;
    v_n := v_n + 1;
  end loop;
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_n;
end;
$$;


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
  if cardinality(v_lines) = 0 and not app.session_is_exam(s) then
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
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return cardinality(v_lines);
end;
$$;


create or replace function app.save_review_grading(p_session_id uuid, p_criteria jsonb, p_scores jsonb, p_notes jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n jsonb;
  v_count integer := 0;
begin
  perform app.open_session_review(p_session_id);
  if jsonb_array_length(coalesce(p_criteria, '[]'::jsonb)) > 0 then
    v_count := v_count + app.set_review_criteria(p_session_id, p_criteria);
  end if;
  if jsonb_array_length(coalesce(p_scores, '[]'::jsonb)) > 0 then
    v_count := v_count + app.set_review_scores(p_session_id, p_scores);
  end if;
  for n in select * from jsonb_array_elements(coalesce(p_notes, '[]'::jsonb)) loop
    perform app.set_student_review_note(p_session_id, (n ->> 'student_id')::uuid, n ->> 'comment', n ->> 'improvement');
    v_count := v_count + 1;
  end loop;
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_count;
end;
$$;


create or replace function app.save_homework_grading(p_session_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_hw jsonb;
  e jsonb;
  v_student uuid;
  v_status text;
  v_score integer;
  v_prev uuid;
  v_current integer;
  v_expected integer;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nữa. Bài Nộp sau thì cập nhật ở Cần làm.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa chấm được.');
  end if;
  v_hw := app.homework_progress(s.id);
  if (v_hw ->> 'state') <> 'CAN_CHAM' then
    perform app.raise_error('HMT_KHONG_CO_BTVN_DE_CHAM', 'Buổi trước không giao BTVN (hoặc đây là buổi đầu của lớp) nên không có gì để chấm.');
  end if;
  v_prev := (v_hw ->> 'prev_session_id')::uuid;
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_student := (e ->> 'student_id')::uuid;
    v_status := e ->> 'status_code';
    v_score := nullif(e ->> 'score', '')::integer;
    v_expected := nullif(e ->> 'expected_version', '')::integer;
    perform app.assert_homework_entry(v_status, v_score);
    if v_status not in ('DA_CHAM', 'LAM_CHUA_XONG') then
      v_score := null;
    end if;
    if not exists (select from app.session_attendance sa
                    where sa.session_id = s.id and sa.student_id = v_student and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')) then
      perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ chấm BTVN cho em có mặt trong buổi này.');
    end if;
    select version into v_current from app.homework_result where session_id = v_prev and student_id = v_student for update;
    -- Luật Q-243: dòng đã bị người khác sửa kể từ lúc mở màn thì từ chối, không ghi đè lặng lẽ.
    if v_expected is not null and v_expected is distinct from coalesce(v_current, 0) then
      perform app.raise_error('HMT_XUNG_DOT', 'Ô này vừa được người khác sửa, tải lại để xem.');
    end if;
    insert into app.homework_result (session_id, branch_id, student_id, status_code, score, note, graded_session_id)
    values (v_prev, s.branch_id, v_student, v_status, v_score, nullif(btrim(e ->> 'note'), ''), s.id)
    on conflict (session_id, student_id) do update
      set status_code = excluded.status_code, score = excluded.score, note = excluded.note, graded_session_id = excluded.graded_session_id,
          version = app.homework_result.version + 1;
    v_n := v_n + 1;
  end loop;
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_n;
end;
$$;


create or replace function app.save_exam_grading(p_session_id uuid, p_scores jsonb, p_notes jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n jsonb;
  v_count integer := 0;
begin
  -- Luôn kiểm buổi (quyền, Đã chốt, đúng loại) dù lô trống.
  perform app.assert_review_writable(p_session_id, true);
  if jsonb_array_length(coalesce(p_scores, '[]'::jsonb)) > 0 then
    v_count := v_count + app.set_exam_scores(p_session_id, p_scores);
  end if;
  for n in select * from jsonb_array_elements(coalesce(p_notes, '[]'::jsonb)) loop
    perform app.set_student_review_note(p_session_id, (n ->> 'student_id')::uuid, n ->> 'comment', n ->> 'improvement');
    v_count := v_count + 1;
  end loop;
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_count;
end;
$$;

-- A-23-13: LOP-09 một dòng mỗi em (ghi danh còn hiệu lực cũ nhất), giờ còn là tổng các ghi danh còn hiệu lực; số đếm nhóm Group By theo cùng cách.
-- Sổ giờ vẫn theo từng ghi danh; trừ buổi học theo ghi danh cũ trước (app.build_session_roster, R-GIO-04) giữ nguyên.

create or replace function app.list_class_students(
  p_class_id uuid, p_filters jsonb default '{}'::jsonb, p_sort text default 'name_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  c app.class;
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_state text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'state', '[]'::jsonb)));
  v_delivery text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'delivery', '[]'::jsonb)));
  -- C96: cơ sở phụ trách của ghi danh (canvas LOP09); dùng để mở một nhóm Group By.
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_result jsonb;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật quyền (như app.get_class_record): không thấy lớp thì như không có.
  if c.id is null
     or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  with f as (
    select ec.id as ec_id, ec.start_date, ec.end_date, ec.end_reason,
           e.id as enrollment_id, e.code as enrollment_code, e.status_code as enrollment_status, e.branch_id as enrollment_branch_id,
           e.delivery_mode_code, st.id as student_id, st.code as student_code, st.full_name
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
      join app.student st on st.id = e.student_id
     where ec.class_id = c.id
       and (v_q is null or app.fold_text(st.full_name || ' ' || st.code || ' ' || e.code) like '%' || v_q || '%')
       and (cardinality(v_state) = 0
            or ('DANG_HOC' = any (v_state) and ec.end_date is null)
            or ('DA_ROI' = any (v_state) and ec.end_date is not null))
       and (cardinality(v_delivery) = 0 or e.delivery_mode_code = any (v_delivery))
       and (v_branch is null or e.branch_id = v_branch)
  ),
  -- A-23-13 (Đ157): một em có hai ghi danh còn hiệu lực trong cùng lớp (sau chuyển lớp, mua thêm gói) chỉ hiện MỘT dòng (ghi danh cũ nhất); dòng đã rời giữ nguyên làm lịch sử.
  f1 as (
    select f.*, row_number() over (partition by f.student_id, (f.end_date is null) order by f.start_date, f.ec_id) as rn
      from f
  ),
  d as (select * from f1 where end_date is not null or rn = 1),
  h as (
    -- Giờ còn của dòng đang học = tổng giờ còn của mọi ghi danh còn hiệu lực của em trong lớp này.
    select d.*, case when d.end_date is null
                     then (select sum(app.enrollment_hours_balance(x.enrollment_id)) from f x where x.student_id = d.student_id and x.end_date is null)
                     else app.enrollment_hours_balance(d.enrollment_id) end as hours_left
      from d
  ),
  page as (
    select h.* from h
     order by case when p_sort = 'start_desc' then h.start_date end desc,
              case when p_sort = 'hours_asc' then h.hours_left end asc,
              h.full_name, h.ec_id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from d),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.ec_id, 'student_id', p.student_id, 'student_code', p.student_code, 'full_name', p.full_name,
             'enrollment_id', p.enrollment_id, 'enrollment_code', p.enrollment_code, 'enrollment_status', p.enrollment_status,
             'branch_code', (select b.code from app.branch b where b.id = p.enrollment_branch_id),
             'delivery_mode_code', p.delivery_mode_code,
             'start_date', p.start_date, 'end_date', p.end_date, 'end_reason', p.end_reason,
             'hours_left', p.hours_left)
             order by case when p_sort = 'start_desc' then p.start_date end desc,
                      case when p_sort = 'hours_asc' then p.hours_left end asc,
                      p.full_name, p.ec_id), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;

create or replace function app.class_student_group_counts(p_class_id uuid, p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  c app.class;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_state text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'state', '[]'::jsonb)));
  v_delivery text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'delivery', '[]'::jsonb)));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật quyền (như list_class_students): không thấy lớp thì như không có.
  if c.id is null
     or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('state', 'branch', 'delivery'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở phụ trách, hình thức học).');
  end if;
  with g as (
    select ec.end_date, e.branch_id, e.delivery_mode_code, e.student_id, ec.id as ec_id, ec.start_date
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
      join app.student st on st.id = e.student_id
     where ec.class_id = c.id
       and (v_q is null or app.fold_text(st.full_name || ' ' || st.code || ' ' || e.code) like '%' || v_q || '%')
       and (cardinality(v_state) = 0
            or ('DANG_HOC' = any (v_state) and ec.end_date is null)
            or ('DA_ROI' = any (v_state) and ec.end_date is not null))
       and (cardinality(v_delivery) = 0 or e.delivery_mode_code = any (v_delivery))
       and (v_branch is null or e.branch_id = v_branch)
  ), g1 as (
    -- A-23-13: cùng cách đếm với app.list_class_students: một dòng đang học mỗi em.
    select g.*, row_number() over (partition by g.student_id, (g.end_date is null) order by g.start_date, g.ec_id) as rn from g
  ), keyed as (
    select case v_f1 when 'state' then case when g1.end_date is null then 'DANG_HOC' else 'DA_ROI' end when 'branch' then g1.branch_id::text when 'delivery' then g1.delivery_mode_code end as k1,
           case v_f2 when 'state' then case when g1.end_date is null then 'DANG_HOC' else 'DA_ROI' end when 'branch' then g1.branch_id::text when 'delivery' then g1.delivery_mode_code end as k2
      from g1 where g1.end_date is not null or g1.rn = 1
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.class_student_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.class_student_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;
