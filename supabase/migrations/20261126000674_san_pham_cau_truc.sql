-- B-26-03 PR-DB1: SẢN PHẨM thay GÓI, phần cấu trúc (anh Trường chốt SP1 26/11).
-- 1) Bỏ luật ép mã Loại-Môn-Khối (vẫn giữ regex, mã không đổi); 2) khối của sản phẩm là danh sách + nhãn; 3) thông tin gợi ý
-- (giờ mỗi tháng, sĩ số, giờ mỗi buổi, buổi mỗi tuần, ghi chú), KHÔNG tự điền vào đơn; 4) dòng báo giá, đơn chụp môn và khối
-- đã chọn; 5) danh sách sản phẩm bán trả đủ, thứ tự ổn định. Tên bảng, hàm giữ nguyên (*package*). Không nạp dữ liệu sản phẩm.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Danh mục Khối của sản phẩm. Mã bắt đầu bằng Kxx thì thuộc khối xx (để ghép lớp); mã khác không ràng khối khi ghép lớp.
-- Tách khỏi danh mục GRADE vì GRADE dùng cho học sinh, lớp, phiếu kiểm tra, khung chương trình.
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order)
select 'PRODUCT_GRADE', 'Khối của sản phẩm', 'MO', null, null,
       'Mã Kxx… ghép lớp khối xx; mã khác (Chuyên sâu, SAT…) không ràng khối.', max(sort_order) + 1 from app.catalog;

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  ('PRODUCT_GRADE', 'K02', '2', 20, false),
  ('PRODUCT_GRADE', 'K03', '3', 30, false),
  ('PRODUCT_GRADE', 'K04', '4', 40, false),
  ('PRODUCT_GRADE', 'K05', '5', 50, false),
  ('PRODUCT_GRADE', 'K05NC', '5NC', 55, false),
  ('PRODUCT_GRADE', 'K06', '6', 60, false),
  ('PRODUCT_GRADE', 'K07', '7', 70, false),
  ('PRODUCT_GRADE', 'K07NC', '7NC', 75, false),
  ('PRODUCT_GRADE', 'K08', '8', 80, false),
  ('PRODUCT_GRADE', 'K08NC', '8NC', 85, false),
  ('PRODUCT_GRADE', 'K09', '9', 90, false),
  ('PRODUCT_GRADE', 'K09NC', '9NC', 95, false),
  ('PRODUCT_GRADE', 'K10', '10', 100, false),
  ('PRODUCT_GRADE', 'K11', '11', 110, false),
  ('PRODUCT_GRADE', 'K12', '12', 120, false),
  ('PRODUCT_GRADE', 'K12_HSA', '12 HSA', 125, false),
  ('PRODUCT_GRADE', 'CHUYEN_SAU', 'Chuyên sâu', 130, false),
  ('PRODUCT_GRADE', 'TOAN_TIENG_ANH', 'Toán tiếng Anh', 140, false),
  ('PRODUCT_GRADE', 'SAT', 'SAT', 150, false);

-- ---------------------------------------------------------------------------
-- Cột mới của sản phẩm. Bảng vài trăm dòng, đọc theo loại, môn (đã có chỉ mục): không thêm chỉ mục cho grade_codes.
-- ---------------------------------------------------------------------------
alter table app.sales_package
  add column grade_codes text[] not null default '{}',
  add column grade_label text,
  add column hours_per_month numeric(6, 2) check (hours_per_month > 0),
  add column standard_class_size integer check (standard_class_size > 0),
  add column hours_per_session numeric(4, 2) check (hours_per_session > 0),
  add column sessions_per_week integer check (sessions_per_week > 0),
  add column note text;
comment on column app.sales_package.grade_codes is 'Mọi khối sản phẩm bán được (danh mục PRODUCT_GRADE). Rỗng = không gắn khối.';
comment on column app.sales_package.grade_label is 'Chữ khối để hiển thị. grade_from_code, grade_to_code suy ra từ grade_codes, chỉ dùng ghép lớp.';
comment on column app.sales_package.hours_per_month is 'Thông tin gợi ý, không tự điền vào đơn (R-TIEN-36).';

