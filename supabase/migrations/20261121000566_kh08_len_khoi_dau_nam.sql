-- KH-08 Lên khối đầu năm học (Code F, 19/11/2026; thẻ F73; anh Trường chốt luật 19/11 23:17).
-- Luật (docs/nghiep-vu/kh08-len-khoi-dau-nam.md):
--  1. Admin bấm tay chạy «Lên khối đầu năm»; không tự chạy.
--  2. Chỉ em ĐANG HỌC (có ghi danh Chờ xếp lớp, Đã xếp lớp hoặc Đang học) và đã có khối. Em bảo lưu, đã dừng học, tiềm năng (chưa ghi danh),
--     chưa có khối, đã tốt nghiệp: bỏ qua, không đổi khối.
--  3. Em lớp 12 thì Tốt nghiệp (ghi ngày tốt nghiệp, giữ khối 12); các khối còn lại tăng một.
--  4. Xem trước từng em (khối cũ, khối mới) và loại trừ được trước khi xác nhận.
--  5. Sau khi xác nhận: hoàn tác cả đợt trong N ngày (tham số grade_promotion_undo_days, mặc định 7); nhật ký từng em (bảng dòng đợt + nhật ký thao tác của học sinh).
-- Làm gì: cột app.student.graduated_on; bảng app.grade_promotion_batch, app.grade_promotion_item; hàm xem trước, chạy, hoàn tác, liệt kê đợt.
select set_config('hmt.migration', 'on', false);

alter table app.student add column graduated_on date;
comment on column app.student.graduated_on is 'Ngày tốt nghiệp (KH-08): em lớp 12 qua đợt Lên khối đầu năm. NULL là chưa tốt nghiệp. Khối giữ 12.';
-- Chỉ mục: loại em đã tốt nghiệp khỏi danh sách xem trước.
create index student_graduated_idx on app.student (graduated_on) where graduated_on is not null;

-- Tham số: số ngày được hoàn tác một đợt (không viết cứng trong hàm).
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('grade_promotion_undo_days', 'Số ngày được hoàn tác đợt lên khối', 'INT', 'ngày', 1, 30, '7', false, 'ADMIN', null,
        'Sau khi xác nhận «Lên khối đầu năm học» (KH-08), Admin hoàn tác cả đợt được trong số ngày này.');

