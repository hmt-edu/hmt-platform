-- Migration 232 (Code D, 16/11/2026): Dừng học giữ thành SỐ DƯ khách hàng (R-GD-16, R-TIEN-33, R-CS-02, R-CS-07, R-V2-24).
-- R-GD-16: dừng học chọn một trong hai: (a) hoàn tiền (R-TIEN-28): làm bằng yêu cầu Hoàn phí loại TOAN_BO (migration 231);
-- (b) giữ thành số dư khách hàng (giờ còn lại × giá sau chiết khấu, không trừ phí): bản ghi này. Giờ tặng còn lại bị huỷ. Không có «giữ nguyên giờ».
-- Việc duyệt nằm ở bản ghi (R-V2-24): quản lý cơ sở rồi kế toán (R-CS-07). Công tắc DUNG_HOC theo cơ sở, MẶC ĐỊNH TẮT.
-- Chưa làm: «Dùng số dư» cho đơn mới (ghi như khoản tiền vào của đơn, đụng lõi tiền: PR riêng sau khi Chat chốt cách ghi).
-- Cách tính tiền giữ (Code D tự chọn, chờ Chat): giờ mua còn lại = min(giờ mua đã cấp − giờ đã học, giờ còn lại), không âm
-- (coi giờ tặng dùng sau cùng nên không làm thiệt khách); tiền giữ = làm tròn(giờ mua còn lại × thành tiền dòng ÷ giờ mua).

-- ---------------------------------------------------------------------------
-- 1. Danh mục
-- ---------------------------------------------------------------------------
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'DUNG_HOC', 'Dừng học, số dư khách hàng', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;

insert into app.catalog (code, name, kind, description, sort_order)
select 'STOP_REASON', 'Lý do dừng học', 'MO', 'Lý do dừng học ghi danh, dùng cho báo cáo (R-CS-12).',
       (select coalesce(max(sort_order), 0) from app.catalog) + 1
where not exists (select from app.catalog where code = 'STOP_REASON');

insert into app.catalog_item (catalog_code, code, name, sort_order)
values
  ('STOP_REASON', 'CHUYEN_NOI_O', 'Chuyển nơi ở, không học được nữa', 1),
  ('STOP_REASON', 'KHONG_HOP', 'Không phù hợp chương trình, lớp', 2),
  ('STOP_REASON', 'TAI_CHINH', 'Khó khăn tài chính', 3),
  ('STOP_REASON', 'KHAC', 'Lý do khác', 99)
on conflict (catalog_code, code) do nothing;
select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- 2. Sổ số dư khách hàng (R-TIEN-33): dùng bảng app.customer_balance_entry của migration 217 (nạp số dư đầu kỳ, Code B);
-- mở rộng thêm loại dòng và cột cho dừng học, KHÔNG tạo bảng mới. Sổ chỉ thêm dòng (trigger 217 đã chặn sửa).
-- ---------------------------------------------------------------------------
alter table app.customer_balance_entry add column if not exists enrollment_id uuid references app.enrollment (id);
alter table app.customer_balance_entry add column if not exists note text;
-- Mở rộng loại dòng: TU_DUNG_HOC (+): sinh từ dừng học; DUNG_CHO_DON (−): dùng cho đơn (làm sau); DIEU_CHINH: sửa sai bằng dòng ngược dấu.
alter table app.customer_balance_entry drop constraint if exists customer_balance_entry_entry_type_check;
alter table app.customer_balance_entry drop constraint if exists customer_balance_entry_check;
alter table app.customer_balance_entry add constraint customer_balance_entry_entry_type_check
  check (entry_type in ('DAU_KY_THU_THUA', 'DAU_KY_CONG_NO', 'TU_DUNG_HOC', 'DUNG_CHO_DON', 'DIEU_CHINH'));
alter table app.customer_balance_entry add constraint customer_balance_entry_sign_check
  check ((entry_type in ('DAU_KY_THU_THUA', 'TU_DUNG_HOC') and amount > 0)
         or (entry_type in ('DAU_KY_CONG_NO', 'DUNG_CHO_DON') and amount < 0)
         or entry_type = 'DIEU_CHINH');
