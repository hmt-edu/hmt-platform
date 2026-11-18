-- A25 (Chat duyệt có điều chỉnh 19/11/2026): yêu cầu buổi (BUOI-07, 08, 09) chọn được loại KIỂM TRA kèm cấu hình điểm; kiểm tra bù không trừ giờ.
-- Luật: R-V2-20 (buổi Kiểm tra: phạm vi, điểm tối đa, điểm tổng hoặc ba nhóm; tổng ba nhóm = điểm tối đa), R-V2-18 và Q-176 (kiểm tra TRỪ giờ như buổi Chính),
-- R-BUOI-03 (học bù không trừ giờ, không gắn buổi gốc), R-BUOI-05 (bổ trợ không trừ giờ). CHỖ CANVAS VÊNH LUẬT (anh Trường xác nhận): khung cho chọn mọi loại buổi (Chính, Củng cố...)
-- ở yêu cầu học bù, bản này CHỈ cho thêm loại Kiểm tra (một mã KIEM_TRA, không thêm KT_GIUA_KY, KT_CUOI_KY). Yêu cầu học bù, bổ trợ chọn Kiểm tra thì buổi sinh ra là KIEM_TRA nhưng KHÔNG trừ giờ
-- (thi bù, đi theo luật học bù); yêu cầu củng cố chọn Kiểm tra thì buổi trừ giờ như buổi Chính.
-- Cách làm: cột `class_session.no_charge` (không trừ giờ dù loại buổi có trừ), hàm app.session_deducts_hours(buổi) dùng thay cho app.session_type_deducts_hours(loại) ở HAI nơi tính giờ
-- (app.build_session_roster, app.deduct_session_hours), cột cấu hình điểm ở app.session_request, hàm app.set_request_exam, và duyệt (app.approve_session_request) chèn buổi đúng loại rồi đặt cấu hình điểm.

alter table app.class_session add column no_charge boolean not null default false;
comment on column app.class_session.no_charge is 'Buổi KHÔNG trừ giờ dù loại buổi có trừ (kiểm tra bù sinh từ yêu cầu học bù, bổ trợ; A25, R-BUOI-03). Mặc định false.';

alter table app.session_request
  add column session_type_code text check (session_type_code is null or session_type_code = 'KIEM_TRA'),
  add column exam_scope text,
  add column exam_max_score numeric(5, 2) check (exam_max_score is null or exam_max_score > 0),
  add column exam_mode text check (exam_mode is null or exam_mode in ('TONG', 'NHOM')),
  add column exam_max_memory numeric(5, 2) not null default 0 check (exam_max_memory >= 0),
  add column exam_max_understand numeric(5, 2) not null default 0 check (exam_max_understand >= 0),
  add column exam_max_apply numeric(5, 2) not null default 0 check (exam_max_apply >= 0);
comment on column app.session_request.session_type_code is 'Rỗng = loại theo yêu cầu (củng cố, học bù, bổ trợ); KIEM_TRA = sinh buổi Kiểm tra kèm cấu hình điểm exam_* (A25).';

-- app.session_deducts_hours(buổi): buổi có trừ giờ không = loại buổi trừ giờ VÀ không đặt no_charge. Thay app.session_type_deducts_hours(loại) ở nơi tính giờ theo buổi cụ thể.
create or replace function app.session_deducts_hours(p_session app.class_session)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select not p_session.no_charge and app.session_type_deducts_hours(p_session.type_code);
$$;
revoke execute on function app.session_deducts_hours(app.class_session) from public, anon, authenticated;

-- app.set_request_exam(yêu cầu, bật, phạm vi, điểm tối đa, cách nhập, tối đa ba nhóm): đặt hoặc bỏ loại Kiểm tra và cấu hình điểm cho yêu cầu NHÁP.
-- Ai gọi: Buổi học · Tạo ở cơ sở của yêu cầu (người tạo yêu cầu). Bật=false thì xoá cấu hình (về loại theo yêu cầu). Luật như app.set_exam_config (R-V2-20).
create or replace function app.set_request_exam(p_request_id uuid, p_enabled boolean, p_scope text default null, p_max_score numeric default null, p_mode text default null,
                                                p_max_memory numeric default 0, p_max_understand numeric default 0, p_max_apply numeric default 0)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
  v_max numeric;
