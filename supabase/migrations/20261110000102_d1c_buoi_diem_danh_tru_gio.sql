-- D1c (Code 2, 10/11/2026): vòng đời buổi học, danh sách buổi, điểm danh hai phía, trừ giờ.
-- Luật: R-BUOI-02, 06, 07, 09; R-GIO-01..08; R-DD-01..03; R-GD-05 (Đã xếp lớp → Đang học), R-GD-12, R-GD-18; R-GV-08; R-V2-17.
-- Làm gì: bảng điểm danh (mỗi em một dòng mỗi buổi); chốt danh sách buổi (sinh dòng điểm danh, nêu lý do em không vào); tự chốt; điểm danh
-- của giáo viên (ô quyết định chính thức) và của vận hành; Done: kiểm đủ điều kiện rồi trừ giờ vào sổ giờ; tự Done; huỷ buổi (có/không tính
-- phí); sửa điểm danh sau Done (chỉ quản lý cơ sở, Admin); dời buổi; đổi giáo viên một buổi (dạy thay).
-- Chưa có (D2): điều kiện nhận xét, BTVN trong Done, loại buổi Kiểm tra; yêu cầu học bù, củng cố, bổ trợ, học thử (ghi câu hỏi cho Chat).
-- Lịch tự chạy (R-GIO-05, R-GIO-06): hàm app.auto_close_sessions, app.auto_complete_sessions viết sẵn; đăng ký pg_cron chờ anh duyệt (chưa có pg_cron nào trong repo).
-- GỘP SAU #205, Q-137 và sau migration 101.
select set_config('hmt.migration', 'on', false);

-- Ghi danh có bật "học trước, đóng tiền sau" (R-GD-12): quản lý cơ sở bật. Cột chỉ khai báo; hàm bật làm cùng luồng đơn (chưa thuộc D1).
alter table app.enrollment add column pay_later_enabled boolean not null default false;

-- ---------------------------------------------------------------------------
-- 1. Bảng điểm danh
-- ---------------------------------------------------------------------------
-- Một em một dòng mỗi buổi (R-GIO-04). Dòng loại khỏi danh sách (is_active = false) giữ lý do để màn buổi hiện "em không vào danh sách kèm lý do".
create table app.session_attendance (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references app.class_session (id),
  class_id uuid not null references app.class (id),
  branch_id uuid not null references app.branch (id),
  student_id uuid not null references app.student (id),
  -- Ghi danh bị trừ giờ (R-GIO-04: hạn sử dụng sớm nhất trước). Null với dòng loại khỏi danh sách và học thử (không trừ giờ, R-GD-11).
  enrollment_id uuid references app.enrollment (id),
  is_active boolean not null default true,
  excluded_reason text check (excluded_reason in ('CHUA_TOI_NGAY_VAO', 'BAO_LUU', 'KET_THUC', 'HET_GIO')),
  is_trial boolean not null default false,
  -- Hai phía (R-DD-02): vận hành ghi riêng, ô của giáo viên quyết định trạng thái chính thức.
  ops_status_catalog text not null default 'ATTENDANCE_STATUS' check (ops_status_catalog = 'ATTENDANCE_STATUS'),
  ops_status_code text,
  contact_reason_catalog text not null default 'ATTENDANCE_CONTACT_REASON' check (contact_reason_catalog = 'ATTENDANCE_CONTACT_REASON'),
  contact_reason_code text,
  ops_note text,
  teacher_status_catalog text not null default 'ATTENDANCE_STATUS' check (teacher_status_catalog = 'ATTENDANCE_STATUS'),
  teacher_status_code text,
  teacher_marked_by uuid,
  teacher_marked_at timestamptz,
  -- Sửa sau Done (R-GIO-07): lý do bắt buộc.
  correction_reason_code text,
  correction_note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (session_id, student_id),
  foreign key (ops_status_catalog, ops_status_code) references app.catalog_item (catalog_code, code),
  foreign key (contact_reason_catalog, contact_reason_code) references app.catalog_item (catalog_code, code),
  foreign key (teacher_status_catalog, teacher_status_code) references app.catalog_item (catalog_code, code),
  check (not is_active or excluded_reason is null)
);
comment on table app.session_attendance is 'Điểm danh: mỗi em một dòng mỗi buổi (R-GIO-04). Trạng thái chính thức = ô của giáo viên (R-DD-02). Ghi chỉ qua hàm nghiệp vụ.';
-- Chỉ mục (lý do): unique (session_id, student_id) là khoá ngoại buổi và tra một em; lịch sử điểm danh của em (hồ sơ học sinh GV-13); ghi danh (trừ giờ);
-- cơ sở cho RLS; hàng chờ gọi nhắc trong ngày (BUOI-11): em chưa có ô giáo viên.
create index session_attendance_student_idx on app.session_attendance (student_id, session_id);
create index session_attendance_enrollment_idx on app.session_attendance (enrollment_id) where enrollment_id is not null;
create index session_attendance_class_idx on app.session_attendance (class_id);
create index session_attendance_branch_idx on app.session_attendance (branch_id);
create index session_attendance_pending_idx on app.session_attendance (session_id) where is_active and teacher_status_code is null;
select app.apply_standard('app.session_attendance');

