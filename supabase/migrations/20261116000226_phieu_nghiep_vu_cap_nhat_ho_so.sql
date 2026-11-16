-- Code B (16/11/2026), Aftersale nhóm phiếu A1, migration 226: phiếu nghiệp vụ chung (app.ticket_task) và phiếu «Cập nhật hồ sơ».
-- Luật: docs/spec/de-xuat-luat-aftersale.md AS-03 (ticket có nghiệp vụ tự sang Đã xử lý khi phiếu xong), AS-10 (7 phiếu; thứ tự làm A→B→C; Nháp → Chờ duyệt →
-- Đã duyệt → Đã thực hiện; nhánh Từ chối có lý do), AS-13 (công tắc AFTERSALE), R-V2-24 (nghiệp vụ thật gắn nhóm con), R-CS-07 (người duyệt theo loại phiếu: cấu hình).
-- Làm gì: bảng phiếu, nhật ký phiếu (chỉ thêm), cấu hình cấp duyệt từng loại phiếu và trường hồ sơ được phép sửa; sáu hàm: tạo, trình, duyệt, từ chối, thực hiện, huỷ.
-- Lát này chỉ THỰC HIỆN được phiếu Cập nhật hồ sơ (không đụng tiền, không đụng ghi danh). Sáu loại phiếu còn lại tạo được ở bước Nháp nhưng thực hiện báo
-- HMT_PHIEU_CHUA_LAM cho tới khi có luật và hàm riêng (chuyển lớp, bảo lưu, đổi lịch dùng bản ghi của cụm Ghi danh).
-- Quyết định tự chọn (phương án an toàn, Chat xác nhận hoặc đổi): người tạo phiếu không tự duyệt phiếu của mình (kể cả Admin); duyệt Cập nhật hồ sơ một cấp: quản lý cơ sở;
-- không sửa SĐT, mã, cơ sở tiếp nhận của hồ sơ (danh tính hồ sơ, R-CRM-28); chỉ sửa các trường trong bảng cấu hình ticket_task_field.
select set_config('hmt.migration', 'on', false);

insert into app.catalog_item (catalog_code, code, name, sort_order) values ('DOC_TYPE', 'PNV', 'Phiếu nghiệp vụ', 8);

