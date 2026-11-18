-- TT-A Phiếu tái tục, nền dữ liệu và thao tác tay (Code C, 18/11/2026; Chat 11:55 chốt chia 5 PR, R-V2-25 chốt lại 18/11 giữ phiếu tái tục).
-- Luật R-GD-13: phiếu tính theo (học sinh, lớp), mỗi cặp tối đa MỘT phiếu đang mở (L1 đến L7); vòng đời L1 đến L8; L5 Không tái tục kết thúc, bắt buộc lý do
-- (danh mục RENEWAL_LOST_REASON); L1B tạo tay. L7A/L7B/L8A do hàm báo giá, đơn (TT-D) đặt, KHÔNG đổi tay. Quyền: module UPSALE (Xem, Tạo, Sửa, Giao việc; không có Duyệt).
-- Làm gì: bảng upsale_ticket + upsale_ticket_event (chỉ thêm), mã TT + 6 số (spec 02), RLS đọc theo ma trận quyền, hàm tạo tay (TT-03), giao việc, đổi giai đoạn,
-- sửa hai ô tự do. Tự sinh theo ngưỡng giờ/ngày (TT-B), danh sách, Kanban, bản ghi (TT-C, TT-D) làm ở PR sau.
select set_config('hmt.migration', 'on', false);

-- 1. Mã phiếu: TT000123 (spec 02).
insert into app.code_format (code, name, prefix, pad_width, start_value) values ('TT', 'Phiếu tái tục', 'TT', 6, 1);

create or replace function app.issue_upsale_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format := app.code_format_of('TT');
begin
  -- Luật spec 02: cấp bằng bảng đếm khoá dòng, không nhảy số; chỉ hàm tạo phiếu gọi.
  return v_format.prefix || lpad(app.next_counter_value('TT', v_format.start_value)::text, v_format.pad_width, '0');
end;
$$;

-- 2. Bảng phiếu tái tục.
create table app.upsale_ticket (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  branch_id uuid not null references app.branch (id),
  student_id uuid not null references app.student (id),
  parent_id uuid not null references app.parent (id),
  class_id uuid not null references app.class (id),
  stage_code text not null default 'L1' check (stage_code in ('L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8')),
  substage_catalog text not null default 'UPSALE_SUBSTAGE' check (substage_catalog = 'UPSALE_SUBSTAGE'),
  substage_code text default 'L1B',
  owner_id uuid references app.user_account (id),
  origin_code text not null check (origin_code in ('HE_THONG', 'TAY')),
  lost_reason_code text,
  lost_note text,
  next_goal text,
  next_roadmap text,
  risk_flag boolean not null default false,
  hours_left numeric(6, 2),
  expected_end_date date,
  closed_at timestamptz,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (substage_catalog, substage_code) references app.catalog_item (catalog_code, code),
  check (stage_code <> 'L5' or lost_reason_code is not null)
);
comment on table app.upsale_ticket is 'Phiếu tái tục (R-GD-13): theo (học sinh, lớp). hours_left và expected_end_date là ảnh chụp lúc sinh (TT-B). Không xoá: kết thúc ở L5 hoặc L8.';
-- Chỉ mục (lý do ghi từng dòng):
-- Mỗi (học sinh, lớp) tối đa một phiếu đang mở (L1 đến L4, L6, L7): luật R-GD-13 và chỗ tra khi tự sinh.
create unique index upsale_ticket_open_uq on app.upsale_ticket (student_id, class_id) where stage_code not in ('L5', 'L8');
-- Danh sách và Kanban theo cơ sở, giai đoạn, mới nhất trước; cột trong chính sách đọc (branch_id).
create index upsale_ticket_branch_stage_idx on app.upsale_ticket (branch_id, stage_code, created_at desc);
-- Việc của tôi (lọc theo người phụ trách).
create index upsale_ticket_owner_idx on app.upsale_ticket (owner_id, stage_code) where owner_id is not null;
-- Khoá ngoại: hồ sơ phụ huynh, lớp (tra phiếu của lớp).
create index upsale_ticket_parent_idx on app.upsale_ticket (parent_id);
create index upsale_ticket_class_idx on app.upsale_ticket (class_id);
-- Tra phiếu đã kết thúc của (học sinh, lớp): L5 không sinh lại.
create index upsale_ticket_student_class_idx on app.upsale_ticket (student_id, class_id, stage_code);
-- Xếp theo ngày hết giờ dự kiến (cột TT-01).
create index upsale_ticket_expected_end_idx on app.upsale_ticket (branch_id, expected_end_date) where closed_at is null;
select app.apply_standard('app.upsale_ticket');

