-- Migration 678 (E-26-05, anh Trường chốt 26/11/2026): ADMIN HỆ THỐNG ĐỦ QUYỀN, PHẦN KHÔNG DÍNH TIỀN.
-- Bảng quyền đã cấp ADMIN mọi ô (chỉ thiếu hai ô tiền). Chỗ còn chặn Admin là các hàm đòi đúng TÊN VAI TRÒ; nay hỏi qua MỘT hàm
-- app.has_role_or_admin. Vai khác không đổi. KHÔNG đụng việc tiền (cấp Kế toán, phiếu có cấp kế toán, phiếu thu): chờ anh chốt, PR sau.
-- Giữ nguyên: không tự duyệt phiếu mình tạo; một người không duyệt hai cấp của cùng phiếu.
-- Không thêm bảng, chỉ mục (user_role đã tra theo user_id).

-- app.has_role_or_admin: người gọi đang có một trong các vai p_roles, HOẶC là Admin hệ thống đã qua xác thực hai bước.
-- Hàm trong: chỉ hàm nghiệp vụ gọi, và hàm đó vẫn phải kiểm quyền phân hệ, cơ sở như cũ. Luật: spec 04 R-HT-01 (phần không dính tiền).
create function app.has_role_or_admin(p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_role ur
                  where ur.user_id = (select auth.uid()) and ur.is_active
                    and (ur.role_code = any (p_roles) or (ur.role_code = 'ADMIN' and app.mfa_satisfied())));
$$;
revoke execute on function app.has_role_or_admin(text[]) from public, anon, authenticated;

-- app.list_tasks_for_destination: chép nguyên bản 20261121000568, chỉ đổi điều kiện vai.
create or replace function app.list_tasks_for_destination()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', k.id, 'code', k.code, 'ticket_code', t.code,
           'student_name', (select s.full_name from app.student s where s.id = t.student_id),
           'from_branch_code', (select b.code from app.branch b where b.id = k.branch_id),
           'dest_branch_code', (select b.code from app.branch b where b.id = k.dest_branch_id),
           'created_at', k.created_at) order by k.created_at desc), '[]'::jsonb)
    from (select * from app.ticket_task k0
           where k0.dest_branch_id is not null and k0.status_code = 'CHO_DUYET' and k0.levels[k0.current_level] = 'QUAN_LY_CO_SO_DICH'
             and app.can_see_branch('TICKET', 'DUYET', k0.dest_branch_id)
             and app.has_role_or_admin(array['BRANCH_MANAGER'])
           order by k0.created_at desc limit app.get_setting_int('list_page_size_max')) k
    join app.ticket t on t.id = k.ticket_id;
$$;

-- app.get_task_for_destination: chép nguyên bản 20261123000625, chỉ đổi điều kiện vai.
create or replace function app.get_task_for_destination(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  e app.enrollment;
begin
  select * into k from app.ticket_task where id = p_id;
  if k.id is null or k.dest_branch_id is null or k.status_code <> 'CHO_DUYET' or k.levels[k.current_level] <> 'QUAN_LY_CO_SO_DICH'
     or not app.can_see_branch('TICKET', 'DUYET', k.dest_branch_id)
     or not app.has_role_or_admin(array['BRANCH_MANAGER']) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  select * into e from app.enrollment where id = nullif(k.payload ->> 'enrollment_id', '')::uuid;
  return jsonb_build_object(
    'task', jsonb_build_object('id', k.id, 'code', k.code, 'reason', k.reason, 'level', k.current_level, 'level_total', cardinality(k.levels),
      'from_branch_code', (select b.code from app.branch b where b.id = k.branch_id),
      'dest_branch_code', (select b.code from app.branch b where b.id = k.dest_branch_id),
      'to_class_id', k.payload ->> 'to_class_id', 'start_date', k.payload ->> 'start_date',
      'student_name', (select s.full_name from app.student s where s.id = t.student_id),
      'hours_left', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::numeric(6, 2),
      'subject_code', app.enrollment_current_subject(e.id),
      'approved_by_source', (select app.staff_display_name(ev.created_by) from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq limit 1)),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'code', c.code, 'subject_code', c.subject_code, 'seats_left', app.class_seats_left(c.id),
               'upcoming', coalesce((select jsonb_agg(jsonb_build_object('date', u.session_date, 'session_no', u.session_no) order by u.session_date)
                                       from (select x.session_date, x.session_no from app.class_session x
                                              where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT')
                                                and x.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
                                              order by x.session_date limit 8) u), '[]'::jsonb)) -- allow-number: số buổi sắp tới gợi ý trong hộp chọn ngày vào lớp
             order by c.code)
        from app.class c
       where c.branch_id = k.dest_branch_id and c.status_code = 'DA_DUYET' and coalesce(app.class_seats_left(c.id), 1) > 0
         and c.subject_code is not distinct from app.enrollment_current_subject(e.id)), '[]'::jsonb));
