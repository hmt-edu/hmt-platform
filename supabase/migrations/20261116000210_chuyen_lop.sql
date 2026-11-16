-- Migration 210 (Code D, 16/11/2026): bản ghi nghiệp vụ Chuyển lớp, chuyển cơ sở (R-GD-10, R-CS-02, R-CS-07, R-V2-24).
-- Đề xuất: docs/de-xuat/chuyen-lop-hoan-phi.md (PR #26). Việc duyệt nằm ở bản ghi này (R-V2-24), ticket chỉ gắn mã tham chiếu.
-- Công tắc tính năng CHUYEN_LOP theo cơ sở, MẶC ĐỊNH TẮT (không có dòng = tắt); Chat bật khi Tester ĐẠT.
-- Chuyển lớp khác môn là chuyển phí (R-CS-03), không làm ở đây: hàm chặn khác môn.

-- ---------------------------------------------------------------------------
-- 1. Danh mục: phân hệ CHUYEN_LOP, lý do chuyển lớp
-- ---------------------------------------------------------------------------
-- MODULE là danh mục hệ thống: thêm mục chỉ qua migration (cờ hmt.migration), như migration 139.
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'CHUYEN_LOP', 'Chuyển lớp, chuyển cơ sở', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;

insert into app.catalog (code, name, kind, description, sort_order)
select 'TRANSFER_REASON', 'Lý do chuyển lớp', 'MO', 'Lý do chuyển lớp, chuyển cơ sở, dùng cho báo cáo (R-CS-12).',
       (select coalesce(max(sort_order), 0) from app.catalog) + 1
where not exists (select from app.catalog where code = 'TRANSFER_REASON');

insert into app.catalog_item (catalog_code, code, name, sort_order)
values
  ('TRANSFER_REASON', 'DOI_LICH_BAN', 'Phụ huynh đổi lịch, bận giờ cũ', 1),
  ('TRANSFER_REASON', 'KHONG_HOP_TRINH_DO', 'Không hợp trình độ lớp', 2),
  ('TRANSFER_REASON', 'DOI_GIAO_VIEN', 'Muốn đổi giáo viên', 3),
  ('TRANSFER_REASON', 'DOI_NOI_O', 'Chuyển chỗ ở, đổi cơ sở', 4),
  ('TRANSFER_REASON', 'KHAC', 'Lý do khác', 99)
on conflict (catalog_code, code) do nothing;
select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- 2. Bảng app.class_transfer (R-GD-10)
-- ---------------------------------------------------------------------------
create table app.class_transfer (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references app.enrollment (id),
  student_id uuid not null references app.student (id),
  from_class_id uuid not null references app.class (id),
  to_class_id uuid not null references app.class (id),
  from_branch_id uuid not null references app.branch (id),
  to_branch_id uuid not null references app.branch (id),
  start_date date not null,
  -- Loại là luật lõi trong code (R-CS-03): đổi giờ, đổi trình độ, đổi giáo viên, chuyển cơ sở.
  kind_code text not null check (kind_code in ('DOI_GIO', 'DOI_TRINH_DO', 'DOI_GIAO_VIEN', 'CHUYEN_CO_SO')),
  reason_catalog text not null default 'TRANSFER_REASON' check (reason_catalog = 'TRANSFER_REASON'),
  reason_code text not null,
  note text,
  ticket_ref text,
  -- Chụp lại giờ còn lại lúc tạo, chỉ để đối chiếu; giờ đi theo ghi danh (R-GD-10).
  hours_snapshot numeric(8, 2) not null,
  status_code text not null default 'NHAP'
    check (status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET', 'DA_CHUYEN', 'TU_CHOI', 'HUY')),
  -- Người duyệt: cơ sở cũ; chuyển cơ sở cần thêm cơ sở mới (R-CS-07).
  approved_from_by uuid,
  approved_from_at timestamptz,
  approved_to_by uuid,
  approved_to_at timestamptz,
  reject_reason text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (reason_catalog, reason_code) references app.catalog_item (catalog_code, code),
  check (from_class_id <> to_class_id),
  check ((kind_code = 'CHUYEN_CO_SO') = (from_branch_id <> to_branch_id))
);
comment on table app.class_transfer is 'Bản ghi Chuyển lớp / chuyển cơ sở (R-GD-10, R-V2-24). Ghi chỉ qua hàm nghiệp vụ. Duyệt ở bản ghi này.';
-- Chỉ mục (lý do): ghi danh (xem lịch sử chuyển, khoá ngoại); cơ sở cũ và mới + tình trạng cho danh sách duyệt và RLS;
-- lớp mới và cũ (khoá ngoại); học sinh (hồ sơ).
create index class_transfer_enrollment_idx on app.class_transfer (enrollment_id, created_at desc);
create index class_transfer_from_branch_idx on app.class_transfer (from_branch_id, status_code, created_at desc);
create index class_transfer_to_branch_idx on app.class_transfer (to_branch_id, status_code);
create index class_transfer_from_class_idx on app.class_transfer (from_class_id);
create index class_transfer_to_class_idx on app.class_transfer (to_class_id);
create index class_transfer_student_idx on app.class_transfer (student_id);
-- Mỗi ghi danh chỉ một bản ghi chuyển lớp còn mở (chưa xong) tại một thời điểm.
create unique index class_transfer_open_uidx on app.class_transfer (enrollment_id)
  where status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET');
select app.apply_standard('app.class_transfer');

alter table app.class_transfer enable row level security;
revoke all on app.class_transfer from public, anon, authenticated;
grant select on app.class_transfer to authenticated;
-- Đọc: theo quyền Xem ghi danh, thấy bản ghi của cơ sở cũ hoặc cơ sở mới.
create policy class_transfer_read on app.class_transfer for select to authenticated
  using ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'CO_SO'
             and (from_branch_id = (select app.current_branch_id()) or to_branch_id = (select app.current_branch_id()))));