begin
  select * into r from app.session_request where id = p_request_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'TAO', r.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', r.branch_id);
  -- Luật: chỉ sửa khi yêu cầu còn Nháp.
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ đặt loại buổi cho yêu cầu đang ở tình trạng Nháp.');
  end if;
  if not coalesce(p_enabled, false) then
    update app.session_request set session_type_code = null, exam_scope = null, exam_max_score = null, exam_mode = null,
           exam_max_memory = 0, exam_max_understand = 0, exam_max_apply = 0 where id = r.id;
    return;
  end if;
  if p_mode is null or p_mode not in ('TONG', 'NHOM') then
    perform app.raise_error('HMT_CACH_NHAP_DIEM_SAI', 'Cách nhập điểm là Điểm tổng hoặc Theo 3 nhóm.');
  end if;
  v_max := coalesce(p_max_score, app.get_setting_int('exam_default_max_score', r.branch_id));
  if v_max <= 0 then
    perform app.raise_error('HMT_DIEM_TOI_DA_SAI', 'Điểm tối đa phải lớn hơn 0.');
  end if;
  -- Luật R-V2-20: theo 3 nhóm thì tổng tối đa 3 nhóm bằng điểm tối đa của buổi.
  if p_mode = 'NHOM' and coalesce(p_max_memory, 0) + coalesce(p_max_understand, 0) + coalesce(p_max_apply, 0) <> v_max then
    perform app.raise_error('HMT_DIEM_NHOM_KHONG_KHOP', 'Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi.');
  end if;
  update app.session_request set session_type_code = 'KIEM_TRA', exam_scope = nullif(btrim(coalesce(p_scope, '')), ''), exam_max_score = v_max, exam_mode = p_mode,
         exam_max_memory = case when p_mode = 'NHOM' then coalesce(p_max_memory, 0) else 0 end,
         exam_max_understand = case when p_mode = 'NHOM' then coalesce(p_max_understand, 0) else 0 end,
         exam_max_apply = case when p_mode = 'NHOM' then coalesce(p_max_apply, 0) else 0 end
   where id = r.id;
end;
$$;
revoke execute on function app.set_request_exam(uuid, boolean, text, numeric, text, numeric, numeric, numeric) from public, anon, authenticated;
grant execute on function app.set_request_exam(uuid, boolean, text, numeric, text, numeric, numeric, numeric) to authenticated;

-- Ba hàm dưới thay bản cũ (chỉ đổi đúng các dòng ghi chú «A25» hoặc dùng app.session_deducts_hours / no_charge; phần còn lại giữ nguyên bản ở migration 102, 141).

