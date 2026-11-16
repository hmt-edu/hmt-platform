-- Migration 216 (Code D, 16/11/2026): bản ghi nghiệp vụ Hoàn phí và Phiếu chi (R-TIEN-28, R-TIEN-31, R-TIEN-34, R-CS-02, R-CS-07, R-V2-24).
-- Tính tiền dùng app.compute_refund (migration 212). Việc duyệt nằm ở bản ghi này (R-V2-24): quản lý cơ sở rồi kế toán (R-CS-07);
-- kế toán duyệt xong thì hệ thống ghi sổ giờ ngược dấu, đổi tình trạng ghi danh (hoàn toàn bộ) và LẬP phiếu chi PC (R-TIEN-34).
-- Công tắc HOAN_PHI theo cơ sở, MẶC ĐỊNH TẮT. Chưa làm: giữ thành số dư khách hàng khi dừng học (R-GD-16, R-TIEN-33), chuyển phí.
-- Số liệu tiền chụp lúc tạo và kiểm lại lúc kế toán duyệt: lệch thì chặn, tạo yêu cầu mới (CLAUDE.md: bản ghi chụp lại giá trị).

-- ---------------------------------------------------------------------------
-- 1. Danh mục
-- ---------------------------------------------------------------------------
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'HOAN_PHI', 'Hoàn phí, phiếu chi', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;

insert into app.catalog (code, name, kind, description, sort_order)
select 'REFUND_REASON', 'Lý do hoàn phí', 'MO', 'Lý do hoàn phí, dùng cho báo cáo (R-CS-12).',
       (select coalesce(max(sort_order), 0) from app.catalog) + 1
where not exists (select from app.catalog where code = 'REFUND_REASON');

insert into app.catalog_item (catalog_code, code, name, sort_order)
values
  ('REFUND_REASON', 'CHUYEN_NOI_O', 'Chuyển nơi ở, không học được nữa', 1),
  ('REFUND_REASON', 'KHONG_HOP', 'Không phù hợp chương trình, lớp', 2),
  ('REFUND_REASON', 'TAI_CHINH', 'Khó khăn tài chính', 3),
  ('REFUND_REASON', 'KHAC', 'Lý do khác', 99)