alter table app.session_attendance enable row level security;
revoke all on app.session_attendance from public, anon, authenticated;
grant select on app.session_attendance to authenticated;
-- Giáo viên chỉ thấy dòng điểm danh của buổi mình được phân công (R-GV-08); danh sách chỉ có sau khi buổi Đã chốt (R-GIO-08) vì dòng chỉ sinh khi chốt.
create policy session_attendance_read on app.session_attendance for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ATTENDANCE', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('ATTENDANCE', 'XEM')) = 'DUOC_PHAN_CONG' and is_active
             and exists (select from app.class_session s where s.id = session_attendance.session_id
                            and (select auth.uid()) in (s.teacher_id, s.assistant_id))));

-- ---------------------------------------------------------------------------
-- 2. Hàm trợ giúp
-- ---------------------------------------------------------------------------
-- Số giờ của buổi (thời lượng, làm tròn 2 chữ số): số giờ trừ khỏi quỹ khi Done (R-GIO-01).
create or replace function app.session_hours(p_session_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select round(extract(epoch from (s.end_time - s.start_time)) / 3600.0, 2)::numeric(6, 2) from app.class_session s where s.id = p_session_id; -- allow-number: 3600 giây một giờ, làm tròn 2 chữ số
$$;

-- Thời điểm kết thúc / bắt đầu của buổi (giờ Việt Nam, CLAUDE.md: thời điểm lưu UTC, ngày học là date).
create or replace function app.session_ends_at(p_session_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') from app.class_session s where s.id = p_session_id;
$$;
create or replace function app.session_starts_at(p_session_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select ((s.session_date + s.start_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') from app.class_session s where s.id = p_session_id;
$$;

-- Quyền thao tác trên một buổi. Phạm vi: toàn hệ thống; cơ sở của buổi; hoặc được phân công (giáo viên, trợ giảng của buổi).
-- p_staff_only = true: loại phạm vi "được phân công" (thao tác của vận hành: R-BUOI-09, R-DD-02, R-GV-08 giáo viên không huỷ buổi).
create or replace function app.assert_session_access(p_session_id uuid, p_module text, p_action text, p_staff_only boolean default false)
returns app.class_session
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_scope text;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  v_scope := app.permission_scope(p_module, p_action);
  if v_scope is null
     or (v_scope = 'CO_SO' and s.branch_id is distinct from app.current_branch_id())
     -- Phạm vi "được phân công": đúng giáo viên hoặc trợ giảng của buổi, và thao tác không dành riêng cho vận hành.
     or (v_scope = 'DUOC_PHAN_CONG' and (p_staff_only or (auth.uid() is distinct from s.teacher_id and auth.uid() is distinct from s.assistant_id))) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này với buổi này.');
  end if;
  return s;
end;
$$;

-- Đánh lại số "Buổi N" của lớp theo ngày, giờ (buổi đang sống: Nháp, Đã chốt, Done, Huỷ có tính phí).
create or replace function app.renumber_class_sessions(p_class_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update app.class_session x set session_no = n.rn
    from (select id, row_number() over (order by session_date, start_time, id) as rn
            from app.class_session where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI')) n
   where x.id = n.id and x.session_no is distinct from n.rn;
$$;

-- ---------------------------------------------------------------------------
-- 3. Chốt danh sách buổi (R-BUOI-02, R-GIO-02, R-GIO-03, R-GIO-04, R-GD-12)
-- ---------------------------------------------------------------------------
-- app.build_session_roster(buổi): sinh dòng điểm danh rồi chuyển buổi Nháp → Đã chốt. NỘI BỘ (hàm chốt tay và tự chốt gọi).
--   Mỗi em một dòng dù có hai ghi danh cùng lớp (R-GIO-04): chọn ghi danh vào lớp sớm nhất còn đủ giờ.
--   Em KHÔNG vào danh sách, nhưng có dòng kèm lý do (is_active = false): chưa tới ngày vào lớp; bảo lưu; ghi danh đã kết thúc hoặc dừng
--   (R-GIO-03); số dư không đủ giờ buổi trừ khi đang trong hạn mức cho học trước (max_sessions_ahead, R-GD-12).
--   Ghi danh sinh SAU ngày buổi không lọt vào danh sách (R-GIO-02): bỏ hẳn, không có dòng.
--   Buổi không trừ giờ (học bù, bổ trợ) không kiểm số dư (R-BUOI-01).
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

-- app.close_session(buổi): chốt danh sách bằng tay. Ai gọi: Buổi học · Sửa ở cơ sở của buổi (vận hành, quản lý cơ sở), không phải giáo viên (R-GV-08).
-- Kết quả: số em vào danh sách.
create or replace function app.close_session(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  perform app.require_feature('VAN_HANH_LOP', s.branch_id);
  return app.build_session_roster(p_session_id);
end;
$$;

-- app.auto_close_sessions(): tự chốt (R-GIO-05). Chốt các buổi Nháp của lớp đã duyệt sẽ bắt đầu trong session_autoclose_scan_hours giờ tới
-- (hoặc đã bắt đầu mà chưa chốt). Lịch chạy mỗi session_autoclose_before_minutes phút (pg_cron, chờ anh duyệt đăng ký). Mỗi buổi một lỗi
-- không dừng buổi khác. Kết quả: số buổi đã chốt.
create or replace function app.auto_close_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_n integer := 0;
  v_scan integer := app.get_setting_int('session_autoclose_scan_hours');
begin
  for r in select s.id from app.class_session s join app.class c on c.id = s.class_id
            where s.status_code = 'NHAP' and c.status_code = 'DA_DUYET'
              and app.session_starts_at(s.id) <= now() + make_interval(hours => v_scan)
            order by s.session_date, s.start_time loop
    begin
      perform app.build_session_roster(r.id);
      v_n := v_n + 1;
    exception when others then
      -- Một buổi lỗi không chặn các buổi khác; buổi vẫn Nháp, lần quét sau thử lại.
      null;
    end;
  end loop;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Điểm danh hai phía (R-DD-01, R-DD-02, R-DD-03, R-GV-08, R-GIO-08)
-- ---------------------------------------------------------------------------
-- app.set_attendance_teacher(buổi, [{student_id, status_code}]): giáo viên, trợ giảng ghi ô chính thức. status_code trống = xoá về "chưa điểm danh".
-- Chỉ khi buổi Đã chốt (R-GIO-08: chưa chốt thì chưa có danh sách); Done rồi chỉ quản lý cơ sở sửa (R-GIO-07, app.correct_attendance_after_done).
-- Giáo viên chỉ ghi trạng thái, không tạo dòng, không đổi tình trạng buổi (R-GV-08).
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
  return v_n;
end;
$$;

-- app.set_attendance_ops(buổi, [{student_id, status_code, contact_reason_code, note}]): vận hành ghi phía mình (BUOI-03, BUOI-11).
-- Ô này không quyết định trạng thái chính thức (R-DD-02). Lý do liên hệ từ danh mục 17; "Khác" bắt buộc ghi chú (R-DD-03).
-- Ai gọi: Điểm danh · Sửa ở cơ sở của buổi (không phải giáo viên). Buổi Nháp chưa có danh sách; Done rồi không ghi.
create or replace function app.set_attendance_ops(p_session_id uuid, p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_status text;
  v_reason text;
  v_note text;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA', true);
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Chỉ ghi điểm danh phía vận hành khi buổi Đã chốt, chưa Done.');
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) loop
    v_status := nullif(e ->> 'status_code', '');
    v_reason := nullif(e ->> 'contact_reason_code', '');
    v_note := nullif(btrim(coalesce(e ->> 'note', '')), '');
    if v_status is not null then
      perform app.assert_catalog_code_active('ATTENDANCE_STATUS', v_status);
    end if;
    if v_reason is not null then
      perform app.assert_catalog_code_active('ATTENDANCE_CONTACT_REASON', v_reason);
      if v_reason = 'KHAC' and v_note is null then
        perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do liên hệ "Khác" cần ghi chú.');
      end if;
    end if;
    update app.session_attendance set ops_status_code = v_status, contact_reason_code = v_reason, ops_note = v_note
     where session_id = p_session_id and student_id = (e ->> 'student_id')::uuid and is_active;
    if not found then
      perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Có em không nằm trong danh sách buổi này.');
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Done và trừ giờ (R-GIO-01, R-GIO-04, R-GIO-06, R-GD-05, R-GD-18)
-- ---------------------------------------------------------------------------
-- app.session_pending_reason(buổi): lý do buổi chưa Done được (BUOI-12), null nếu đủ điều kiện. D2 thêm điều kiện nhận xét.
create or replace function app.session_pending_reason(p_session_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_missing integer;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.status_code <> 'DA_CHOT' then
    return 'Buổi chưa chốt danh sách.';
  end if;
  if app.session_ends_at(p_session_id) > now() then
    return 'Buổi chưa kết thúc.';
  end if;
  select count(*) into v_missing from app.session_attendance where session_id = p_session_id and is_active and teacher_status_code is null;
  if v_missing > 0 then
    return format('Giáo viên chưa điểm danh %s em.', v_missing);
  end if;
  return null;
end;
$$;

-- app.deduct_session_hours(buổi): ghi dòng trừ giờ vào sổ giờ cho mọi em trong danh sách (R-GIO-01: có tên trong danh sách + buổi Done →
-- trừ, dù có mặt, đi muộn hay vắng). Trừ đúng một lần mỗi buổi mỗi ghi danh (chỉ mục duy nhất). Không trừ buổi học bù, học bổ trợ,
-- học thử. Luật R-GD-18: quỹ không được âm, trừ khi ghi danh bật học trước và còn trong hạn mức. NỘI BỘ.
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
  if not app.session_type_deducts_hours(s.type_code) then
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

-- app.mark_session_done(buổi): Đã chốt → Done (R-BUOI-02). NỘI BỘ: giáo viên không đổi tình trạng buổi (R-GV-08); hàm tự Done và
-- bước hoàn tất của giáo viên gọi. Điều kiện: buổi đã kết thúc; mọi em trong danh sách có điểm danh của giáo viên (R-GIO-06; D2 thêm nhận xét).
-- Làm: trừ giờ (deduct_session_hours); ghi danh Đã xếp lớp → Đang học khi có buổi Done đầu tiên (R-GD-05).
create or replace function app.mark_session_done(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
begin
  perform 1 from app.class_session where id = p_session_id for update;
  v_reason := app.session_pending_reason(p_session_id);
  if v_reason is not null then
    perform app.raise_error('HMT_BUOI_CHUA_DONE_DUOC', v_reason);
  end if;
  perform app.deduct_session_hours(p_session_id);
  update app.class_session set status_code = 'DONE' where id = p_session_id;
  update app.enrollment set status_code = 'DANG_HOC'
   where status_code = 'DA_XEP_LOP' and id in (select enrollment_id from app.session_attendance
                                               where session_id = p_session_id and is_active and enrollment_id is not null);
end;
$$;

-- app.auto_complete_sessions(): tự Done (R-GIO-06): các buổi Đã chốt đã đủ điều kiện thì Done; chưa đủ thì giữ Đã chốt (lý do xem
-- app.session_pending_reason). Mỗi buổi một lỗi không chặn buổi khác. Kết quả: số buổi đã Done.
create or replace function app.auto_complete_sessions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_n integer := 0;
begin
  for r in select s.id from app.class_session s where s.status_code = 'DA_CHOT' order by s.session_date, s.start_time loop
    if app.session_pending_reason(r.id) is null then
      begin
        perform app.mark_session_done(r.id);
        v_n := v_n + 1;
      exception when others then
        null;
      end;
    end if;
  end loop;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Huỷ buổi (R-BUOI-06, R-BUOI-07, R-BUOI-09)
-- ---------------------------------------------------------------------------
-- app.cancel_session(buổi, kiểu, lý do, ghi chú): huỷ buổi chưa Done, kể cả sau khi đã chốt danh sách (R-BUOI-09).
-- Ai gọi: Buổi học · Sửa, vận hành hoặc quản lý cơ sở; giáo viên không huỷ được (R-GV-08).
-- Lý do từ danh mục 23: mã TT_ (trung tâm) → luôn Huỷ không tính phí, tự thêm một buổi vào cuối lịch, dời "Buổi N" (R-BUOI-06);
--   mã HS_ (học sinh) chỉ cho lớp riêng, người huỷ chọn Huỷ có/không tính phí (R-BUOI-07). "Khác" bắt buộc ghi chú.
-- Huỷ có tính phí: trừ giờ như một buổi Done cho các em trong danh sách (R-BUOI-02, R-BUOI-03); các dòng điểm danh bị vô hiệu (R-BUOI-09).
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
  update app.class_session set status_code = v_kind where id = s.id;

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

-- ---------------------------------------------------------------------------
-- 7. Sửa sau Done, dời buổi, dạy thay
-- ---------------------------------------------------------------------------
-- app.correct_attendance_after_done(buổi, em, trạng thái, lý do, ghi chú): sửa điểm danh sau khi buổi Done (BUOI-14, R-GIO-07).
-- Ai gọi: Điểm danh · Duyệt (Trưởng cơ sở, Admin) ở cơ sở của buổi. Bắt buộc lý do (danh mục 25). Đổi giữa các trạng thái đi học KHÔNG đổi giờ
-- (vẫn trừ theo R-GIO-01). Thêm hoặc bớt em khỏi danh sách: thêm dòng điều chỉnh sổ giờ qua app.adjust_enrollment_hours (R-GD-04).
create or replace function app.correct_attendance_after_done(p_session_id uuid, p_student_id uuid, p_status_code text, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_requires_note boolean;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  perform app.assert_can('ATTENDANCE', 'DUYET', s.branch_id);
  if s.status_code <> 'DONE' then
    perform app.raise_error('HMT_BUOI_CHUA_DONE', 'Chỉ sửa điểm danh sau Done bằng chức năng này. Buổi chưa Done thì giáo viên sửa.');
  end if;
  perform app.assert_catalog_code_active('ATTENDANCE_STATUS', p_status_code);
  perform app.assert_catalog_code_active('HOURS_ADJUST_REASON', p_reason_code);
  select requires_note into v_requires_note from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' and code = p_reason_code;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  update app.session_attendance set teacher_status_code = p_status_code, teacher_marked_by = auth.uid(), teacher_marked_at = now(),
         correction_reason_code = p_reason_code, correction_note = nullif(btrim(p_note), '')
   where session_id = p_session_id and student_id = p_student_id and is_active;
  if not found then
    perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Em không nằm trong danh sách buổi này.');
  end if;
end;
$$;

-- app.move_session(buổi, ngày, giờ bắt đầu, giờ kết thúc, phòng): dời một buổi chưa Done (BUOI-05). Buổi đánh dấu chỉnh lẻ tay: sinh lại lịch
-- (R-LOP-10) giữ nguyên. Trùng phòng, giáo viên chỉ cảnh báo (R-LOP-08). Ai gọi: Buổi học · Sửa (không phải giáo viên).
create or replace function app.move_session(p_session_id uuid, p_date date, p_start time, p_end time, p_room_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA_DUOC', 'Chỉ dời buổi chưa Done và chưa huỷ.');
  end if;
  if p_date is null or p_start is null or p_end is null or p_end <= p_start then
    perform app.raise_error('HMT_BUOI_GIO_SAI', 'Cần ngày, giờ bắt đầu và giờ kết thúc sau giờ bắt đầu.');
  end if;
  update app.class_session set session_date = p_date, start_time = p_start, end_time = p_end,
         room_id = coalesce(p_room_id, room_id), is_manual = true where id = s.id;
  perform app.renumber_class_sessions(s.class_id);
  return jsonb_build_object('warnings', app.class_clash_warnings(s.class_id));
end;
$$;

-- app.change_session_staff(buổi, giáo viên, trợ giảng): đổi người dạy một buổi (dạy thay, BUOI-13, R-LOP-10, R-LOP-11). Giờ dạy tính cho
-- người dạy thật. Buổi chưa Done. Ai gọi: Buổi học · Sửa (không phải giáo viên).
create or replace function app.change_session_staff(p_session_id uuid, p_teacher_id uuid, p_assistant_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA_DUOC', 'Chỉ đổi người dạy buổi chưa Done và chưa huỷ.');
  end if;
  if p_teacher_id is not null and not exists (select from app.user_account where id = p_teacher_id and not is_locked) then
    perform app.raise_error('HMT_NHAN_SU_KHONG_CO', 'Giáo viên không tồn tại hoặc đã bị khoá.');
  end if;
  update app.class_session set teacher_id = p_teacher_id, assistant_id = p_assistant_id, is_manual = true where id = s.id;
  return jsonb_build_object('warnings', app.class_clash_warnings(s.class_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function
  app.session_hours(uuid), app.session_ends_at(uuid), app.session_starts_at(uuid), app.assert_session_access(uuid, text, text, boolean),
  app.renumber_class_sessions(uuid), app.build_session_roster(uuid), app.close_session(uuid), app.auto_close_sessions(),
  app.set_attendance_teacher(uuid, jsonb), app.set_attendance_ops(uuid, jsonb), app.session_pending_reason(uuid),
  app.deduct_session_hours(uuid), app.mark_session_done(uuid), app.auto_complete_sessions(),
  app.cancel_session(uuid, text, text, text), app.correct_attendance_after_done(uuid, uuid, text, text, text),
  app.move_session(uuid, date, time, time, uuid), app.change_session_staff(uuid, uuid, uuid)
  from public, anon, authenticated;
-- Giao diện gọi: chốt tay, điểm danh hai phía, lý do chưa Done, huỷ, sửa sau Done, dời, dạy thay, giờ của buổi.
grant execute on function
  app.session_hours(uuid), app.close_session(uuid), app.set_attendance_teacher(uuid, jsonb), app.set_attendance_ops(uuid, jsonb),
  app.session_pending_reason(uuid), app.cancel_session(uuid, text, text, text),
  app.correct_attendance_after_done(uuid, uuid, text, text, text), app.move_session(uuid, date, time, time, uuid),
  app.change_session_staff(uuid, uuid, uuid)
  to authenticated;

select set_config('hmt.migration', '', false);
