-- T2 (Đ285 đến Đ290; spec 04 mục 14: R-V2-04, R-V2-31): số điện thoại thứ hai của phụ huynh, cột mới của phụ huynh và học sinh,
-- khớp phụ huynh theo cả hai số. Nạp dữ liệu CS5 (T4) dùng các cột này.
-- Không đổi: quy tắc đúng 10 số bắt đầu bằng 0 (`HMT_SDT_SAI`) giữ nguyên.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Cột mới
-- Phụ huynh: SĐT thứ hai (phone_2), họ tên người thân (relative_name; địa chỉ đã có từ trước).
-- Học sinh: giới tính (gender), loại trường (school_type), khối (grade, từ 1 đến 12). Trường (school) và mục tiêu (goal) đã có.
-- Lead: SĐT thứ hai của phụ huynh (parent_phone_2), để nạp cơ hội có số thứ hai.
-- ---------------------------------------------------------------------------
alter table app.parent
  add column phone_2 text check (phone_2 ~ '^0[0-9]{9}$'),
  add column relative_name text check (relative_name is null or btrim(relative_name) <> '');
comment on column app.parent.phone_2 is 'SĐT thứ hai (R-V2-04): dùng để khớp phụ huynh như số chính.';
comment on column app.parent.relative_name is 'Họ tên người thân (cột ho_ten_2 của file nạp, R-V2-31).';

alter table app.student
  add column gender text check (gender in ('NAM', 'NU')),
  add column school_type text check (school_type is null or btrim(school_type) <> ''),
  add column grade smallint check (grade between 1 and 12);
comment on column app.student.gender is 'Giới tính: NAM hoặc NU (R-V2-31).';
comment on column app.student.grade is 'Khối đang học, từ 1 đến 12 (R-V2-31, R-V2-10).';

alter table app.lead
  add column parent_phone_2 text check (parent_phone_2 ~ '^0[0-9]{9}$');
comment on column app.lead.parent_phone_2 is 'SĐT thứ hai của phụ huynh (R-V2-04).';

-- Chỉ mục: tìm phụ huynh, lead theo số thứ hai (khớp phụ huynh, kiểm trùng khi tạo).
create index parent_phone_2_idx on app.parent (phone_2) where phone_2 is not null;
create index lead_phone_2_idx on app.lead (parent_phone_2) where parent_phone_2 is not null;
-- Khối: lọc, nhóm theo khối ở danh sách học sinh và nạp lớp.
create index student_grade_idx on app.student (grade) where grade is not null;

