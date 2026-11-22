-- BC-09 «Chốt tháng» giờ dạy giáo viên (thẻ F-23-07; khung BC09_chot_pc, BC09_chot_loc_pc, BC09_da_chot_pc, BC09_bm_pc). Mức CAO: căn cứ tính lương.
-- Luật (anh Trường chốt 18/11 + ghi chú Design 1aab): chốt CẢ HỆ THỐNG một lần mỗi tháng; tháng đã chốt khoá, KHÔNG có Mở lại; hiện «Đã chốt bởi … lúc …»;
-- Trưởng cơ sở không chốt được (chỉ người có quyền Báo cáo · Xem phạm vi Toàn hệ thống và Báo cáo · Xuất: Kế toán, Admin); không chốt tháng chưa kết thúc.
-- Chốt = chụp lại số giờ từng người, từng cơ sở lúc chốt (bản ghi nghiệp vụ chụp lại giá trị, không tính lại): xem tháng đã chốt luôn ra đúng số đã chốt.
-- Phần «sửa buổi sau chốt thì chênh lệch đưa vào tháng sau» CHƯA làm (cần luật chi tiết, đã báo trong PR).
select set_config('hmt.migration', 'on', false);

-- Bảng chốt: mỗi tháng một dòng. Chỉ mục: unique(month) cho tra cứu theo tháng. Ghi qua hàm security definer, không có chính sách ghi cho người dùng.
create table app.teaching_hours_close (
  id uuid primary key default gen_random_uuid(),
  month date not null unique check (month = date_trunc('month', month)::date),
  closed_at timestamptz not null default now(),
  closed_by uuid not null,
  total_hours numeric(10,2) not null check (total_hours >= 0),
  -- Ảnh chụp lúc chốt: {rows: [{user_id, code, name, role, branch_code, hours, by_type:{CHINH, CUNG_CO, HOC_BU, BO_TRO}}]}.
  snapshot jsonb not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.teaching_hours_close is 'BC-09: tháng giờ dạy đã chốt (cả hệ thống), kèm ảnh chụp số giờ. Chỉ thêm, không sửa, không xoá, không mở lại.';
select app.apply_standard('app.teaching_hours_close');
alter table app.teaching_hours_close enable row level security;
revoke all on app.teaching_hours_close from public, anon, authenticated;
grant select on app.teaching_hours_close to authenticated;
create policy teaching_hours_close_read on app.teaching_hours_close for select to authenticated
  using ((select app.has_permission('REPORT', 'XEM')));

-- Luật: tháng đã chốt thì khoá, không sửa (kể cả quản trị): chặn mọi UPDATE. Xoá đã bị apply_standard chặn.
create or replace function app.tg_teaching_hours_close_locked()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_THANG_DA_CHOT', 'Tháng giờ dạy đã chốt, không sửa và không mở lại.');
  return null;
end;
$$;
create trigger teaching_hours_close_locked before update on app.teaching_hours_close
  for each row execute function app.tg_teaching_hours_close_locked();

-- ---------------------------------------------------------------------------
-- app.close_teaching_hours_month(p_month): chốt giờ dạy một tháng cho CẢ HỆ THỐNG.
-- Ai gọi: người có Báo cáo · Xem phạm vi Toàn hệ thống VÀ Báo cáo · Xuất (Kế toán, Admin); Trưởng cơ sở (phạm vi cơ sở) bị chặn.
-- Đầu vào: p_month (ngày bất kỳ trong tháng). Kết quả: {month, closed_at, total_hours}.
-- Luật: tháng phải đã kết thúc (HMT_THANG_CHUA_KET_THUC); chưa chốt (HMT_THANG_DA_CHOT); số liệu chụp từ app.report_teaching_hours (một nguồn).
-- ---------------------------------------------------------------------------
create or replace function app.close_teaching_hours_month(p_month date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_first date := date_trunc('month', p_month)::date;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_page integer := app.get_setting_int('list_page_size_max');
  v_offset integer := 0;
  v_part jsonb;
  v_total bigint;
  v_hours numeric;
  v_rows jsonb := '[]'::jsonb;
  v_closed_at timestamptz;
begin
  if p_month is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn tháng cần chốt.');
  end if;
  -- Luật quyền: chốt cả hệ thống, chỉ người xem toàn hệ thống và có quyền Xuất báo cáo (Kế toán, Admin).
  if app.permission_scope('REPORT', 'XEM') is distinct from 'TOAN_HE_THONG' or not app.has_permission('REPORT', 'XUAT') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Kế toán hoặc Admin được chốt giờ dạy (chốt cả hệ thống).');
  end if;
  -- Luật: không chốt tháng chưa kết thúc.
  if (v_first + interval '1 month')::date > v_today then
    perform app.raise_error('HMT_THANG_CHUA_KET_THUC', 'Tháng này chưa kết thúc, chưa chốt được.');
  end if;
  -- Luật: mỗi tháng chốt một lần. Khoá theo tháng để hai người bấm cùng lúc không chốt hai lần.
  perform pg_advisory_xact_lock(hashtext('teaching_hours_close'), (extract(year from v_first) * 12 + extract(month from v_first))::integer); -- allow-number: 12 tháng một năm, chỉ để đánh số khoá theo tháng
  if exists (select from app.teaching_hours_close where month = v_first) then
    perform app.raise_error('HMT_THANG_DA_CHOT', 'Tháng này đã được chốt.');
  end if;
  -- Chụp số liệu: gom mọi trang của báo cáo (toàn hệ thống, mọi cơ sở).
  loop
    v_part := app.report_teaching_hours(v_first, null, v_page, v_offset);
    v_total := (v_part ->> 'total')::bigint;
    v_hours := (v_part -> 'totals' ->> 'hours')::numeric;
    v_rows := v_rows || (v_part -> 'rows');
    v_offset := v_offset + v_page;
    exit when v_offset >= v_total;
  end loop;
  insert into app.teaching_hours_close (month, closed_by, total_hours, snapshot)
  values (v_first, app.current_actor(), coalesce(v_hours, 0), jsonb_build_object('rows', v_rows))
  returning closed_at into v_closed_at;
  return jsonb_build_object('month', v_first, 'closed_at', v_closed_at, 'total_hours', coalesce(v_hours, 0));
end;
$$;
comment on function app.close_teaching_hours_month(date) is 'BC-09: chốt giờ dạy một tháng cho cả hệ thống (chụp số liệu, khoá, không mở lại). Kế toán, Admin.';

-- ---------------------------------------------------------------------------
-- app.teaching_hours_view(p_month, p_branch_id, p_limit, p_offset): báo cáo giờ dạy KÈM trạng thái chốt, màn BC-09 gọi hàm này.
-- Tháng chưa chốt: số liệu sống từ app.report_teaching_hours, 'closed' = null. Tháng đã chốt: số liệu từ ảnh chụp lúc chốt (lọc cơ sở, phân trang như báo cáo),
-- 'closed' = {closed_at, closed_by_name}. Quyền như báo cáo (Báo cáo · Xem; phạm vi cơ sở chỉ thấy cơ sở mình).
-- ---------------------------------------------------------------------------
create or replace function app.teaching_hours_view(p_month date default null, p_branch_id uuid default null, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('REPORT', 'XEM');
  v_first date := date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Ho_Chi_Minh')::date))::date;
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_branch_code text;
  v_close app.teaching_hours_close;
  v_live jsonb;
  v_totals jsonb;
  v_total bigint;
  v_rows jsonb;
begin
  -- Luật quyền (giống báo cáo xem): Báo cáo · Xem; phạm vi hẹp chỉ cơ sở mình.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem báo cáo.');
  end if;
  select * into v_close from app.teaching_hours_close where month = v_first;
  if not found then
    -- Chưa chốt: số liệu sống (hàm gốc tự kiểm phạm vi cơ sở), có cờ chưa chốt.
    v_live := app.report_teaching_hours(v_first, p_branch_id, v_limit, p_offset);
    return v_live || jsonb_build_object('closed', null);
  end if;
  if v_scope <> 'TOAN_HE_THONG' then
    if p_branch_id is not null and p_branch_id <> (select app.current_branch_id()) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ xem được báo cáo của cơ sở mình.');
    end if;
    select code into v_branch_code from app.branch where id = (select app.current_branch_id());
  elsif p_branch_id is not null then
    select code into v_branch_code from app.branch where id = p_branch_id;
  end if;
  -- Tháng đã chốt: đọc từ ảnh chụp, lọc cơ sở rồi tổng hợp lại như báo cáo sống.
  with snap as (
    select x.* from jsonb_to_recordset(v_close.snapshot -> 'rows')
      as x (user_id uuid, code text, name text, role text, branch_code text, hours numeric, by_type jsonb)
     where v_branch_code is null or x.branch_code = v_branch_code
  )
  select jsonb_build_object(
           'hours', coalesce((select sum(hours) from snap), 0),
           'teachers', (select count(distinct user_id) from snap where role = 'GIAO_VIEN'),
           'assistants', (select count(distinct user_id) from snap where role = 'TRO_GIANG'),
           'by_type', jsonb_build_object(
             'CHINH', coalesce((select sum((by_type ->> 'CHINH')::numeric) from snap), 0),
             'CUNG_CO', coalesce((select sum((by_type ->> 'CUNG_CO')::numeric) from snap), 0),
             'HOC_BU', coalesce((select sum((by_type ->> 'HOC_BU')::numeric) from snap), 0),
             'BO_TRO', coalesce((select sum((by_type ->> 'BO_TRO')::numeric) from snap), 0))),
         (select count(*) from snap),
         coalesce((select jsonb_agg(jsonb_build_object('user_id', y.user_id, 'code', y.code, 'name', y.name, 'role', y.role, 'branch_code', y.branch_code,
                                                       'hours', y.hours, 'by_type', y.by_type)
                                    order by y.code nulls last, y.name, y.user_id, y.branch_code)
                     from (select * from snap order by code nulls last, name, user_id, branch_code
                            limit v_limit offset greatest(coalesce(p_offset, 0), 0)) y), '[]'::jsonb)
    into v_totals, v_total, v_rows;
  return jsonb_build_object('month', v_first, 'total', v_total, 'totals', v_totals, 'rows', v_rows,
                            'closed', jsonb_build_object('closed_at', v_close.closed_at, 'closed_by_name', app.staff_display_name(v_close.closed_by)));
end;
$$;
comment on function app.teaching_hours_view(date, uuid, integer, integer) is 'BC-09: báo cáo giờ dạy kèm trạng thái chốt; tháng đã chốt đọc từ ảnh chụp.';

revoke execute on function app.close_teaching_hours_month(date), app.teaching_hours_view(date, uuid, integer, integer) from public, anon;
grant execute on function app.close_teaching_hours_month(date), app.teaching_hours_view(date, uuid, integer, integer) to authenticated;
