-- Code B (15/11/2026), Aftersale lát đầu (Đợt 2, PR Draft), migration 157: bảng ticket, nhật ký, hàm tạo, giao, đổi trạng thái, danh sách, Kanban.
-- Luật: docs/spec/de-xuat-luat-aftersale.md (AS-01 đến AS-09, ĐÃ CHỐT 15/11), R-V2-23, R-V2-24 (nghiệp vụ thật chưa làm: nhóm con [NV] đóng tay kèm ghi chú), R-V2-26.
-- Làm gì: app.ticket, app.ticket_event (chỉ thêm), mã chứng từ DN/KN/GV-<CS>-<YYMM>-<STT> (AS-01), luồng 7 trạng thái (AS-02), hạn phản hồi và xử lý chụp lúc tạo
-- từ bảng loại × mức độ hoặc hạn riêng nhóm con (AS-07), trừ thời gian Chờ thông tin, RLS theo ma trận quyền TICKET (AS-09), công tắc phân hệ AFTERSALE kiểm trong hàm.
-- Chưa làm (ghi trong PR): phiếu nghiệp vụ (nhóm A đi sau), người bị khiếu nại ngoài cột liên kết, ticket giáo viên thấy theo lớp mình, báo cáo.
select set_config('hmt.migration', 'on', false);

create table app.ticket (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  ticket_type text not null check (ticket_type in ('DN', 'KN', 'GV')),
  branch_id uuid not null references app.branch (id),
  title text not null check (btrim(title) <> ''),
  description text not null check (btrim(description) <> ''),
  channel_code text not null,
  category_code text not null references app.ticket_category (code),
  priority_code text not null check (priority_code in ('KHAN', 'CAO', 'THUONG', 'THAP')),
  status_code text not null default 'MOI' check (status_code in ('MOI', 'DA_GIAO', 'DANG_XU_LY', 'CHO_THONG_TIN', 'DA_XU_LY', 'DA_DONG', 'DA_HUY')),
  team_code text,
  assignee_id uuid references app.user_account (id),
  parent_id uuid references app.parent (id),
  sender_user_id uuid references app.user_account (id),
  student_id uuid references app.student (id),
  class_id uuid references app.class (id),
  enrollment_id uuid references app.enrollment (id),
  accused_user_id uuid references app.user_account (id),
  related_ticket_id uuid references app.ticket (id),
  satisfaction smallint check (satisfaction between 1 and 5), -- allow-number: thang mức hài lòng 1 đến 5 (R-CS-14)
  resolution text,
  cancel_reason text,
  response_due_at timestamptz not null,
  resolve_due_at timestamptz not null,
  first_response_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  paused_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  -- Người gửi: đề nghị, khiếu nại là phụ huynh; ticket giáo viên là tài khoản giáo viên (AS-05).
  check ((ticket_type = 'GV' and sender_user_id is not null) or (ticket_type <> 'GV' and parent_id is not null)),
  check (status_code <> 'DA_HUY' or cancel_reason is not null)
);
comment on table app.ticket is 'Ticket CS: Đề nghị (DN), Khiếu nại (KN), Ticket giáo viên (GV). Không xoá: huỷ là đổi trạng thái (AS-02).';
-- Chỉ mục (lý do ghi từng dòng):
-- danh sách và Kanban theo cơ sở, trạng thái, hạn xử lý (bộ lọc Quá hạn, Sắp quá hạn); cột trong chính sách đọc (branch_id).
create index ticket_branch_status_due_idx on app.ticket (branch_id, status_code, resolve_due_at);
-- "Ticket của tôi" (người phụ trách) và chính sách đọc phạm vi Được phân công.
create index ticket_assignee_status_idx on app.ticket (assignee_id, status_code) where assignee_id is not null;
-- Chính sách đọc phạm vi Được phân công (ticket mình tạo) và nhật ký.
create index ticket_created_by_idx on app.ticket (created_by, created_at desc);
-- Lọc theo loại và sắp xếp mới nhất.
create index ticket_type_status_created_idx on app.ticket (ticket_type, status_code, created_at desc);
-- Khoá ngoại và lọc theo nhóm con, phụ huynh, học sinh, lớp, ghi danh, ticket liên quan.
create index ticket_category_idx on app.ticket (category_code);
create index ticket_parent_idx on app.ticket (parent_id) where parent_id is not null;
create index ticket_student_idx on app.ticket (student_id) where student_id is not null;
create index ticket_class_idx on app.ticket (class_id) where class_id is not null;
create index ticket_enrollment_idx on app.ticket (enrollment_id) where enrollment_id is not null;
create index ticket_related_idx on app.ticket (related_ticket_id) where related_ticket_id is not null;
create index ticket_sender_user_idx on app.ticket (sender_user_id) where sender_user_id is not null;
create index ticket_accused_idx on app.ticket (accused_user_id) where accused_user_id is not null;
-- Bộ lọc "Chờ đóng": Đã xử lý quá số ngày chưa đóng.
create index ticket_resolved_idx on app.ticket (resolved_at) where status_code = 'DA_XU_LY';
-- Tìm theo tiêu đề, mã.
create index ticket_title_trgm_idx on app.ticket using gin (title extensions.gin_trgm_ops);
select app.apply_standard('app.ticket');

