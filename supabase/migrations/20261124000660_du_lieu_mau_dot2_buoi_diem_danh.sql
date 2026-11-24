-- Dữ liệu mẫu staging, ĐỢT 2, mảnh buổi học, điểm danh, nội dung, bài tập, nhận xét (Code E, 24/11/2026; thẻ E-23-31, E-23-33). CAO: dữ liệu đào tạo.
-- Thiết kế: docs/nghiep-vu/du-lieu-mau-dot2-thiet-ke.md (#654); khung 648; lead/cơ hội 655; báo giá/đơn/thu 656; học sinh/lớp/ghi danh/ticket 657.
-- Làm gì: app.demo_make_sessions bám LỚP ĐÃ DUYỆT và 3 em ghi danh của mảnh 657: lấy 2 buổi đầu của lớp (do duyệt lớp sinh ra, đã gắn bộ), dời về quá khứ,
--   buổi 1 = DONE đủ bốn bước (điểm danh, nội dung + bài tập về nhà, nhận xét + điểm, nhận xét đã gửi phụ huynh) để cổng Học tập và Phụ huynh có dữ liệu;
--   buổi 2 = Đã chốt, có điểm danh (một em vắng có phép), chưa Done, có chấm bài tập về nhà của buổi 1.
-- Cách làm (Chat chốt «ghi trực tiếp, không bỏ qua kiểm quyền» vì lớp mẫu không có giáo viên thật): chèn thẳng vào bảng điểm danh, nội dung, nhận xét, bài tập về nhà;
--   KHÔNG gọi hàm lưu của giáo viên (app.assert_session_access), KHÔNG gọi app.mark_session_done nên KHÔNG trừ giờ học sinh thật; không đụng hàm lõi quyền hay tiền.
--   Buổi, ghi danh, sổ giờ đều đã có cờ is_demo từ mảnh 657; các dòng con theo buổi mẫu nên bị ẩn cùng buổi khi xoá bộ.
-- Luật an toàn: khoá STAGING + công tắc (app.assert_demo_data_allowed), chỉ gọi từ hàm tạo bộ (app.demo_assert_caller_set: bộ của chính người gọi), không nhận dữ liệu từ người gọi,
--   mỗi bộ chỉ đổ một lần. Thêm ĐÚNG MỘT dòng perform vào app.create_demo_data_set.
select set_config('hmt.migration', 'on', false);

create or replace function app.demo_make_sessions(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_class app.class;
  v_sessions uuid[];
  v_session uuid;
  v_date date;
  v_students uuid[];
  v_version uuid;
  v_n integer;
  v_k integer;
  v_att uuid;
  v_status text;
  v_crit uuid;
  v_review constant text[] := array['Tập trung nghe giảng, làm bài tốt.', 'Hiểu bài, cần làm thêm bài tập vận dụng.', 'Tiến bộ rõ so với buổi trước.'];
  v_lines constant text[] := array['[MẪU] Ôn lại kiến thức buổi trước', '[MẪU] Bài mới: ví dụ và bài tập trên lớp'];
  v_back integer;
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, null);
  -- Lớp mẫu đã duyệt của bộ (mảnh 657 duyệt đúng một lớp); không có thì bỏ qua, không báo lỗi cả bộ.
  select c.* into v_class from app.class c
    join app.demo_data_item i on i.entity_type = 'CLASS' and i.entity_id = c.id and i.set_id = p_set_id
   where c.is_demo and c.status_code = 'DA_DUYET' order by c.created_at limit 1;
  if v_class.id is null then
    return;
  end if;
  -- Mỗi bộ chỉ đổ một lần: buổi đã có điểm danh thì dừng.
  if exists (select 1 from app.session_attendance a join app.class_session s on s.id = a.session_id where s.class_id = v_class.id) then
    return;
  end if;
  select array_agg(x.id order by x.session_date, x.session_no) into v_sessions
    from (select s.id, s.session_date, s.session_no from app.class_session s
           where s.class_id = v_class.id and s.is_demo order by s.session_date, s.session_no limit 2) x;  -- allow-number: hai buổi đầu có dữ liệu mẫu
  select array_agg(e.student_id order by e.created_at, e.id) into v_students
    from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = v_class.id
   where e.is_demo;
  if coalesce(array_length(v_sessions, 1), 0) < 2 or coalesce(array_length(v_students, 1), 0) < 1 then  -- allow-number: kế hoạch dữ liệu mẫu: 2 buổi đầu có dữ liệu
    return;
  end if;
  -- Ngày em vào lớp dời về trước buổi đầu (khớp buổi quá khứ).
  update app.enrollment_class ec set start_date = v_today - 21  -- allow-number: dời mốc về quá khứ cho dữ liệu mẫu
   where ec.class_id = v_class.id and ec.enrollment_id in (select id from app.enrollment where is_demo);
  select v.id into v_version
    from app.review_rubric_version v
   where v.status = 'DANG_DUNG'
     and v.subject_set = coalesce((select ss.subject_set from app.review_subject_set ss where ss.subject_code = v_class.subject_code), 'MON_PHU');

  for v_n in 1 .. 2 loop  -- allow-number: hai buổi mẫu
    v_session := v_sessions[v_n];
    v_back := case v_n when 1 then 14 else 7 end;  -- allow-number: buổi 1 cách 2 tuần, buổi 2 cách 1 tuần
    v_date := v_today - v_back;
    update app.class_session set session_date = v_date, is_manual = true where id = v_session;

    -- Điểm danh (giáo viên): buổi 2 em thứ ba vắng có phép, còn lại có mặt (đi muộn một em ở buổi 1).
    for v_k in 1 .. array_length(v_students, 1) loop
      v_status := case when v_n = 2 and v_k = 3 then 'VANG_CO_PHEP' when v_n = 1 and v_k = 2 then 'DI_MUON' else 'CO_MAT' end;  -- allow-number: vị trí em trong kế hoạch mẫu
      insert into app.session_attendance (session_id, class_id, branch_id, student_id, enrollment_id, teacher_status_code, teacher_marked_by, teacher_marked_at, created_by, updated_by)
      select v_session, v_class.id, p_branch_id, st, e.id, v_status, v_user, now(), v_user, v_user
        from (select v_students[v_k] as st) q
        join app.enrollment e on e.student_id = q.st and e.is_demo
       order by e.created_at limit 1;
    end loop;

    -- Nội dung buổi và bài tập về nhà.
    insert into app.session_content (session_id, branch_id, homework_text, created_by, updated_by)
    values (v_session, p_branch_id, '[MẪU] Làm các bài tập 1 đến 5 trong phiếu bài tập.', v_user, v_user);
    insert into app.session_content_line (session_id, branch_id, sort_order, line_text, created_by, updated_by)
    select v_session, p_branch_id, o::integer, t, v_user, v_user from unnest(v_lines) with ordinality as x (t, o);

    -- Buổi 1: nhận xét + điểm cho từng em có mặt, đã gửi phụ huynh (CSKH đánh dấu), buổi Done. Buổi 2: Đã chốt, chưa chấm.
    if v_n = 1 then
      -- Tiêu chí của buổi: bản Đang dùng của bộ tiêu chí môn (cùng cách app.open_session_review, không qua kiểm quyền).
      insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order, rubric_version_id, level_descs, created_by, updated_by)
      select v_session, p_branch_id, rc.id, rc.group_code, rc.name, rc.sort_order, v_version,
             coalesce((select jsonb_object_agg(d.level::text, d.description) from app.review_level_desc d
                        where d.version_id = v_version and d.criterion_id = rc.id), '{}'::jsonb), v_user, v_user
        from app.review_criteria_for_subject(v_class.subject_code) rc;
      for v_att in select a.id from app.session_attendance a where a.session_id = v_session and a.teacher_status_code in ('CO_MAT', 'DI_MUON') loop
        for v_crit in select sc.id from app.session_review_criterion sc where sc.session_id = v_session loop
          insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score, created_by, updated_by)
          values (v_session, p_branch_id, v_crit, v_att, 'DA_DANH_GIA', 3 + (abs(hashtext(v_att::text || v_crit::text)) % 3), v_user, v_user);  -- allow-number: điểm mẫu 3 đến 5 trên thang 1 đến 5
        end loop;
        insert into app.session_student_review (attendance_id, session_id, branch_id, teacher_comment, improvement_note, parent_sent_at, parent_sent_by, created_by, updated_by)
        values (v_att, v_session, p_branch_id, '[MẪU] ' || v_review[1 + (abs(hashtext(v_att::text)) % array_length(v_review, 1))], '[MẪU] Làm thêm bài tập về nhà đều đặn.', now(), v_user, v_user, v_user);
      end loop;
    else
      -- Buổi 2: chấm bài tập về nhà của buổi 1 cho các em có mặt buổi 1 (Đã chấm, một em Làm chưa xong).
      insert into app.homework_result (session_id, branch_id, student_id, status_code, score, note, graded_session_id, created_by, updated_by)
      select v_sessions[1], p_branch_id, a.student_id,
             case when a.student_id = v_students[1] then 'DA_CHAM' else 'LAM_CHUA_XONG' end, case when a.student_id = v_students[1] then 5 else 3 end,  -- allow-number: điểm mẫu
             '[MẪU] Chấm ở buổi 2', v_session, v_user, v_user
        from app.session_attendance a where a.session_id = v_sessions[1] and a.teacher_status_code in ('CO_MAT', 'DI_MUON');
    end if;
  end loop;

  -- Trạng thái: buổi 1 Done (đã đủ bốn bước), buổi 2 Đã chốt. Ghi trực tiếp, KHÔNG gọi mark_session_done nên không trừ giờ.
  update app.class_session set status_code = 'DONE' where id = v_sessions[1];
  update app.class_session set status_code = 'DA_CHOT' where id = v_sessions[2];  -- allow-number: chỉ số buổi 2 trong mảng
