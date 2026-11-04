-- T4a: nạp dữ liệu cũ theo loại, bước đầu: Phụ huynh và Học sinh (docs/spec/04 R-V2-29, 30, 31, 34; anh Trường chốt 04/11, Đ285).
-- Giao diện (màn Nhập, T5) đọc file mẫu (tab 01_PHUHUYNH, 02_HOCSINH), gửi tối đa import_max_rows hàng dạng JSON.
-- Hàm app.import_records chạy mỗi hàng trong một khối con bắt lỗi (như app.import_leads):
--   - Xem trước và nhập dùng chung một đường mã; xem trước chạy xong thì hoàn tác nên kết quả luôn khớp nhập thật.
--   - Dòng lỗi (LOI) và dòng trùng (TRUNG) bị bỏ qua, không dừng cả lô; nhập lại thì dòng đã nạp thành TRUNG (không ghi đè, không gộp).
-- QUYỀN RIÊNG TƯ: kết quả, thông báo lỗi và nhật ký nạp KHÔNG chứa họ tên, SĐT hay mã cũ. Mỗi dòng chỉ báo số dòng, chữ cái đầu của
-- tên và (nếu trùng) mã hồ sơ có sẵn (PH…, HS…), không phải dữ liệu cá nhân.

select set_config('hmt.migration', 'on', false);

-- Tham số: số dòng tối đa mỗi lần nạp (không viết cứng).
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('import_max_rows', 'Số dòng tối đa mỗi lần nạp dữ liệu cũ', 'INT', 'dòng', 1, 5000, '1000', false, null, null,
   'Giới hạn một lần nạp theo loại (phụ huynh, học sinh…) từ file mẫu; quá thì chặn cả lô.');

