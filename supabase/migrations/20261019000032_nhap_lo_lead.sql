-- P3b3b: nhập lô lead từ file (docs/spec/04 R-CRM-11 "giữ như bản cũ"; TS-04; tham số lead_import_max_rows).
-- Giao diện (P3f) đọc file CSV, ghép cột, gửi tối đa lead_import_max_rows hàng dạng JSON. Hàm app.import_leads chạy mỗi hàng qua
-- ĐÚNG hàm app.create_lead (không viết lại luật), trong một khối con bắt lỗi từng hàng:
--   - Xem trước và nhập dùng chung một đường mã; xem trước chạy xong thì hoàn tác toàn bộ nên kết quả luôn khớp nhập thật.
--   - Nhập: một giao dịch, bỏ dòng lỗi và dòng trùng SĐT, báo tổng kết.
-- Mỗi lần nhập thật ghi một dòng nhật ký (app.lead_import_log).

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Nhật ký nhập lô: người nhập, cơ sở, tên file, số liệu. Ghi gọn (không chép dữ liệu từng dòng; từng lead đã có nhật ký thao tác riêng).
-- ---------------------------------------------------------------------------
create table app.lead_import_log (
  id uuid primary key default gen_random_uuid(),
  importer_id uuid not null references app.user_account (id),
  branch_id uuid not null references app.branch (id),
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
comment on table app.lead_import_log is 'Nhật ký mỗi lần nhập lô lead từ file (R-CRM-11, TS-04).';
-- Xem lại các lần nhập của một người (và Admin xem theo thời gian).
create index lead_import_log_importer_idx on app.lead_import_log (importer_id, created_at desc);
-- Khoá ngoại và xem theo cơ sở.
create index lead_import_log_branch_idx on app.lead_import_log (branch_id, created_at desc);
select app.apply_standard('app.lead_import_log');
alter table app.lead_import_log enable row level security;
revoke all on app.lead_import_log from public, anon, authenticated;
grant select on app.lead_import_log to authenticated;
-- Người nhập xem các lần nhập của mình; Admin xem tất cả.
create policy lead_import_log_read on app.lead_import_log for select to authenticated
  using (importer_id = (select auth.uid()) or (select app.has_permission('ADMIN', 'XEM')));

-- ---------------------------------------------------------------------------
-- Một hàng nhập: ghép dữ liệu hàng với giá trị mặc định rồi gọi app.create_lead. Hàm nội bộ (chạy trong khối con bắt lỗi của
-- app.import_leads). Khoá của hàng (tên cột sau khi ghép ở giao diện): parent_name, parent_phone, student_name,
-- student_birth_year, source_type_code, source_code, channel_code, need, owner_email. Ô nào trống thì lấy giá trị mặc định
-- (nguồn, kênh, chiến dịch, cơ sở, người phụ trách). Cột email sale chỉ có tác dụng khi người nhập có quyền Giao việc cùng cơ sở
-- (create_lead kiểm). Kết quả: {id, code} của lead vừa tạo.
-- ---------------------------------------------------------------------------
create or replace function app.import_one_lead(p_row jsonb, p_defaults jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year integer;
  v_email text := nullif(btrim(coalesce(p_row ->> 'owner_email', '')), '');
  v_owner uuid := nullif(p_defaults ->> 'owner_id', '')::uuid;
  v_data jsonb;
begin
  if jsonb_typeof(p_row) <> 'object' then
    perform app.raise_error('HMT_DONG_SAI', 'Dòng không đúng định dạng.');
  end if;
  -- Luật: năm sinh học sinh là số nguyên (create_lead kiểm tiếp từ 1900 trở lên).
  begin
    v_year := nullif(btrim(coalesce(p_row ->> 'student_birth_year', '')), '')::integer;
  exception when invalid_text_representation then
    perform app.raise_error('HMT_NAM_SINH_SAI', 'Năm sinh học sinh phải là số, ví dụ 2012.');
  end;
  -- Người phụ trách theo email trong file (nếu có); không có thì mặc định.
  if v_email is not null then
    select id into v_owner from app.user_account where lower(login_name) = lower(v_email) and student_code is null;
    if v_owner is null then
      perform app.raise_error('HMT_NGUOI_PHU_TRACH_SAI', format('Không tìm thấy nhân viên có email %s.', v_email));
    end if;
  end if;
  v_data := jsonb_strip_nulls(jsonb_build_object(
    'parent_name', nullif(btrim(coalesce(p_row ->> 'parent_name', '')), ''),
    'parent_phone', coalesce(p_row ->> 'parent_phone', ''),
    'student_name', nullif(btrim(coalesce(p_row ->> 'student_name', '')), ''),
    'student_birth_year', v_year,
    'need', nullif(btrim(coalesce(p_row ->> 'need', '')), ''),
    'source_type_code', coalesce(nullif(btrim(coalesce(p_row ->> 'source_type_code', '')), ''), p_defaults ->> 'source_type_code'),
    'source_code', coalesce(nullif(btrim(coalesce(p_row ->> 'source_code', '')), ''), p_defaults ->> 'source_code'),
    -- Hàng có nguồn riêng thì không thừa kế kênh mặc định (kênh của nguồn khác sẽ sai); hàng không ghi nguồn thì lấy kênh mặc định.
    'channel_code', coalesce(nullif(btrim(coalesce(p_row ->> 'channel_code', '')), ''),
                             case when nullif(btrim(coalesce(p_row ->> 'source_code', '')), '') is null then p_defaults ->> 'channel_code' end),
    'campaign_id', p_defaults ->> 'campaign_id',
    'branch_id', p_defaults ->> 'branch_id',
    'owner_id', v_owner));
  -- Mọi luật của lead (SĐT, nguồn ba tầng, cơ sở, người phụ trách, trùng SĐT) do create_lead kiểm; trùng SĐT chưa xác nhận thì báo
  -- HMT_SDT_TRUNG, hàng bị bỏ qua.
  return app.create_lead(v_data, false, null);
end;
$$;

-- ---------------------------------------------------------------------------
-- Nhập lô lead (TS-04). Ai gọi: người có quyền Lead · Tạo ở cơ sở nhập (CSKH nhập được; anh chốt 18/10).
-- Đầu vào:
--   p_rows: mảng JSON các hàng (khoá như app.import_one_lead; có thể kèm "row" là số dòng trong file để báo lỗi);
--   p_commit: false = xem trước (không ghi gì), true = nhập thật;
--   p_defaults: {source_type_code, source_code, channel_code, campaign_id, branch_id, owner_id}; mặc định cơ sở và người
--     phụ trách là của người nhập (Admin chọn cơ sở và người phụ trách của cơ sở đó);
--   p_file_name: tên file, ghi vào nhật ký.
-- Kết quả: {mode, total, imported, duplicates, errors, rows: [{row, status, code, message}]}; status là HOP_LE, TRUNG
--   (kèm mã bản có sẵn, ví dụ "Trùng với LD000231") hoặc LOI (kèm câu tiếng Việt).
-- Luật: tối đa lead_import_max_rows hàng mỗi lần (quá thì chặn cả lô); bỏ dòng lỗi và dòng trùng SĐT (với lead đang dùng, phụ
--   huynh có sẵn, hoặc dòng trước đó trong file); nhập là một giao dịch; xem trước hoàn tác toàn bộ.
-- ---------------------------------------------------------------------------
create or replace function app.import_leads(
  p_rows jsonb, p_commit boolean default false, p_defaults jsonb default '{}'::jsonb, p_file_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('lead_import_max_rows');
  v_branch uuid := coalesce(nullif(p_defaults ->> 'branch_id', '')::uuid, app.current_branch_id());
  v_defaults jsonb;
  v_total integer;
  v_result jsonb := '[]'::jsonb;
  v_ok integer := 0;
  v_dup integer := 0;
  v_err integer := 0;
  v_i integer := 0;
  v_rown integer;
  v_row jsonb;
  v_hint text;
  v_msg text;
  v_created jsonb;
  v_exist text;
  v_detail text;
  v_final jsonb;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nhập.');
  end if;
  -- Luật: quyền tạo lead ở cơ sở nhập (CSKH cũng nhập được).
  perform app.assert_can('LEAD', 'TAO', v_branch);
  v_total := jsonb_array_length(p_rows);
  -- Luật: tối đa lead_import_max_rows hàng mỗi lần, quá thì chặn cả lô.
  if v_total > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_DONG', format('File có %s dòng, tối đa %s dòng mỗi lần nhập.', v_total, v_max));
  end if;
  v_defaults := p_defaults || jsonb_build_object('branch_id', v_branch,
                                                 'owner_id', coalesce(nullif(p_defaults ->> 'owner_id', ''), auth.uid()::text));

  -- Xem trước và nhập dùng chung một đường mã: xem trước chạy hết rồi hoàn tác (ném lỗi mang kết quả ra ngoài).
  begin
    for v_row in select value from jsonb_array_elements(p_rows) loop
      v_i := v_i + 1;
      -- Số dòng báo lỗi: số dòng trong file nếu có, không thì thứ tự trong lô.
      v_rown := case when (v_row ->> 'row') ~ '^[0-9]{1,9}$' then (v_row ->> 'row')::integer else v_i end;
      begin
        v_created := app.import_one_lead(v_row, v_defaults);
        v_ok := v_ok + 1;
        v_result := v_result || jsonb_build_object('row', v_rown, 'status', 'HOP_LE',
                                                   'code', v_created ->> 'code', 'message', null);
      exception when others then
        get stacked diagnostics v_hint = pg_exception_hint, v_msg = message_text;
        if v_hint = 'HMT_SDT_TRUNG' then
          -- Dòng trùng SĐT: nêu mã bản có sẵn (lead hoặc phụ huynh, kể cả dòng trước trong file).
          select d.code into v_exist from app.find_duplicate_contacts(v_row ->> 'parent_phone') d order by d.kind, d.code limit 1;
          v_dup := v_dup + 1;
          v_result := v_result || jsonb_build_object('row', v_rown, 'status', 'TRUNG',
                                                     'code', v_exist, 'message', format('Trùng với %s', coalesce(v_exist, 'hồ sơ có sẵn')));
        else
          v_err := v_err + 1;
          v_result := v_result || jsonb_build_object('row', v_rown, 'status', 'LOI',
                                                     'code', null, 'message', v_msg);
        end if;
      end;
    end loop;
    v_final := jsonb_build_object('mode', case when p_commit then 'NHAP' else 'XEM_TRUOC' end, 'total', v_total,
                                  'imported', v_ok, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result);
    if not p_commit then
      raise exception using errcode = 'HMT01', message = 'Xem trước nhập lô (hoàn tác)', detail = v_final::text;
    end if;
  exception when sqlstate 'HMT01' then
    get stacked diagnostics v_detail = pg_exception_detail;
    v_final := v_detail::jsonb;
  end;

  -- Nhập thật: ghi nhật ký một dòng cho cả lô (cùng giao dịch với các lead đã nhập).
  if p_commit then
    insert into app.lead_import_log (importer_id, branch_id, file_name, rows_total, imported_count, duplicate_count, error_count)
    values (auth.uid(), v_branch, nullif(btrim(coalesce(p_file_name, '')), ''), v_total, v_ok, v_dup, v_err);
  end if;
  return v_final;
end;
$$;

revoke execute on function app.import_one_lead(jsonb, jsonb) from public, anon, authenticated;
revoke execute on function app.import_leads(jsonb, boolean, jsonb, text) from public, anon;
grant execute on function app.import_leads(jsonb, boolean, jsonb, text) to authenticated;

select set_config('hmt.migration', '', false);