end;
$$;
revoke all on function app.demo_make_sessions(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hàm tạo bộ: giữ nguyên bản 657, thêm đúng một dòng perform app.demo_make_sessions.
-- ---------------------------------------------------------------------------
create or replace function app.create_demo_data_set()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_branch uuid := app.current_branch_id();
  v_id uuid;
begin
  -- Luật (1): khoá môi trường và công tắc.
  perform app.assert_demo_data_allowed();
  if v_user is null or not app.current_user_active() then
    perform app.raise_error('HMT_DEMO_CHUA_DANG_NHAP', 'Cần đăng nhập để tạo dữ liệu mẫu.');
  end if;
  if v_branch is null then
    perform app.raise_error('HMT_DEMO_THIEU_CO_SO', 'Chọn cơ sở trước khi tạo dữ liệu mẫu.');
  end if;
  -- Luật (5): hạn mức theo người và theo cơ sở (chỉ tính bộ chưa xoá).
  if (select count(*) from app.demo_data_set where created_by = v_user and status_code = 'DANG_DUNG')
       >= app.get_setting_int('demo_data_max_per_user') then
    perform app.raise_error('HMT_DEMO_QUA_HAN_MUC_NGUOI', 'Bạn đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.');
  end if;
  if (select count(*) from app.demo_data_set where branch_id = v_branch and status_code = 'DANG_DUNG')
       >= app.get_setting_int('demo_data_max_per_branch') then
    perform app.raise_error('HMT_DEMO_QUA_HAN_MUC_CO_SO', 'Cơ sở này đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.');
  end if;
  insert into app.demo_data_set (branch_id, created_by, updated_by)
  values (v_branch, v_user, v_user)
  returning id into v_id;
  -- Đợt 2: đổ chuỗi dữ liệu cố định vào bộ v_id tại đây (mỗi mảnh một hàm con).
  perform app.demo_make_leads(v_id, v_branch);
  perform app.demo_make_sales(v_id, v_branch);
  perform app.demo_make_education(v_id, v_branch);
  perform app.demo_make_sessions(v_id, v_branch);
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- E-23-34: buổi sinh MUỘN của lớp mẫu (duyệt lớp sau, phân lớp, buổi bù/bổ trợ) phải mang cờ mẫu.
-- Làm gì: trước khi chèn buổi, nếu lớp là lớp mẫu thì đặt is_demo = true và ghi demo_data_item vào đúng bộ của lớp.
-- Ai gọi: trigger, không gọi tay. Luật: xoá bộ ẩn được cả buổi sinh sau (ra-soát báo buổi mất cờ mẫu).
-- Chỉ mục: dùng demo_data_item_entity_idx (entity_type, entity_id) để tìm bộ của lớp.
-- ---------------------------------------------------------------------------
create or replace function app.class_session_inherit_demo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_set uuid;
begin
  if new.is_demo then
    return new;
  end if;
  -- Luật: chỉ lớp mẫu truyền cờ cho buổi.
  select i.set_id into v_set
    from app.demo_data_item i
    join app.class c on c.id = new.class_id and c.is_demo
   where i.entity_type = 'CLASS' and i.entity_id = new.class_id
   limit 1;
  if v_set is not null then
    new.is_demo := true;
    insert into app.demo_data_item (set_id, entity_type, entity_id, created_by, updated_by)
    values (v_set, 'SESSION', new.id, auth.uid(), auth.uid())
    on conflict (set_id, entity_type, entity_id) do nothing;
  end if;
  return new;
end;
$$;
revoke all on function app.class_session_inherit_demo() from public, anon, authenticated;

create trigger class_session_inherit_demo
  before insert on app.class_session
  for each row execute function app.class_session_inherit_demo();