-- ---------------------------------------------------------------------------
-- 3. Tạo bản ghi (Nháp)
-- ---------------------------------------------------------------------------
-- app.create_class_transfer: tạo yêu cầu chuyển lớp ở trạng thái Nháp.
-- Ai gọi: Ghi danh · Sửa ở cơ sở của ghi danh (CSKH, Trưởng cơ sở, Admin). Cờ CHUYEN_LOP của cơ sở cũ phải bật.
-- Đầu vào: ghi danh, lớp mới, ngày vào lớp mới, loại, mã lý do, ghi chú, mã ticket (có thể trống).
-- Kết quả: id bản ghi. Luật: R-GD-10 (cùng môn; chuyển cơ sở giữ giờ), R-GD-06, R-GD-08, R-GD-15, R-CS-03.
create or replace function app.create_class_transfer(
  p_enrollment_id uuid, p_to_class_id uuid, p_start_date date, p_kind_code text,
  p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v_from app.class;
  v_to app.class;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('CHUYEN_LOP', e.branch_id);
  -- Luật R-GD-10: chỉ ghi danh còn hiệu lực mới chuyển được.
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_GHI_DANH_KHONG_CHUYEN_DUOC', 'Ghi danh này không còn hiệu lực để chuyển lớp.');
  end if;
  select c.* into v_from from app.enrollment_class ec join app.class c on c.id = ec.class_id
   where ec.enrollment_id = e.id and ec.end_date is null;
  if v_from.id is null then
    perform app.raise_error('HMT_GHI_DANH_CHUA_CO_LOP', 'Ghi danh chưa có lớp đang học nên chưa chuyển lớp được. Hãy xếp lớp.');
  end if;
  select * into v_to from app.class where id = p_to_class_id;
  if v_to.id is null then
    perform app.raise_error('HMT_LOP_KHONG_TIM_THAY', 'Chuyển lớp: không tìm thấy lớp.');
  end if;
  if v_to.id = v_from.id then
    perform app.raise_error('HMT_CHUYEN_LOP_TRUNG_LOP', 'Lớp mới trùng lớp đang học.');
  end if;
  -- Luật R-CS-03: loại chuyển phải khớp cơ sở; chuyển lớp khác môn là chuyển phí, không làm ở đây.
  if p_kind_code not in ('DOI_GIO', 'DOI_TRINH_DO', 'DOI_GIAO_VIEN', 'CHUYEN_CO_SO') then
    perform app.raise_error('HMT_CHUYEN_LOP_LOAI_SAI', 'Loại chuyển lớp không hợp lệ.');
  end if;
  if (p_kind_code = 'CHUYEN_CO_SO') <> (v_to.branch_id <> v_from.branch_id) then
    perform app.raise_error('HMT_CHUYEN_LOP_LOAI_SAI', 'Loại chuyển không khớp cơ sở: chọn «Chuyển cơ sở» khi lớp mới ở cơ sở khác, và ngược lại.');
  end if;
  if v_to.subject_code is distinct from v_from.subject_code then
    perform app.raise_error('HMT_CHUYEN_LOP_KHAC_MON', 'Chuyển sang lớp khác môn là chuyển phí, chưa làm ở chức năng này.');
  end if;
  -- Luật R-GD-06, R-GD-08, R-GD-15: kiểm lớp mới, ngày vào, trùng giờ (kiểm lại khi thực hiện).
  perform app.assert_class_fits(p_to_class_id, e.package_id, v_to.branch_id, 'Chuyển lớp');
  perform app.assert_enrol_start_date(p_to_class_id, p_start_date, 'Chuyển lớp');
  perform app.assert_no_time_clash(e.student_id, p_to_class_id, p_start_date, e.id, 'Chuyển lớp');
  perform app.assert_catalog_code_active('TRANSFER_REASON', p_reason_code);
  if exists (select from app.class_transfer where enrollment_id = e.id and status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_CHUYEN_LOP_DANG_MO', 'Ghi danh này đã có một yêu cầu chuyển lớp chưa xong.');
  end if;
  insert into app.class_transfer (enrollment_id, student_id, from_class_id, to_class_id, from_branch_id, to_branch_id,
                                  start_date, kind_code, reason_code, note, ticket_ref, hours_snapshot)
  values (e.id, e.student_id, v_from.id, v_to.id, v_from.branch_id, v_to.branch_id,
          p_start_date, p_kind_code, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          coalesce(app.enrollment_hours_balance(e.id), 0))
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Trình, duyệt, từ chối, huỷ
-- ---------------------------------------------------------------------------
-- Lấy bản ghi để sửa trạng thái (khoá dòng), báo lỗi nếu không có hoặc không đúng trạng thái cho phép.
create or replace function app.class_transfer_for_update(p_id uuid, p_allowed text[])
returns app.class_transfer
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.class_transfer;
begin
  select * into t from app.class_transfer where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu chuyển lớp.');
  end if;
  if not (t.status_code = any (p_allowed)) then
    perform app.raise_error('HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Yêu cầu chuyển lớp đang ở trạng thái không cho thao tác này.');
  end if;
  return t;
end;
$$;

-- app.submit_class_transfer: trình duyệt (Nháp → Chờ duyệt). Ai: Ghi danh · Sửa ở cơ sở cũ.
create or replace function app.submit_class_transfer(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.class_transfer;
begin
  t := app.class_transfer_for_update(p_id, array['NHAP']);
  perform app.assert_can('ENROLLMENT', 'SUA', t.from_branch_id);
  perform app.require_feature('CHUYEN_LOP', t.from_branch_id);
  update app.class_transfer set status_code = 'CHO_DUYET' where id = t.id;
end;
$$;

-- app.approve_class_transfer: duyệt (R-CS-07). Ai: Ghi danh · Duyệt. Cùng môn: người duyệt ở cơ sở cũ.
-- Chuyển cơ sở cần quản lý CẢ HAI cơ sở: mỗi người duyệt phần cơ sở mình có quyền; Admin duyệt cả hai một lần.
-- Người tạo không tự duyệt bản ghi của mình, trừ Admin (luật tách người lập và người duyệt).
create or replace function app.approve_class_transfer(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.class_transfer;
  v_user uuid := (select auth.uid());
  v_from_ok boolean;
  v_to_ok boolean;
begin
  t := app.class_transfer_for_update(p_id, array['CHO_DUYET']);
  perform app.require_feature('CHUYEN_LOP', t.from_branch_id);
  v_from_ok := app.can_see_branch('ENROLLMENT', 'DUYET', t.from_branch_id);
  v_to_ok := t.kind_code = 'CHUYEN_CO_SO' and app.can_see_branch('ENROLLMENT', 'DUYET', t.to_branch_id);
  if not (v_from_ok or v_to_ok) then
    perform app.raise_error('HMT_CHUYEN_LOP_THIEU_QUYEN_DUYET', 'Bạn không có quyền duyệt chuyển lớp ở cơ sở này.');
  end if;
  if t.created_by = v_user and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_CHUYEN_LOP_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  if v_from_ok and t.approved_from_at is null then
    t.approved_from_by := v_user; t.approved_from_at := now();
  end if;
  if v_to_ok and t.approved_to_at is null then
    t.approved_to_by := v_user; t.approved_to_at := now();
  end if;
  update app.class_transfer
     set approved_from_by = t.approved_from_by, approved_from_at = t.approved_from_at,
         approved_to_by = t.approved_to_by, approved_to_at = t.approved_to_at,
         status_code = case when t.approved_from_at is not null
                             and (t.kind_code <> 'CHUYEN_CO_SO' or t.approved_to_at is not null)
                            then 'DA_DUYET' else 'CHO_DUYET' end
   where id = t.id;
end;
$$;

-- app.reject_class_transfer: từ chối (bắt buộc lý do). Ai: người có quyền Duyệt ở cơ sở cũ hoặc cơ sở mới.
create or replace function app.reject_class_transfer(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.class_transfer;
begin
  t := app.class_transfer_for_update(p_id, array['CHO_DUYET']);
  if not (app.can_see_branch('ENROLLMENT', 'DUYET', t.from_branch_id)
          or (t.kind_code = 'CHUYEN_CO_SO' and app.can_see_branch('ENROLLMENT', 'DUYET', t.to_branch_id))) then
    perform app.raise_error('HMT_CHUYEN_LOP_THIEU_QUYEN_DUYET', 'Bạn không có quyền từ chối chuyển lớp ở cơ sở này.');
  end if;
  if nullif(btrim(p_reason), '') is null then
    perform app.raise_error('HMT_CHUYEN_LOP_THIEU_LY_DO', 'Từ chối phải ghi lý do.');
  end if;
  update app.class_transfer set status_code = 'TU_CHOI', reject_reason = btrim(p_reason) where id = t.id;
end;
$$;

-- app.cancel_class_transfer: huỷ yêu cầu chưa thực hiện (Nháp, Chờ duyệt, Đã duyệt). Ai: Ghi danh · Sửa ở cơ sở cũ.
create or replace function app.cancel_class_transfer(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.class_transfer;
begin
  t := app.class_transfer_for_update(p_id, array['NHAP', 'CHO_DUYET', 'DA_DUYET']);
  perform app.assert_can('ENROLLMENT', 'SUA', t.from_branch_id);
  update app.class_transfer set status_code = 'HUY' where id = t.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Thực hiện
-- ---------------------------------------------------------------------------
-- app.execute_class_transfer: thực hiện chuyển lớp đã duyệt (Đã duyệt → Đã chuyển). Ai: Ghi danh · Sửa ở cơ sở cũ.
-- Kiểm lại toàn bộ luật lớp mới vì lớp có thể đầy hoặc trùng giờ sau khi duyệt, rồi gọi app.move_enrollment_class (R-GD-10).
create or replace function app.execute_class_transfer(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.class_transfer;
begin
  t := app.class_transfer_for_update(p_id, array['DA_DUYET']);
  perform app.assert_can('ENROLLMENT', 'SUA', t.from_branch_id);
  perform app.require_feature('CHUYEN_LOP', t.from_branch_id);
  -- move_enrollment_class kiểm hiệu lực ghi danh, môn, khối, chỗ, ngày vào, trùng giờ.
  perform app.move_enrollment_class(t.enrollment_id, t.to_class_id, t.start_date, coalesce(t.ticket_ref, t.id::text));
  update app.class_transfer set status_code = 'DA_CHUYEN' where id = t.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Quyền gọi
-- ---------------------------------------------------------------------------
revoke execute on function app.class_transfer_for_update(uuid, text[]) from public, anon, authenticated;
revoke execute on function
  app.create_class_transfer(uuid, uuid, date, text, text, text, text),
  app.submit_class_transfer(uuid), app.approve_class_transfer(uuid),
  app.reject_class_transfer(uuid, text), app.cancel_class_transfer(uuid), app.execute_class_transfer(uuid)
  from public, anon;
grant execute on function
  app.create_class_transfer(uuid, uuid, date, text, text, text, text),
  app.submit_class_transfer(uuid), app.approve_class_transfer(uuid),
  app.reject_class_transfer(uuid, text), app.cancel_class_transfer(uuid), app.execute_class_transfer(uuid)
  to authenticated;