-- Khối (Kxx) mà một mã khối sản phẩm thuộc về; null = không ràng khối khi ghép lớp.
create or replace function app.product_base_grade(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select substring(p_code from '^K[0-9]{2}');
$$;
revoke execute on function app.product_base_grade(text) from public, anon, authenticated;

create or replace function app.tg_sales_package_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_code text;
  v_from integer;
  v_to integer;
  v_unbound boolean;
begin
  if TG_OP = 'UPDATE' then
    -- Luật: loại, môn, khối của sản phẩm không đổi (dòng chứng từ đã chụp theo); muốn khác thì tạo sản phẩm mới.
    if not app.is_migration() and (new.package_type_code is distinct from old.package_type_code
       or new.subject_code is distinct from old.subject_code
       or new.grade_from_code is distinct from old.grade_from_code or new.grade_to_code is distinct from old.grade_to_code
       or new.grade_codes is distinct from old.grade_codes) then
      perform app.raise_error('HMT_GOI_KHONG_DOI', 'Loại lớp, môn, khối của sản phẩm không đổi được. Tạo sản phẩm mới.');
    end if;
    return new;
  end if;
  perform app.assert_catalog_code_active('PACKAGE_TYPE', new.package_type_code);
  -- Luật R-TIEN-15: dịch vụ, tài liệu không gắn môn, khối.
  if app.package_unit(new.package_type_code) <> 'GIO' then
    if new.subject_code is not null or new.grade_from_code is not null or new.grade_to_code is not null
       or cardinality(new.grade_codes) > 0 then
      perform app.raise_error('HMT_GOI_KHONG_DOI', 'Sản phẩm dịch vụ, tài liệu không gắn môn, khối.');
    end if;
    return new;
  end if;
  -- Luật: sản phẩm giờ học phải có môn (ghép lớp chặn sai môn); khối không bắt buộc.
  if new.subject_code is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Sản phẩm giờ học cần môn.');
  end if;
  perform app.assert_catalog_code_active('SUBJECT', new.subject_code);
  -- Cách nhập cũ (khối đầu, khối cuối): suy ra danh sách khối.
  if cardinality(new.grade_codes) = 0 and new.grade_from_code is not null then
    perform app.assert_catalog_code_active('GRADE', new.grade_from_code);
    perform app.assert_catalog_code_active('GRADE', coalesce(new.grade_to_code, new.grade_from_code));
    select sort_order into v_from from app.catalog_item where catalog_code = 'GRADE' and code = new.grade_from_code;
    select sort_order into v_to from app.catalog_item where catalog_code = 'GRADE' and code = coalesce(new.grade_to_code, new.grade_from_code);
    if v_to < v_from then
      perform app.raise_error('HMT_KHOI_SAI', 'Khối đầu không được lớn hơn khối cuối.');
    end if;
    select array_agg(code order by sort_order) into new.grade_codes
      from app.catalog_item where catalog_code = 'GRADE' and sort_order between v_from and v_to;
  end if;
  if cardinality(new.grade_codes) = 0 then
    new.grade_from_code := null;
    new.grade_to_code := null;
    return new;
  end if;
  foreach v_code in array new.grade_codes loop
    perform app.assert_catalog_code_active('PRODUCT_GRADE', v_code);
  end loop;
  -- Sắp theo thứ tự danh mục, bỏ trùng.
  select array_agg(c.code order by c.sort_order) into new.grade_codes
    from app.catalog_item c where c.catalog_code = 'PRODUCT_GRADE' and c.code = any (new.grade_codes);
  if nullif(btrim(coalesce(new.grade_label, '')), '') is null then
    select string_agg(c.name, ', ' order by c.sort_order) into new.grade_label
      from app.catalog_item c where c.catalog_code = 'PRODUCT_GRADE' and c.code = any (new.grade_codes);
  end if;
  -- Luật (anh chốt F): có khối không phải Kxx (Chuyên sâu, Toán tiếng Anh, SAT) thì không ràng khối; 12 HSA thuộc khối 12.
  select bool_or(app.product_base_grade(x) is null) into v_unbound from unnest(new.grade_codes) x;
  if v_unbound then
    new.grade_from_code := null;
    new.grade_to_code := null;
    return new;
  end if;
  select min(g.sort_order), max(g.sort_order) into v_from, v_to
    from app.catalog_item g where g.catalog_code = 'GRADE'
     and g.code in (select app.product_base_grade(x) from unnest(new.grade_codes) x);
  -- Luật (anh chốt E): chặn lớp sai khối theo dải, nên các khối của một sản phẩm phải liền nhau.
  if (select count(*) from app.catalog_item g where g.catalog_code = 'GRADE' and g.sort_order between v_from and v_to)
     <> (select count(distinct app.product_base_grade(x)) from unnest(new.grade_codes) x) then
    perform app.raise_error('HMT_KHOI_KHONG_LIEN', 'Các khối của một sản phẩm phải liền nhau. Khối rời thì tách thành sản phẩm khác.');
  end if;
  select code into new.grade_from_code from app.catalog_item where catalog_code = 'GRADE' and sort_order = v_from;
  select code into new.grade_to_code from app.catalog_item where catalog_code = 'GRADE' and sort_order = v_to;
  if new.grade_to_code = new.grade_from_code then
    new.grade_to_code := null;
  end if;
  return new;
end;
$$;

-- Sản phẩm đã có: suy ra danh sách khối và nhãn từ khối đầu, khối cuối.
update app.sales_package p
   set grade_codes = s.codes, grade_label = s.label
  from (select p2.id, array_agg(g.code order by g.sort_order) as codes, string_agg(pg.name, ', ' order by g.sort_order) as label
          from app.sales_package p2
          join app.catalog_item f on f.catalog_code = 'GRADE' and f.code = p2.grade_from_code
          join app.catalog_item t on t.catalog_code = 'GRADE' and t.code = coalesce(p2.grade_to_code, p2.grade_from_code)
          join app.catalog_item g on g.catalog_code = 'GRADE' and g.sort_order between f.sort_order and t.sort_order
          join app.catalog_item pg on pg.catalog_code = 'PRODUCT_GRADE' and pg.code = g.code
         group by p2.id) s
 where p.id = s.id;

select set_config('hmt.migration', '', false);

-- Lấy từ 20261025000044_p5a_cau_hinh_ban_hang.sql; chỉ đổi phần chụp khối, môn (B-26-03).
create or replace function app.save_sales_package(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
begin
  if p_id is null then
    perform app.assert_config_sales('TAO');
    if btrim(coalesce(p_data ->> 'name', '')) = '' or btrim(coalesce(p_data ->> 'code', '')) = '' then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã và tên gói.');
    end if;
    begin
      insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code, grade_to_code, legacy_ref,
        grade_codes, grade_label, hours_per_month, standard_class_size, hours_per_session, sessions_per_week, note)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), p_data ->> 'package_type_code',
              nullif(p_data ->> 'subject_code', ''), nullif(p_data ->> 'grade_from_code', ''),
              nullif(p_data ->> 'grade_to_code', ''), nullif(p_data ->> 'legacy_ref', ''),
              array(select jsonb_array_elements_text(coalesce(p_data -> 'grade_codes', '[]'::jsonb))),
              nullif(btrim(coalesce(p_data ->> 'grade_label', '')), ''), nullif(p_data ->> 'hours_per_month', '')::numeric,
              nullif(p_data ->> 'standard_class_size', '')::integer, nullif(p_data ->> 'hours_per_session', '')::numeric,
              nullif(p_data ->> 'sessions_per_week', '')::integer, nullif(btrim(coalesce(p_data ->> 'note', '')), ''))
      returning id into v_id;
    exception when unique_violation then
      perform app.raise_error('HMT_MA_GOI_TRUNG', 'Mã gói này đã có.');
    end;
  else
    perform app.assert_config_sales('SUA');
    if not exists (select from app.sales_package where id = p_id) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy gói.');
    end if;
    update app.sales_package set
      name = case when p_data ? 'name' then btrim(coalesce(p_data ->> 'name', '')) else name end,
      legacy_ref = case when p_data ? 'legacy_ref' then nullif(p_data ->> 'legacy_ref', '') else legacy_ref end,
      grade_label = case when p_data ? 'grade_label' then nullif(btrim(coalesce(p_data ->> 'grade_label', '')), '') else grade_label end,
      grade_codes = case when p_data ? 'grade_codes' then array(select jsonb_array_elements_text(p_data -> 'grade_codes')) else grade_codes end,
      hours_per_month = case when p_data ? 'hours_per_month' then nullif(p_data ->> 'hours_per_month', '')::numeric else hours_per_month end,
      standard_class_size = case when p_data ? 'standard_class_size' then nullif(p_data ->> 'standard_class_size', '')::integer else standard_class_size end,
      hours_per_session = case when p_data ? 'hours_per_session' then nullif(p_data ->> 'hours_per_session', '')::numeric else hours_per_session end,
      sessions_per_week = case when p_data ? 'sessions_per_week' then nullif(p_data ->> 'sessions_per_week', '')::integer else sessions_per_week end,
      note = case when p_data ? 'note' then nullif(btrim(coalesce(p_data ->> 'note', '')), '') else note end,
      package_type_code = coalesce(p_data ->> 'package_type_code', package_type_code),
      subject_code = case when p_data ? 'subject_code' then nullif(p_data ->> 'subject_code', '') else subject_code end,
      grade_from_code = case when p_data ? 'grade_from_code' then nullif(p_data ->> 'grade_from_code', '') else grade_from_code end,
      grade_to_code = case when p_data ? 'grade_to_code' then nullif(p_data ->> 'grade_to_code', '') else grade_to_code end
     where id = p_id;
  end if;
  return v_id;
end;
$$;