end;
$$;

-- app.set_task_destination_class: chép nguyên bản 20261123000625, chỉ đổi điều kiện vai.
create or replace function app.set_task_destination_class(p_id uuid, p_class_id uuid, p_start_date date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  c app.class;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null or k.dest_branch_id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chuyển cơ sở.');
  end if;
  if k.status_code <> 'CHO_DUYET' or k.levels[k.current_level] <> 'QUAN_LY_CO_SO_DICH' then
    perform app.raise_error('HMT_PHIEU_CHUA_DEN_LUOT', 'Phiếu chưa đến lượt quản lý cơ sở đích chọn lớp.');
  end if;
  if not app.has_role_or_admin(array['BRANCH_MANAGER']) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản lý cơ sở đích chọn lớp mới.');
  end if;
  perform app.assert_can('TICKET', 'DUYET', k.dest_branch_id);
  select * into c from app.class where id = p_class_id;
  if c.id is null or c.branch_id <> k.dest_branch_id or c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp đã duyệt của cơ sở đích.');
  end if;
  -- R-CS-03 (thẻ C-23-13): chuyển lớp chỉ cùng môn; khác môn đi nhánh Chuyển phí. Chặn ngay lúc chọn lớp, không để duyệt xong mới lỗi.
  if c.subject_code is distinct from app.enrollment_current_subject((k.payload ->> 'enrollment_id')::uuid) then
    perform app.raise_error('HMT_CHUYEN_LOP_KHAC_MON', 'Khác môn: dùng Chuyển phí.');
  end if;
  if coalesce(app.class_seats_left(c.id), 1) <= 0 then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Lớp đã hết chỗ.');
  end if;
  if p_start_date is null or not exists (select from app.class_session x where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT') and x.session_date = p_start_date
                                           and x.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date) then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn một buổi sắp tới của lớp mới làm ngày bắt đầu.');
  end if;
  update app.ticket_task set payload = payload || jsonb_build_object('to_class_id', c.id, 'start_date', p_start_date) where id = k.id;
  perform app.ticket_task_log(k, 'CHON_LOP', 'CHO_DUYET', 'CHO_DUYET', 'Chọn lớp ' || c.code || ' ở cơ sở đích.');
end;
$$;

-- app.approve_ticket_task: chép nguyên bản 20261124000646, chỉ đổi điều kiện vai ở cấp cơ sở đích (cấp Kế toán và phiếu tiền giữ nguyên).
create or replace function app.approve_ticket_task(p_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_level text;
  v_last boolean;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  if k.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ duyệt phiếu đang Chờ duyệt.');
  end if;
  v_level := k.levels[k.current_level];
  if v_level = 'QUAN_LY_CO_SO_DICH' then
    -- CS-07: cấp quản lý cơ sở ĐẾN: đúng quản lý (vai trò Quản lý cơ sở) của cơ sở đích, và đã chọn lớp mới ở bước này.
    if k.dest_branch_id is null or not app.has_role_or_admin(array['BRANCH_MANAGER']) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho quản lý cơ sở đích.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', k.dest_branch_id);
    if nullif(k.payload ->> 'to_class_id', '') is null or nullif(k.payload ->> 'start_date', '') is null then
      perform app.raise_error('HMT_PHIEU_CHUA_CHON_LOP', 'Chọn lớp mới và buổi bắt đầu ở cơ sở đích trước khi duyệt.');
    end if;
  elsif v_level = 'KE_TOAN' then
    -- Luật R-HT-01, R-TIEN-01: cấp kế toán chỉ vai trò Kế toán duyệt (Admin không duyệt tiền).
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'ACCOUNTANT') then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho kế toán.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', null);
  else
    perform app.assert_can('TICKET', 'DUYET', k.branch_id);
    -- Luật R-CS-07 (anh chốt 24/11/2026, N0 #18): cấp Quản lý cơ sở do Trưởng cơ sở (đúng cơ sở, đã kiểm ở assert_can) hoặc Admin duyệt; Kế toán không duyệt cấp này.
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN')) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho Trưởng cơ sở hoặc Admin.');
    end if;
    -- Luật R-HT-01, R-CS-07: phiếu có cấp kế toán là phiếu tiền; cấp quản lý cơ sở của phiếu tiền do quản lý cơ sở duyệt (không Admin, không kế toán thay).
    if 'KE_TOAN' = any (k.levels) and not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'BRANCH_MANAGER') then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho quản lý cơ sở.');
    end if;
  end if;
  if k.created_by is not distinct from auth.uid() then
    perform app.raise_error('HMT_PHIEU_TU_DUYET', 'Người tạo phiếu không tự duyệt phiếu của mình.');
  end if;
  -- Luật R-TIEN-01: một người không duyệt hai cấp của cùng một phiếu.
  if exists (select from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' and ev.created_by = auth.uid()) then
    perform app.raise_error('HMT_PHIEU_MOT_NGUOI_HAI_CAP', 'Một người không duyệt hai cấp của cùng một phiếu.');
  end if;
  v_last := k.current_level >= cardinality(k.levels);
  update app.ticket_task set
    status_code = case when v_last then 'DA_DUYET' else 'CHO_DUYET' end,
    current_level = case when v_last then current_level else current_level + 1 end,
    approved_at = case when v_last then now() else approved_at end
   where id = k.id;
  perform app.ticket_task_log(k, 'DUYET', 'CHO_DUYET', case when v_last then 'DA_DUYET' else 'CHO_DUYET' end, nullif(btrim(coalesce(p_note, '')), ''));
end;
$$;

-- app.create_ticket: chép nguyên bản 20261115000157, chỉ đổi điều kiện tạo ticket giáo viên.
create or replace function app.create_ticket(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text := nullif(p_data ->> 'ticket_type', '');
  v_branch uuid := coalesce(nullif(p_data ->> 'branch_id', '')::uuid, app.current_branch_id());
  v_cat app.ticket_category;
  v_priority text;
  v_channel text := nullif(p_data ->> 'channel_code', '');
  v_title text := nullif(btrim(coalesce(p_data ->> 'title', '')), '');
  v_desc text := nullif(btrim(coalesce(p_data ->> 'description', '')), '');
  v_parent uuid := nullif(p_data ->> 'parent_id', '')::uuid;
  v_student uuid := nullif(p_data ->> 'student_id', '')::uuid;
  v_class uuid := nullif(p_data ->> 'class_id', '')::uuid;
  v_branch_code text;
  v_resp_hours integer;
  v_res_hours integer;
  v_code text;
  v_id uuid;
  v_now timestamptz := now();
begin
  if v_branch is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa xác định cơ sở của ticket.');
  end if;
  -- Luật AS-13: công tắc phân hệ Aftersale theo cơ sở (kiểm cả ở giao diện và trong hàm).
  perform app.require_feature('AFTERSALE', v_branch);
  -- Luật AS-09: quyền tạo theo ma trận (giáo viên chỉ tạo).
  perform app.assert_can('TICKET', 'TAO', v_branch);
  if v_type is null or v_type not in ('DN', 'KN', 'GV') then
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Loại ticket phải là Đề nghị, Khiếu nại hoặc Ticket giáo viên.');
  end if;
  -- Luật AS-05: chỉ giáo viên có quyền chỉ tạo mới tạo ticket giáo viên; người khác tạo đề nghị, khiếu nại.
  if v_type = 'GV' and not app.has_role_or_admin(array['TEACHER', 'TA']) then
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Chỉ giáo viên, trợ giảng tạo được ticket giáo viên.');
  end if;
  if v_type <> 'GV' and exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('TEACHER', 'TA'))
     and not app.has_permission('TICKET', 'SUA') then
    -- Giáo viên theo R-CS-10 tạo ticket cho lớp mình; luật AS-05 gom về Ticket giáo viên.
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Giáo viên tạo ticket loại Ticket giáo viên.');
  end if;
  -- Luật AS-02: các ô tiếp nhận bắt buộc (trừ đính kèm).
  if v_title is null or v_desc is null or v_channel is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Cần có tiêu đề, mô tả và kênh tiếp nhận.');
  end if;
  perform app.assert_catalog_code_active('TICKET_CHANNEL', v_channel);
  select * into v_cat from app.ticket_category where code = nullif(p_data ->> 'category_code', '') and kind = 'SUBGROUP' and is_active;
  if v_cat.id is null or v_cat.ticket_type <> v_type then
    perform app.raise_error('HMT_TICKET_NHOM_SAI', 'Nhóm con không có, đã Ngừng hoặc không thuộc loại ticket này.');
  end if;
  v_priority := coalesce(nullif(p_data ->> 'priority_code', ''), v_cat.default_priority);
  perform app.assert_catalog_code_active('TICKET_PRIORITY', v_priority);
  -- Luật AS-09/AS-05: người gửi theo loại.
  if v_type <> 'GV' and v_parent is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Đề nghị, khiếu nại cần chọn phụ huynh (người gửi).');
  end if;
  -- Luật AS-10, AS-05: nhóm con bắt buộc học sinh (đề nghị có nghiệp vụ; học kém, nghỉ nhiều) và lớp (học kém, nghỉ nhiều).
  if v_cat.requires_student and v_student is null then
    perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Nhóm con này bắt buộc chọn học sinh.');
  end if;
  if v_cat.requires_class and v_class is null then
    perform app.raise_error('HMT_TICKET_THIEU_LOP', 'Nhóm con này bắt buộc chọn lớp.');
  end if;
  select code into v_branch_code from app.branch where id = v_branch;
  -- Luật AS-07: hạn phản hồi đầu và hạn xử lý chụp lúc tạo (giờ lịch).
  select r.response_hours into v_resp_hours from app.ticket_sla_rule r where r.ticket_type = v_type and r.priority_code = v_priority;
  v_res_hours := app.ticket_resolve_hours(v_type, v_priority, v_cat.code);
  -- Luật AS-01: mã DN, KN, GV-<CS>-<YYMM>-<STT>.
  v_code := app.issue_document_number(v_type, v_branch_code);
  insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, parent_id, sender_user_id,
                          student_id, class_id, enrollment_id, accused_user_id, related_ticket_id, response_due_at, resolve_due_at)
  values (v_code, v_type, v_branch, v_title, v_desc, v_channel, v_cat.code, v_priority, v_parent, case when v_type = 'GV' then auth.uid() end,
          v_student, v_class, nullif(p_data ->> 'enrollment_id', '')::uuid, nullif(p_data ->> 'accused_user_id', '')::uuid,
          nullif(p_data ->> 'related_ticket_id', '')::uuid, v_now + make_interval(hours => v_resp_hours), v_now + make_interval(hours => v_res_hours))
  returning id into v_id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, to_status) values (v_id, v_branch, 'TAO', 'MOI');
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- app.teacher_class_tickets: chép nguyên bản 20261116000144, chỉ đổi điều kiện vai và phạm vi của Admin.
create or replace function app.teacher_class_tickets(p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total bigint;
  v_rows jsonb;
begin
  if not app.has_role_or_admin(array['TEACHER', 'TA']) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ giáo viên, trợ giảng xem được ticket lớp mình.');
  end if;
  perform app.require_feature('AFTERSALE', app.current_branch_id());
  with f as (
    select t from app.ticket t
     -- Admin: mọi ticket gắn lớp hoặc do giáo viên báo, ở mọi cơ sở; giáo viên, trợ giảng như cũ.
     where case when (select app.has_role_or_admin('{}')) then t.class_id is not null or t.ticket_type = 'GV'
                else t.branch_id = app.current_branch_id()
                     and (t.created_by = (select auth.uid()) or (t.class_id is not null and app.is_assigned_to_class(t.class_id))) end
  ), page as (
    select * from f order by (t).created_at desc, (t).id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(app.ticket_row(p.t)
           || jsonb_build_object('class_code', (select k.code from app.class k where k.id = (p.t).class_id),
                                 'student_name', (select s.full_name from app.student s where s.id = (p.t).student_id))
           order by (p.t).created_at desc, (p.t).id), '[]'::jsonb)
    into v_total, v_rows
    from page p;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.teacher_ticket_options: chép nguyên bản 20261116000144, chỉ đổi điều kiện vai; Admin chọn được mọi lớp của cơ sở đang làm việc.
create or replace function app.teacher_ticket_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := app.current_branch_id();
begin
  -- Chỉ giáo viên, trợ giảng (R-CS-10, AS-05).
  if not app.has_role_or_admin(array['TEACHER', 'TA']) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ giáo viên, trợ giảng dùng được màn này.');
  end if;
  perform app.require_feature('AFTERSALE', v_branch);
  return jsonb_build_object(
    'categories', coalesce((select jsonb_agg(jsonb_build_object(
        'code', c.code, 'name', c.name, 'group_code', g.code, 'group_name', g.name, 'nature_code', c.nature_code,
        'requires_student', c.requires_student, 'requires_class', c.requires_class) order by g.sort_order, c.sort_order)
      from app.ticket_category c join app.ticket_category g on g.code = c.parent_code
     where c.kind = 'SUBGROUP' and c.ticket_type = 'GV' and c.is_active and g.is_active), '[]'::jsonb),
    'classes', coalesce((select jsonb_agg(jsonb_build_object(
        'id', k.id, 'code', k.code,
        'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = k.subject_code),
        'students', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.full_name) order by s.full_name)
                                from app.student s
                               where s.id in (select e.student_id from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                               where ec.class_id = k.id and ec.end_date is null)), '[]'::jsonb)) order by k.code)
      from app.class k where k.status_code = 'DA_DUYET' and k.branch_id = v_branch and (app.has_role_or_admin('{}') or app.is_assigned_to_class(k.id))), '[]'::jsonb));