create or replace function app.build_session_roster(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_hours numeric := app.session_hours(p_session_id);
  v_deducts boolean;
  v_ahead integer := app.get_setting_int('max_sessions_ahead', (select branch_id from app.class_session where id = p_session_id));
  r record;
  v_pick uuid;
  v_reason text;
  v_n integer := 0;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.status_code <> 'NHAP' then
    perform app.raise_error('HMT_BUOI_KHONG_CHOT_DUOC', 'Chỉ chốt danh sách buổi đang ở Nháp.');
  end if;
  v_deducts := app.session_deducts_hours(s);
  for r in
    select e.student_id,
           (array_agg(e.id order by ec.start_date, e.created_at, e.id)) as enr_ids
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
     where ec.class_id = s.class_id and (ec.end_date is null or ec.end_date >= s.session_date)
       -- Luật R-GIO-02: ghi danh sinh sau ngày buổi không lọt vào danh sách.
       and (e.created_at at time zone 'Asia/Ho_Chi_Minh')::date <= s.session_date
       -- Luật R-BUOI-05, R-BUOI-03 (BUOI-09, BUOI-07): buổi học bổ trợ và học bù chỉ có các em yếu được chọn trong yêu cầu (không phải cả lớp).
       and (not (s.type_code in ('BO_TRO', 'HOC_BU') or s.no_charge)
            or e.student_id in (select rs.student_id from app.session_request_student rs
                                  join app.session_request q on q.id = rs.request_id where q.created_session_id = s.id and rs.is_active))
     group by e.student_id
  loop
    v_pick := null;
    v_reason := null;
    -- Mỗi em chọn một ghi danh đủ điều kiện, ưu tiên ghi danh vào lớp sớm nhất (R-GIO-04).
    select e.id into v_pick
      from unnest(r.enr_ids) with ordinality as t (eid, ord)
      join app.enrollment e on e.id = t.eid
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = s.class_id
     where ec.start_date <= s.session_date and (ec.end_date is null or ec.end_date >= s.session_date)
       and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
       and (not v_deducts
            or app.enrollment_hours_balance(e.id) + case when e.pay_later_enabled then v_ahead * v_hours else 0 end >= v_hours)
     order by t.ord
     limit 1;
    if v_pick is null then
      -- Lý do của ghi danh đầu tiên (Luật R-GIO-03).
      select case
               when ec.start_date > s.session_date then 'CHUA_TOI_NGAY_VAO'
               when e.status_code = 'BAO_LUU' then 'BAO_LUU'
               when e.status_code in ('DUNG', 'HOAN_PHI', 'HOAN_THANH', 'CHUYEN_LOP') then 'KET_THUC'
               else 'HET_GIO'
             end into v_reason
        from unnest(r.enr_ids) with ordinality as t (eid, ord)
        join app.enrollment e on e.id = t.eid
        join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = s.class_id
       order by t.ord limit 1;
      insert into app.session_attendance (session_id, class_id, branch_id, student_id, is_active, excluded_reason)
      values (s.id, s.class_id, s.branch_id, r.student_id, false, v_reason);
    else
      insert into app.session_attendance (session_id, class_id, branch_id, student_id, enrollment_id)
      values (s.id, s.class_id, s.branch_id, r.student_id, v_pick);
      v_n := v_n + 1;
    end if;
  end loop;
  update app.class_session set status_code = 'DA_CHOT' where id = s.id;
  return v_n;
end;
$$;

create or replace function app.deduct_session_hours(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_hours numeric := app.session_hours(p_session_id);
  v_ahead integer;
  r record;
  v_balance numeric;
  v_n integer := 0;
begin
  select * into s from app.class_session where id = p_session_id;
  if not app.session_deducts_hours(s) then
    return 0;
  end if;
  v_ahead := app.get_setting_int('max_sessions_ahead', s.branch_id);
  for r in select sa.enrollment_id, e.pay_later_enabled, e.branch_id as e_branch
             from app.session_attendance sa join app.enrollment e on e.id = sa.enrollment_id
            where sa.session_id = p_session_id and sa.is_active and not sa.is_trial and sa.enrollment_id is not null loop
    v_balance := app.enrollment_hours_balance(r.enrollment_id);
    if v_balance - v_hours < -(case when r.pay_later_enabled then v_ahead * v_hours else 0 end) then
      perform app.raise_error('HMT_QUY_GIO_AM', 'Quỹ giờ của một học sinh không đủ cho buổi này. Điều chỉnh giờ hoặc loại em khỏi danh sách rồi Done lại.');
    end if;
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id)
    values (r.enrollment_id, r.e_branch, 'TRU_BUOI', -v_hours, p_session_id)
    on conflict do nothing;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

create or replace function app.approve_session_request(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
  c app.class;
  v_session uuid;
  v_teacher uuid;
  v_assistant uuid;
begin
  select * into r from app.session_request where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'DUYET', r.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', r.branch_id);
  if r.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được yêu cầu buổi ở tình trạng Chờ duyệt.');
  end if;
  select * into c from app.class where id = r.class_id;
  if c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_LOP_CHUA_DUYET', 'Lớp không còn ở tình trạng đã duyệt nên không chèn thêm buổi được.');
  end if;
  if r.session_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    perform app.raise_error('HMT_NGAY_BUOI_QUA_KHU', 'Ngày buổi củng cố đã qua, không chèn được. Từ chối yêu cầu và tạo yêu cầu mới.');
  end if;
  if r.kind in ('BO_TRO', 'HOC_BU') then
    -- Luật R-BUOI-05, R-BUOI-03: học bổ trợ và học bù không trừ giờ học sinh; giáo viên là người được chọn (học bù không chọn thì lấy giáo viên khung giờ của lớp), vẫn tính giờ dạy; danh sách chỉ các em được chọn (build_session_roster).
    v_teacher := coalesce(r.teacher_id, (select sl.teacher_id from app.class_slot sl where sl.class_id = c.id and sl.is_active order by sl.weekday, sl.start_time limit 1));
    v_assistant := null;
  else
    select sl.teacher_id, sl.assistant_id into v_teacher, v_assistant
      from app.class_slot sl
     where sl.class_id = c.id and sl.is_active
     order by (sl.weekday = extract(isodow from r.session_date)::integer) desc, sl.weekday, sl.start_time
     limit 1;
  end if;
  insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id, type_code, status_code, is_manual, no_charge)
  values (c.id, c.branch_id, r.session_date, r.start_time, r.end_time, v_teacher, v_assistant, r.room_id,
          case when r.session_type_code = 'KIEM_TRA' then 'KIEM_TRA' else case r.kind when 'BO_TRO' then 'BO_TRO' when 'HOC_BU' then 'HOC_BU' else 'CUNG_CO' end end, 'NHAP', true,
          -- Luật (Chat 19/11, R-BUOI-03, R-V2-20): kiểm tra BÙ (từ yêu cầu học bù, bổ trợ) KHÔNG trừ giờ; kiểm tra từ yêu cầu củng cố trừ giờ như buổi Chính (R-V2-18).
          coalesce(r.session_type_code = 'KIEM_TRA', false) and r.kind in ('BO_TRO', 'HOC_BU'))
  returning id into v_session;
  -- Loại Kiểm tra (A25): đặt cấu hình điểm đã nhập ở yêu cầu (cùng luật app.set_exam_config; người duyệt có quyền Sửa buổi ở cơ sở).
  if r.session_type_code = 'KIEM_TRA' then
    perform app.set_exam_config(v_session, r.exam_scope, r.exam_max_score, r.exam_mode, r.exam_max_memory, r.exam_max_understand, r.exam_max_apply);
  end if;
  perform app.renumber_class_sessions(c.id);
  update app.session_request set status_code = 'DA_DUYET', decided_at = now(), decided_by = auth.uid(), created_session_id = v_session where id = r.id;
  return jsonb_build_object('session_id', v_session, 'warnings', app.class_clash_warnings(c.id));
end;
$$;

create or replace function app.list_session_requests(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SESSION', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array'
                          then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_can_approve text := app.permission_scope('SESSION', 'DUYET');
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null or v_scope = 'DUOC_PHAN_CONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem yêu cầu buổi.');
  end if;
  with f as (
    select r.* from app.session_request r
     where (v_scope = 'TOAN_HE_THONG' or r.branch_id = app.current_branch_id())
       and (v_status is null or r.status_code = any (v_status))
       and (v_class is null or r.class_id = v_class)
  ), page as (
    select * from f order by created_at desc, code desc limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id, 'code', p.code, 'kind', p.kind, 'status_code', p.status_code,
           'class_id', p.class_id, 'class_code', c.code,
           'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
           'student_count', case when p.kind in ('BO_TRO', 'HOC_BU') then (select count(*) from app.session_request_student rs where rs.request_id = p.id and rs.is_active)
                                 else (select count(distinct e.student_id) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                        where ec.class_id = c.id and ec.end_date is null) end,
           'student_names', case when p.kind in ('BO_TRO', 'HOC_BU') then (select coalesce(jsonb_agg(st.full_name order by st.full_name), '[]'::jsonb)
                                                               from app.session_request_student rs join app.student st on st.id = rs.student_id
                                                              where rs.request_id = p.id and rs.is_active) else '[]'::jsonb end,
           'teacher_name', app.staff_display_name(p.teacher_id),
           'session_date', p.session_date, 'start_time', p.start_time, 'end_time', p.end_time,
           'room_name', (select rm.name from app.room rm where rm.id = p.room_id),
           'note', p.note, 'reason', p.reason, 'session_type_code', p.session_type_code,
           'exam', case when p.session_type_code = 'KIEM_TRA' then jsonb_build_object('scope', p.exam_scope, 'max_score', p.exam_max_score, 'mode', p.exam_mode,
                         'max_memory', p.exam_max_memory, 'max_understand', p.exam_max_understand, 'max_apply', p.exam_max_apply) end, 'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
           'reject_reason_code', p.reject_reason_code, 'reject_note', p.reject_note, 'created_session_id', p.created_session_id,
           'can_approve', p.status_code = 'CHO_DUYET' and (v_can_approve = 'TOAN_HE_THONG' or (v_can_approve = 'CO_SO' and p.branch_id = app.current_branch_id())))
           order by p.created_at desc, p.code desc), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
-- create or replace giữ nguyên quyền gọi đã cấp ở migration 102, 141.
