-- Cụm Buổi B (BUOI-04 Huỷ buổi, BUOI-05 Dời buổi, BUOI-12 Buổi chưa hoàn tất): lưu lý do huỷ buổi và các hàm đọc, nhắc cho giao diện.
-- Luật: R-BUOI-06 (trung tâm huỷ: không tính phí, tự thêm buổi cuối), R-BUOI-07 (lớp riêng: người huỷ chọn có/không tính phí, bắt buộc lý do), R-BUOI-09 (huỷ tới khi Done),
-- R-LOP-08 (trùng phòng, giáo viên chỉ cảnh báo), R-GIO-06 (lý do chưa Done), R-GV-05 (hạn giáo viên hoàn tất = giờ kết thúc + teacher_session_complete_hours), R-HT-07 (giờ Việt Nam).
-- Không đổi luật huỷ, dời: chỉ LƯU lý do huỷ (app.cancel_session thay bản 102, thêm đúng một dòng lưu) và thêm hàm đọc, nhắc.

-- 1. Lý do huỷ buổi lưu cùng buổi (danh mục SESSION_CANCEL_REASON) để BUOI-01, BUOI-02 hiện lại.
alter table app.class_session
  add column cancel_reason_catalog text not null default 'SESSION_CANCEL_REASON' check (cancel_reason_catalog = 'SESSION_CANCEL_REASON'),
  add column cancel_reason_code text,
  add column cancel_note text,
  add constraint class_session_cancel_reason_fk foreign key (cancel_reason_catalog, cancel_reason_code) references app.catalog_item (catalog_code, code);
comment on column app.class_session.cancel_reason_code is 'Lý do huỷ buổi (SESSION_CANCEL_REASON); chỉ có khi buổi ở nhánh Huỷ. Buổi huỷ trước migration 123 để trống.';
-- Chỉ mục: không thêm (không lọc, không sắp theo cột này; chỉ đọc cùng dòng buổi). Khoá ngoại ghép trỏ danh mục nhỏ, không cần chỉ mục.

-- Loại thông báo cho "Nhắc giáo viên" (BUOI-12).
-- Danh mục hệ thống: thêm mục được khi đang chạy migration.
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note)
values ('NOTIFICATION_KIND', 'NHAC_HOAN_TAT_BUOI', 'Nhắc hoàn tất buổi', 2, false)
on conflict (catalog_code, code) do nothing;
select set_config('hmt.migration', '', false);