-- Ô tìm kiếm phụ huynh tìm được cả số thứ hai: cột sinh tự động phải dựng lại.
drop index app.parent_search_idx;
alter table app.parent drop column search_text;
alter table app.parent add column search_text text generated always as (
  app.fold_text(code || ' ' || full_name || ' ' || phone || ' ' || coalesce(phone_2, '') || ' ' || coalesce(legacy_ref, ''))
) stored;
create index parent_search_idx on app.parent using gin (search_text extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- 2. app.find_or_create_parent(SĐT, tên, phường, tỉnh, địa chỉ, cơ sở, SĐT thứ hai)
-- Làm gì: khớp phụ huynh theo SĐT đã chuẩn hoá: số chính hoặc số thứ hai của bất kỳ hồ sơ nào (R-V2-04, R-CRM-27).
--   Khớp thì dùng hồ sơ có sẵn (còn dùng trước, rồi cũ nhất; hồ sơ đã gộp thì trả bản giữ lại, R-CRM-25), không ghi đè tên;
--   chỉ điền số thứ hai nếu hồ sơ chưa có. Không khớp thì tạo mới (cấp mã PH), cơ sở tiếp nhận là cơ sở của cơ hội (R-CRM-28).
-- Ai gọi: hàm tạo cơ hội và hàm nạp dữ liệu (nội bộ, không mở cho API). Kết quả: id phụ huynh.
-- Lỗi: HMT_SDT_SAI khi số chính, hoặc số thứ hai có nhập, không đủ 10 số bắt đầu bằng 0.
-- ---------------------------------------------------------------------------
drop function app.find_or_create_parent(text, text, text, text, text, uuid);

create or replace function app.find_or_create_parent(
  p_phone text, p_name text, p_ward_code text, p_province_code text, p_address text, p_branch_id uuid,
  p_phone_2 text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := app.normalize_phone(p_phone);
  v_phone_2 text := nullif(app.normalize_phone(p_phone_2), '');
  v_id uuid;
  v_row app.parent;
begin
  -- Luật R-V2-04: số thứ hai, nếu có, cũng phải đủ 10 số.
  if v_phone_2 is not null and v_phone_2 !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại thứ hai cần đủ 10 số, bắt đầu bằng 0.');
  end if;

  -- Luật R-V2-04, R-CRM-27: khớp số chính hoặc số thứ hai với số chính hoặc số thứ hai của hồ sơ; hồ sơ cũ nhất, không ghi đè tên.
  -- Hồ sơ đã gộp thì trả bản giữ lại (R-CRM-25); ưu tiên hồ sơ còn dùng, rồi cũ nhất.
  select coalesce(merged_into_id, id) into v_id from app.parent
   where phone in (v_phone, coalesce(v_phone_2, v_phone))
      or phone_2 in (v_phone, coalesce(v_phone_2, v_phone))
   order by (record_status = 'DANG_DUNG') desc, created_at, id limit 1;
  if v_id is not null then
    -- Chỉ điền chỗ trống: số thứ hai mới của hồ sơ chưa có số thứ hai và không trùng số chính.
    update app.parent set phone_2 = v_phone_2
     where id = v_id and phone_2 is null and v_phone_2 is not null and v_phone_2 is distinct from phone
       and v_phone_2 is distinct from v_phone and phone = v_phone;
    return v_id;
  end if;
  if v_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  -- Luật R-CRM-28: tạo mới thì cơ sở tiếp nhận là cơ sở của cơ hội.
  insert into app.parent (code, full_name, phone, phone_2, ward_code, province_code, address, branch_id)
  values (app.issue_person_code('PH'), btrim(p_name), v_phone, v_phone_2, p_ward_code, p_province_code, p_address, p_branch_id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function app.find_or_create_parent(text, text, text, text, text, uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. app.find_duplicate_contacts(SĐT): kiểm trùng số khi tạo lead (TS-03, TS-14)
-- Làm gì: như bản trước, nhưng khớp cả số thứ hai của lead (parent_phone_2) và của phụ huynh (phone_2) (R-V2-04).
-- Hồ sơ ngoài phạm vi xem chỉ lộ mã và cơ sở. Chỉ báo trùng, không chặn (R-V2-05).
-- ---------------------------------------------------------------------------
create or replace function app.find_duplicate_contacts(p_phone text, p_exclude_lead_id uuid default null)
returns table (kind text, id uuid, code text, label text, branch_code text, visible boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_phone text := app.normalize_phone(p_phone);
begin
  if app.permission_scope('LEAD', 'TAO') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo lead.');
  end if;
  if v_phone !~ '^0[0-9]{9}$' then
    return;
  end if;
  return query
    select * from (
      select 'LEAD'::text as kind, l.id as id, l.code as code,
             case when app.can_see_branch('LEAD', 'XEM', l.branch_id)
                  then l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), '') end as label,
             b.code as branch_code, app.can_see_branch('LEAD', 'XEM', l.branch_id) as visible
        from app.lead l join app.branch b on b.id = l.branch_id
       where (l.parent_phone = v_phone or l.parent_phone_2 = v_phone)
         and l.record_status = 'DANG_DUNG' and l.id is distinct from p_exclude_lead_id
      union all
      select 'PARENT'::text, r.id, r.code,
             case when app.can_see_branch('PARENT', 'XEM', r.branch_id)
                  then r.full_name || ' · ' || (select count(*) from app.student s where s.parent_id = r.id and s.record_status = 'DANG_DUNG') || ' con' end,
             b.code, app.can_see_branch('PARENT', 'XEM', r.branch_id)
        -- Hồ sơ đã gộp thì trỏ về bản giữ lại (R-CRM-25): số điện thoại vẫn báo trùng, nhưng với hồ sơ còn dùng.
        from (select distinct coalesce(p.merged_into_id, p.id) as rid from app.parent p
               where p.phone = v_phone or p.phone_2 = v_phone) x
        join app.parent r on r.id = x.rid
        join app.branch b on b.id = r.branch_id
    ) q
    order by q.kind, q.code
    limit app.get_setting_int('search_result_max');
end;
$$;

select set_config('hmt.migration', '', false);