create table app.ticket_event (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  ticket_id uuid not null references app.ticket (id),
  branch_id uuid not null references app.branch (id),
  event_type text not null check (event_type in ('TAO', 'GIAO', 'DOI_TRANG_THAI', 'DOI_NHOM_CON', 'DOI_MUC_DO')),
  from_status text,
  to_status text,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.ticket_event is 'Nhật ký ticket, chỉ thêm dòng: tạo, giao, đổi trạng thái, đổi nhóm con, đổi mức độ.';
-- Chỉ mục (lý do): lịch sử của một ticket theo thứ tự ghi; cơ sở cho RLS.
create index ticket_event_ticket_idx on app.ticket_event (ticket_id, seq);
create index ticket_event_branch_idx on app.ticket_event (branch_id);
select app.apply_standard('app.ticket_event');
create or replace function app.tg_ticket_event_append_only()
returns trigger language plpgsql set search_path = ''
as $$
begin
  perform app.raise_error('HMT_NHAT_KY_CHI_THEM', 'Nhật ký ticket chỉ thêm dòng, không sửa.');
  return null;
end;
$$;
create trigger ticket_event_no_update before update on app.ticket_event for each row execute function app.tg_ticket_event_append_only();

-- RLS (AS-09): phạm vi toàn hệ thống thấy hết; phạm vi cơ sở thấy ticket cơ sở mình; phạm vi Được phân công (giáo viên) thấy ticket mình tạo hoặc mình phụ trách.
-- Ghi chỉ qua hàm nghiệp vụ.
alter table app.ticket enable row level security;
alter table app.ticket_event enable row level security;
revoke all on app.ticket, app.ticket_event from public, anon, authenticated;
grant select on app.ticket, app.ticket_event to authenticated;
create policy ticket_read on app.ticket for select to authenticated using (
  (select app.permission_scope('TICKET', 'XEM')) = 'TOAN_HE_THONG'
  or ((select app.permission_scope('TICKET', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
  or ((select app.permission_scope('TICKET', 'XEM')) = 'DUOC_PHAN_CONG'
      and (created_by = (select auth.uid()) or assignee_id = (select auth.uid()))));
create policy ticket_event_read on app.ticket_event for select to authenticated using (
  exists (select from app.ticket t where t.id = ticket_event.ticket_id));

-- app.ticket_resolve_hours(loại, mức độ, mã nhóm con): hạn xử lý xong (giờ): hạn riêng nhóm con nếu có, không thì bảng loại × mức độ (AS-07).
create or replace function app.ticket_resolve_hours(p_type text, p_priority text, p_category_code text)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce((select c.resolve_hours_override from app.ticket_category c where c.code = p_category_code),
                  (select r.resolve_hours from app.ticket_sla_rule r where r.ticket_type = p_type and r.priority_code = p_priority));
$$;

-- app.create_ticket(dữ liệu): tạo ticket. Ai gọi: người có quyền Ticket · Tạo ở cơ sở đó (CSKH, Sale, Quản lý cơ sở, giáo viên).
-- Dữ liệu (jsonb): ticket_type (DN, KN, GV), branch_id (mặc định cơ sở của người tạo), title, description, channel_code, category_code (nhóm con),
-- priority_code (tuỳ chọn, mặc định theo nhóm con), parent_id (bắt buộc với DN, KN), student_id, class_id, enrollment_id, accused_user_id, related_ticket_id.
-- Ticket giáo viên: người gửi là chính người tạo. Kết quả: {id, code}. Luật: công tắc AFTERSALE (AS-13), mã AS-01, hạn AS-07, bắt buộc học sinh, lớp theo nhóm con (AS-05, AS-10).
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
  if v_type = 'GV' and not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('TEACHER', 'TA')) then
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

-- app.assign_ticket(mã ticket, đội, người phụ trách): giao ticket (Mới → Đã giao; ticket đang xử lý thì giao lại, giữ trạng thái).
-- Ai gọi: Ticket · Sửa ở cơ sở đó (CSKH, Quản lý cơ sở). Người phụ trách phải là nhân sự đúng cơ sở (AS-09).
create or replace function app.assign_ticket(p_id uuid, p_team text, p_assignee uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không giao lại được.');
  end if;
  perform app.assert_catalog_code_active('TICKET_TEAM', p_team);
  perform app.assert_staff_in_branch(p_assignee, t.branch_id);
  update app.ticket set team_code = p_team, assignee_id = p_assignee, status_code = case when status_code = 'MOI' then 'DA_GIAO' else status_code end
   where id = p_id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, from_status, to_status)
  values (p_id, t.branch_id, 'GIAO', t.status_code, case when t.status_code = 'MOI' then 'DA_GIAO' else t.status_code end);
end;
$$;

-- app.change_ticket_status(mã ticket, trạng thái mới, ghi chú, mức hài lòng, kết quả): chuyển trạng thái theo luồng chung (AS-02).
-- Luồng: Mới → Đã giao (qua app.assign_ticket) → Đang xử lý ↔ Chờ thông tin; Đang xử lý → Đã xử lý → Đã đóng; Đã xử lý → Đang xử lý; Đã đóng → Đang xử lý (mở lại
-- trong complaint_reopen_max_days, AS-03); Đã huỷ từ mọi bước trước khi đóng, bắt buộc lý do. Ai gọi: Ticket · Sửa ở cơ sở đó.
-- Luật: Đã xử lý cần kết quả; đóng khiếu nại cần mức hài lòng 1 đến 5 (AS-04); đóng ticket nhóm con có nghiệp vụ cần ghi chú "làm tay" (AS-03, R-V2-24, chưa có phiếu);
-- ra khỏi Chờ thông tin thì dời hạn bằng thời gian đã chờ (AS-07); lần đầu sang Đang xử lý ghi thời điểm phản hồi đầu.
create or replace function app.change_ticket_status(p_id uuid, p_to text, p_note text default null, p_satisfaction integer default null, p_resolution text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_resolution text := nullif(btrim(coalesce(p_resolution, '')), '');
  v_ok boolean;
  v_pause interval;
  v_biz text;
begin
  select * into t from app.ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  perform app.assert_catalog_code_active('TICKET_STATUS', p_to);
  -- Luật AS-02: bảng chuyển trạng thái hợp lệ.
  v_ok := (t.status_code, p_to) in (
    ('MOI', 'DA_GIAO'), ('MOI', 'DA_HUY'),
    ('DA_GIAO', 'DANG_XU_LY'), ('DA_GIAO', 'DA_HUY'),
    ('DANG_XU_LY', 'CHO_THONG_TIN'), ('DANG_XU_LY', 'DA_XU_LY'), ('DANG_XU_LY', 'DA_HUY'),
    ('CHO_THONG_TIN', 'DANG_XU_LY'), ('CHO_THONG_TIN', 'DA_HUY'),
    ('DA_XU_LY', 'DA_DONG'), ('DA_XU_LY', 'DANG_XU_LY'), ('DA_XU_LY', 'DA_HUY'),
    ('DA_DONG', 'DANG_XU_LY'));
  if not v_ok then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Không chuyển được ticket từ trạng thái này sang trạng thái đã chọn.');
  end if;
  if p_to = 'DA_GIAO' and (t.team_code is null or t.assignee_id is null) then
    perform app.raise_error('HMT_TICKET_CHUA_GIAO', 'Cần chọn đội và người phụ trách (giao ticket) trước.');
  end if;
  if p_to = 'DA_HUY' and v_note is null then
    perform app.raise_error('HMT_TICKET_THIEU_LY_DO', 'Huỷ ticket cần ghi lý do.');
  end if;
  if p_to = 'DA_XU_LY' and coalesce(v_resolution, t.resolution) is null then
    perform app.raise_error('HMT_TICKET_THIEU_KET_QUA', 'Chuyển sang Đã xử lý cần ghi kết quả.');
  end if;
  if p_to = 'DA_DONG' then
    -- Luật AS-04: đóng khiếu nại bắt buộc mức hài lòng 1 đến 5.
    if t.ticket_type = 'KN' and (p_satisfaction is null or p_satisfaction not between 1 and 5) then -- allow-number: thang 1 đến 5
      perform app.raise_error('HMT_TICKET_THIEU_HAI_LONG', 'Đóng khiếu nại cần ghi mức hài lòng của phụ huynh từ 1 đến 5.');
    end if;
    -- Luật AS-03, R-V2-24: nhóm con có nghiệp vụ chưa có phiếu thì đóng bằng tay kèm ghi chú.
    select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
    if v_biz is not null and v_note is null then
      perform app.raise_error('HMT_TICKET_THIEU_GHI_CHU', 'Ticket có nghiệp vụ đi kèm: đóng bằng tay cần ghi chú (làm tay).');
    end if;
  end if;
  if p_to = 'DANG_XU_LY' and t.status_code = 'DA_DONG' then
    -- Luật AS-03: mở lại trong số ngày cho phép sau khi đóng.
    if t.closed_at is null or now() > t.closed_at + make_interval(days => app.get_setting_int('complaint_reopen_max_days')::integer) then
      perform app.raise_error('HMT_TICKET_QUA_HAN_MO_LAI', 'Đã quá số ngày cho phép mở lại ticket.');
    end if;
  end if;
  -- Luật AS-07: ra khỏi Chờ thông tin thì dời hạn bằng thời gian đã chờ.
  if t.status_code = 'CHO_THONG_TIN' and t.paused_at is not null then
    v_pause := now() - t.paused_at;
  end if;
  update app.ticket set
    status_code = p_to,
    resolution = coalesce(v_resolution, resolution),
    cancel_reason = case when p_to = 'DA_HUY' then v_note else cancel_reason end,
    satisfaction = case when p_to = 'DA_DONG' and t.ticket_type = 'KN' then p_satisfaction else satisfaction end,
    first_response_at = case when p_to = 'DANG_XU_LY' and first_response_at is null then now() else first_response_at end,
    paused_at = case when p_to = 'CHO_THONG_TIN' then now() else null end,
    response_due_at = case when v_pause is not null and first_response_at is null then response_due_at + v_pause else response_due_at end,
    resolve_due_at = case when v_pause is not null then resolve_due_at + v_pause else resolve_due_at end,
    resolved_at = case when p_to = 'DA_XU_LY' then now() when p_to = 'DANG_XU_LY' then null else resolved_at end,
    closed_at = case when p_to = 'DA_DONG' then now() when p_to = 'DANG_XU_LY' then null else closed_at end
   where id = p_id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, from_status, to_status, note)
  values (p_id, t.branch_id, 'DOI_TRANG_THAI', t.status_code, p_to, v_note);
end;
$$;

-- Dòng danh sách ticket (dùng chung cho danh sách CSN01 và Kanban CSN02). Trạng thái hạn: QUA_HAN, SAP_QUA_HAN (còn dưới as_sla_warn_percent thời gian xử lý),
-- CHO_DONG (Đã xử lý quá as_close_wait_days chưa đóng); ticket đã xử lý, đóng, huỷ không tính quá hạn (AS-07).
create or replace function app.ticket_row(t app.ticket)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'code', t.code, 'title', t.title, 'ticket_type', t.ticket_type, 'branch_code', (select b.code from app.branch b where b.id = t.branch_id),
    'category_name', (select c.name from app.ticket_category c where c.code = t.category_code), 'priority_code', t.priority_code, 'status_code', t.status_code,
    'assignee_name', app.staff_display_name(t.assignee_id),
    'sender_name', coalesce((select p.full_name from app.parent p where p.id = t.parent_id), app.staff_display_name(t.sender_user_id)),
    'resolve_due_at', t.resolve_due_at, 'created_at', t.created_at,
    'sla_state', case
      when t.status_code = 'DA_XU_LY' and t.resolved_at < now() - make_interval(days => app.get_setting_int('as_close_wait_days')::integer) then 'CHO_DONG'
      when t.status_code in ('DA_XU_LY', 'DA_DONG', 'DA_HUY') then 'KHONG'
      when now() > t.resolve_due_at then 'QUA_HAN'
      when t.resolve_due_at - now() < (t.resolve_due_at - t.created_at) * (app.get_setting_int('as_sla_warn_percent') / 100.0)::double precision then 'SAP_QUA_HAN' -- allow-number: phần trăm chia 100
      else 'KHONG' end);
$$;

-- app.list_tickets(bộ lọc, số dòng, bỏ qua): danh sách ticket phân trang ở máy chủ (CSN01). RLS lọc theo quyền người gọi (không security definer).
-- Bộ lọc (jsonb, đều tuỳ chọn): ticket_type, status_code, category_code, priority_code, sla_state (QUA_HAN, SAP_QUA_HAN, CHO_DONG), mine (true: tôi tạo hoặc tôi phụ trách),
-- branch_id, q (mã hoặc tiêu đề). Số dòng mặc định list_page_size_default, tối đa list_page_size_max. Kết quả {total, rows[]}; mới nhất trước.
create or replace function app.list_tickets(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_sla text := nullif(p_filters ->> 'sla_state', '');
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select t from app.ticket t
     where (p_filters ->> 'ticket_type' is null or t.ticket_type = p_filters ->> 'ticket_type')
       and (p_filters ->> 'status_code' is null or t.status_code = p_filters ->> 'status_code')
       and (p_filters ->> 'category_code' is null or t.category_code = p_filters ->> 'category_code')
       and (p_filters ->> 'priority_code' is null or t.priority_code = p_filters ->> 'priority_code')
       and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
       and (coalesce((p_filters ->> 'mine')::boolean, false) = false or t.created_by = auth.uid() or t.assignee_id = auth.uid())
       and (v_q is null or t.code ilike '%' || v_q || '%' or t.title ilike '%' || v_q || '%')
       and (v_sla is null or app.ticket_row(t) ->> 'sla_state' = v_sla))
  select (select count(*) from f),
         coalesce((select jsonb_agg(app.ticket_row(x.t) order by (x.t).created_at desc, (x.t).id)
                     from (select f.t from f order by (f.t).created_at desc, (f.t).id limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.ticket_board(bộ lọc, số dòng mỗi cột): Kanban theo trạng thái (CSN02), một lần gọi. Mỗi cột {status_code, total, rows[]}; bộ lọc như app.list_tickets.
create or replace function app.ticket_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default 20)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('status_code', s.code, 'name', s.name,
           'total', (app.list_tickets(p_filters || jsonb_build_object('status_code', s.code), 1, 0) ->> 'total')::bigint,
           'rows', app.list_tickets(p_filters || jsonb_build_object('status_code', s.code), least(greatest(p_per_column, 1), 50), 0) -> 'rows') -- allow-number: trần 50 dòng mỗi cột Kanban
         order by s.sort_order), '[]'::jsonb)
    from app.catalog_item s where s.catalog_code = 'TICKET_STATUS' and s.is_active;
$$;

revoke execute on function app.ticket_resolve_hours(text, text, text), app.create_ticket(jsonb), app.assign_ticket(uuid, text, uuid),
  app.change_ticket_status(uuid, text, text, integer, text), app.ticket_row(app.ticket), app.list_tickets(jsonb, integer, integer),
  app.ticket_board(jsonb, integer) from public, anon, authenticated;
grant execute on function app.create_ticket(jsonb), app.assign_ticket(uuid, text, uuid), app.change_ticket_status(uuid, text, text, integer, text),
  app.list_tickets(jsonb, integer, integer), app.ticket_board(jsonb, integer), app.ticket_row(app.ticket) to authenticated;

select set_config('hmt.migration', '', false);
