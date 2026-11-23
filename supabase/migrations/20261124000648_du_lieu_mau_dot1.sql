-- Dữ liệu mẫu staging, ĐỢT 1 (Code E, 24/11/2026; thẻ E-23-25/27/28; Chat duyệt thiết kế 04:40, anh OK concept 01:11).
-- Làm gì: nút «Dữ liệu mẫu của tôi» ở staging tạo một BỘ dữ liệu giả cho cơ sở người bấm; người tạo xoá bộ của mình, Admin xoá mọi bộ (xoá = đổi trạng thái, không xoá cứng).
-- Đợt 1 = khung: bảng bộ + bảng dòng thuộc bộ, cờ is_demo trên 7 bảng, khoá môi trường, tham số, hạn mức, hàm tạo/xoá/liệt kê.
-- Hàm tạo ở đợt 1 CHƯA đổ chuỗi dữ liệu (đợt 2: lead, cơ hội, báo giá, đơn, thu, học sinh, lớp, buổi, điểm danh, bài tập, ticket).
-- Luật an toàn (anh Trường, Chat 04:40):
--   (1) Hàm tạo và xoá kiểm công tắc demo_data_enabled VÀ khoá môi trường (bảng app.deployment_env phải ghi STAGING; không ai đổi qua giao diện).
--       Không có dòng khoá = coi như chạy thật = luôn từ chối (HMT_DEMO_TAT).
--   (2) Hàm tạo là security definer nhưng chỉ tạo NỘI DUNG CỐ ĐỊNH của bộ, không nhận dữ liệu tuỳ ý từ người gọi; không tự duyệt, không vượt luật «người tạo không tự duyệt».
--   (3) Người tạo xoá bộ của mình; Admin xoá mọi bộ; kiểm trong hàm.
--   (4) Mọi dòng created_by = người bấm; nhật ký tạo/xoá tự ghi qua audit_log (apply_standard).
--   (5) Hạn mức 3 bộ chưa xoá mỗi người, 10 bộ chưa xoá mỗi cơ sở, đọc từ tham số có min/max.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Khoá môi trường: một dòng duy nhất do seed riêng của staging đặt. Không cấp quyền ghi cho ai trên giao diện.
-- ---------------------------------------------------------------------------
create table app.deployment_env (
  singleton boolean primary key default true check (singleton),
  env_code text not null check (env_code in ('STAGING', 'PROD')),
  created_at timestamptz not null default now()
);
comment on table app.deployment_env is 'Khoá môi trường (chỉ staging được tạo dữ liệu mẫu). Không có dòng = coi là chạy thật. Chỉ seed staging ghi; không cấp quyền cho giao diện.';
alter table app.deployment_env enable row level security;
-- Không có chính sách và không cấp quyền: không ai đọc, ghi qua API. Hàm security definer đọc trực tiếp.

-- ---------------------------------------------------------------------------
-- Tham số
-- ---------------------------------------------------------------------------
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('demo_data_enabled', 'Cho phép tạo dữ liệu mẫu', 'BOOL', null, null, null, 'false', false, 'ADMIN', null,
   'Chỉ có tác dụng ở môi trường thử nghiệm (staging). Mặc định tắt. Ở chạy thật luôn từ chối dù bật.'),
  ('demo_data_max_per_user', 'Số bộ dữ liệu mẫu tối đa mỗi người', 'INT', 'bộ', 1, 20, '3', false, 'ADMIN', null,
   'Số bộ dữ liệu mẫu chưa xoá tối đa của mỗi người tạo.'),
  ('demo_data_max_per_branch', 'Số bộ dữ liệu mẫu tối đa mỗi cơ sở', 'INT', 'bộ', 1, 100, '10', false, 'ADMIN', null,
   'Số bộ dữ liệu mẫu chưa xoá tối đa của mỗi cơ sở.');