-- Cấu hình: số cấp duyệt từng loại phiếu (AS-10, R-CS-07). QUAN_LY_CO_SO: quyền Ticket · Duyệt ở cơ sở của ticket; KE_TOAN: vai trò kế toán.
create table app.ticket_task_rule (
  id uuid primary key default gen_random_uuid(),
  task_type text not null unique check (task_type in ('CAP_NHAT_HO_SO', 'DOI_LICH', 'CHUYEN_LOP', 'BAO_LUU', 'DUNG_HOC', 'HOAN_PHI', 'CHUYEN_PHI')),
  levels text[] not null check (cardinality(levels) between 1 and 3 and levels <@ array['QUAN_LY_CO_SO', 'KE_TOAN']), -- allow-number: tối đa 3 cấp, hiện dùng 1 đến 2
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.ticket_task_rule is 'Cấp duyệt của từng loại phiếu nghiệp vụ (R-CS-07, AS-10). Admin sửa; phiếu đã trình giữ số cấp đã chụp.';
select app.apply_standard('app.ticket_task_rule');
insert into app.ticket_task_rule (task_type, levels) values
  ('CAP_NHAT_HO_SO', array['QUAN_LY_CO_SO']), ('DOI_LICH', array['QUAN_LY_CO_SO']), ('CHUYEN_LOP', array['QUAN_LY_CO_SO']), ('BAO_LUU', array['QUAN_LY_CO_SO']),
  ('DUNG_HOC', array['QUAN_LY_CO_SO', 'KE_TOAN']), ('HOAN_PHI', array['QUAN_LY_CO_SO', 'KE_TOAN']), ('CHUYEN_PHI', array['QUAN_LY_CO_SO', 'KE_TOAN']);

-- Cấu hình: trường hồ sơ được phép sửa bằng phiếu Cập nhật hồ sơ. SĐT, mã, cơ sở tiếp nhận KHÔNG nằm ở đây (danh tính hồ sơ).
create table app.ticket_task_field (
  id uuid primary key default gen_random_uuid(),
  entity text not null check (entity in ('PARENT', 'STUDENT')),
  field_code text not null,
  label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (entity, field_code)
);
comment on table app.ticket_task_field is 'Trường hồ sơ sửa được qua phiếu Cập nhật hồ sơ. Chỉ các trường có cột tương ứng trong hàm app.execute_ticket_task dùng được.';
select app.apply_standard('app.ticket_task_field');
insert into app.ticket_task_field (entity, field_code, label) values
  ('PARENT', 'full_name', 'Họ tên phụ huynh'), ('PARENT', 'address', 'Địa chỉ'), ('PARENT', 'relative_name', 'Người thân'),
  ('STUDENT', 'school', 'Trường'), ('STUDENT', 'school_type', 'Loại trường'), ('STUDENT', 'grade', 'Khối'), ('STUDENT', 'goal', 'Mục tiêu'), ('STUDENT', 'gender', 'Giới tính');

create table app.ticket_task (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  ticket_id uuid not null references app.ticket (id),
  branch_id uuid not null references app.branch (id),
  task_type text not null references app.ticket_task_rule (task_type),
  status_code text not null default 'NHAP' check (status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET', 'DA_THUC_HIEN', 'TU_CHOI', 'DA_HUY')),
  reason text not null check (btrim(reason) <> ''),
  payload jsonb not null default '{}'::jsonb,
  result jsonb,
  levels text[] not null,
  current_level integer not null default 0 check (current_level >= 0),
  reject_reason text,
  cancel_reason text,
  submitted_at timestamptz,
  approved_at timestamptz,
  executed_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (status_code <> 'TU_CHOI' or reject_reason is not null),
  check (status_code <> 'DA_HUY' or cancel_reason is not null)
);
comment on table app.ticket_task is 'Phiếu nghiệp vụ gắn ticket (AS-10): Nháp → Chờ duyệt → Đã duyệt → Đã thực hiện; nhánh Từ chối và Huỷ có lý do. Không xoá.';
-- Chỉ mục (lý do): theo ticket (một phiếu đang mở mỗi ticket, danh sách phiếu của ticket); theo cơ sở và trạng thái (hàng chờ duyệt, CSN-05); khoá ngoại.
create index ticket_task_ticket_idx on app.ticket_task (ticket_id, created_at desc);
create index ticket_task_branch_status_idx on app.ticket_task (branch_id, status_code);
-- Mỗi ticket chỉ một phiếu đang mở (Nháp, Chờ duyệt, Đã duyệt): luật AS-10, kiểm cả ở DB.
create unique index ticket_task_one_open_idx on app.ticket_task (ticket_id) where status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET');
select app.apply_standard('app.ticket_task');

create table app.ticket_task_event (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  task_id uuid not null references app.ticket_task (id),
  branch_id uuid not null references app.branch (id),
  event_type text not null check (event_type in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'THUC_HIEN', 'HUY')),
  from_status text,
  to_status text,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.ticket_task_event is 'Nhật ký phiếu nghiệp vụ, chỉ thêm dòng.';
create index ticket_task_event_task_idx on app.ticket_task_event (task_id, seq);
create index ticket_task_event_branch_idx on app.ticket_task_event (branch_id);
select app.apply_standard('app.ticket_task_event');
create trigger ticket_task_event_no_update before update on app.ticket_task_event for each row execute function app.tg_ticket_event_append_only();

-- RLS: thấy phiếu nếu thấy ticket của phiếu (cùng phạm vi AS-09); ghi chỉ qua hàm nghiệp vụ.
alter table app.ticket_task enable row level security;
alter table app.ticket_task_event enable row level security;
alter table app.ticket_task_rule enable row level security;
alter table app.ticket_task_field enable row level security;
revoke all on app.ticket_task, app.ticket_task_event, app.ticket_task_rule, app.ticket_task_field from public, anon, authenticated;
grant select on app.ticket_task, app.ticket_task_event, app.ticket_task_rule, app.ticket_task_field to authenticated;
create policy ticket_task_read on app.ticket_task for select to authenticated using (exists (select from app.ticket t where t.id = ticket_task.ticket_id));
create policy ticket_task_event_read on app.ticket_task_event for select to authenticated using (exists (select from app.ticket_task k where k.id = ticket_task_event.task_id));
create policy ticket_task_rule_read on app.ticket_task_rule for select to authenticated using ((select app.has_permission('TICKET', 'XEM')));
create policy ticket_task_field_read on app.ticket_task_field for select to authenticated using ((select app.has_permission('TICKET', 'XEM')));

-- app.ticket_task_log (nội bộ): ghi một dòng nhật ký phiếu.
create or replace function app.ticket_task_log(p_task app.ticket_task, p_type text, p_from text, p_to text, p_note text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.ticket_task_event (task_id, branch_id, event_type, from_status, to_status, note) values (p_task.id, p_task.branch_id, p_type, p_from, p_to, p_note);
$$;

-- app.ticket_task_finish_ticket (nội bộ): phiếu Đã thực hiện hoặc Từ chối thì ticket có nghiệp vụ tự sang Đã xử lý, người phụ trách đóng tay (AS-03).
create or replace function app.ticket_task_finish_ticket(p_ticket_id uuid, p_resolution text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_ticket_id for update;
  -- Luật AS-03: chỉ chuyển khi ticket còn đang xử lý; đã Đã xử lý, Đã đóng, Đã huỷ thì giữ nguyên.
  if t.status_code in ('MOI', 'DA_GIAO', 'DANG_XU_LY', 'CHO_THONG_TIN') then
    update app.ticket set status_code = 'DA_XU_LY', resolution = coalesce(resolution, p_resolution), resolved_at = now(),
           first_response_at = coalesce(first_response_at, now()), paused_at = null
     where id = t.id;
    insert into app.ticket_event (ticket_id, branch_id, event_type, from_status, to_status, note)
    values (t.id, t.branch_id, 'DOI_TRANG_THAI', t.status_code, 'DA_XU_LY', 'Phiếu nghiệp vụ xong: ' || p_resolution);
  end if;
end;
$$;

-- app.create_ticket_task(ticket, loại phiếu, lý do, dữ liệu): tạo phiếu ở bước Nháp. Ai gọi: Ticket · Sửa ở cơ sở của ticket.
-- Luật: công tắc AFTERSALE (AS-13); ticket chưa đóng, chưa huỷ; nhóm con của ticket có phiếu nghiệp vụ đúng loại (R-V2-24); mỗi ticket một phiếu đang mở (AS-10);
-- lý do bắt buộc; phiếu Cập nhật hồ sơ kiểm dữ liệu sớm (trường được phép, hồ sơ thuộc ticket). Kết quả {id, code}.
-- Dữ liệu Cập nhật hồ sơ: {entity: PARENT|STUDENT, changes: {trường: giá trị}}; hồ sơ là học sinh của ticket (STUDENT) hoặc phụ huynh của ticket/học sinh (PARENT).
create or replace function app.create_ticket_task(p_ticket_id uuid, p_type text, p_reason text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_biz text;
  v_levels text[];
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_entity text;
  v_key text;
begin
  select * into t from app.ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không tạo phiếu được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập lý do của phiếu.');
  end if;
  select r.levels into v_levels from app.ticket_task_rule r where r.task_type = p_type;
  if v_levels is null then
    perform app.raise_error('HMT_PHIEU_LOAI_SAI', 'Loại phiếu nghiệp vụ không có.');
  end if;
  -- Luật R-V2-24: nhóm con của ticket phải có phiếu nghiệp vụ đúng loại.
  select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
  if v_biz is distinct from p_type then
    perform app.raise_error('HMT_PHIEU_KHAC_NHOM', 'Nhóm con của ticket này không dùng loại phiếu đã chọn.');
  end if;
  -- Luật AS-10: mỗi ticket một phiếu đang mở.
  if exists (select from app.ticket_task k where k.ticket_id = t.id and k.status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO', 'Ticket này đã có một phiếu đang mở. Xong hoặc huỷ phiếu đó trước.');
  end if;
  -- Kiểm sớm dữ liệu phiếu Cập nhật hồ sơ.
  if p_type = 'CAP_NHAT_HO_SO' then
    v_entity := p_payload ->> 'entity';
    if v_entity is null or v_entity not in ('PARENT', 'STUDENT') or jsonb_typeof(p_payload -> 'changes') is distinct from 'object' or (p_payload -> 'changes') = '{}'::jsonb then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn hồ sơ (phụ huynh hoặc học sinh) và ít nhất một trường cần sửa.');
    end if;
    if v_entity = 'STUDENT' and t.student_id is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.');
    end if;
    for v_key in select jsonb_object_keys(p_payload -> 'changes') loop
      if not exists (select from app.ticket_task_field f where f.entity = v_entity and f.field_code = v_key and f.is_active) then
        perform app.raise_error('HMT_PHIEU_TRUONG_SAI', 'Trường này không được sửa bằng phiếu Cập nhật hồ sơ.');
      end if;
    end loop;
  end if;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('PNV', v_branch_code);
  insert into app.ticket_task (code, ticket_id, branch_id, task_type, reason, payload, levels)
  values (v_code, t.id, t.branch_id, p_type, v_reason, coalesce(p_payload, '{}'::jsonb), v_levels) returning id into v_id;
  perform app.ticket_task_log((select k from app.ticket_task k where k.id = v_id), 'TAO', null, 'NHAP', null);
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- app.submit_ticket_task(mã phiếu): trình duyệt (Nháp → Chờ duyệt, cấp 1). Ai gọi: Ticket · Sửa ở cơ sở của phiếu.
create or replace function app.submit_ticket_task(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  perform app.assert_can('TICKET', 'SUA', k.branch_id);
  if k.status_code <> 'NHAP' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ trình phiếu đang ở bước Nháp.');
  end if;
  update app.ticket_task set status_code = 'CHO_DUYET', current_level = 1, submitted_at = now() where id = k.id;
  perform app.ticket_task_log(k, 'TRINH', 'NHAP', 'CHO_DUYET', null);
end;
$$;

-- app.approve_ticket_task(mã phiếu, ghi chú): duyệt một cấp; hết cấp thì sang Đã duyệt. Ai gọi: người có quyền duyệt của cấp hiện tại (R-CS-07).
-- Luật: cấp QUAN_LY_CO_SO cần Ticket · Duyệt ở cơ sở của phiếu; cấp KE_TOAN cần vai trò kế toán; người tạo phiếu không tự duyệt (quyết định an toàn, xem đầu file).
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
  if v_level = 'KE_TOAN' then
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN')) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho kế toán.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', null);
  else
    perform app.assert_can('TICKET', 'DUYET', k.branch_id);
  end if;
  if k.created_by is not distinct from auth.uid() then
    perform app.raise_error('HMT_PHIEU_TU_DUYET', 'Người tạo phiếu không tự duyệt phiếu của mình.');
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

-- app.reject_ticket_task(mã phiếu, lý do): từ chối (Chờ duyệt → Từ chối), bắt buộc lý do; ticket có nghiệp vụ tự sang Đã xử lý (AS-03). Ai gọi: như duyệt.
create or replace function app.reject_ticket_task(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_level text;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  if k.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ từ chối phiếu đang Chờ duyệt.');
  end if;
  v_level := k.levels[k.current_level];
  if v_level = 'KE_TOAN' then
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN')) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho kế toán.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', null);
  else
    perform app.assert_can('TICKET', 'DUYET', k.branch_id);
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_PHIEU_THIEU_LY_DO', 'Từ chối phiếu cần ghi lý do.');
  end if;
  update app.ticket_task set status_code = 'TU_CHOI', reject_reason = v_reason where id = k.id;
  perform app.ticket_task_log(k, 'TU_CHOI', 'CHO_DUYET', 'TU_CHOI', v_reason);
  perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' bị từ chối.');
end;
$$;

-- app.execute_ticket_task(mã phiếu): thực hiện phiếu Đã duyệt. Ai gọi: Ticket · Sửa ở cơ sở của phiếu.
-- Lát A1: chỉ phiếu Cập nhật hồ sơ (sửa trường trong ticket_task_field của phụ huynh hoặc học sinh gắn ticket; ghi giá trị trước và sau vào kết quả phiếu).
-- Các loại phiếu khác báo HMT_PHIEU_CHUA_LAM. Xong thì ticket có nghiệp vụ tự sang Đã xử lý (AS-03).
create or replace function app.execute_ticket_task(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  v_entity text;
  v_ch jsonb;
  v_target uuid;
  v_before jsonb;
  v_grade smallint;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  perform app.assert_can('TICKET', 'SUA', k.branch_id);
  if k.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ thực hiện phiếu đã duyệt.');
  end if;
  if k.task_type <> 'CAP_NHAT_HO_SO' then
    perform app.raise_error('HMT_PHIEU_CHUA_LAM', 'Loại phiếu này chưa thực hiện được ở bản hiện tại.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  v_entity := k.payload ->> 'entity';
  v_ch := k.payload -> 'changes';
  if v_entity = 'STUDENT' then
    v_target := t.student_id;
    if v_target is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh.');
    end if;
    select jsonb_build_object('school', s.school, 'school_type', s.school_type, 'grade', s.grade, 'goal', s.goal, 'gender', s.gender) into v_before from app.student s where s.id = v_target;
    if v_ch ? 'grade' then
      v_grade := nullif(v_ch ->> 'grade', '')::smallint;
    end if;
    -- Luật: chỉ cập nhật khoá có trong phiếu; các trường khác giữ nguyên (không dùng SQL động).
    update app.student s set
      school = case when v_ch ? 'school' then nullif(btrim(v_ch ->> 'school'), '') else s.school end,
      school_type = case when v_ch ? 'school_type' then nullif(btrim(v_ch ->> 'school_type'), '') else s.school_type end,
      grade = case when v_ch ? 'grade' then v_grade else s.grade end,
      goal = case when v_ch ? 'goal' then nullif(btrim(v_ch ->> 'goal'), '') else s.goal end,
      gender = case when v_ch ? 'gender' then nullif(btrim(v_ch ->> 'gender'), '') else s.gender end
     where s.id = v_target;
  else
    -- PARENT: phụ huynh của ticket, hoặc phụ huynh của học sinh gắn ticket.
    v_target := coalesce(t.parent_id, (select s.parent_id from app.student s where s.id = t.student_id));
    if v_target is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không xác định được phụ huynh để cập nhật.');
    end if;
    select jsonb_build_object('full_name', p.full_name, 'address', p.address, 'relative_name', p.relative_name) into v_before from app.parent p where p.id = v_target;
    update app.parent p set
      full_name = case when v_ch ? 'full_name' then coalesce(nullif(btrim(v_ch ->> 'full_name'), ''), p.full_name) else p.full_name end,
      address = case when v_ch ? 'address' then nullif(btrim(v_ch ->> 'address'), '') else p.address end,
      relative_name = case when v_ch ? 'relative_name' then nullif(btrim(v_ch ->> 'relative_name'), '') else p.relative_name end
     where p.id = v_target;
  end if;
  update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(),
         result = jsonb_build_object('entity', v_entity, 'record_id', v_target, 'before', v_before, 'changes', v_ch)
   where id = k.id;
  perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
  perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
end;
$$;

-- app.cancel_ticket_task(mã phiếu, lý do): huỷ phiếu chưa thực hiện (Nháp, Chờ duyệt, Đã duyệt), bắt buộc lý do. Ai gọi: Ticket · Sửa ở cơ sở của phiếu.
create or replace function app.cancel_ticket_task(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  perform app.assert_can('TICKET', 'SUA', k.branch_id);
  if k.status_code not in ('NHAP', 'CHO_DUYET', 'DA_DUYET') then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu đã xong hoặc đã đóng, không huỷ được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_PHIEU_THIEU_LY_DO', 'Huỷ phiếu cần ghi lý do.');
  end if;
  update app.ticket_task set status_code = 'DA_HUY', cancel_reason = v_reason where id = k.id;
  perform app.ticket_task_log(k, 'HUY', k.status_code, 'DA_HUY', v_reason);
end;
$$;

revoke execute on function app.ticket_task_log(app.ticket_task, text, text, text, text), app.ticket_task_finish_ticket(uuid, text),
  app.create_ticket_task(uuid, text, text, jsonb), app.submit_ticket_task(uuid), app.approve_ticket_task(uuid, text), app.reject_ticket_task(uuid, text),
  app.execute_ticket_task(uuid), app.cancel_ticket_task(uuid, text) from public, anon, authenticated;
grant execute on function app.create_ticket_task(uuid, text, text, jsonb), app.submit_ticket_task(uuid), app.approve_ticket_task(uuid, text), app.reject_ticket_task(uuid, text),
  app.execute_ticket_task(uuid), app.cancel_ticket_task(uuid, text) to authenticated;

select set_config('hmt.migration', '', false);
