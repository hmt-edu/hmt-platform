-- A-23-18 / G18 (anh chốt 23/11, Chat duyệt đề xuất docs/de-xuat/nhan-buoi-bu-bo-tro-canh-bao-trung-gv.md): buổi học bù và bổ trợ mang nhãn riêng, KHÔNG chiếm số buổi chính.
-- Làm gì: (1) app.session_type_numbered(loại): loại nào được đánh «Buổi N» (mọi loại trừ HOC_BU, BO_TRO; củng cố và kiểm tra vẫn chiếm số, R-BUOI-04);
-- (2) app.renumber_class_sessions: chỉ đánh số buổi chính theo ngày, giờ; buổi bù, bổ trợ có session_no = null; (3) app.session_cancel_preview: số «buổi thêm cuối lịch» chỉ đếm buổi chính;
-- (4) app.generate_class_sessions: dùng chung hàm đánh số (thân giữ nguyên bản d1a, chỉ thay đoạn đánh số); (5) đánh lại số một lần cho mọi lớp đang có buổi bù hoặc bổ trợ.
-- Trừ giờ, chốt tháng, sổ giờ KHÔNG phụ thuộc session_no (đã rà: các hàm này dùng id buổi, ngày, giờ, loại buổi).
-- Chỉ mục: không thêm (tìm buổi theo lớp đã có chỉ mục class_id, ngày). Audit: trigger chuẩn chỉ ghi trường đổi (session_no). Nhãn hiển thị lấy tên loại từ danh mục SESSION_TYPE ở giao diện.
create or replace function app.session_type_numbered(p_type_code text)
returns boolean
language sql
immutable
set search_path = ''
as $$ select p_type_code not in ('HOC_BU', 'BO_TRO') $$;
grant execute on function app.session_type_numbered(text) to authenticated;

create or replace function app.renumber_class_sessions(p_class_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  -- Buổi chính: số theo ngày, giờ. Buổi bù, bổ trợ: không số.
  update app.class_session x set session_no = n.rn
    from (select id, row_number() over (order by session_date, start_time, id) as rn
            from app.class_session
           where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI') and app.session_type_numbered(type_code)) n
   where x.id = n.id and x.session_no is distinct from n.rn;
  update app.class_session x set session_no = null
   where x.class_id = p_class_id and x.session_no is not null
     and not app.session_type_numbered(x.type_code);
$$;

create or replace function app.generate_class_sessions(p_class_id uuid, p_from date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_slots jsonb;
  v_kept integer;
  v_made integer;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật R-LOP-10: buổi Nháp từ ngày áp dụng, chưa chỉnh lẻ tay, bị thay.
  update app.class_session set status_code = 'DA_THAY'
   where class_id = p_class_id and status_code = 'NHAP' and not is_manual and session_date >= p_from;
  select count(*) into v_kept from app.class_session
   where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI');
  select coalesce(jsonb_agg(jsonb_build_object('start_time', s.start_time, 'end_time', s.end_time,
                                               'repeat_weeks', s.repeat_weeks, 'first_date', s.first_date, 'id', s.id)), '[]'::jsonb)
    into v_slots from app.class_slot s where s.class_id = p_class_id and s.is_active;
  -- Sinh mới: mỗi dòng lịch trỏ về khung (slot_no là thứ tự trong mảng); lấy giáo viên, trợ giảng, phòng từ khung.
  with sched as (
    select * from app.compute_class_schedule(c.branch_id, greatest(p_from, c.start_date), greatest(c.total_sessions - v_kept, 0), v_slots)
  ), ins as (
    insert into app.class_session (class_id, branch_id, slot_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id)
    select c.id, c.branch_id, (v_slots -> sc.slot_no ->> 'id')::uuid, sc.session_date, sc.start_time, sc.end_time,
           sl.teacher_id, sl.assistant_id, sl.room_id
      from sched sc join app.class_slot sl on sl.id = (v_slots -> sc.slot_no ->> 'id')::uuid
    returning 1
  )
  select count(*) into v_made from ins;
  -- Đánh lại số buổi chính theo ngày, giờ (A-23-18: học bù, bổ trợ không chiếm số).
  perform app.renumber_class_sessions(p_class_id);
  update app.class set expected_end_date = (select max(session_date) from app.class_session
                                             where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI'))
   where id = p_class_id;
  return v_made;
end;
$$;

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
   where class_id = s.class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI') and id <> s.id
     and app.session_type_numbered(type_code);
  return jsonb_build_object('added_session_no', case when v_date is null then null else v_no end, 'added_date', v_date);
end;
$$;

-- (5) Đánh lại số một lần cho lớp đang có buổi bù hoặc bổ trợ (một giao dịch của migration; chỉ các lớp này).
do $$
declare r record;
begin
  for r in select distinct class_id from app.class_session where type_code in ('HOC_BU', 'BO_TRO') loop
    perform app.renumber_class_sessions(r.class_id);
  end loop;
end $$;