on conflict (catalog_code, code) do nothing;
select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- 2. Bảng
-- ---------------------------------------------------------------------------
create table app.refund_request (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references app.enrollment (id),
  student_id uuid not null references app.student (id),
  branch_id uuid not null references app.branch (id),
  kind_code text not null check (kind_code in ('TOAN_BO', 'MOT_PHAN')),
  reason_catalog text not null default 'REFUND_REASON' check (reason_catalog = 'REFUND_REASON'),
  reason_code text not null,
  note text,
  ticket_ref text,
  -- Số liệu tiền chụp lúc tạo (app.compute_refund). Đồng; giờ numeric(8,2).
  hours_refund numeric(8, 2) not null check (hours_refund >= 0),
  paid_amount bigint not null,
  hours_used numeric(8, 2) not null,
  unit_price_base bigint not null,
  unit_price_net numeric(14, 2) not null,
  base_amount bigint not null,
  fee_percent numeric(5, 2) not null,
  fee_amount bigint not null,
  refund_amount bigint not null check (refund_amount > 0),
  status_code text not null default 'NHAP'
    check (status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET', 'DA_CHI', 'TU_CHOI', 'HUY')),
  manager_by uuid,
  manager_at timestamptz,
  accountant_by uuid,
  accountant_at timestamptz,
  reject_reason text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (reason_catalog, reason_code) references app.catalog_item (catalog_code, code)
);
comment on table app.refund_request is 'Bản ghi Hoàn phí (R-TIEN-28, 31; R-V2-24). Số tiền chụp lúc tạo. Ghi chỉ qua hàm nghiệp vụ.';
-- Chỉ mục (lý do): ghi danh (lịch sử, khoá ngoại); cơ sở + tình trạng cho danh sách duyệt và RLS; học sinh (khoá ngoại, hồ sơ).
create index refund_request_enrollment_idx on app.refund_request (enrollment_id, created_at desc);
create index refund_request_branch_idx on app.refund_request (branch_id, status_code, created_at desc);
create index refund_request_student_idx on app.refund_request (student_id);
-- Mỗi ghi danh chỉ một yêu cầu hoàn phí chưa xong.
create unique index refund_request_open_uidx on app.refund_request (enrollment_id)
  where status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET');
select app.apply_standard('app.refund_request');

-- Phiếu chi PC (R-TIEN-34): kế toán lập (sinh khi kế toán duyệt hoàn phí); chỉ thêm, đổi tình trạng khi đã chi.
create table app.payment_voucher (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  refund_request_id uuid not null unique references app.refund_request (id),
  branch_id uuid not null references app.branch (id),
  parent_id uuid not null references app.parent (id),
  amount bigint not null check (amount > 0),
  status_code text not null default 'CHO_CHI' check (status_code in ('CHO_CHI', 'DA_CHI')),
  paid_at timestamptz,
  paid_by uuid,
  pay_note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((status_code = 'DA_CHI') = (paid_at is not null))
);
comment on table app.payment_voucher is 'Phiếu chi PC cho hoàn phí (R-TIEN-34). Phiếu ghi theo cơ sở của học sinh.';
-- Chỉ mục (lý do): cơ sở + tình trạng (danh sách chờ chi, RLS); phụ huynh (khoá ngoại).
create index payment_voucher_branch_idx on app.payment_voucher (branch_id, status_code, created_at desc);
create index payment_voucher_parent_idx on app.payment_voucher (parent_id);
select app.apply_standard('app.payment_voucher');

alter table app.refund_request enable row level security;
alter table app.payment_voucher enable row level security;
revoke all on app.refund_request, app.payment_voucher from public, anon, authenticated;
grant select on app.refund_request, app.payment_voucher to authenticated;
-- Đọc: quyền Xem phiếu thu/phiếu chi (RECEIPT) theo phạm vi; số tiền nhạy cảm nên không dùng quyền Xem ghi danh.
create policy refund_request_read on app.refund_request for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));
create policy payment_voucher_read on app.payment_voucher for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- 3. Hàm
-- ---------------------------------------------------------------------------
create or replace function app.refund_request_for_update(p_id uuid, p_allowed text[])
returns app.refund_request
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  select * into r from app.refund_request where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu hoàn phí.');
  end if;
  if not (r.status_code = any (p_allowed)) then
    perform app.raise_error('HMT_HOAN_PHI_KHONG_DUOC_SUA', 'Yêu cầu hoàn phí đang ở trạng thái không cho thao tác này.');
  end if;
  return r;
end;
$$;