-- ---------------------------------------------------------------------------
-- Bảng bộ dữ liệu mẫu và các dòng thuộc bộ
-- ---------------------------------------------------------------------------
create table app.demo_data_set (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references app.branch (id),
  status_code text not null default 'DANG_DUNG' check (status_code in ('DANG_DUNG', 'DA_XOA')),
  deleted_at timestamptz,
  deleted_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.demo_data_set is 'Một bộ dữ liệu mẫu (staging). Xoá = DA_XOA, không xoá cứng.';
-- Chỉ mục: đếm hạn mức theo người (created_by) và theo cơ sở trong các bộ chưa xoá; liệt kê mới nhất trước.
create index demo_data_set_user_idx on app.demo_data_set (created_by) where status_code = 'DANG_DUNG';
create index demo_data_set_branch_idx on app.demo_data_set (branch_id) where status_code = 'DANG_DUNG';
create index demo_data_set_created_idx on app.demo_data_set (created_at desc);
select app.apply_standard('app.demo_data_set');

create table app.demo_data_item (
  id uuid primary key default gen_random_uuid(),
  set_id uuid not null references app.demo_data_set (id),
  entity_type text not null check (entity_type in ('LEAD', 'OPPORTUNITY', 'ORDER', 'STUDENT', 'CLASS', 'SESSION', 'TICKET')),
  entity_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (set_id, entity_type, entity_id)
);
comment on table app.demo_data_item is 'Bản ghi nào thuộc bộ dữ liệu mẫu nào (để xoá/ẩn cả bộ).';
-- Chỉ mục: mở các dòng của một bộ (khoá ngoại) đã được unique (set_id, ...) bao; tìm bộ chứa một bản ghi.
create index demo_data_item_entity_idx on app.demo_data_item (entity_type, entity_id);
select app.apply_standard('app.demo_data_item');

-- ---------------------------------------------------------------------------
-- Cờ is_demo trên 7 bảng (để bộ lọc «Ẩn dữ liệu mẫu» ở báo cáo rẻ). Chỉ mục từng phần: chỉ chứa dòng mẫu.
-- ---------------------------------------------------------------------------
alter table app.lead add column is_demo boolean not null default false;
alter table app.opportunity add column is_demo boolean not null default false;
alter table app.sales_order add column is_demo boolean not null default false;
alter table app.student add column is_demo boolean not null default false;
alter table app.class add column is_demo boolean not null default false;
alter table app.class_session add column is_demo boolean not null default false;
alter table app.ticket add column is_demo boolean not null default false;
create index lead_demo_idx on app.lead (id) where is_demo;
create index opportunity_demo_idx on app.opportunity (id) where is_demo;
create index sales_order_demo_idx on app.sales_order (id) where is_demo;
create index student_demo_idx on app.student (id) where is_demo;
create index class_demo_idx on app.class (id) where is_demo;
create index class_session_demo_idx on app.class_session (id) where is_demo;
create index ticket_demo_idx on app.ticket (id) where is_demo;

-- ---------------------------------------------------------------------------
-- RLS: đọc bộ của mình hoặc (Admin) mọi bộ; không ghi trực tiếp, chỉ qua hàm.
-- ---------------------------------------------------------------------------
alter table app.demo_data_set enable row level security;
alter table app.demo_data_item enable row level security;
grant select on app.demo_data_set, app.demo_data_item to authenticated;
create policy demo_data_set_read on app.demo_data_set for select to authenticated
  using (created_by = (select auth.uid()) or 'ADMIN' = any ((select app.current_roles())));
create policy demo_data_item_read on app.demo_data_item for select to authenticated
  using (exists (select 1 from app.demo_data_set s
                  where s.id = demo_data_item.set_id
                    and (s.created_by = (select auth.uid()) or 'ADMIN' = any ((select app.current_roles())))));

-- ---------------------------------------------------------------------------
-- Kiểm khoá: công tắc bật VÀ môi trường là STAGING. Lỗi HMT_DEMO_TAT.
-- ---------------------------------------------------------------------------
create or replace function app.assert_demo_data_allowed()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not coalesce((select e.env_code = 'STAGING' from app.deployment_env e), false)
     or not app.get_setting_bool('demo_data_enabled') then
    perform app.raise_error('HMT_DEMO_TAT', 'Dữ liệu mẫu đang tắt. Chức năng này chỉ dùng ở môi trường thử nghiệm.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tạo một bộ dữ liệu mẫu cho cơ sở của người bấm.
-- Ai gọi: mọi tài khoản đang dùng được (cơ sở lấy từ token, không nhận tham số).
-- Kết quả: id bộ mới. Lỗi: HMT_DEMO_TAT, HMT_DEMO_CHUA_DANG_NHAP, HMT_DEMO_THIEU_CO_SO, HMT_DEMO_QUA_HAN_MUC_NGUOI, HMT_DEMO_QUA_HAN_MUC_CO_SO.
-- Đợt 1: chỉ tạo bản ghi bộ; đợt 2 gọi các hàm con tạo chuỗi dữ liệu (không tự duyệt).
-- ---------------------------------------------------------------------------
create or replace function app.create_demo_data_set()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_branch uuid := app.current_branch_id();
  v_id uuid;
begin
  -- Luật (1): khoá môi trường và công tắc.
  perform app.assert_demo_data_allowed();
  if v_user is null or not app.current_user_active() then
    perform app.raise_error('HMT_DEMO_CHUA_DANG_NHAP', 'Cần đăng nhập để tạo dữ liệu mẫu.');
  end if;
  if v_branch is null then
    perform app.raise_error('HMT_DEMO_THIEU_CO_SO', 'Chọn cơ sở trước khi tạo dữ liệu mẫu.');
  end if;
  -- Luật (5): hạn mức theo người và theo cơ sở (chỉ tính bộ chưa xoá).
  if (select count(*) from app.demo_data_set where created_by = v_user and status_code = 'DANG_DUNG')
       >= app.get_setting_int('demo_data_max_per_user') then
    perform app.raise_error('HMT_DEMO_QUA_HAN_MUC_NGUOI', 'Bạn đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.');
  end if;
  if (select count(*) from app.demo_data_set where branch_id = v_branch and status_code = 'DANG_DUNG')
       >= app.get_setting_int('demo_data_max_per_branch') then
    perform app.raise_error('HMT_DEMO_QUA_HAN_MUC_CO_SO', 'Cơ sở này đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.');
  end if;
  insert into app.demo_data_set (branch_id, created_by, updated_by)
  values (v_branch, v_user, v_user)
  returning id into v_id;
  -- Đợt 2: đổ chuỗi dữ liệu cố định vào bộ v_id tại đây.
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xoá (ẩn) một bộ: đổi trạng thái. Luật (3): chủ bộ hoặc Admin.
-- Lỗi: HMT_DEMO_TAT, HMT_DEMO_KHONG_THAY_BO, HMT_DEMO_KHONG_DU_QUYEN, HMT_DEMO_DA_XOA.
-- Đợt 2: cũng ẩn các bản ghi thuộc bộ (cờ is_demo giữ để lọc báo cáo).
-- ---------------------------------------------------------------------------
create or replace function app.delete_demo_data_set(p_set_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_set app.demo_data_set;
begin
  perform app.assert_demo_data_allowed();
  select * into v_set from app.demo_data_set where id = p_set_id for update;
  if not found then
    perform app.raise_error('HMT_DEMO_KHONG_THAY_BO', 'Không thấy bộ dữ liệu mẫu này.');
  end if;
  if v_set.created_by is distinct from v_user and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Chỉ người tạo bộ hoặc Admin được xoá bộ dữ liệu mẫu.');
  end if;
  if v_set.status_code = 'DA_XOA' then
    perform app.raise_error('HMT_DEMO_DA_XOA', 'Bộ dữ liệu mẫu này đã xoá.');
  end if;
  update app.demo_data_set
     set status_code = 'DA_XOA', deleted_at = now(), deleted_by = v_user, updated_by = v_user
   where id = p_set_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Liệt kê bộ (phân trang máy chủ, mặc định 50, tối đa 100). Người thường thấy bộ của mình; Admin thấy mọi bộ.
-- ---------------------------------------------------------------------------
create or replace function app.list_demo_data_sets(p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, branch_id uuid, branch_name text, status_code text, created_at timestamptz, created_by uuid, creator_name text, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.branch_id, b.name, s.status_code, s.created_at, s.created_by, u.display_name,
         count(*) over ()
    from app.demo_data_set s
    join app.branch b on b.id = s.branch_id
    left join app.user_account u on u.id = s.created_by
   where (s.created_by = auth.uid() or 'ADMIN' = any (app.current_roles()))
   order by s.created_at desc
   limit least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max')) offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ---------------------------------------------------------------------------
-- Giao diện hỏi «có hiện nút Dữ liệu mẫu của tôi không»: đúng khi môi trường là staging VÀ công tắc bật. Không báo lỗi.
-- ---------------------------------------------------------------------------
create or replace function app.demo_data_available()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select e.env_code = 'STAGING' from app.deployment_env e), false)
         and app.get_setting_bool('demo_data_enabled');
$$;
revoke all on function app.demo_data_available() from public, anon;
grant execute on function app.demo_data_available() to authenticated;

-- Quyền gọi: chỉ người đăng nhập; không cho khách.
revoke all on function app.assert_demo_data_allowed() from public, anon;
revoke all on function app.create_demo_data_set() from public, anon;
revoke all on function app.delete_demo_data_set(uuid) from public, anon;
revoke all on function app.list_demo_data_sets(integer, integer) from public, anon;
grant execute on function app.create_demo_data_set() to authenticated;
grant execute on function app.delete_demo_data_set(uuid) to authenticated;
grant execute on function app.list_demo_data_sets(integer, integer) to authenticated;
