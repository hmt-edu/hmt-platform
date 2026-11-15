-- Yêu cầu buổi: BUOI-08 Tạo yêu cầu buổi củng cố, BUOI-10 Yêu cầu buổi (danh sách, duyệt). Lát đầu của cụm BUOI-07..10: CHỈ loại CUNG_CO (buổi củng cố).
-- Học bù (BUOI-07) và học bổ trợ (BUOI-09) làm ở lát sau: luật học bù (chọn buổi có sẵn hay sinh buổi mới, R-BUOI-03) còn mâu thuẫn với khung canvas.
-- Luật: R-BUOI-04 (củng cố là yêu cầu riêng vì tính tiền như buổi thường, phải được duyệt; duyệt thì chèn buổi và dời nhãn bài các buổi sau),
-- R-BUOI-10 (chỉ cần quản lý cơ sở duyệt; không bắt buộc ghi nhận phụ huynh đồng ý), R-BUOI-01 (củng cố là buổi trừ giờ), R-LOP-08 (trùng phòng, giáo viên chỉ cảnh báo),
-- R-HT-01 (Admin duyệt thay việc không dính tiền), R-HT-04 (lý do từ chối từ danh mục, "Khác" bắt ghi chú), R-CS (không áp dụng).
-- Cờ: phân hệ mới YEU_CAU_BUOI, MẶC ĐỊNH TẮT (không có dòng cờ = tắt); duyệt tạo buổi nên chạm luồng buổi và điểm danh (chế độ tự chủ 15/11, mục 3).
--
-- Nhãn bài các buổi sau dời tự nhiên: số buổi đánh lại theo thứ tự ngày (app.renumber_class_sessions), nên chèn một buổi thì các buổi sau tăng một.

-- Danh mục: phân hệ cờ, loại chứng từ, một lý do từ chối riêng cho yêu cầu buổi.
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'YEU_CAU_BUOI', 'Yêu cầu buổi (củng cố, học bù, học bổ trợ)', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'DOC_TYPE', 'YB', 'Yêu cầu buổi', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'DOC_TYPE'
on conflict (catalog_code, code) do nothing;
insert into app.catalog_item (catalog_code, code, name, sort_order, applies_to)
select 'REJECT_REASON', 'KHONG_XEP_DUOC_LICH', 'Không xếp được lịch', coalesce(max(sort_order), 0) + 1, array['YEU_CAU_BUOI']
  from app.catalog_item where catalog_code = 'REJECT_REASON'
on conflict (catalog_code, code) do nothing;