-- Chỉ mục (lý do): ghi danh (khoá ngoại, tra dòng sinh từ dừng học).
create index customer_balance_enrollment_idx on app.customer_balance_entry (enrollment_id) where enrollment_id is not null;
-- Đọc bảng: giữ chính sách chỉ-Admin của 217; màn khách hàng và kế toán đọc số dư qua app.customer_balance (hàm bên dưới).

-- ---------------------------------------------------------------------------
-- 3. Bản ghi Dừng học
-- ---------------------------------------------------------------------------
create table app.enrollment_stop (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references app.enrollment (id),
  student_id uuid not null references app.student (id),
  parent_id uuid not null references app.parent (id),
  branch_id uuid not null references app.branch (id),
  reason_catalog text not null default 'STOP_REASON' check (reason_catalog = 'STOP_REASON'),
  reason_code text not null,
  note text,
  ticket_ref text,
  -- Số liệu chụp lúc tạo (đồng; giờ numeric(8,2)).
  hours_left numeric(8, 2) not null,
  hours_paid_left numeric(8, 2) not null check (hours_paid_left >= 0),
  hours_cancelled numeric(8, 2) not null check (hours_cancelled >= 0),
  unit_price_net numeric(14, 2) not null,
  balance_amount bigint not null check (balance_amount >= 0),
  status_code text not null default 'NHAP'
    check (status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET', 'TU_CHOI', 'HUY')),
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
comment on table app.enrollment_stop is 'Bản ghi Dừng học giữ thành số dư khách hàng (R-GD-16, R-V2-24). Hoàn tiền dùng yêu cầu Hoàn phí TOAN_BO.';
-- Chỉ mục (lý do): ghi danh (lịch sử, khoá ngoại); cơ sở + tình trạng (danh sách duyệt, RLS); học sinh, phụ huynh (khoá ngoại).
create index enrollment_stop_enrollment_idx on app.enrollment_stop (enrollment_id, created_at desc);
create index enrollment_stop_branch_idx on app.enrollment_stop (branch_id, status_code, created_at desc);
create index enrollment_stop_student_idx on app.enrollment_stop (student_id);
create index enrollment_stop_parent_idx on app.enrollment_stop (parent_id);
create unique index enrollment_stop_open_uidx on app.enrollment_stop (enrollment_id)
  where status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN');
select app.apply_standard('app.enrollment_stop');

alter table app.enrollment_stop enable row level security;
revoke all on app.enrollment_stop from public, anon, authenticated;
grant select on app.enrollment_stop to authenticated;
-- Đọc: quyền Xem phiếu thu/phiếu chi (RECEIPT) theo phạm vi (số tiền nhạy cảm).
create policy enrollment_stop_read on app.enrollment_stop for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- 4. Hàm
-- ---------------------------------------------------------------------------
-- Số dư hiện tại của phụ huynh (tổng sổ). Ai: quyền Xem phiếu thu/phiếu chi ở cơ sở của phụ huynh.
create or replace function app.customer_balance(p_parent_id uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from app.parent where id = p_parent_id;
  if v_branch is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  perform app.assert_can('RECEIPT', 'XEM', v_branch);
  return coalesce((select sum(amount) from app.customer_balance_entry where parent_id = p_parent_id), 0);
end;
$$;

create or replace function app.enrollment_stop_for_update(p_id uuid, p_allowed text[])
returns app.enrollment_stop
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  select * into s from app.enrollment_stop where id = p_id for update;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu dừng học.');
  end if;
  if not (s.status_code = any (p_allowed)) then
    perform app.raise_error('HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Yêu cầu dừng học đang ở trạng thái không cho thao tác này.');
  end if;
  return s;
end;
$$;

-- Tính số liệu dừng học giữ số dư (không ghi gì). NỘI BỘ. Kết quả jsonb: hours_left, hours_paid_left, hours_cancelled, unit_price_net, balance_amount.
-- Lỗi HMT_DUNG_HOC_KHONG_CO_DON: ghi danh không có dòng đơn nên không có giá.
create or replace function app.compute_stop_balance(p_enrollment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  l app.sales_order_line;
  v_left numeric;
  v_granted numeric;
  v_used numeric;
  v_paid_left numeric;
  v_net numeric;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  select * into l from app.sales_order_line where id = e.order_line_id;
  if l.id is null then
    perform app.raise_error('HMT_DUNG_HOC_KHONG_CO_DON', 'Ghi danh này không có dòng đơn nên chưa tính được số dư (cần giá).');
  end if;
  v_left := greatest(app.enrollment_hours_balance(e.id), 0);
  select coalesce(sum(g.hours), 0) into v_granted from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type in ('CAP_MUA', 'DAU_KY');
  select coalesce(sum(-g.hours), 0) into v_used from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type = 'TRU_BUOI';
  -- Luật R-GD-16: giờ tặng còn lại bị huỷ, không quy ra tiền; coi giờ tặng được dùng sau cùng.
  v_paid_left := greatest(least(v_granted - v_used, v_left), 0);
  v_net := l.line_total::numeric / l.quantity;
  return jsonb_build_object('hours_left', v_left, 'hours_paid_left', v_paid_left, 'hours_cancelled', v_left - v_paid_left,
                            'unit_price_net', round(v_net, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
                            'balance_amount', round(v_paid_left * v_net)::bigint);
end;
$$;

-- app.create_enrollment_stop: tạo yêu cầu dừng học giữ số dư (Nháp), chụp số liệu. Ai: Ghi danh · Sửa; cờ DUNG_HOC bật.
create or replace function app.create_enrollment_stop(p_enrollment_id uuid, p_reason_code text, p_note text default null, p_ticket_ref text default null)
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
  perform app.require_feature('DUNG_HOC', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_DUNG_HOC_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để dừng học.');
  end if;
  perform app.assert_catalog_code_active('STOP_REASON', p_reason_code);
  -- Chưa kiểm chéo với yêu cầu Hoàn phí đang mở (bảng nằm ở migration 231); ghi danh sang Dừng/Hoàn phí khi duyệt nên yêu cầu thứ hai bị chặn ở bước duyệt.
  if exists (select from app.enrollment_stop where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN')) then
    perform app.raise_error('HMT_DUNG_HOC_DANG_MO', 'Ghi danh này đã có một yêu cầu dừng học chưa xong.');
  end if;
  v := app.compute_stop_balance(e.id);
  insert into app.enrollment_stop (enrollment_id, student_id, parent_id, branch_id, reason_code, note, ticket_ref,
                                   hours_left, hours_paid_left, hours_cancelled, unit_price_net, balance_amount)
  values (e.id, e.student_id, e.parent_id, e.branch_id, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_left')::numeric, (v ->> 'hours_paid_left')::numeric, (v ->> 'hours_cancelled')::numeric,
          (v ->> 'unit_price_net')::numeric, (v ->> 'balance_amount')::bigint)
  returning id into v_id;
  return v_id;
end;
$$;

-- app.submit_enrollment_stop: Nháp → Chờ quản lý. Ai: Ghi danh · Sửa.
create or replace function app.submit_enrollment_stop(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['NHAP']);
  perform app.assert_can('ENROLLMENT', 'SUA', s.branch_id);
  perform app.require_feature('DUNG_HOC', s.branch_id);
  update app.enrollment_stop set status_code = 'CHO_QL' where id = s.id;
end;
$$;

-- app.approve_stop_manager: quản lý cơ sở duyệt (R-CS-07). Ai: Ghi danh · Duyệt; người tạo không tự duyệt (trừ Admin).
create or replace function app.approve_stop_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_QL']);
  perform app.assert_can('ENROLLMENT', 'DUYET', s.branch_id);
  perform app.require_feature('DUNG_HOC', s.branch_id);
  if s.created_by = (select auth.uid()) and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_DUNG_HOC_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  update app.enrollment_stop set status_code = 'CHO_KE_TOAN', manager_by = (select auth.uid()), manager_at = now() where id = s.id;
end;
$$;

-- app.approve_stop_accountant: kế toán duyệt (R-CS-07): kiểm lại số liệu (lệch thì chặn), ghi sổ giờ ngược dấu cho MỌI giờ còn lại
-- (giờ tặng bị huỷ, R-GD-16), ghi danh sang Dừng, đóng dòng xếp lớp, ghi dòng số dư khách hàng (+). Ai: Đối soát kế toán · Duyệt (chỉ Kế toán).
create or replace function app.approve_stop_accountant(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
  e app.enrollment;
  v jsonb;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_KE_TOAN']);
  perform app.assert_can('ACCOUNTING', 'DUYET', s.branch_id);
  perform app.require_feature('DUNG_HOC', s.branch_id);
  select * into e from app.enrollment where id = s.enrollment_id for update;
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_DUNG_HOC_GHI_DANH_SAI', 'Ghi danh không còn hiệu lực để dừng học.');
  end if;
  v := app.compute_stop_balance(e.id);
  if (v ->> 'balance_amount')::bigint <> s.balance_amount or (v ->> 'hours_left')::numeric <> s.hours_left then
    perform app.raise_error('HMT_DUNG_HOC_SO_LIEU_DOI', 'Số liệu đã thay đổi từ lúc tạo yêu cầu (giờ đã học hoặc tiền đã đóng). Hãy huỷ và tạo yêu cầu mới.');
  end if;
  if s.hours_left > 0 then
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, source_ref)
    values (e.id, e.branch_id, 'DIEU_CHINH', -s.hours_left, 'KHAC', 'Dừng học, giữ số dư', 'STOP-' || s.id::text); -- lý do «Khác» (bắt buộc ghi chú)
  end if;
  update app.enrollment_class set end_date = greatest(current_date, start_date), end_reason = 'DUNG'
   where enrollment_id = e.id and end_date is null;
  update app.enrollment set status_code = 'DUNG' where id = e.id;
  if s.balance_amount > 0 then
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, enrollment_id, source_ref, note)
    values (s.parent_id, s.student_id, s.branch_id, 'TU_DUNG_HOC', s.balance_amount, (now() at time zone 'Asia/Ho_Chi_Minh')::date, e.id, 'STOP-' || s.id::text, 'Dừng học, giữ thành số dư');
  end if;
  update app.enrollment_stop set status_code = 'DA_DUYET', accountant_by = (select auth.uid()), accountant_at = now() where id = s.id;
end;
$$;

-- app.reject_enrollment_stop: từ chối (bắt buộc lý do) ở bước quản lý hoặc kế toán.
create or replace function app.reject_enrollment_stop(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_QL', 'CHO_KE_TOAN']);
  if s.status_code = 'CHO_QL' then
    perform app.assert_can('ENROLLMENT', 'DUYET', s.branch_id);
  else
    perform app.assert_can('ACCOUNTING', 'DUYET', s.branch_id);
  end if;
  if nullif(btrim(p_reason), '') is null then
    perform app.raise_error('HMT_DUNG_HOC_THIEU_LY_DO', 'Từ chối phải ghi lý do.');
  end if;
  update app.enrollment_stop set status_code = 'TU_CHOI', reject_reason = btrim(p_reason) where id = s.id;
end;
$$;

-- app.cancel_enrollment_stop: huỷ yêu cầu chưa duyệt xong. Ai: Ghi danh · Sửa.
create or replace function app.cancel_enrollment_stop(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['NHAP', 'CHO_QL', 'CHO_KE_TOAN']);
  perform app.assert_can('ENROLLMENT', 'SUA', s.branch_id);
  update app.enrollment_stop set status_code = 'HUY' where id = s.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Quyền gọi
-- ---------------------------------------------------------------------------
revoke execute on function app.enrollment_stop_for_update(uuid, text[]), app.compute_stop_balance(uuid) from public, anon, authenticated;
revoke execute on function
  app.customer_balance(uuid), app.create_enrollment_stop(uuid, text, text, text), app.submit_enrollment_stop(uuid),
  app.approve_stop_manager(uuid), app.approve_stop_accountant(uuid), app.reject_enrollment_stop(uuid, text), app.cancel_enrollment_stop(uuid)
  from public, anon;
grant execute on function
  app.customer_balance(uuid), app.create_enrollment_stop(uuid, text, text, text), app.submit_enrollment_stop(uuid),
  app.approve_stop_manager(uuid), app.approve_stop_accountant(uuid), app.reject_enrollment_stop(uuid, text), app.cancel_enrollment_stop(uuid)
  to authenticated;
