-- Yêu cầu buổi: BUOI-09 Tạo yêu cầu học bổ trợ (lát hai của cụm BUOI-07..10; học bù BUOI-07 chờ Chat chốt luật). Chạy sau migration 139 (bảng session_request).
-- Luật: R-BUOI-05 (học bổ trợ: kèm thêm cho em yếu, tạo từ lớp, quản lý cơ sở duyệt, không trừ giờ, vẫn tính vào giờ dạy của giáo viên), R-BUOI-01 (BO_TRO không trừ giờ),
-- R-BUOI-10 (chỉ quản lý cơ sở duyệt), R-GV-14 (giờ dạy tính cho người dạy thật), R-GIO-02, R-GIO-03, R-GIO-04 (danh sách buổi như mọi buổi, chỉ lọc theo em được chọn).
-- Thêm: loại BO_TRO ở session_request, cột teacher_id, bảng session_request_student (các em yếu được chọn), hàm save_support_request; mở rộng approve_session_request
-- (chèn buổi BO_TRO với giáo viên được chọn), list_session_requests (tên em, tên giáo viên) và build_session_roster (buổi BO_TRO chỉ gồm các em được chọn).

alter table app.session_request drop constraint session_request_kind_check;
alter table app.session_request add constraint session_request_kind_check check (kind in ('CUNG_CO', 'BO_TRO'));
alter table app.session_request add column teacher_id uuid references app.user_account (id);
-- Chỉ mục (lý do): khoá ngoại giáo viên cho báo cáo, lọc.
create index session_request_teacher_idx on app.session_request (teacher_id) where teacher_id is not null;