end;
$$;

-- app.teacher_create_ticket: chép nguyên bản 20261116000144, chỉ đổi điều kiện vai, phạm vi lớp của Admin, cơ sở của ticket.
create or replace function app.teacher_create_ticket(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_class uuid := nullif(p_data ->> 'class_id', '')::uuid;
  v_student uuid := nullif(p_data ->> 'student_id', '')::uuid;
  k app.class;
begin
  if not app.has_role_or_admin(array['TEACHER', 'TA']) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ giáo viên, trợ giảng tạo được ticket giáo viên.');
  end if;
  if v_class is not null then
    select * into k from app.class where id = v_class;
    -- Luật R-CS-10: lớp phải thuộc cơ sở của người tạo và người tạo được phân công ở lớp đó.
    if k.id is null or (not app.has_role_or_admin('{}')
       and (k.branch_id is distinct from app.current_branch_id() or not app.is_assigned_to_class(k.id))) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ tạo ticket cho lớp mình được phân công.');
    end if;
    if v_student is not null and not exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                              where ec.class_id = k.id and ec.end_date is null and e.student_id = v_student) then
      perform app.raise_error('HMT_EM_KHONG_TRONG_LOP', 'Học sinh này không đang học trong lớp đã chọn.');
    end if;
  elsif v_student is not null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn lớp trước khi chọn học sinh.');
  end if;
  -- Ticket thuộc cơ sở của lớp (Admin tạo cho lớp cơ sở khác); giáo viên vốn cùng cơ sở nên không đổi.
  return app.create_ticket(p_data || jsonb_build_object('ticket_type', 'GV', 'channel_code', 'GIAO_VIEN_BAO')
    || case when k.id is not null then jsonb_build_object('branch_id', k.branch_id) else '{}'::jsonb end);
end;
$$;