create table app.session_request (
  id uuid not null unique default gen_random_uuid(),
  code text primary key,
  branch_id uuid not null references app.branch (id),
  kind text not null check (kind in ('CUNG_CO')),
  class_id uuid not null references app.class (id),
  session_date date not null,
  start_time time not null,
  end_time time not null,
  room_id uuid references app.room (id),
  note text,
  status_code text not null default 'NHAP' check (status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET', 'TU_CHOI', 'HUY')),
  submitted_at timestamptz,
  decided_at timestamptz,
  decided_by uuid,
  reject_reason_code text,
  reject_note text,
  created_session_id uuid references app.class_session (id),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (end_time > start_time)
);
comment on table app.session_request is 'Yêu cầu buổi (BUOI-07..10). Lát đầu: loại CUNG_CO (R-BUOI-04). Mã YB-<CS>-<YYMM>-<số>.';
-- Chỉ mục (lý do): danh sách lọc theo cơ sở, tình trạng, mới nhất trước; khoá ngoại lớp, phòng, buổi đã sinh.
create index session_request_list_idx on app.session_request (branch_id, status_code, created_at desc);
create index session_request_class_idx on app.session_request (class_id);
create index session_request_room_idx on app.session_request (room_id) where room_id is not null;
create index session_request_session_idx on app.session_request (created_session_id) where created_session_id is not null;
select app.apply_standard('app.session_request');

alter table app.session_request enable row level security;
grant select on app.session_request to authenticated;
-- Đọc: toàn hệ thống hoặc cùng cơ sở (như danh sách buổi của vận hành); giáo viên (được phân công) không xem yêu cầu buổi.
create policy session_request_read on app.session_request for select to authenticated
  using ((select app.permission_scope('SESSION', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SESSION', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- app.save_session_request(id, lớp, ngày, giờ bắt đầu, giờ kết thúc, phòng, ghi chú) -> {id, code}
-- Tạo hoặc sửa yêu cầu buổi củng cố ở tình trạng Nháp. Ai gọi: có quyền Buổi học · Tạo ở cơ sở của lớp (CSKH, Trưởng cơ sở, Admin). Cần phân hệ YEU_CAU_BUOI bật.
create or replace function app.save_session_request(p_id uuid, p_class_id uuid, p_date date, p_start time, p_end time, p_room_id uuid default null,
                                                    p_note text default null)
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
begin
  select * into c from app.class where id = p_class_id;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  perform app.assert_can('SESSION', 'TAO', c.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', c.branch_id);
  -- Luật R-BUOI-04: chỉ lớp đã duyệt mới chèn thêm buổi.
  if c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_LOP_CHUA_DUYET', 'Chỉ lớp đã duyệt mới có yêu cầu buổi củng cố.');
  end if;
  if p_date is null or p_start is null or p_end is null then
    perform app.raise_error('HMT_THIEU_NGAY_GIO', 'Nhập ngày và giờ buổi củng cố.');
  end if;
  if p_end <= p_start then
    perform app.raise_error('HMT_BUOI_GIO_SAI', 'Giờ kết thúc phải sau giờ bắt đầu.');
  end if;
  if p_room_id is not null and not exists (select from app.room where id = p_room_id and branch_id = c.branch_id and is_active) then
    perform app.raise_error('HMT_PHONG_KHONG_CO', 'Phòng không có hoặc đã Ngừng ở cơ sở của lớp.');
  end if;
  if p_id is null then
    select code into v_branch_code from app.branch where id = c.branch_id;
    v_code := app.issue_document_number('YB', v_branch_code);
    insert into app.session_request (code, branch_id, kind, class_id, session_date, start_time, end_time, room_id, note)
    values (v_code, c.branch_id, 'CUNG_CO', c.id, p_date, p_start, p_end, p_room_id, nullif(btrim(p_note), ''))
    returning * into r;
  else
    select * into r from app.session_request where id = p_id for update;
    if r.id is null or r.branch_id <> c.branch_id then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
    end if;
    if r.status_code <> 'NHAP' then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ sửa được yêu cầu buổi ở tình trạng Nháp.');
    end if;
    update app.session_request set class_id = c.id, session_date = p_date, start_time = p_start, end_time = p_end, room_id = p_room_id,
           note = nullif(btrim(p_note), '') where id = r.id returning * into r;
  end if;
  return jsonb_build_object('id', r.id, 'code', r.code);
end;
$$;

-- app.submit_session_request(id): Nháp → Chờ duyệt. Ai gọi: như lưu.
create or replace function app.submit_session_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
begin
  select * into r from app.session_request where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'TAO', r.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', r.branch_id);
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi duyệt được yêu cầu buổi ở tình trạng Nháp.');
  end if;
  update app.session_request set status_code = 'CHO_DUYET', submitted_at = now() where id = r.id;
end;
$$;

-- app.cancel_session_request(id): Nháp hoặc Chờ duyệt → Huỷ. Ai gọi: có quyền Buổi học · Tạo ở cơ sở của yêu cầu.
create or replace function app.cancel_session_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
begin
  select * into r from app.session_request where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'TAO', r.branch_id);
  if r.status_code not in ('NHAP', 'CHO_DUYET') then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ huỷ được yêu cầu buổi Nháp hoặc Chờ duyệt.');
  end if;
  update app.session_request set status_code = 'HUY', decided_at = now(), decided_by = auth.uid() where id = r.id;
end;
$$;

-- app.approve_session_request(id) -> {session_id, warnings}
-- Duyệt yêu cầu Chờ duyệt: chèn một buổi loại Củng cố (Nháp, đánh dấu chỉnh lẻ tay) vào lịch của lớp rồi đánh lại số buổi theo ngày, nên nhãn bài các buổi sau dời một
-- (R-BUOI-04). Giáo viên, trợ giảng của buổi lấy theo khung giờ cùng thứ trong tuần của lớp (không có thì để trống, chọn sau ở BUOI-13). Trùng phòng, giáo viên chỉ cảnh báo
-- (R-LOP-08). Ai gọi: Buổi học · Duyệt ở cơ sở của yêu cầu (Trưởng cơ sở; Admin duyệt thay, R-HT-01). Ngày buổi phải từ hôm nay trở đi (giờ Việt Nam).
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
  select sl.teacher_id, sl.assistant_id into v_teacher, v_assistant
    from app.class_slot sl
   where sl.class_id = c.id and sl.is_active
   order by (sl.weekday = extract(isodow from r.session_date)::integer) desc, sl.weekday, sl.start_time
   limit 1;
  insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id, type_code, status_code, is_manual)
  values (c.id, c.branch_id, r.session_date, r.start_time, r.end_time, v_teacher, v_assistant, r.room_id, 'CUNG_CO', 'NHAP', true)
  returning id into v_session;
  perform app.renumber_class_sessions(c.id);
  update app.session_request set status_code = 'DA_DUYET', decided_at = now(), decided_by = auth.uid(), created_session_id = v_session where id = r.id;
  return jsonb_build_object('session_id', v_session, 'warnings', app.class_clash_warnings(c.id));
end;
$$;

-- app.reject_session_request(id, mã lý do, ghi chú): Chờ duyệt → Từ chối. Lý do từ danh mục "Lý do từ chối" áp dụng cho yêu cầu buổi; "Khác" bắt ghi chú (R-HT-04).
create or replace function app.reject_session_request(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
  v_requires_note boolean;
  v_applies text[];
begin
  select * into r from app.session_request where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'DUYET', r.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', r.branch_id);
  if r.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ từ chối được yêu cầu buổi ở tình trạng Chờ duyệt.');
  end if;
  perform app.assert_catalog_code_active('REJECT_REASON', p_reason_code);
  select requires_note, applies_to into v_requires_note, v_applies
    from app.catalog_item where catalog_code = 'REJECT_REASON' and code = p_reason_code;
  if coalesce(array_length(v_applies, 1), 0) > 0 and not ('YEU_CAU_BUOI' = any (v_applies)) then
    perform app.raise_error('HMT_LY_DO_KHONG_AP_DUNG', 'Lý do này không áp dụng cho yêu cầu buổi.');
  end if;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  update app.session_request set status_code = 'TU_CHOI', decided_at = now(), decided_by = auth.uid(), reject_reason_code = p_reason_code,
         reject_note = nullif(btrim(p_note), '') where id = r.id;
end;
$$;

-- app.list_session_requests(bộ lọc, số dòng, bỏ qua) -> {total, rows}
-- Bộ lọc: status (mảng mã tình trạng), kind, class_id. Phân trang ở máy chủ (mặc định 50, tối đa 100). Ai gọi: có quyền xem buổi toàn hệ thống hoặc cơ sở mình
-- (giáo viên được phân công không xem). Mỗi dòng kèm can_approve (người gọi duyệt được ở cơ sở đó) để giao diện hiện nút Duyệt, Từ chối.
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
           'student_count', (select count(distinct e.student_id) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                              where ec.class_id = c.id and ec.end_date is null),
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

revoke execute on function
  app.save_session_request(uuid, uuid, date, time, time, uuid, text), app.submit_session_request(uuid), app.cancel_session_request(uuid),
  app.approve_session_request(uuid), app.reject_session_request(uuid, text, text), app.list_session_requests(jsonb, integer, integer)
  from public, anon, authenticated;
grant execute on function
  app.save_session_request(uuid, uuid, date, time, time, uuid, text), app.submit_session_request(uuid), app.cancel_session_request(uuid),
  app.approve_session_request(uuid), app.reject_session_request(uuid, text, text), app.list_session_requests(jsonb, integer, integer)
  to authenticated;