create table app.session_request_student (
  id uuid not null unique default gen_random_uuid(),
  request_id uuid not null references app.session_request (id),
  student_id uuid not null references app.student (id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (request_id, student_id)
);
comment on table app.session_request_student is 'Các em yếu được chọn trong yêu cầu học bổ trợ (R-BUOI-05).';
-- Chỉ mục (lý do): tìm yêu cầu theo em; khoá chính (yêu cầu, em) đã phục vụ đọc theo yêu cầu.
create index session_request_student_student_idx on app.session_request_student (student_id);
select app.apply_standard('app.session_request_student');
alter table app.session_request_student enable row level security;
grant select on app.session_request_student to authenticated;
create policy session_request_student_read on app.session_request_student for select to authenticated
  using (exists (select from app.session_request q where q.id = request_id));

-- app.save_support_request(id, lớp, mảng em, ngày, giờ bắt đầu, giờ kết thúc, giáo viên, phòng, ghi chú) -> {id, code}
-- Tạo hoặc sửa yêu cầu học bổ trợ ở Nháp (tạo từ lớp, R-BUOI-05). Ai gọi: có quyền Buổi học · Tạo ở cơ sở của lớp. Cần phân hệ YEU_CAU_BUOI bật.
-- Mỗi em phải đang học trong lớp (còn dòng ghi danh vào lớp, chưa kết thúc); ít nhất một em; giáo viên phải có vai trò Giáo viên và thuộc cơ sở của lớp.
create or replace function app.save_support_request(p_id uuid, p_class_id uuid, p_student_ids uuid[], p_date date, p_start time, p_end time,
                                                    p_teacher_id uuid, p_room_id uuid default null, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  r app.session_request;
  v_code text;
  v_branch_code text;
  v_ids uuid[] := array(select distinct x from unnest(coalesce(p_student_ids, '{}'::uuid[])) x);
begin
  select * into c from app.class where id = p_class_id;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  perform app.assert_can('SESSION', 'TAO', c.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', c.branch_id);
  if c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_LOP_CHUA_DUYET', 'Chỉ lớp đã duyệt mới có yêu cầu học bổ trợ.');
  end if;
  if coalesce(array_length(v_ids, 1), 0) = 0 then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Chọn ít nhất một em cần bổ trợ.');
  end if;
  -- Luật R-BUOI-05: chỉ em đang học trong lớp này.
  if exists (select from unnest(v_ids) x
              where not exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                 where ec.class_id = c.id and e.student_id = x and ec.end_date is null)) then
    perform app.raise_error('HMT_EM_KHONG_TRONG_LOP', 'Có em không đang học trong lớp này.');
  end if;
  if p_date is null or p_start is null or p_end is null then
    perform app.raise_error('HMT_THIEU_NGAY_GIO', 'Nhập ngày và giờ buổi học bổ trợ.');
  end if;
  if p_end <= p_start then
    perform app.raise_error('HMT_BUOI_GIO_SAI', 'Giờ kết thúc phải sau giờ bắt đầu.');
  end if;
  if p_teacher_id is null or not exists (
       select from app.user_account u
        where u.id = p_teacher_id and not u.is_locked and u.branch_id = c.branch_id
          and exists (select from app.user_role ur where ur.user_id = u.id and ur.is_active and ur.role_code = 'TEACHER')) then
    perform app.raise_error('HMT_GIAO_VIEN_KHONG_HOP_LE', 'Chọn giáo viên của cơ sở này.');
  end if;
  if p_room_id is not null and not exists (select from app.room where id = p_room_id and branch_id = c.branch_id and is_active) then
    perform app.raise_error('HMT_PHONG_KHONG_CO', 'Phòng không có hoặc đã Ngừng ở cơ sở của lớp.');
  end if;
  if p_id is null then
    select code into v_branch_code from app.branch where id = c.branch_id;
    v_code := app.issue_document_number('YB', v_branch_code);
    insert into app.session_request (code, branch_id, kind, class_id, session_date, start_time, end_time, room_id, note, teacher_id)
    values (v_code, c.branch_id, 'BO_TRO', c.id, p_date, p_start, p_end, p_room_id, nullif(btrim(p_note), ''), p_teacher_id)
    returning * into r;
  else
    select * into r from app.session_request where id = p_id for update;
    if r.id is null or r.branch_id <> c.branch_id or r.kind <> 'BO_TRO' then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu học bổ trợ.');
    end if;
    if r.status_code <> 'NHAP' then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ sửa được yêu cầu buổi ở tình trạng Nháp.');
    end if;
    update app.session_request set class_id = c.id, session_date = p_date, start_time = p_start, end_time = p_end, room_id = p_room_id,
           note = nullif(btrim(p_note), ''), teacher_id = p_teacher_id where id = r.id returning * into r;
    -- Bảng không cho xoá cứng: em bị bỏ ra khỏi yêu cầu thì tắt is_active.
    update app.session_request_student set is_active = false where request_id = r.id and student_id <> all (v_ids);
  end if;
  insert into app.session_request_student (request_id, student_id) select r.id, x from unnest(v_ids) x
  on conflict (request_id, student_id) do update set is_active = true;
  return jsonb_build_object('id', r.id, 'code', r.code);
end;
$$;

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
  v_deducts := app.session_type_deducts_hours(s.type_code);
  for r in
    select e.student_id,
           (array_agg(e.id order by ec.start_date, e.created_at, e.id)) as enr_ids
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
     where ec.class_id = s.class_id and (ec.end_date is null or ec.end_date >= s.session_date)
       -- Luật R-GIO-02: ghi danh sinh sau ngày buổi không lọt vào danh sách.
       and (e.created_at at time zone 'Asia/Ho_Chi_Minh')::date <= s.session_date
       -- Luật R-BUOI-05 (BUOI-09): buổi học bổ trợ chỉ có các em yếu được chọn trong yêu cầu (không phải cả lớp).
       and (s.type_code <> 'BO_TRO'
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
  if r.kind = 'BO_TRO' then
    -- Luật R-BUOI-05: học bổ trợ do giáo viên được chọn dạy, không trừ giờ học sinh, vẫn tính giờ dạy; danh sách chỉ các em được chọn (build_session_roster).
    v_teacher := r.teacher_id;
    v_assistant := null;
  else
    select sl.teacher_id, sl.assistant_id into v_teacher, v_assistant
      from app.class_slot sl
     where sl.class_id = c.id and sl.is_active
     order by (sl.weekday = extract(isodow from r.session_date)::integer) desc, sl.weekday, sl.start_time
     limit 1;
  end if;
  insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id, type_code, status_code, is_manual)
  values (c.id, c.branch_id, r.session_date, r.start_time, r.end_time, v_teacher, v_assistant, r.room_id,
          case when r.kind = 'BO_TRO' then 'BO_TRO' else 'CUNG_CO' end, 'NHAP', true)
  returning id into v_session;
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
           'student_count', case when p.kind = 'BO_TRO' then (select count(*) from app.session_request_student rs where rs.request_id = p.id and rs.is_active)
                                 else (select count(distinct e.student_id) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                        where ec.class_id = c.id and ec.end_date is null) end,
           'student_names', case when p.kind = 'BO_TRO' then (select coalesce(jsonb_agg(st.full_name order by st.full_name), '[]'::jsonb)
                                                               from app.session_request_student rs join app.student st on st.id = rs.student_id
                                                              where rs.request_id = p.id and rs.is_active) else '[]'::jsonb end,
           'teacher_name', app.staff_display_name(p.teacher_id),
           'session_date', p.session_date, 'start_time', p.start_time, 'end_time', p.end_time,
           'room_name', (select rm.name from app.room rm where rm.id = p.room_id),
           'note', p.note, 'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
           'reject_reason_code', p.reject_reason_code, 'reject_note', p.reject_note, 'created_session_id', p.created_session_id,
           'can_approve', p.status_code = 'CHO_DUYET' and (v_can_approve = 'TOAN_HE_THONG' or (v_can_approve = 'CO_SO' and p.branch_id = app.current_branch_id())))
           order by p.created_at desc, p.code desc), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.save_support_request(uuid, uuid, uuid[], date, time, time, uuid, uuid, text) from public, anon, authenticated;
grant execute on function app.save_support_request(uuid, uuid, uuid[], date, time, time, uuid, uuid, text) to authenticated;