create table app.upsale_ticket_event (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  ticket_id uuid not null references app.upsale_ticket (id),
  branch_id uuid not null references app.branch (id),
  event_type text not null check (event_type in ('TAO', 'GIAO', 'DOI_GIAI_DOAN', 'SUA_GHI_CHU')),
  from_stage text,
  to_stage text,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.upsale_ticket_event is 'Nhật ký phiếu tái tục, chỉ thêm dòng: tạo, giao, đổi giai đoạn, sửa ghi chú.';
-- Chỉ mục (lý do): lịch sử của một phiếu theo thứ tự ghi; cơ sở cho RLS.
create index upsale_ticket_event_ticket_idx on app.upsale_ticket_event (ticket_id, seq);
create index upsale_ticket_event_branch_idx on app.upsale_ticket_event (branch_id);
select app.apply_standard('app.upsale_ticket_event');
create or replace function app.tg_upsale_ticket_event_append_only()
returns trigger language plpgsql set search_path = ''
as $$
begin
  perform app.raise_error('HMT_NHAT_KY_CHI_THEM', 'Nhật ký phiếu tái tục chỉ thêm dòng, không sửa.');
  return null;
end;
$$;
create trigger upsale_ticket_event_no_update before update on app.upsale_ticket_event for each row execute function app.tg_upsale_ticket_event_append_only();

-- 3. RLS đọc theo ma trận quyền UPSALE (như phiếu thu); ghi chỉ qua hàm nghiệp vụ.
alter table app.upsale_ticket enable row level security;
alter table app.upsale_ticket_event enable row level security;
revoke all on app.upsale_ticket, app.upsale_ticket_event from public, anon, authenticated;
grant select on app.upsale_ticket, app.upsale_ticket_event to authenticated;
create policy upsale_ticket_read on app.upsale_ticket for select to authenticated
  using ((select app.permission_scope('UPSALE', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('UPSALE', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy upsale_ticket_event_read on app.upsale_ticket_event for select to authenticated
  using ((select app.permission_scope('UPSALE', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('UPSALE', 'XEM')) is not null and branch_id = (select app.current_branch_id())));

-- Ghi một dòng nhật ký (hàm nội bộ).
create or replace function app.upsale_add_event(p_ticket_id uuid, p_type text, p_from text, p_to text, p_note text default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.upsale_ticket_event (ticket_id, branch_id, event_type, from_stage, to_stage, note)
  select t.id, t.branch_id, p_type, p_from, p_to, nullif(btrim(coalesce(p_note, '')), '') from app.upsale_ticket t where t.id = p_ticket_id;
$$;

-- ---------------------------------------------------------------------------
-- TT-03 Tạo phiếu tái tục thủ công. Ai gọi: người có quyền Phiếu tái tục · Tạo ở cơ sở của lớp (CSKH, Sale, Admin). Đầu vào: học sinh, lớp, ghi chú.
-- Kết quả: {id, code}. Luật R-GD-13: học sinh phải đang học ở lớp (dòng xếp lớp đang mở); mỗi (học sinh, lớp) tối đa một phiếu đang mở; phiếu ở L1B.
-- Phiếu L5 cũ không chặn tạo tay (CSKH tạo tay L1B khi cần). Công tắc Bán hàng kiểm trong hàm.
-- ---------------------------------------------------------------------------
create or replace function app.create_upsale_ticket(p_student_id uuid, p_class_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_class app.class;
  v_student app.student;
  v_id uuid;
  v_code text;
begin
  select * into v_class from app.class where id = p_class_id;
  select * into v_student from app.student where id = p_student_id;
  if v_class.id is null or v_student.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy học sinh hoặc lớp.');
  end if;
  perform app.assert_can('UPSALE', 'TAO', v_class.branch_id);
  perform app.require_feature('BAN_HANG', v_class.branch_id);
  -- Luật R-GD-13: học sinh phải đang học ở lớp này.
  if not exists (select from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id
                  where e.student_id = p_student_id and ec.class_id = p_class_id and ec.end_date is null) then
    perform app.raise_error('HMT_HOC_SINH_KHONG_O_LOP', 'Học sinh này hiện không học ở lớp đã chọn nên chưa tạo được phiếu tái tục.');
  end if;
  -- Luật R-GD-13: mỗi học sinh ở mỗi lớp tối đa một phiếu đang mở.
  if exists (select from app.upsale_ticket where student_id = p_student_id and class_id = p_class_id and stage_code not in ('L5', 'L8')) then
    perform app.raise_error('HMT_DA_CO_PHIEU_TAI_TUC', 'Học sinh này đã có phiếu tái tục đang mở ở lớp này.');
  end if;
  v_code := app.issue_upsale_code();
  insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  values (v_code, v_class.branch_id, p_student_id, v_student.parent_id, p_class_id, 'L1', 'L1B', 'TAY')
  returning id into v_id;
  perform app.upsale_add_event(v_id, 'TAO', null, 'L1', coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Tạo thủ công'));
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- ---------------------------------------------------------------------------
-- Giao phiếu cho người phụ trách. Ai gọi: người có quyền Phiếu tái tục · Giao việc (Trưởng cơ sở, CSKH, Admin theo ma trận) ở cơ sở của phiếu.
-- Đầu vào: phiếu, người nhận (người thuộc cơ sở của phiếu). Kết quả: {id, owner_id}. Phiếu đã kết thúc (L5, L8) không giao nữa.
-- ---------------------------------------------------------------------------
create or replace function app.assign_upsale_ticket(p_id uuid, p_owner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
begin
  select * into t from app.upsale_ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'GIAO_VIEC', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  if t.stage_code in ('L5', 'L8') then
    perform app.raise_error('HMT_PHIEU_DA_KET_THUC', 'Phiếu tái tục đã kết thúc, không giao nữa.');
  end if;
  -- Luật: người nhận phải thuộc cơ sở của phiếu.
  perform app.assert_staff_in_branch(p_owner_id, t.branch_id);
  update app.upsale_ticket set owner_id = p_owner_id where id = p_id;
  perform app.upsale_add_event(p_id, 'GIAO', t.stage_code, t.stage_code, 'Giao cho ' || coalesce(app.staff_display_name(p_owner_id), '(chưa rõ)'));
  return jsonb_build_object('id', p_id, 'owner_id', p_owner_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Đổi giai đoạn bằng tay. Ai gọi: người có quyền Phiếu tái tục · Sửa ở cơ sở của phiếu. Đầu vào: phiếu, giai đoạn mới, lý do (bắt buộc với L5), ghi chú.
-- Luật R-GD-13: bằng tay chỉ đi giữa L1 đến L4, tới L6 (Đồng ý) hoặc L5 (Không tái tục, bắt buộc lý do từ RENEWAL_LOST_REASON, «Khác» cần ghi chú).
-- L7 và L8 do hàm báo giá, đơn đặt (TT-D); phiếu đã ở L5, L7, L8 không đổi tay. Về L1 từ giai đoạn sau giữ nhóm con hiện có.
-- ---------------------------------------------------------------------------
create or replace function app.change_upsale_stage(p_id uuid, p_to text, p_reason_code text default null, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_item app.catalog_item;
begin
  select * into t from app.upsale_ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  -- Luật R-GD-13: phiếu đã kết thúc hoặc đã sang bước tiền thì không đổi tay.
  if t.stage_code in ('L5', 'L7', 'L8') then
    perform app.raise_error('HMT_PHIEU_KHONG_DOI_TAY', 'Phiếu tái tục đang ở bước này nên không đổi giai đoạn bằng tay được.');
  end if;
  if p_to not in ('L1', 'L2', 'L3', 'L4', 'L5', 'L6') or p_to = t.stage_code then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Giai đoạn mới không hợp lệ. L7 và L8 do hệ thống đặt khi có báo giá, đơn.');
  end if;
  -- Luật R-GD-13: L5 Không tái tục bắt buộc lý do từ danh mục; «Khác» cần ghi chú.
  if p_to = 'L5' then
    select * into v_item from app.catalog_item where catalog_code = 'RENEWAL_LOST_REASON' and code = p_reason_code and is_active;
    if v_item.id is null then
      perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do không tái tục.');
    end if;
    if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
      perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
    end if;
    update app.upsale_ticket set stage_code = 'L5', substage_code = null, lost_reason_code = p_reason_code,
           lost_note = nullif(btrim(coalesce(p_note, '')), ''), closed_at = now() where id = p_id;
  else
    -- Nhóm con chỉ có ở L1 (L1A hệ thống sinh, L1B tạo tay); sang giai đoạn khác thì bỏ.
    update app.upsale_ticket set stage_code = p_to,
           substage_code = case when p_to = 'L1' then case t.origin_code when 'HE_THONG' then 'L1A' else 'L1B' end end where id = p_id;
  end if;
  perform app.upsale_add_event(p_id, 'DOI_GIAI_DOAN', t.stage_code, p_to, p_note);
  return jsonb_build_object('id', p_id, 'stage_code', p_to);
end;
$$;

-- ---------------------------------------------------------------------------
-- Sửa hai ô tự do «Mục tiêu/nhu cầu tiếp theo» và «Lộ trình tiếp theo» (R-GD-13, 26/10). Mọi lần sửa ghi nhật ký (chỉ trường đổi).
-- Ai gọi: người có quyền Phiếu tái tục · Sửa. Đầu vào: phiếu, hai chuỗi (null = không đổi ô đó).
-- ---------------------------------------------------------------------------
create or replace function app.update_upsale_notes(p_id uuid, p_next_goal text default null, p_next_roadmap text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_changed text[] := '{}';
begin
  select * into t from app.upsale_ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  if p_next_goal is not null and p_next_goal is distinct from coalesce(t.next_goal, '') then
    v_changed := v_changed || 'Mục tiêu/nhu cầu tiếp theo'::text;
  end if;
  if p_next_roadmap is not null and p_next_roadmap is distinct from coalesce(t.next_roadmap, '') then
    v_changed := v_changed || 'Lộ trình tiếp theo'::text;
  end if;
  if array_length(v_changed, 1) is null then
    return jsonb_build_object('id', p_id, 'changed', false);
  end if;
  update app.upsale_ticket set next_goal = coalesce(nullif(btrim(p_next_goal), ''), case when p_next_goal is null then next_goal end),
                               next_roadmap = coalesce(nullif(btrim(p_next_roadmap), ''), case when p_next_roadmap is null then next_roadmap end)
   where id = p_id;
  perform app.upsale_add_event(p_id, 'SUA_GHI_CHU', t.stage_code, t.stage_code, 'Sửa: ' || array_to_string(v_changed, ', '));
  return jsonb_build_object('id', p_id, 'changed', true);
end;
$$;

select set_config('hmt.migration', '', false);

-- Hàm nội bộ không cho người đăng nhập gọi trực tiếp; hàm thao tác kiểm quyền bên trong.
revoke execute on function app.issue_upsale_code(), app.upsale_add_event(uuid, text, text, text, text), app.tg_upsale_ticket_event_append_only() from public, anon, authenticated;
revoke execute on function app.create_upsale_ticket(uuid, uuid, text), app.assign_upsale_ticket(uuid, uuid), app.change_upsale_stage(uuid, text, text, text),
  app.update_upsale_notes(uuid, text, text) from public, anon;
grant execute on function app.create_upsale_ticket(uuid, uuid, text), app.assign_upsale_ticket(uuid, uuid), app.change_upsale_stage(uuid, text, text, text),
  app.update_upsale_notes(uuid, text, text) to authenticated;
