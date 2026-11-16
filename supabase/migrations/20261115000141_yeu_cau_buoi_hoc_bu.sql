-- Yêu cầu buổi: BUOI-07 Tạo yêu cầu học bù (lát ba của cụm BUOI-07..10). Chạy sau migration 140. Chat chốt 16/11: LUẬT THẮNG CANVAS (R-BUOI-03 [CHỐT]):
-- CSKH tạo yêu cầu có LÝ DO bắt buộc, quản lý cơ sở duyệt → SINH BUỔI MỚI loại Học bù (không "chọn buổi có sẵn của lớp khác" như canvas BUOI07). Không trừ giờ,
-- không gắn buổi gốc, chưa giới hạn số buổi. Luật: R-BUOI-03, R-BUOI-01 (HOC_BU không trừ), R-BUOI-10, R-GIO-02, R-GIO-03, R-GIO-04, R-HT-01.
-- Thêm: loại HOC_BU ở session_request, cột reason (lý do bắt buộc khi Gửi duyệt), hàm save_makeup_request; mở rộng approve_session_request, list_session_requests,
-- build_session_roster (học bù chỉ gồm các em được chọn, như bổ trợ).

alter table app.session_request drop constraint session_request_kind_check;
alter table app.session_request add constraint session_request_kind_check check (kind in ('CUNG_CO', 'BO_TRO', 'HOC_BU'));
alter table app.session_request add column reason text;

-- app.save_makeup_request(id, lớp, mảng em, ngày, giờ bắt đầu, giờ kết thúc, giáo viên (tuỳ chọn), phòng, lý do) -> {id, code}
-- Tạo hoặc sửa yêu cầu học bù ở Nháp. Ai gọi: có quyền Buổi học · Tạo ở cơ sở của lớp (CSKH; ma trận quyền hiện chưa cho Sale quyền này). Cần phân hệ YEU_CAU_BUOI bật.
-- Luật R-BUOI-03: lý do bắt buộc; mỗi em phải đang học trong lớp; không gắn buổi gốc. Giáo viên bỏ trống thì khi duyệt lấy giáo viên khung giờ của lớp.
create or replace function app.save_makeup_request(p_id uuid, p_class_id uuid, p_student_ids uuid[], p_date date, p_start time, p_end time,
                                                   p_teacher_id uuid, p_room_id uuid default null, p_reason text default null)
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
    perform app.raise_error('HMT_LOP_CHUA_DUYET', 'Chỉ lớp đã duyệt mới có yêu cầu học bù.');
  end if;
  -- Luật R-BUOI-03: lý do bắt buộc.
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Nhập lý do học bù.');
  end if;
  if coalesce(array_length(v_ids, 1), 0) = 0 then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Chọn ít nhất một em học bù.');
  end if;
  if exists (select from unnest(v_ids) x
              where not exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                 where ec.class_id = c.id and e.student_id = x and ec.end_date is null)) then
    perform app.raise_error('HMT_EM_KHONG_TRONG_LOP', 'Có em không đang học trong lớp này.');
  end if;
  if p_date is null or p_start is null or p_end is null then
    perform app.raise_error('HMT_THIEU_NGAY_GIO', 'Nhập ngày và giờ buổi học bù.');
  end if;
  if p_end <= p_start then
    perform app.raise_error('HMT_BUOI_GIO_SAI', 'Giờ kết thúc phải sau giờ bắt đầu.');
  end if;
  if p_teacher_id is not null and not exists (
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
    insert into app.session_request (code, branch_id, kind, class_id, session_date, start_time, end_time, room_id, note, teacher_id, reason)
    values (v_code, c.branch_id, 'HOC_BU', c.id, p_date, p_start, p_end, p_room_id, null, p_teacher_id, btrim(p_reason))
    returning * into r;
  else
    select * into r from app.session_request where id = p_id for update;
    if r.id is null or r.branch_id <> c.branch_id or r.kind <> 'HOC_BU' then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu học bù.');
    end if;
    if r.status_code <> 'NHAP' then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ sửa được yêu cầu buổi ở tình trạng Nháp.');
    end if;
    update app.session_request set class_id = c.id, session_date = p_date, start_time = p_start, end_time = p_end, room_id = p_room_id,
           teacher_id = p_teacher_id, reason = btrim(p_reason) where id = r.id returning * into r;
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
       -- Luật R-BUOI-05, R-BUOI-03 (BUOI-09, BUOI-07): buổi học bổ trợ và học bù chỉ có các em yếu được chọn trong yêu cầu (không phải cả lớp).
       and (s.type_code not in ('BO_TRO', 'HOC_BU')
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
  insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id, type_code, status_code, is_manual)
  values (c.id, c.branch_id, r.session_date, r.start_time, r.end_time, v_teacher, v_assistant, r.room_id,
          case r.kind when 'BO_TRO' then 'BO_TRO' when 'HOC_BU' then 'HOC_BU' else 'CUNG_CO' end, 'NHAP', true)
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
           'student_count', case when p.kind in ('BO_TRO', 'HOC_BU') then (select count(*) from app.session_request_student rs where rs.request_id = p.id and rs.is_active)
                                 else (select count(distinct e.student_id) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                        where ec.class_id = c.id and ec.end_date is null) end,
           'student_names', case when p.kind in ('BO_TRO', 'HOC_BU') then (select coalesce(jsonb_agg(st.full_name order by st.full_name), '[]'::jsonb)
                                                               from app.session_request_student rs join app.student st on st.id = rs.student_id
                                                              where rs.request_id = p.id and rs.is_active) else '[]'::jsonb end,
           'teacher_name', app.staff_display_name(p.teacher_id),
           'session_date', p.session_date, 'start_time', p.start_time, 'end_time', p.end_time,
           'room_name', (select rm.name from app.room rm where rm.id = p.room_id),
           'note', p.note, 'reason', p.reason, 'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
           'reject_reason_code', p.reject_reason_code, 'reject_note', p.reject_note, 'created_session_id', p.created_session_id,
           'can_approve', p.status_code = 'CHO_DUYET' and (v_can_approve = 'TOAN_HE_THONG' or (v_can_approve = 'CO_SO' and p.branch_id = app.current_branch_id())))
           order by p.created_at desc, p.code desc), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.save_makeup_request(uuid, uuid, uuid[], date, time, time, uuid, uuid, text) from public, anon, authenticated;
grant execute on function app.save_makeup_request(uuid, uuid, uuid[], date, time, time, uuid, uuid, text) to authenticated;