-- ---------------------------------------------------------------------------
-- Bảng đợt và dòng đợt. Ghi chỉ qua hàm; đọc cho Admin. Khung chung: người, giờ, nhật ký, không xoá.
-- ---------------------------------------------------------------------------
create table app.grade_promotion_batch (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references app.branch (id), -- NULL = mọi cơ sở
  promoted_count integer not null check (promoted_count >= 0),
  graduated_count integer not null check (graduated_count >= 0),
  excluded_count integer not null check (excluded_count >= 0),
  status_code text not null default 'DA_CHAY' check (status_code in ('DA_CHAY', 'DA_HOAN_TAC')),
  undone_at timestamptz,
  undone_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.grade_promotion_batch is 'Đợt Lên khối đầu năm học (KH-08). Hoàn tác trong grade_promotion_undo_days ngày.';
-- Chỉ mục: liệt kê đợt mới nhất trước.
create index grade_promotion_batch_created_idx on app.grade_promotion_batch (created_at desc);

create table app.grade_promotion_item (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references app.grade_promotion_batch (id),
  student_id uuid not null references app.student (id),
  old_grade smallint not null,
  new_grade smallint, -- NULL = tốt nghiệp (khối giữ nguyên)
  undone boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.grade_promotion_item is 'Từng em trong một đợt Lên khối: khối cũ, khối mới (NULL: tốt nghiệp). Nhật ký từng em.';
-- Chỉ mục: mở các em của một đợt; tìm lịch sử lên khối của một em.
create index grade_promotion_item_batch_idx on app.grade_promotion_item (batch_id);
create index grade_promotion_item_student_idx on app.grade_promotion_item (student_id);
select app.apply_standard('app.grade_promotion_batch');
select app.apply_standard('app.grade_promotion_item');

alter table app.grade_promotion_batch enable row level security;
alter table app.grade_promotion_item enable row level security;
revoke all on app.grade_promotion_batch, app.grade_promotion_item from public, anon, authenticated;
grant select on app.grade_promotion_batch, app.grade_promotion_item to authenticated;
create policy grade_promotion_batch_read on app.grade_promotion_batch for select to authenticated
  using ((select app.has_permission('ADMIN', 'XEM')));
create policy grade_promotion_item_read on app.grade_promotion_item for select to authenticated
  using ((select app.has_permission('ADMIN', 'XEM')));

-- ---------------------------------------------------------------------------
-- Các em đủ điều kiện lên khối (luật 2). Hàm nội bộ cho xem trước và chạy.
-- ---------------------------------------------------------------------------
create or replace function app.grade_promotion_candidates(p_branch uuid)
returns table (student_id uuid, old_grade smallint, new_grade smallint)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.grade,
         case when s.grade >= 12 then null else (s.grade + 1)::smallint end -- allow-number: khối cuối cấp là lớp 12 (R-V2-31); lớp 12 tốt nghiệp
    from app.student s
   where s.grade is not null
     and s.graduated_on is null
     and (p_branch is null or s.branch_id = p_branch)
     -- Đang học = có ghi danh Chờ xếp lớp, Đã xếp lớp hoặc Đang học (cùng định nghĩa app.student_status).
     and exists (select from app.enrollment e where e.student_id = s.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC'));
$$;
revoke execute on function app.grade_promotion_candidates(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- app.preview_grade_promotion(bộ lọc, số dòng, bỏ qua): xem trước từng em (khối cũ, khối mới) và số em bị bỏ qua theo lý do.
-- Bộ lọc: branch_id (mặc định mọi cơ sở), q (tên, mã HS). Kết quả {eligible, graduating, skipped{khong_dang_hoc (bảo lưu, đã dừng), tiem_nang, chua_co_khoi, da_tot_nghiep},
-- total, rows[{student_id, code, full_name, branch_code, old_grade, new_grade}]}; new_grade NULL là tốt nghiệp. Ai gọi: Admin (aal2).
-- ---------------------------------------------------------------------------
create or replace function app.preview_grade_promotion(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_result jsonb;
begin
  perform app.assert_account_admin(); -- Luật 1: chỉ Admin.
  with c as materialized (select * from app.grade_promotion_candidates(v_branch)),
  scoped as (select s.id, s.grade, s.graduated_on, (c.student_id is not null) as eligible,
                    exists (select from app.enrollment e where e.student_id = s.id) as has_enrollment
               from app.student s left join c on c.student_id = s.id
              where v_branch is null or s.branch_id = v_branch),
  page as (
    select s.id, s.code, s.full_name, s.branch_id, c.old_grade, c.new_grade
      from c join app.student s on s.id = c.student_id
     where v_q is null or s.search_text like '%' || v_q || '%'
     order by s.code, s.id limit v_limit offset v_offset)
  select jsonb_build_object(
           'eligible', (select count(*) from c),
           'graduating', (select count(*) from c where c.new_grade is null),
           'skipped', jsonb_build_object(
             'da_tot_nghiep', (select count(*) from scoped where graduated_on is not null),
             'chua_co_khoi', (select count(*) from scoped where grade is null and graduated_on is null),
             'khong_dang_hoc', (select count(*) from scoped where grade is not null and graduated_on is null and not eligible and has_enrollment),
             'tiem_nang', (select count(*) from scoped where grade is not null and graduated_on is null and not eligible and not has_enrollment)),
           'total', (select count(*) from c join app.student s on s.id = c.student_id where v_q is null or s.search_text like '%' || v_q || '%'),
           'rows', coalesce((select jsonb_agg(jsonb_build_object('student_id', p.id, 'code', p.code, 'full_name', p.full_name, 'branch_code', b.code,
                                                              'old_grade', p.old_grade, 'new_grade', p.new_grade) order by p.code, p.id)
                               from page p join app.branch b on b.id = p.branch_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.run_grade_promotion(bộ lọc, các em loại trừ): chạy một đợt. Một giao dịch: mọi em đủ điều kiện (trừ em loại trừ) tăng một khối;
-- lớp 12 tốt nghiệp. Ghi đợt và dòng từng em. Kết quả {batch_id, promoted, graduated, excluded}. Ai gọi: Admin (aal2).
-- ---------------------------------------------------------------------------
create or replace function app.run_grade_promotion(p_filters jsonb default '{}'::jsonb, p_excluded uuid[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_excluded uuid[] := coalesce(p_excluded, '{}');
  v_batch uuid;
  v_promoted integer;
  v_graduated integer;
  v_excluded_n integer;
begin
  perform app.assert_account_admin(); -- Luật 1: chỉ Admin.
  -- Chỉ tính em loại trừ nào thật sự đủ điều kiện (em lạ bị bỏ qua, không làm lệch số).
  select count(*) into v_excluded_n from app.grade_promotion_candidates(v_branch) c where c.student_id = any (v_excluded);
  select count(*) filter (where c.new_grade is not null), count(*) filter (where c.new_grade is null) into v_promoted, v_graduated
    from app.grade_promotion_candidates(v_branch) c where not (c.student_id = any (v_excluded));
  if v_promoted + v_graduated = 0 then
    perform app.raise_error('HMT_KHONG_CO_EM_LEN_KHOI', 'Không có em nào đủ điều kiện lên khối (đang học, đã có khối, chưa tốt nghiệp).');
  end if;

  insert into app.grade_promotion_batch (branch_id, promoted_count, graduated_count, excluded_count)
  values (v_branch, v_promoted, v_graduated, v_excluded_n) returning id into v_batch;
  insert into app.grade_promotion_item (batch_id, student_id, old_grade, new_grade)
  select v_batch, c.student_id, c.old_grade, c.new_grade from app.grade_promotion_candidates(v_branch) c where not (c.student_id = any (v_excluded));
  -- Luật 3: tăng một khối; lớp 12 ghi ngày tốt nghiệp (theo giờ Việt Nam), giữ khối.
  update app.student s set grade = coalesce(i.new_grade, s.grade),
                           graduated_on = case when i.new_grade is null then (now() at time zone 'Asia/Ho_Chi_Minh')::date else s.graduated_on end
    from app.grade_promotion_item i where i.batch_id = v_batch and s.id = i.student_id;
  return jsonb_build_object('batch_id', v_batch, 'promoted', v_promoted, 'graduated', v_graduated, 'excluded', v_excluded_n);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.undo_grade_promotion(đợt): hoàn tác cả đợt trong grade_promotion_undo_days ngày (luật 5). Em đã được sửa khối tay sau đợt thì giữ nguyên
-- (không đè), tính vào «bỏ qua». Kết quả {restored, kept}. Ai gọi: Admin (aal2).
-- ---------------------------------------------------------------------------
create or replace function app.undo_grade_promotion(p_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_batch app.grade_promotion_batch;
  v_days integer := app.get_setting_int('grade_promotion_undo_days');
  v_restored integer;
  v_total integer;
begin
  perform app.assert_account_admin(); -- Luật 1: chỉ Admin.
  select * into v_batch from app.grade_promotion_batch where id = p_batch_id for update;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không có đợt lên khối này.');
  end if;
  if v_batch.status_code = 'DA_HOAN_TAC' then
    perform app.raise_error('HMT_DOT_DA_HOAN_TAC', 'Đợt này đã hoàn tác rồi.');
  end if;
  if v_batch.created_at < now() - make_interval(days => v_days) then
    perform app.raise_error('HMT_QUA_HAN_HOAN_TAC', format('Đã quá %s ngày kể từ lúc chạy, không hoàn tác được nữa. Sửa khối từng em ở hồ sơ học sinh.', v_days));
  end if;
  select count(*) into v_total from app.grade_promotion_item where batch_id = p_batch_id;
  -- Khôi phục em còn đúng khối do đợt đặt (khối mới, hoặc đã tốt nghiệp vẫn đúng ngày tốt nghiệp của đợt).
  with back as (
    update app.student s set grade = i.old_grade, graduated_on = null
      from app.grade_promotion_item i
     where i.batch_id = p_batch_id and not i.undone and s.id = i.student_id
       and ((i.new_grade is not null and s.grade = i.new_grade)
            or (i.new_grade is null and s.graduated_on is not null and s.grade = i.old_grade))
    returning i.id)
  update app.grade_promotion_item i set undone = true from back b where i.id = b.id;
  get diagnostics v_restored = row_count;
  update app.grade_promotion_batch set status_code = 'DA_HOAN_TAC', undone_at = now(), undone_by = auth.uid() where id = p_batch_id;
  return jsonb_build_object('restored', v_restored, 'kept', v_total - v_restored);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.list_grade_promotion_batches(): các đợt đã chạy (mới nhất trước), kèm hạn hoàn tác. Ai gọi: Admin (xem).
-- ---------------------------------------------------------------------------
create or replace function app.list_grade_promotion_batches()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer := app.get_setting_int('grade_promotion_undo_days');
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem các đợt lên khối.');
  end if;
  return jsonb_build_object('undo_days', v_days, 'rows', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', b.id, 'created_at', b.created_at, 'created_by_name', app.staff_display_name(b.created_by),
             'branch_code', (select code from app.branch where id = b.branch_id),
             'promoted', b.promoted_count, 'graduated', b.graduated_count, 'excluded', b.excluded_count,
             'status', b.status_code, 'undo_until', b.created_at + make_interval(days => v_days),
             'can_undo', b.status_code = 'DA_CHAY' and b.created_at >= now() - make_interval(days => v_days))
           order by b.created_at desc)
      from (select * from app.grade_promotion_batch order by created_at desc limit 50) b), '[]'::jsonb)); -- allow-number: 50 đợt gần nhất đủ cho màn lịch sử
end;
$$;

revoke execute on function app.preview_grade_promotion(jsonb, integer, integer), app.run_grade_promotion(jsonb, uuid[]),
  app.undo_grade_promotion(uuid), app.list_grade_promotion_batches() from public, anon;
grant execute on function app.preview_grade_promotion(jsonb, integer, integer), app.run_grade_promotion(jsonb, uuid[]),
  app.undo_grade_promotion(uuid), app.list_grade_promotion_batches() to authenticated;