-- 2. app.cancel_session: giữ nguyên luật huỷ (migration 102), thêm lưu lý do, ghi chú.
create or replace function app.cancel_session(p_session_id uuid, p_kind text, p_reason_code text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_requires_note boolean;
  v_center boolean;
  v_kind text;
  v_slots jsonb;
  v_made uuid;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  select * into c from app.class where id = s.class_id;
  perform app.require_feature('VAN_HANH_LOP', s.branch_id);
  -- Luật R-BUOI-09: huỷ được tới khi Done.
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_HUY_DUOC', 'Chỉ huỷ được buổi chưa Done và chưa huỷ. Buổi đã Done sai thì sửa điểm danh kèm lý do.');
  end if;
  perform app.assert_catalog_code_active('SESSION_CANCEL_REASON', p_reason_code);
  select requires_note into v_requires_note from app.catalog_item where catalog_code = 'SESSION_CANCEL_REASON' and code = p_reason_code;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  v_center := p_reason_code like 'TT\_%';
  if v_center then
    -- Luật R-BUOI-06: trung tâm huỷ thì không tính phí.
    v_kind := 'HUY_KHONG_PHI';
  else
    -- Luật R-BUOI-07: học sinh huỷ chỉ áp lớp riêng; người huỷ tự chọn có/không tính phí.
    if c.class_type_code <> 'LR' then
      perform app.raise_error('HMT_HUY_BUOI_HS_CHI_LOP_RIENG', 'Lý do của học sinh chỉ dùng cho lớp riêng. Lớp chung huỷ vì lý do của trung tâm.');
    end if;
    if p_kind is null or p_kind not in ('HUY_CO_PHI', 'HUY_KHONG_PHI') then
      perform app.raise_error('HMT_HUY_BUOI_CAN_CHON_KIEU', 'Chọn huỷ có tính phí hoặc không tính phí.');
    end if;
    v_kind := p_kind;
  end if;
  -- Huỷ có tính phí: cần danh sách để trừ giờ; buổi Nháp thì chốt trước.
  if v_kind = 'HUY_CO_PHI' then
    if s.status_code = 'NHAP' then
      perform app.build_session_roster(s.id);
    end if;
    perform app.deduct_session_hours(s.id);
  end if;
  update app.session_attendance set is_active = false where session_id = s.id and is_active;
  -- Lưu lý do và ghi chú huỷ (BUOI-04: BUOI-01, BUOI-02 hiện lại lý do).
  update app.class_session set status_code = v_kind, cancel_reason_code = p_reason_code, cancel_note = nullif(btrim(coalesce(p_note, '')), '') where id = s.id;

  -- Luật R-BUOI-06: trung tâm huỷ thì tự thêm một buổi vào cuối lịch, đánh lại số buổi.
  if v_center then
    select coalesce(jsonb_agg(jsonb_build_object('start_time', sl.start_time, 'end_time', sl.end_time, 'repeat_weeks', sl.repeat_weeks,
                                                 'first_date', sl.first_date, 'id', sl.id)), '[]'::jsonb)
      into v_slots from app.class_slot sl where sl.class_id = c.id and sl.is_active;
    insert into app.class_session (class_id, branch_id, slot_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id)
    select c.id, c.branch_id, sl.id, x.session_date, x.start_time, x.end_time, sl.teacher_id, sl.assistant_id, sl.room_id
      from app.compute_class_schedule(c.branch_id,
             (select max(session_date) from app.class_session where class_id = c.id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI')) + 1,
             1, v_slots) x
      join app.class_slot sl on sl.id = (v_slots -> x.slot_no ->> 'id')::uuid
    returning id into v_made;
    perform app.renumber_class_sessions(c.id);
    update app.class set expected_end_date = (select max(session_date) from app.class_session
                                               where class_id = c.id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI'))
     where id = c.id;
  end if;
  return jsonb_build_object('status', v_kind, 'added_session_id', v_made);
end;
$$;



-- 3. app.session_cancel_preview(buổi): BUOI-04 "xem trước" khi trung tâm huỷ: buổi sẽ thêm vào cuối lịch (số buổi, ngày). Chỉ đọc, không ghi.
-- Ai gọi: Buổi học · Sửa (vận hành, không phải giáo viên). Kết quả: {added_session_no, added_date}; không tính được thì cả hai null.
create or replace function app.session_cancel_preview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_slots jsonb;
  v_date date;
  v_no integer;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  -- Luật R-BUOI-06: buổi thêm vào cuối lịch, theo các khung giờ đang dùng, sau buổi cuối đang sống.
  select coalesce(jsonb_agg(jsonb_build_object('start_time', sl.start_time, 'end_time', sl.end_time, 'repeat_weeks', sl.repeat_weeks,
                                               'first_date', sl.first_date, 'id', sl.id)), '[]'::jsonb)
    into v_slots from app.class_slot sl where sl.class_id = s.class_id and sl.is_active;
  select x.session_date into v_date
    from app.compute_class_schedule(s.branch_id,
           (select max(session_date) from app.class_session where class_id = s.class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI')) + 1,
           1, v_slots) x limit 1;
  -- Sau khi huỷ buổi này (không tính phí) buổi thêm là buổi cuối: số buổi = số buổi đang sống (không kể buổi này) + 1.
  select count(*) + 1 into v_no from app.class_session
   where class_id = s.class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI') and id <> s.id;
  return jsonb_build_object('added_session_no', case when v_date is null then null else v_no end, 'added_date', v_date);
end;
$$;

-- 4. app.session_move_options(buổi): BUOI-05, danh sách phòng đang dùng của cơ sở để chọn (và phòng hiện tại của buổi). Ai gọi: Buổi học · Sửa (không phải giáo viên).
-- Kết quả: {rooms: [{id, code, name}], current_room_id}.
create or replace function app.session_move_options(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  return jsonb_build_object('current_room_id', s.room_id, 'rooms', coalesce((
    select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'name', r.name) order by r.sort_order, r.code)
      from app.room r where r.branch_id = s.branch_id and (r.is_active or r.id = s.room_id)), '[]'::jsonb));
end;
$$;

-- 5. app.session_move_check(buổi, ngày, giờ bắt đầu, giờ kết thúc, phòng): BUOI-05 "kiểm trùng" TRƯỚC khi lưu (R-LOP-08: chỉ cảnh báo, không chặn).
-- Kết quả: {room_clash: [chữ], teacher_clash: [chữ]}; mỗi chữ nêu buổi đang chiếm phòng hoặc giáo viên đó cùng giờ. Chỉ đọc. Ai gọi: Buổi học · Sửa.
create or replace function app.session_move_check(p_session_id uuid, p_date date, p_start time, p_end time, p_room_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_room uuid;
  v_rooms jsonb;
  v_teachers jsonb;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  v_room := coalesce(p_room_id, s.room_id);
  if p_date is null or p_start is null or p_end is null or p_end <= p_start then
    return jsonb_build_object('room_clash', '[]'::jsonb, 'teacher_clash', '[]'::jsonb);
  end if;
  -- Luật R-LOP-08: trùng phòng cùng ngày, giờ giao nhau với buổi còn sống của lớp khác (hoặc buổi khác của cùng lớp).
  select coalesce(jsonb_agg(format('%s ngày %s %s–%s đã có buổi %s · Buổi %s', r.code, to_char(b.session_date, 'DD/MM/YYYY'),
           to_char(b.start_time, 'HH24:MI'), to_char(b.end_time, 'HH24:MI'), c.code, coalesce(b.session_no::text, '—'))), '[]'::jsonb)
    into v_rooms
    from app.class_session b join app.class c on c.id = b.class_id join app.room r on r.id = b.room_id
   where v_room is not null and b.room_id = v_room and b.id <> s.id and b.session_date = p_date
     and b.start_time < p_end and p_start < b.end_time and b.status_code in ('NHAP', 'DA_CHOT', 'DONE');
  select coalesce(jsonb_agg(format('Giáo viên %s đã có buổi %s · Buổi %s ngày %s %s–%s', coalesce(t.display_name, ''), c.code, coalesce(b.session_no::text, '—'),
           to_char(b.session_date, 'DD/MM/YYYY'), to_char(b.start_time, 'HH24:MI'), to_char(b.end_time, 'HH24:MI'))), '[]'::jsonb)
    into v_teachers
    from app.class_session b join app.class c on c.id = b.class_id left join app.user_account t on t.id = b.teacher_id
   where s.teacher_id is not null and b.teacher_id = s.teacher_id and b.id <> s.id and b.session_date = p_date
     and b.start_time < p_end and p_start < b.end_time and b.status_code in ('NHAP', 'DA_CHOT', 'DONE');
  return jsonb_build_object('room_clash', v_rooms, 'teacher_clash', v_teachers);
end;
$$;

-- 6. app.session_pending_list(bộ lọc, số dòng, bỏ qua): BUOI-12, buổi Đã chốt đã kết thúc mà giáo viên chưa hoàn tất, kèm hạn (R-GV-05) và lý do chưa Done (R-GIO-06).
-- Ai gọi: Buổi học · Xem (toàn hệ thống hoặc cơ sở). Bộ lọc: branch_id, q (mã lớp), kind ('QUA_HAN' đã quá hạn; 'CON_HAN' còn hạn).
-- Sắp xếp: hạn sớm nhất trước (quá hạn nhiều nhất đứng đầu). Kết quả: {total, rows: [{id, class_code, subject_name, session_no, session_date, start_time, teacher_name,
--   deadline, minutes_left (âm = quá hạn), reason}]}.
create or replace function app.session_pending_list(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_result jsonb;
begin
  with f as not materialized (
    select s.*, c.code as class_code, c.subject_catalog, c.subject_code, c.search_text,
           ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh')
             + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer) as deadline
      from app.class_session s join app.class c on c.id = s.class_id
     where s.status_code = 'DA_CHOT'
       and ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') <= now()
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), g as (
    select * from f where v_kind is null or (v_kind = 'QUA_HAN' and f.deadline < now()) or (v_kind = 'CON_HAN' and f.deadline >= now())
  ), page as (
    select * from g order by g.deadline, g.id limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', p.id, 'class_code', p.class_code, 'subject_name', sub.name, 'session_no', p.session_no, 'session_date', p.session_date,
                      'start_time', to_char(p.start_time, 'HH24:MI'), 'teacher_name', t.display_name, 'deadline', p.deadline,
                      'minutes_left', floor(extract(epoch from (p.deadline - now())) / 60)::integer, -- allow-number: 60 giây một phút
                      'reason', app.session_pending_reason(p.id)) order by p.deadline, p.id)
               from page p
               join app.catalog_item sub on sub.catalog_code = p.subject_catalog and sub.code = p.subject_code
               left join app.user_account t on t.id = p.teacher_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- 7. app.remind_teacher_session(buổi): BUOI-12 "Nhắc GV": ghi một thông báo cho giáo viên của buổi (loại NHAC_HOAN_TAT_BUOI). Chỉ buổi Đã chốt đã kết thúc.
-- Ai gọi: Buổi học · Sửa (vận hành, không phải giáo viên). Thông báo nêu tên lớp, buổi, ngày; không chép nội dung nhận xét. Kết quả: true nếu đã nhắc, lỗi nếu buổi không có giáo viên.
create or replace function app.remind_teacher_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_class text;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_KHONG_CAN_NHAC', 'Chỉ nhắc với buổi Đã chốt mà giáo viên chưa hoàn tất.');
  end if;
  if s.teacher_id is null then
    perform app.raise_error('HMT_BUOI_CHUA_CO_GIAO_VIEN', 'Buổi này chưa có giáo viên để nhắc.');
  end if;
  select code into v_class from app.class where id = s.class_id;
  insert into app.notification (user_id, kind, title, actor_id)
  values (s.teacher_id, 'NHAC_HOAN_TAT_BUOI',
          format('Nhắc hoàn tất điểm danh, nhận xét: %s · Buổi %s ngày %s', v_class, coalesce(s.session_no::text, '—'), to_char(s.session_date, 'DD/MM/YYYY')),
          auth.uid());
  return true;
end;
$$;

-- 8. BUOI-01, BUOI-02 hiện lý do huỷ: thay hai hàm đọc của migration 120.
-- app.session_list(bộ lọc, sắp xếp, số dòng, bỏ qua): BUOI-01. Bộ lọc: date_from, date_to (ngày học), class_id, teacher_id, branch_id, status (mảng mã tình trạng buổi),
-- q (mã lớp). Sắp xếp: time_asc (mặc định: ngày, giờ), time_desc. Buổi DA_THAY không hiện.
-- Kết quả: {total, rows: [{id, session_date, start_time, end_time, class_id, class_code, subject_name, branch_code, session_no, type_code, type_name, teacher_name,
--   room_name, status_code, status_name, note}]}. note: lý do chưa Done của buổi Đã chốt (R-GIO-06); lý do huỷ (kèm ghi chú) của buổi đã huỷ (R-BUOI-06, R-BUOI-07); buổi khác để trống.
create or replace function app.session_list(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_from date := nullif(p_filters ->> 'date_from', '')::date;
  v_to date := nullif(p_filters ->> 'date_to', '')::date;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_desc boolean := p_sort = 'time_desc';
  v_result jsonb;
begin
  with f as not materialized (
    select s.*
      from app.class_session s
      join app.class c on c.id = s.class_id
     where s.status_code <> 'DA_THAY'
       -- Luật phạm vi: không phải toàn hệ thống thì chỉ thấy cơ sở của mình.
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_from is null or s.session_date >= v_from)
       and (v_to is null or s.session_date <= v_to)
       and (v_class is null or s.class_id = v_class)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (cardinality(v_status) = 0 or s.status_code = any (v_status))
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), page as (
    select * from f
     order by case when v_desc then null else f.session_date end asc, case when v_desc then null else f.start_time end asc,
              case when v_desc then f.session_date end desc, case when v_desc then f.start_time end desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', p.id, 'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
                      'class_id', c.id, 'class_code', c.code, 'subject_name', sub.name, 'branch_code', b.code, 'session_no', p.session_no,
                      'type_code', p.type_code, 'type_name', ty.name, 'teacher_name', t.display_name, 'room_name', r.name,
                      'status_code', p.status_code, 'status_name', st.name,
                      'note', case when p.status_code = 'DA_CHOT' then app.session_pending_reason(p.id)
                                 when p.status_code in ('HUY_CO_PHI', 'HUY_KHONG_PHI') then
                                   (select ci.name || coalesce(' · ' || p.cancel_note, '') from app.catalog_item ci
                                     where ci.catalog_code = 'SESSION_CANCEL_REASON' and ci.code = p.cancel_reason_code) end)
                    order by case when v_desc then null else p.session_date end asc, case when v_desc then null else p.start_time end asc,
                             case when v_desc then p.session_date end desc, case when v_desc then p.start_time end desc, p.id)
               from page p
               join app.class c on c.id = p.class_id
               join app.branch b on b.id = p.branch_id
               join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
               join app.catalog_item ty on ty.catalog_code = p.type_catalog and ty.code = p.type_code
               join app.catalog_item st on st.catalog_code = p.status_catalog and st.code = p.status_code
               left join app.user_account t on t.id = p.teacher_id
               left join app.room r on r.id = p.room_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- app.session_record(buổi): BUOI-02, bản ghi chỉ đọc. Ai xem được buổi theo quyền Buổi học · Xem (toàn hệ thống hoặc cơ sở; không phải giáo viên "được phân công").
-- Kết quả: {session: {...}, pending_reason, complete_deadline, listed, students: [...], excluded: [...], reviews: [...]}.
--   students: em trong danh sách (is_active) kèm điểm danh hai cột; mismatch = hai bên cùng ghi mà khác nhau (thẻ "Lệch", R-DD-02).
--   excluded: em có dòng bị loại khỏi danh sách kèm mã lý do (R-GIO-02). reviews: nhận xét của giáo viên cho từng em (rỗng khi chưa có).
--   complete_deadline: giờ kết thúc cộng teacher_session_complete_hours (R-GV-05); chỉ tính khi buổi Đã chốt.
create or replace function app.session_record(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_session jsonb;
  v_hours integer;
begin
  -- Luật phạm vi: thao tác của vận hành (giáo viên không mở bản ghi này).
  s := app.assert_session_access(p_id, 'SESSION', 'XEM', true);
  v_hours := app.get_setting_int('teacher_session_complete_hours', s.branch_id);

  select jsonb_build_object(
           'id', s.id, 'status_code', s.status_code, 'status_name', st.name, 'type_code', s.type_code, 'type_name', ty.name, 'session_no', s.session_no,
           'session_date', s.session_date, 'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'),
           'class_id', c.id, 'class_code', c.code, 'class_type_code', c.class_type_code, 'subject_name', sub.name, 'branch_code', b.code, 'branch_name', b.name,
           'teacher_name', t.display_name, 'assistant_name', ta.display_name, 'room_name', r.name, 'start_lesson', c.start_lesson,
           'cancel_reason_code', s.cancel_reason_code, 'cancel_reason_name', cr.name, 'cancel_note', s.cancel_note)
    into v_session
    from app.class c
    join app.branch b on b.id = s.branch_id
    join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
    join app.catalog_item ty on ty.catalog_code = s.type_catalog and ty.code = s.type_code
    join app.catalog_item st on st.catalog_code = s.status_catalog and st.code = s.status_code
    left join app.user_account t on t.id = s.teacher_id
    left join app.user_account ta on ta.id = s.assistant_id
    left join app.room r on r.id = s.room_id
    left join app.catalog_item cr on cr.catalog_code = s.cancel_reason_catalog and cr.code = s.cancel_reason_code
   where c.id = s.class_id;

  return jsonb_build_object(
    'session', v_session,
    'pending_reason', case when s.status_code = 'DA_CHOT' then app.session_pending_reason(s.id) end,
    'complete_deadline', case when s.status_code = 'DA_CHOT' then app.session_ends_at(s.id) + make_interval(hours => v_hours) end,
    'listed', s.status_code in ('DA_CHOT', 'DONE'),
    -- Luật R-DD-02: hai cột; ô của giáo viên quyết định trạng thái chính thức, cột vận hành chỉ để đối chiếu.
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
               'student_id', st2.id, 'student_code', st2.code, 'full_name', st2.full_name, 'is_trial', sa.is_trial,
               'enrollment_code', e.code, 'ops_status_code', sa.ops_status_code, 'ops_status_name', os.name,
               'teacher_status_code', sa.teacher_status_code, 'teacher_status_name', ts.name,
               'mismatch', sa.ops_status_code is not null and sa.teacher_status_code is not null and sa.ops_status_code <> sa.teacher_status_code)
             order by st2.full_name, st2.id)
        from app.session_attendance sa
        join app.student st2 on st2.id = sa.student_id
        left join app.enrollment e on e.id = sa.enrollment_id
        left join app.catalog_item os on os.catalog_code = sa.ops_status_catalog and os.code = sa.ops_status_code
        left join app.catalog_item ts on ts.catalog_code = sa.teacher_status_catalog and ts.code = sa.teacher_status_code
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb),
    -- Luật R-GIO-02: em không vào danh sách kèm lý do (chưa tới ngày vào lớp, bảo lưu, kết thúc, hết giờ).
    'excluded', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', st2.id, 'student_code', st2.code, 'full_name', st2.full_name, 'reason_code', sa.excluded_reason)
             order by st2.full_name, st2.id)
        from app.session_attendance sa join app.student st2 on st2.id = sa.student_id
       where sa.session_id = s.id and not sa.is_active and sa.excluded_reason is not null), '[]'::jsonb),
    'reviews', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', st2.id, 'full_name', st2.full_name, 'comment', rv.teacher_comment, 'teacher_status_code', sa.teacher_status_code)
             order by st2.full_name, st2.id)
        from app.session_attendance sa
        join app.student st2 on st2.id = sa.student_id
        left join app.session_student_review rv on rv.attendance_id = sa.id
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

revoke all on function app.session_cancel_preview(uuid), app.session_move_options(uuid), app.session_move_check(uuid, date, time, time, uuid),
  app.session_pending_list(jsonb, integer, integer), app.remind_teacher_session(uuid), app.session_list(jsonb, text, integer, integer), app.session_record(uuid)
  from public, anon;
grant execute on function app.session_cancel_preview(uuid), app.session_move_options(uuid), app.session_move_check(uuid, date, time, time, uuid),
  app.session_pending_list(jsonb, integer, integer), app.remind_teacher_session(uuid), app.session_list(jsonb, text, integer, integer), app.session_record(uuid)
  to authenticated;

-- Chỉ mục: không thêm. session_pending_list dùng class_session_open_idx (buổi chưa Done, ngày, giờ) của migration 100; hàng nhắc dùng notification_user_idx.