-- ---------------------------------------------------------------------------
-- Nhật ký nạp: người nạp, loại, tên file, số liệu. Không chép dữ liệu từng dòng (từng hồ sơ đã có nhật ký thao tác riêng).
-- ---------------------------------------------------------------------------
create table app.import_log (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('PHU_HUYNH', 'HOC_SINH')),
  importer_id uuid not null references app.user_account (id),
  file_name text,
  rows_total integer not null check (rows_total >= 0),
  imported_count integer not null check (imported_count >= 0),
  duplicate_count integer not null check (duplicate_count >= 0),
  error_count integer not null check (error_count >= 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.import_log is 'Nhật ký mỗi lần nạp dữ liệu cũ theo loại (R-V2-30). Chỉ số liệu, không có họ tên, SĐT.';
-- Xem các lần nạp theo loại và thời gian (Admin).
create index import_log_kind_idx on app.import_log (kind, created_at desc);
-- Khoá ngoại và xem theo người nạp.
create index import_log_importer_idx on app.import_log (importer_id, created_at desc);
select app.apply_standard('app.import_log');
alter table app.import_log enable row level security;
revoke all on app.import_log from public, anon, authenticated;
grant select on app.import_log to authenticated;
create policy import_log_read on app.import_log for select to authenticated
  using ((select app.has_permission('ADMIN', 'XEM')));

-- ---------------------------------------------------------------------------
-- Hàm trợ giúp (nội bộ)
-- ---------------------------------------------------------------------------
-- Chữ trong ô: bỏ khoảng trắng thừa; trống thì null.
create or replace function app.import_text(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(btrim(regexp_replace(coalesce(p_value, ''), '\s+', ' ', 'g')), '');
$$;

-- Chữ cái đầu của tên (không dấu, viết hoa), dùng để báo dòng lỗi mà không in họ tên.
create or replace function app.import_initial(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(upper(left(app.fold_text(btrim(coalesce(p_name, ''))), 1)), '');
$$;

-- Số điện thoại trong ô: chuẩn hoá; trống thì null; sai thì báo lỗi (câu không chứa số).
create or replace function app.import_phone(p_value text, p_required boolean)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := app.import_text(p_value);
begin
  if v is null then
    if p_required then
      perform app.raise_error('HMT_SDT_SAI', 'Thiếu số điện thoại.');
    end if;
    return null;
  end if;
  v := app.normalize_phone(v);
  if v !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  return v;
end;
$$;

-- Cơ sở theo mã: phải là mã cơ sở có thật.
create or replace function app.import_branch(p_code text)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if app.import_text(p_code) is null then
    perform app.raise_error('HMT_CO_SO_SAI', 'Thiếu mã cơ sở.');
  end if;
  select id into v_id from app.branch where code = upper(app.import_text(p_code)) and is_active;
  if v_id is null then
    perform app.raise_error('HMT_CO_SO_SAI', 'Mã cơ sở không có thật.');
  end if;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_one_parent(hàng): một hàng Phụ huynh. Khoá hàng: ma_cu, ho_ten, sdt, sdt_2, ho_ten_2, dia_chi, co_so.
-- Kết quả: {status: HOP_LE|TRUNG, code, initial}; hàng sai thì báo lỗi HMT_* (câu không chứa dữ liệu cá nhân).
-- Luật R-V2-30: mã cũ lưu vào legacy_ref; trùng mã cũ thì bỏ qua, không ghi đè.
-- Luật R-V2-04, R-CRM-27: trùng SĐT chính hoặc SĐT thứ hai với hồ sơ phụ huynh nào có sẵn (số chính hoặc số thứ hai) hoặc với dòng
--   trước trong file thì TRUNG, bỏ qua, KHÔNG tự gộp (anh Trường chốt 04/11).
-- ---------------------------------------------------------------------------
create or replace function app.import_one_parent(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_legacy text;
  v_name text;
  v_initial text;
  v_phone text;
  v_phone_2 text;
  v_branch uuid;
  v_existing text;
  v_code text;
begin
  if jsonb_typeof(p_row) <> 'object' then
    perform app.raise_error('HMT_DONG_SAI', 'Dòng không đúng định dạng.');
  end if;
  v_name := app.import_text(p_row ->> 'ho_ten');
  v_initial := app.import_initial(v_name);
  v_legacy := app.import_text(p_row ->> 'ma_cu');
  if v_legacy is null then
    perform app.raise_error('HMT_THIEU_MA_CU', 'Thiếu mã cũ.');
  end if;
  if v_name is null then
    perform app.raise_error('HMT_THIEU_HO_TEN', 'Thiếu họ tên.');
  end if;
  v_phone := app.import_phone(p_row ->> 'sdt', true);
  v_phone_2 := app.import_phone(p_row ->> 'sdt_2', false);
  -- Số thứ hai trùng số chính thì coi như không có.
  if v_phone_2 = v_phone then
    v_phone_2 := null;
  end if;
  -- Luật: cơ sở phải là mã cơ sở có thật.
  v_branch := app.import_branch(p_row ->> 'co_so');

  -- Luật R-V2-30: trùng mã cũ thì bỏ qua.
  select code into v_existing from app.parent where legacy_ref = v_legacy order by created_at, id limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'initial', v_initial, 'message', 'Trùng mã cũ, đã có hồ sơ');
  end if;
  -- Luật R-V2-04: trùng SĐT (kể cả SĐT thứ hai) với hồ sơ có sẵn thì bỏ qua, không gộp.
  select p.code into v_existing from app.parent p
   where p.phone in (v_phone, coalesce(v_phone_2, v_phone)) or p.phone_2 in (v_phone, coalesce(v_phone_2, v_phone))
   order by (p.record_status = 'DANG_DUNG') desc, p.created_at, p.id limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'initial', v_initial, 'message', 'Trùng số điện thoại, đã có hồ sơ');
  end if;

  v_code := app.issue_person_code('PH');
  insert into app.parent (code, full_name, phone, phone_2, relative_name, address, branch_id, legacy_ref)
  values (v_code, v_name, v_phone, v_phone_2, app.import_text(p_row ->> 'ho_ten_2'), app.import_text(p_row ->> 'dia_chi'),
          v_branch, v_legacy);
  return jsonb_build_object('status', 'HOP_LE', 'code', v_code, 'initial', v_initial, 'message', null);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_one_student(hàng): một hàng Học sinh. Khoá hàng: ma_cu, ho_ten, ngay_sinh (yyyy-mm-dd), gioi_tinh (Nam/Nữ),
--   sdt_ph, truong, loai_truong, khoi (1 đến 12), ghi_chu (mục tiêu), co_so.
-- Luật R-V2-30: trùng mã cũ thì bỏ qua, không ghi đè. Cùng phụ huynh + tên + năm sinh với học sinh có sẵn cũng là TRUNG (R-CRM-27).
-- Luật: phụ huynh khớp theo SĐT (số chính hoặc số thứ hai); không khớp thì LOI, KHÔNG tự tạo phụ huynh (anh Trường chốt 04/11).
-- Luật R-V2-29: bắt buộc ngày sinh (có năm sinh), khối 1 đến 12.
-- ---------------------------------------------------------------------------
create or replace function app.import_one_student(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_legacy text;
  v_name text;
  v_initial text;
  v_birth date;
  v_gender text;
  v_gender_in text;
  v_grade integer;
  v_phone text;
  v_branch uuid;
  v_parent uuid;
  v_existing text;
  v_code text;
begin
  if jsonb_typeof(p_row) <> 'object' then
    perform app.raise_error('HMT_DONG_SAI', 'Dòng không đúng định dạng.');
  end if;
  v_name := app.import_text(p_row ->> 'ho_ten');
  v_initial := app.import_initial(v_name);
  v_legacy := app.import_text(p_row ->> 'ma_cu');
  if v_legacy is null then
    perform app.raise_error('HMT_THIEU_MA_CU', 'Thiếu mã cũ.');
  end if;
  if v_name is null then
    perform app.raise_error('HMT_THIEU_HO_TEN', 'Thiếu họ tên.');
  end if;

  -- Luật R-V2-29: ngày sinh bắt buộc, dạng yyyy-mm-dd, không ở tương lai, từ năm 1900.
  if app.import_text(p_row ->> 'ngay_sinh') is null then
    perform app.raise_error('HMT_NGAY_SINH_SAI', 'Thiếu ngày sinh (học sinh bắt buộc có năm sinh).');
  end if;
  if app.import_text(p_row ->> 'ngay_sinh') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    perform app.raise_error('HMT_NGAY_SINH_SAI', 'Ngày sinh cần dạng yyyy-mm-dd.');
  end if;
  begin
    v_birth := app.import_text(p_row ->> 'ngay_sinh')::date;
  exception when others then
    perform app.raise_error('HMT_NGAY_SINH_SAI', 'Ngày sinh không có thật.');
  end;
  if extract(year from v_birth) < 1900 or v_birth > current_date then -- allow-number: năm tối thiểu 1900 như ràng buộc cột birth_year
    perform app.raise_error('HMT_NGAY_SINH_SAI', 'Ngày sinh phải từ năm 1900 và không ở tương lai.');
  end if;

  -- Luật R-V2-29: khối là số nguyên 1 đến 12.
  if app.import_text(p_row ->> 'khoi') is null or app.import_text(p_row ->> 'khoi') !~ '^[0-9]{1,2}$' then
    perform app.raise_error('HMT_KHOI_SAI', 'Khối cần là số từ 1 đến 12.');
  end if;
  v_grade := app.import_text(p_row ->> 'khoi')::integer;
  if v_grade < 1 or v_grade > 12 then -- allow-number: khối 1 đến 12, như ràng buộc cột grade
    perform app.raise_error('HMT_KHOI_SAI', 'Khối cần là số từ 1 đến 12.');
  end if;

  -- Giới tính (không bắt buộc): Nam / Nữ.
  v_gender_in := app.import_text(p_row ->> 'gioi_tinh');
  if v_gender_in is not null then
    v_gender := case app.fold_text(v_gender_in) when 'nam' then 'NAM' when 'nu' then 'NU' else null end;
    if v_gender is null then
      perform app.raise_error('HMT_GIOI_TINH_SAI', 'Giới tính chỉ nhận Nam hoặc Nữ.');
    end if;
  end if;

  v_phone := app.import_phone(p_row ->> 'sdt_ph', true);
  v_branch := app.import_branch(p_row ->> 'co_so');

  -- Luật R-V2-30: trùng mã cũ thì bỏ qua, không ghi đè.
  select code into v_existing from app.student where legacy_ref = v_legacy order by created_at, id limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'initial', v_initial, 'message', 'Trùng mã cũ, đã có hồ sơ');
  end if;

  -- Luật: phụ huynh khớp theo SĐT (số chính hoặc số thứ hai); hồ sơ đã gộp thì lấy bản giữ lại. Không khớp: LOI, không tự tạo phụ huynh.
  select coalesce(p.merged_into_id, p.id) into v_parent from app.parent p
   where p.phone = v_phone or p.phone_2 = v_phone
   order by (p.record_status = 'DANG_DUNG') desc, p.created_at, p.id limit 1;
  if v_parent is null then
    perform app.raise_error('HMT_PHU_HUYNH_KHONG_KHOP', 'Không khớp phụ huynh nào theo số điện thoại; nạp phụ huynh trước.');
  end if;

  -- Luật R-CRM-27: cùng phụ huynh, tên chuẩn hoá và năm sinh với học sinh có sẵn thì bỏ qua.
  select s.code into v_existing from app.student s
   where s.parent_id = v_parent and app.normalize_person_name(s.full_name) = app.normalize_person_name(v_name)
     and s.birth_year = extract(year from v_birth)::integer
   order by (s.record_status = 'DANG_DUNG') desc, s.created_at, s.id limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'initial', v_initial, 'message', 'Trùng học sinh của phụ huynh này, đã có hồ sơ');
  end if;

  v_code := app.issue_person_code('HS');
  insert into app.student (code, parent_id, full_name, birth_date, birth_year, school, school_type, grade, gender, goal, branch_id, legacy_ref)
  values (v_code, v_parent, v_name, v_birth, extract(year from v_birth)::integer, app.import_text(p_row ->> 'truong'),
          app.import_text(p_row ->> 'loai_truong'), v_grade, v_gender, app.import_text(p_row ->> 'ghi_chu'), v_branch, v_legacy);
  return jsonb_build_object('status', 'HOP_LE', 'code', v_code, 'initial', v_initial, 'message', null);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_records(loại, hàng, nhập thật?, tên file): nạp theo loại (màn Nhập, chỉ Admin).
-- Ai gọi: Admin (quyền ADMIN · Tạo; Admin có xác thực hai bước).
-- Đầu vào: p_kind PHU_HUYNH hoặc HOC_SINH; p_rows mảng JSON (mỗi hàng có thể kèm "row" là số dòng trong file);
--   p_commit false = xem trước (không ghi gì), true = nạp thật; p_file_name ghi vào nhật ký.
-- Kết quả: {mode, kind, total, imported, duplicates, errors, rows: [{row, label, initial, status, code, message}]};
--   status HOP_LE | TRUNG (kèm mã hồ sơ có sẵn) | LOI (kèm câu tiếng Việt); label = "Dòng N (X.)" với X là chữ cái đầu của tên.
--   Kết quả không chứa họ tên, SĐT, mã cũ.
-- Luật: tối đa import_max_rows hàng mỗi lần (quá thì chặn cả lô); dòng lỗi và dòng trùng bị bỏ qua, các dòng hợp lệ vẫn nạp
--   (phụ huynh, học sinh: R-V2-30); nạp là một giao dịch; xem trước hoàn tác toàn bộ.
-- ---------------------------------------------------------------------------
create or replace function app.import_records(
  p_kind text, p_rows jsonb, p_commit boolean default false, p_file_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('import_max_rows');
  v_total integer;
  v_result jsonb := '[]'::jsonb;
  v_ok integer := 0;
  v_dup integer := 0;
  v_err integer := 0;
  v_i integer := 0;
  v_rown integer;
  v_row jsonb;
  v_one jsonb;
  v_initial text;
  v_hint text;
  v_msg text;
  v_state text;
  v_detail text;
  v_final jsonb;
begin
  -- Luật: chỉ Admin (đã xác thực hai bước) dùng màn Nhập.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được nạp dữ liệu cũ.');
  end if;
  if p_kind not in ('PHU_HUYNH', 'HOC_SINH') then
    perform app.raise_error('HMT_LOAI_NAP_SAI', 'Loại dữ liệu nạp không hợp lệ.');
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nạp.');
  end if;
  v_total := jsonb_array_length(p_rows);
  -- Luật: tối đa import_max_rows hàng mỗi lần, quá thì chặn cả lô.
  if v_total > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_DONG', format('File có %s dòng, tối đa %s dòng mỗi lần nạp.', v_total, v_max));
  end if;

  -- Xem trước và nạp dùng chung một đường mã: xem trước chạy hết rồi hoàn tác (ném lỗi mang kết quả ra ngoài).
  begin
    for v_row in select value from jsonb_array_elements(p_rows) loop
      v_i := v_i + 1;
      -- Số dòng báo lỗi: số dòng trong file nếu có, không thì thứ tự trong lô.
      v_rown := case when jsonb_typeof(v_row) = 'object' and (v_row ->> 'row') ~ '^[0-9]{1,9}$' then (v_row ->> 'row')::integer else v_i end;
      v_initial := case when jsonb_typeof(v_row) = 'object' then app.import_initial(v_row ->> 'ho_ten') end;
      begin
        v_one := case p_kind when 'PHU_HUYNH' then app.import_one_parent(v_row) else app.import_one_student(v_row) end;
        if v_one ->> 'status' = 'TRUNG' then
          v_dup := v_dup + 1;
        else
          v_ok := v_ok + 1;
        end if;
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s (%s.)', v_rown, coalesce(v_initial, '?')),
                                                   'initial', v_initial, 'status', v_one ->> 'status', 'code', v_one ->> 'code',
                                                   'message', v_one ->> 'message');
      exception when others then
        get stacked diagnostics v_hint = pg_exception_hint, v_msg = message_text, v_state = returned_sqlstate;
        v_err := v_err + 1;
        -- Chỉ lấy câu lỗi nghiệp vụ của ta (HMT_*, đã viết không chứa dữ liệu cá nhân); lỗi lạ chỉ báo mã, không chép nội dung.
        if v_hint not like 'HMT\_%' then
          v_msg := format('Không ghi được dòng này (lỗi hệ thống, mã %s).', v_state);
        end if;
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s (%s.)', v_rown, coalesce(v_initial, '?')),
                                                   'initial', v_initial, 'status', 'LOI', 'code', null, 'message', v_msg);
      end;
    end loop;
    v_final := jsonb_build_object('mode', case when p_commit then 'NHAP' else 'XEM_TRUOC' end, 'kind', p_kind, 'total', v_total,
                                  'imported', v_ok, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result);
    if not p_commit then
      raise exception using errcode = 'HMT01', message = 'Xem trước nạp dữ liệu (hoàn tác)', detail = v_final::text;
    end if;
  exception when sqlstate 'HMT01' then
    get stacked diagnostics v_detail = pg_exception_detail;
    v_final := v_detail::jsonb;
  end;

  -- Nạp thật: ghi nhật ký một dòng cho cả lô (cùng giao dịch với các hồ sơ đã nạp). Chỉ số liệu.
  if p_commit then
    insert into app.import_log (kind, importer_id, file_name, rows_total, imported_count, duplicate_count, error_count)
    values (p_kind, auth.uid(), left(nullif(btrim(coalesce(p_file_name, '')), ''), 200), v_total, v_ok, v_dup, v_err); -- allow-number: độ dài tối đa tên file ghi nhật ký, không phải số nghiệp vụ
  end if;
  return v_final;
end;
$$;

revoke execute on function app.import_text(text), app.import_initial(text), app.import_phone(text, boolean),
  app.import_branch(text), app.import_one_parent(jsonb), app.import_one_student(jsonb) from public, anon, authenticated;
revoke execute on function app.import_records(text, jsonb, boolean, text) from public, anon;
grant execute on function app.import_records(text, jsonb, boolean, text) to authenticated;

select set_config('hmt.migration', '', false);