-- app.create_refund_request: tạo yêu cầu hoàn phí (Nháp), chụp số tiền. Ai: Ghi danh · Sửa; cờ HOAN_PHI bật.
-- Đầu vào: ghi danh, loại (TOAN_BO | MOT_PHAN), giờ hoàn (bắt buộc với MOT_PHAN), mã lý do, ghi chú, mã ticket.
-- Luật: R-TIEN-28, R-TIEN-31 (qua compute_refund). Ghi danh phải còn hiệu lực.
create or replace function app.create_refund_request(
  p_enrollment_id uuid, p_kind text, p_hours numeric, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('HOAN_PHI', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để hoàn phí.');
  end if;
  perform app.assert_catalog_code_active('REFUND_REASON', p_reason_code);
  if exists (select from app.refund_request where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET')) then
    perform app.raise_error('HMT_HOAN_PHI_DANG_MO', 'Ghi danh này đã có một yêu cầu hoàn phí chưa xong.');
  end if;
  v := app.compute_refund(e.id, p_kind, p_hours);
  insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, note, ticket_ref,
                                  hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net,
                                  base_amount, fee_percent, fee_amount, refund_amount)
  values (e.id, e.student_id, e.branch_id, p_kind, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_refund')::numeric, (v ->> 'paid_amount')::bigint, (v ->> 'hours_used')::numeric,
          (v ->> 'unit_price_base')::bigint, round((v ->> 'unit_price_net')::numeric, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
          (v ->> 'base_amount')::bigint,
          (v ->> 'fee_percent')::numeric, (v ->> 'fee_amount')::bigint, (v ->> 'refund_amount')::bigint)
  returning id into v_id;
  return v_id;
end;
$$;

-- app.submit_refund_request: Nháp → Chờ quản lý. Ai: Ghi danh · Sửa.
create or replace function app.submit_refund_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['NHAP']);
  perform app.assert_can('ENROLLMENT', 'SUA', r.branch_id);
  perform app.require_feature('HOAN_PHI', r.branch_id);
  update app.refund_request set status_code = 'CHO_QL' where id = r.id;
end;
$$;

-- app.approve_refund_manager: quản lý cơ sở duyệt (R-CS-07): Chờ quản lý → Chờ kế toán. Ai: Ghi danh · Duyệt; người tạo không tự duyệt (trừ Admin).
create or replace function app.approve_refund_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['CHO_QL']);
  perform app.assert_can('ENROLLMENT', 'DUYET', r.branch_id);
  perform app.require_feature('HOAN_PHI', r.branch_id);
  if r.created_by = (select auth.uid()) and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_HOAN_PHI_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  update app.refund_request set status_code = 'CHO_KE_TOAN', manager_by = (select auth.uid()), manager_at = now() where id = r.id;
end;
$$;

-- app.approve_refund_accountant: kế toán duyệt (R-CS-07, R-TIEN-34): ghi sổ giờ ngược dấu, đổi tình trạng ghi danh (hoàn toàn bộ),
-- lập phiếu chi PC. Ai: Đối soát kế toán · Duyệt (chỉ Kế toán, R-TIEN-01). Một Kế toán được vừa lập vừa duyệt (R-TIEN-34).
-- Kiểm lại số tiền: nếu số liệu đã đổi so với lúc tạo (có buổi Done, có thu/đảo tiền) thì chặn, tạo yêu cầu mới.
-- Kết quả: id phiếu chi.
create or replace function app.approve_refund_accountant(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
  e app.enrollment;
  v jsonb;
  v_left numeric;
  v_hours numeric;
  v_branch_code text;
  v_code text;
  v_voucher uuid;
begin
  r := app.refund_request_for_update(p_id, array['CHO_KE_TOAN']);
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  perform app.require_feature('HOAN_PHI', r.branch_id);
  select * into e from app.enrollment where id = r.enrollment_id for update;
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh không còn hiệu lực để hoàn phí.');
  end if;
  -- Luật chụp lại số tiền: tính lại, lệch thì chặn.
  v := app.compute_refund(e.id, r.kind_code, case when r.kind_code = 'MOT_PHAN' then r.hours_refund end);
  if (v ->> 'refund_amount')::bigint <> r.refund_amount or (v ->> 'hours_used')::numeric <> r.hours_used then
    perform app.raise_error('HMT_HOAN_PHI_SO_LIEU_DOI', 'Số liệu đã thay đổi từ lúc tạo yêu cầu (giờ đã học hoặc tiền đã đóng). Hãy huỷ và tạo yêu cầu mới.');
  end if;
  -- Sổ giờ ngược dấu (R-GD-04): hoàn toàn bộ trừ hết giờ còn lại (giờ tặng bị huỷ, R-TIEN-28); hoàn một phần trừ đúng giờ hoàn.
  v_left := app.enrollment_hours_balance(e.id);
  v_hours := case when r.kind_code = 'TOAN_BO' then greatest(v_left, 0) else r.hours_refund end;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('PC', v_branch_code);
  if v_hours > 0 then
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, source_ref)
    values (e.id, e.branch_id, 'DIEU_CHINH', -v_hours, 'KHAC', 'Hoàn phí ' || v_code, v_code); -- lý do «Khác» (bắt buộc ghi chú); không thêm mục vào danh mục lý do điều chỉnh
  end if;
  -- Hoàn toàn bộ: ghi danh sang Hoàn phí, đóng dòng xếp lớp đang mở.
  if r.kind_code = 'TOAN_BO' then
    update app.enrollment_class set end_date = greatest(current_date, start_date), end_reason = 'DUNG'
     where enrollment_id = e.id and end_date is null;
    update app.enrollment set status_code = 'HOAN_PHI' where id = e.id;
  end if;
  insert into app.payment_voucher (code, refund_request_id, branch_id, parent_id, amount)
  values (v_code, r.id, r.branch_id, e.parent_id, r.refund_amount)
  returning id into v_voucher;
  update app.refund_request set status_code = 'DA_DUYET', accountant_by = (select auth.uid()), accountant_at = now() where id = r.id;
  return v_voucher;
end;
$$;

-- app.pay_payment_voucher: ghi nhận đã chi tiền (Chờ chi → Đã chi); yêu cầu hoàn phí sang Đã chi. Ai: Đối soát kế toán · Duyệt.
create or replace function app.pay_payment_voucher(p_voucher_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pv app.payment_voucher;
begin
  select * into pv from app.payment_voucher where id = p_voucher_id for update;
  if pv.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chi.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', pv.branch_id);
  if pv.status_code <> 'CHO_CHI' then
    perform app.raise_error('HMT_PHIEU_CHI_DA_CHI', 'Phiếu chi này đã chi rồi.');
  end if;
  update app.payment_voucher set status_code = 'DA_CHI', paid_at = now(), paid_by = (select auth.uid()), pay_note = nullif(btrim(p_note), '')
   where id = pv.id;
  update app.refund_request set status_code = 'DA_CHI' where id = pv.refund_request_id;
end;
$$;

-- app.reject_refund_request: từ chối (bắt buộc lý do) ở bước quản lý hoặc kế toán. Ai: Ghi danh · Duyệt (bước quản lý), Đối soát kế toán · Duyệt (bước kế toán).
create or replace function app.reject_refund_request(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['CHO_QL', 'CHO_KE_TOAN']);
  if r.status_code = 'CHO_QL' then
    perform app.assert_can('ENROLLMENT', 'DUYET', r.branch_id);
  else
    perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  end if;
  if nullif(btrim(p_reason), '') is null then
    perform app.raise_error('HMT_HOAN_PHI_THIEU_LY_DO', 'Từ chối phải ghi lý do.');
  end if;
  update app.refund_request set status_code = 'TU_CHOI', reject_reason = btrim(p_reason) where id = r.id;
end;
$$;

-- app.cancel_refund_request: huỷ yêu cầu chưa duyệt xong (Nháp, Chờ quản lý, Chờ kế toán). Ai: Ghi danh · Sửa.
create or replace function app.cancel_refund_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['NHAP', 'CHO_QL', 'CHO_KE_TOAN']);
  perform app.assert_can('ENROLLMENT', 'SUA', r.branch_id);
  update app.refund_request set status_code = 'HUY' where id = r.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Quyền gọi
-- ---------------------------------------------------------------------------
revoke execute on function app.refund_request_for_update(uuid, text[]) from public, anon, authenticated;
revoke execute on function
  app.create_refund_request(uuid, text, numeric, text, text, text), app.submit_refund_request(uuid), app.approve_refund_manager(uuid),
  app.approve_refund_accountant(uuid), app.pay_payment_voucher(uuid, text), app.reject_refund_request(uuid, text), app.cancel_refund_request(uuid)
  from public, anon;
grant execute on function
  app.create_refund_request(uuid, text, numeric, text, text, text), app.submit_refund_request(uuid), app.approve_refund_manager(uuid),
  app.approve_refund_accountant(uuid), app.pay_payment_voucher(uuid, text), app.reject_refund_request(uuid, text), app.cancel_refund_request(uuid)
  to authenticated;
