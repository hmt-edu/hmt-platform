-- Migration 215 (Code D, 16/11/2026): bản ghi nghiệp vụ Bảo lưu ghi danh (R-GD-09, R-CS-02, R-CS-03, R-CS-07, R-V2-24).
-- Việc duyệt nằm ở bản ghi này (R-V2-24); ticket chỉ gắn mã tham chiếu `ticket_ref` (nối khoá ngoại sau khi ticket #18 vào main).
-- Công tắc BAO_LUU theo cơ sở, MẶC ĐỊNH TẮT (không có dòng = tắt). Dừng học (R-GD-16) làm ở PR riêng cùng hoàn phí.
-- Luật: bảo lưu giữ nguyên giờ còn lại (không đụng sổ giờ); một lần không quá `reservation_max_months` (R-GD-09);
-- trong thời gian bảo lưu em không vào danh sách buổi (đã có: build_session_roster loại ghi danh BAO_LUU). Bảo lưu bắt đầu ở NGÀY DUYỆT.
-- Chưa làm: dừng sinh phiếu tái tục khi bảo lưu (R-GD-13, chưa có bảng phiếu tái tục); tự kết thúc khi hết hạn (cần lịch pg_cron, chờ anh duyệt):
-- hiện có app.end_enrollment_hold cho người dùng và app.end_expired_enrollment_holds (nội bộ, chưa đăng ký lịch).

-- ---------------------------------------------------------------------------
-- 1. Danh mục: phân hệ BAO_LUU, lý do bảo lưu
-- ---------------------------------------------------------------------------
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'BAO_LUU', 'Bảo lưu ghi danh', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;

insert into app.catalog (code, name, kind, description, sort_order)
select 'HOLD_REASON', 'Lý do bảo lưu', 'MO', 'Lý do bảo lưu ghi danh, dùng cho báo cáo (R-CS-12).',
       (select coalesce(max(sort_order), 0) from app.catalog) + 1
where not exists (select from app.catalog where code = 'HOLD_REASON');

insert into app.catalog_item (catalog_code, code, name, sort_order)
values
  ('HOLD_REASON', 'BAN_THI', 'Bận thi, bận việc học khác', 1),
  ('HOLD_REASON', 'SUC_KHOE', 'Sức khoẻ', 2),
  ('HOLD_REASON', 'GIA_DINH', 'Việc gia đình, đi xa', 3),
  ('HOLD_REASON', 'KHAC', 'Lý do khác', 99)
on conflict (catalog_code, code) do nothing;
select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- 2. Bảng app.enrollment_hold
-- ---------------------------------------------------------------------------
create table app.enrollment_hold (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references app.enrollment (id),
  student_id uuid not null references app.student (id),
  branch_id uuid not null references app.branch (id),
  -- MOI: bảo lưu mới; GIA_HAN: nối tiếp một bảo lưu đang chạy (R-CS-03 nhóm con).
  kind_code text not null check (kind_code in ('MOI', 'GIA_HAN')),
  months integer not null check (months >= 1),
  -- Ngày bắt đầu và hết hạn: đặt khi duyệt (bắt đầu = ngày duyệt; gia hạn = ngày hết hạn của bản trước).
  start_date date,
  end_date date,
  -- Tình trạng ghi danh trước khi bảo lưu, để trả lại khi kết thúc.
  return_status_code text check (return_status_code in ('DA_XEP_LOP', 'DANG_HOC')),
  extends_hold_id uuid references app.enrollment_hold (id),
  reason_catalog text not null default 'HOLD_REASON' check (reason_catalog = 'HOLD_REASON'),
  reason_code text not null,
  note text,
  ticket_ref text,
  status_code text not null default 'NHAP'
    check (status_code in ('NHAP', 'CHO_DUYET', 'DANG_BAO_LUU', 'KET_THUC', 'TU_CHOI', 'HUY')),
  approved_by uuid,
  approved_at timestamptz,
  reject_reason text,
  ended_at timestamptz,
  ended_by uuid,
  -- HET_HAN: tới hạn; QUAY_LAI_SOM: học lại trước hạn (R-CS-03); GIA_HAN: thay bằng bản gia hạn.
  end_kind text check (end_kind in ('HET_HAN', 'QUAY_LAI_SOM', 'GIA_HAN')),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (reason_catalog, reason_code) references app.catalog_item (catalog_code, code),
  check ((status_code in ('DANG_BAO_LUU', 'KET_THUC')) = (start_date is not null)),
  check ((status_code = 'KET_THUC') = (end_kind is not null))
);
comment on table app.enrollment_hold is 'Bản ghi Bảo lưu ghi danh (R-GD-09, R-V2-24). Ghi chỉ qua hàm nghiệp vụ. Duyệt ở bản ghi này.';
-- Chỉ mục (lý do): ghi danh (lịch sử bảo lưu, khoá ngoại); cơ sở + tình trạng cho danh sách duyệt và RLS;
-- ngày hết hạn của bản đang chạy (quét kết thúc khi hết hạn); học sinh, bản gia hạn trỏ về (khoá ngoại).
create index enrollment_hold_enrollment_idx on app.enrollment_hold (enrollment_id, created_at desc);
create index enrollment_hold_branch_idx on app.enrollment_hold (branch_id, status_code, created_at desc);
create index enrollment_hold_due_idx on app.enrollment_hold (end_date) where status_code = 'DANG_BAO_LUU';
create index enrollment_hold_student_idx on app.enrollment_hold (student_id);
create index enrollment_hold_extends_idx on app.enrollment_hold (extends_hold_id) where extends_hold_id is not null;
-- Mỗi ghi danh chỉ một bản ghi còn mở (chưa xong).
create unique index enrollment_hold_open_uidx on app.enrollment_hold (enrollment_id)
  where status_code in ('NHAP', 'CHO_DUYET');
-- Một ghi danh chỉ một bảo lưu đang chạy.
create unique index enrollment_hold_running_uidx on app.enrollment_hold (enrollment_id)
  where status_code = 'DANG_BAO_LUU';
select app.apply_standard('app.enrollment_hold');

alter table app.enrollment_hold enable row level security;
revoke all on app.enrollment_hold from public, anon, authenticated;
grant select on app.enrollment_hold to authenticated;
create policy enrollment_hold_read on app.enrollment_hold for select to authenticated
  using ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- 3. Hàm
-- ---------------------------------------------------------------------------
-- Lấy bản ghi để sửa (khoá dòng); báo lỗi nếu không có hoặc sai trạng thái.
create or replace function app.enrollment_hold_for_update(p_id uuid, p_allowed text[])
returns app.enrollment_hold
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
begin
  select * into h from app.enrollment_hold where id = p_id for update;
  if h.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu bảo lưu.');
  end if;
  if not (h.status_code = any (p_allowed)) then
    perform app.raise_error('HMT_BAO_LUU_KHONG_DUOC_SUA', 'Yêu cầu bảo lưu đang ở trạng thái không cho thao tác này.');
  end if;
  return h;
end;
$$;

-- app.create_enrollment_hold: tạo yêu cầu bảo lưu (Nháp). Ai: Ghi danh · Sửa ở cơ sở của ghi danh; cờ BAO_LUU bật.
-- Đầu vào: ghi danh, số tháng, mã lý do, ghi chú, mã ticket. Luật: R-GD-09 (một lần không quá reservation_max_months).
-- Gia hạn (R-CS-03): truyền p_extends_hold_id là bản đang bảo lưu của chính ghi danh đó; số tháng của bản gia hạn cũng không quá mức tối đa.
create or replace function app.create_enrollment_hold(
  p_enrollment_id uuid, p_months integer, p_reason_code text, p_note text default null, p_ticket_ref text default null,
  p_extends_hold_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  prev app.enrollment_hold;
  v_max integer;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('BAO_LUU', e.branch_id);
  -- Luật R-GD-09: thời gian một lần không quá tham số của cơ sở.
  v_max := app.get_setting_int('reservation_max_months', e.branch_id);
  if p_months is null or p_months < 1 or p_months > v_max then
    perform app.raise_error('HMT_BAO_LUU_QUA_THOI_GIAN', format('Bảo lưu mỗi lần từ 1 đến %s tháng.', v_max));
  end if;
  perform app.assert_catalog_code_active('HOLD_REASON', p_reason_code);
  if p_extends_hold_id is null then
    -- Bảo lưu mới: ghi danh phải còn hiệu lực và chưa bảo lưu.
    if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC') then
      perform app.raise_error('HMT_BAO_LUU_GHI_DANH_SAI', 'Chỉ ghi danh Đã xếp lớp hoặc Đang học mới bảo lưu được.');
    end if;
  else
    select * into prev from app.enrollment_hold where id = p_extends_hold_id for update;
    if prev.id is null or prev.enrollment_id <> e.id or prev.status_code <> 'DANG_BAO_LUU' then
      perform app.raise_error('HMT_BAO_LUU_GIA_HAN_SAI', 'Chỉ gia hạn được bảo lưu đang chạy của chính ghi danh này.');
    end if;
  end if;
  if exists (select from app.enrollment_hold where enrollment_id = e.id and status_code in ('NHAP', 'CHO_DUYET')) then
    perform app.raise_error('HMT_BAO_LUU_DANG_MO', 'Ghi danh này đã có một yêu cầu bảo lưu chưa xong.');
  end if;
  insert into app.enrollment_hold (enrollment_id, student_id, branch_id, kind_code, months, extends_hold_id,
                                   reason_code, note, ticket_ref, return_status_code)
  values (e.id, e.student_id, e.branch_id, case when p_extends_hold_id is null then 'MOI' else 'GIA_HAN' end, p_months, p_extends_hold_id,
          p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          case when p_extends_hold_id is null then e.status_code else prev.return_status_code end)
  returning id into v_id;
  return v_id;
end;
$$;

-- app.submit_enrollment_hold: Nháp → Chờ duyệt. Ai: Ghi danh · Sửa.
create or replace function app.submit_enrollment_hold(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
begin
  h := app.enrollment_hold_for_update(p_id, array['NHAP']);
  perform app.assert_can('ENROLLMENT', 'SUA', h.branch_id);
  perform app.require_feature('BAO_LUU', h.branch_id);
  update app.enrollment_hold set status_code = 'CHO_DUYET' where id = h.id;
end;
$$;

-- app.approve_enrollment_hold: duyệt (R-CS-07: quản lý cơ sở). Ai: Ghi danh · Duyệt; người tạo không tự duyệt (trừ Admin).
-- Duyệt xong bảo lưu BẮT ĐẦU NGAY: ghi danh sang Bảo lưu, giờ còn lại giữ nguyên. Gia hạn: bản trước kết thúc kiểu GIA_HAN,
-- bản mới nối tiếp từ ngày hết hạn của bản trước.
create or replace function app.approve_enrollment_hold(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
  prev app.enrollment_hold;
  v_start date;
begin
  h := app.enrollment_hold_for_update(p_id, array['CHO_DUYET']);
  perform app.assert_can('ENROLLMENT', 'DUYET', h.branch_id);
  perform app.require_feature('BAO_LUU', h.branch_id);
  if h.created_by = (select auth.uid()) and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_BAO_LUU_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  if h.extends_hold_id is null then
    -- Bảo lưu mới: kiểm lại ghi danh còn hợp lệ.
    if not exists (select from app.enrollment e where e.id = h.enrollment_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')) then
      perform app.raise_error('HMT_BAO_LUU_GHI_DANH_SAI', 'Ghi danh không còn ở trạng thái bảo lưu được.');
    end if;
    v_start := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
    update app.enrollment set status_code = 'BAO_LUU' where id = h.enrollment_id;
  else
    select * into prev from app.enrollment_hold where id = h.extends_hold_id for update;
    if prev.status_code <> 'DANG_BAO_LUU' then
      perform app.raise_error('HMT_BAO_LUU_GIA_HAN_SAI', 'Bảo lưu cần gia hạn không còn chạy.');
    end if;
    v_start := prev.end_date;
    update app.enrollment_hold
       set status_code = 'KET_THUC', end_kind = 'GIA_HAN', ended_at = now(), ended_by = (select auth.uid())
     where id = prev.id;
  end if;
  update app.enrollment_hold
     set status_code = 'DANG_BAO_LUU', start_date = v_start, end_date = (v_start + make_interval(months => h.months))::date,
         approved_by = (select auth.uid()), approved_at = now()
   where id = h.id;
end;
$$;

-- app.reject_enrollment_hold: từ chối (bắt buộc lý do). Ai: Ghi danh · Duyệt.
create or replace function app.reject_enrollment_hold(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
begin
  h := app.enrollment_hold_for_update(p_id, array['CHO_DUYET']);
  perform app.assert_can('ENROLLMENT', 'DUYET', h.branch_id);
  if nullif(btrim(p_reason), '') is null then
    perform app.raise_error('HMT_BAO_LUU_THIEU_LY_DO', 'Từ chối phải ghi lý do.');
  end if;
  update app.enrollment_hold set status_code = 'TU_CHOI', reject_reason = btrim(p_reason) where id = h.id;
end;
$$;

-- app.cancel_enrollment_hold: huỷ yêu cầu chưa chạy (Nháp, Chờ duyệt). Ai: Ghi danh · Sửa.
create or replace function app.cancel_enrollment_hold(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
begin
  h := app.enrollment_hold_for_update(p_id, array['NHAP', 'CHO_DUYET']);
  perform app.assert_can('ENROLLMENT', 'SUA', h.branch_id);
  update app.enrollment_hold set status_code = 'HUY' where id = h.id;
end;
$$;

-- Kết thúc một bảo lưu đang chạy: trả ghi danh về tình trạng trước đó (giờ còn lại không đổi). Dùng chung cho người dùng và quét hết hạn.
create or replace function app.finish_enrollment_hold(p_hold_id uuid, p_end_kind text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
begin
  select * into h from app.enrollment_hold where id = p_hold_id for update;
  update app.enrollment set status_code = coalesce(h.return_status_code, 'DANG_HOC')
   where id = h.enrollment_id and status_code = 'BAO_LUU';
  update app.enrollment_hold set status_code = 'KET_THUC', end_kind = p_end_kind, ended_at = now(), ended_by = (select auth.uid())
   where id = h.id;
end;
$$;

-- app.end_enrollment_hold: học lại sớm (R-CS-03 «quay lại học sớm») hoặc kết thúc khi tới hạn. Ai: Ghi danh · Duyệt.
create or replace function app.end_enrollment_hold(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h app.enrollment_hold;
begin
  h := app.enrollment_hold_for_update(p_id, array['DANG_BAO_LUU']);
  perform app.assert_can('ENROLLMENT', 'DUYET', h.branch_id);
  perform app.require_feature('BAO_LUU', h.branch_id);
  perform app.finish_enrollment_hold(h.id, case when h.end_date <= (now() at time zone 'Asia/Ho_Chi_Minh')::date then 'HET_HAN' else 'QUAY_LAI_SOM' end);
end;
$$;

-- app.end_expired_enrollment_holds: kết thúc mọi bảo lưu đã tới hạn. NỘI BỘ, CHƯA đăng ký lịch pg_cron (chờ anh duyệt như các lịch khác).
-- Kết quả: số bản đã kết thúc.
create or replace function app.end_expired_enrollment_holds()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_n integer := 0;
begin
  for r in select id from app.enrollment_hold
            where status_code = 'DANG_BAO_LUU' and end_date <= (now() at time zone 'Asia/Ho_Chi_Minh')::date
            order by end_date loop
    perform app.finish_enrollment_hold(r.id, 'HET_HAN');
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Quyền gọi
-- ---------------------------------------------------------------------------
revoke execute on function app.enrollment_hold_for_update(uuid, text[]), app.finish_enrollment_hold(uuid, text),
  app.end_expired_enrollment_holds() from public, anon, authenticated;
revoke execute on function
  app.create_enrollment_hold(uuid, integer, text, text, text, uuid), app.submit_enrollment_hold(uuid), app.approve_enrollment_hold(uuid),
  app.reject_enrollment_hold(uuid, text), app.cancel_enrollment_hold(uuid), app.end_enrollment_hold(uuid)
  from public, anon;
grant execute on function
  app.create_enrollment_hold(uuid, integer, text, text, text, uuid), app.submit_enrollment_hold(uuid), app.approve_enrollment_hold(uuid),
  app.reject_enrollment_hold(uuid, text), app.cancel_enrollment_hold(uuid), app.end_enrollment_hold(uuid)
  to authenticated;
