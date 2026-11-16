-- Code B (15/11/2026), nạp dữ liệu CS5: cột nguon_goc của tab 05_COHOI (Chat chốt 15/11 21:15; bảng đối chiếu T5 phát hiện vênh script ↔ hàm).
-- Luật: R-V2-30. Cột nguon_goc của script là chữ tự do ("Page T9", "BGĐ"), không phải tên loại nguồn. Làm gì: nếu khớp tên loại nguồn trong danh mục thì dùng;
-- "BGĐ" thành loại Ban Giám Đốc; mọi giá trị khác (hoặc trống) thành Marketing KÈM CẢNH BÁO "Loại nguồn suy mặc định" (không phải lỗi); chữ gốc ghi vào ghi chú
-- của cơ hội (không thêm cột). Báo cáo nạp Cơ hội có thêm số dòng suy loại nguồn: summary.source_type_defaulted. Nguồn (cột nguon) vẫn phải thuộc loại.
-- Thay app.import_one_opportunity và app.import_records bằng create or replace (bản của migration 072). Không thêm bảng hay chỉ mục.
select set_config('hmt.migration', 'on', false);

create or replace function app.import_one_opportunity(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_legacy text;
  v_parent_name text;
  v_initial text;
  v_phone text;
  v_phone_2 text;
  v_branch uuid;
  v_created date;
  v_owner uuid;
  v_owner_name text;
  v_type_name text;
  v_source_name text;
  v_channel_name text;
  v_type_code text;
  v_type_defaulted boolean := false;
  v_type_raw_missing boolean := false;
  v_source_code text;
  v_channel_code text;
  v_stage text;
  v_substage text;
  v_stage_order integer;
  v_l5_order integer;
  v_names text[];
  v_years text[];
  v_year integer;
  v_school text;
  v_skip text;
  v_existing text;
  v_parent_id uuid;
  v_parent_code text;
  v_warnings jsonb := '[]'::jsonb;
  v_lead_id uuid;
  v_opp_id uuid;
  v_code text;
  v_note text;
  v_i integer;
  v_missing boolean;
  v_attached boolean := false;
begin
  if jsonb_typeof(p_row) <> 'object' then
    perform app.raise_error('HMT_DONG_SAI', 'Dòng không đúng định dạng.');
  end if;
  v_parent_name := app.import_text(p_row ->> 'ho_ten_ph');
  v_initial := app.import_initial(v_parent_name);
  v_legacy := app.import_text(p_row ->> 'ma_cu');
  if v_legacy is null then
    perform app.raise_error('HMT_THIEU_MA_CU', 'Thiếu mã cũ.');
  end if;

  -- Luật R-V2-30: trùng mã cũ thì bỏ qua, không ghi đè.
  select code into v_existing from app.opportunity where legacy_ref = v_legacy order by created_at, id limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'initial', v_initial, 'message', 'Trùng mã cũ, đã có cơ hội');
  end if;

  if v_parent_name is null then
    perform app.raise_error('HMT_THIEU_HO_TEN', 'Thiếu họ tên phụ huynh.');
  end if;
  v_phone := app.import_phone(p_row ->> 'sdt_ph', true);
  v_phone_2 := app.import_phone(p_row ->> 'sdt_2', false);
  if v_phone_2 = v_phone then
    v_phone_2 := null;
  end if;
  v_branch := app.import_branch(p_row ->> 'co_so');
  -- Luật R-HT-02: dữ liệu nghiệp vụ không ghi cơ sở văn phòng.
  if not exists (select from app.branch where id = v_branch and not is_office) then
    perform app.raise_error('HMT_CO_SO_VAN_PHONG', 'Cơ sở văn phòng (Hội sở) không có cơ hội.');
  end if;
  -- Luật: ngày tạo cũ đúng dạng yyyy-mm-dd, không ở tương lai.
  if app.import_text(p_row ->> 'ngay_tao') is null or app.import_text(p_row ->> 'ngay_tao') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    perform app.raise_error('HMT_NGAY_SAI', 'Ngày tạo cần đúng dạng yyyy-mm-dd.');
  end if;
  begin
    v_created := (app.import_text(p_row ->> 'ngay_tao'))::date;
  exception when others then
    perform app.raise_error('HMT_NGAY_SAI', 'Ngày tạo không phải ngày có thật.');
  end;
  if v_created > current_date then
    perform app.raise_error('HMT_NGAY_SAI', 'Ngày tạo không được ở tương lai.');
  end if;

  -- Luật: người phụ trách là tên đăng nhập (legacy_ref của tài khoản), cùng cơ sở. Tài khoản đã khoá (người nghỉ) vẫn nhận cơ hội cũ, kèm cảnh báo.
  v_owner_name := app.import_text(p_row ->> 'nguoi_phu_trach');
  if v_owner_name is null then
    perform app.raise_error('HMT_NGUOI_PHU_TRACH_SAI', 'Thiếu người phụ trách.');
  end if;
  select id into v_owner from app.user_account where legacy_ref = v_owner_name and student_code is null order by created_at, id limit 1;
  if v_owner is null then
    perform app.raise_error('HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách chưa có tài khoản (nạp Người dùng trước).');
  end if;
  if not exists (select from app.user_account where id = v_owner and branch_id = v_branch) then
    perform app.raise_error('HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách không thuộc cơ sở của dòng này.');
  end if;
  if exists (select from app.user_account where id = v_owner and is_locked) then
    v_warnings := v_warnings || to_jsonb('Người phụ trách đã nghỉ hoặc bị khoá.'::text);
  end if;

  -- Luật: nguồn ba tầng khớp theo tên với danh mục; nguồn thuộc loại, kênh thuộc nguồn; nguồn có kênh thì phải có kênh (như lead).
  v_type_name := app.import_text(p_row ->> 'nguon_goc');
  v_source_name := app.import_text(p_row ->> 'nguon');
  v_channel_name := app.import_text(p_row ->> 'medium');
  if v_source_name is null then
    perform app.raise_error('HMT_THIEU_NGUON', 'Thiếu nguồn.');
  end if;
  if v_type_name is null then
    v_type_name := 'Marketing';
    v_type_raw_missing := true;
    v_type_defaulted := true;
    v_warnings := v_warnings || to_jsonb('Loại nguồn suy mặc định.'::text);
  end if;
  v_type_code := app.import_match_catalog('SOURCE_TYPE', v_type_name);
  if v_type_code is null then
    -- Quyết định Chat 15/11 (cột nguon_goc của script là chữ tự do, không phải tên loại nguồn): "BGĐ" thành Ban Giám Đốc; mọi giá trị khác
    -- không khớp thành Marketing, KÈM CẢNH BÁO (không phải lỗi); chữ gốc ghi vào ghi chú của cơ hội. Luật HMT_NGUON_SAI về nguồn thuộc loại giữ nguyên.
    v_type_code := case when app.fold_text(v_type_name) in ('bgd', 'ban giam doc') then 'BAN_GIAM_DOC' else 'MARKETING' end;
    v_type_defaulted := true;
    v_warnings := v_warnings || to_jsonb('Loại nguồn suy mặc định.'::text);
  end if;
  v_source_code := app.import_match_catalog('SOURCE', v_source_name, (select id from app.catalog_item where catalog_code = 'SOURCE_TYPE' and code = v_type_code));
  if v_source_code is null then
    perform app.raise_error('HMT_NGUON_SAI', 'Nguồn không có trong danh mục hoặc không thuộc loại nguồn.');
  end if;
  if v_channel_name is not null then
    v_channel_code := app.import_match_catalog('SOURCE_CHANNEL', v_channel_name, (select id from app.catalog_item where catalog_code = 'SOURCE' and code = v_source_code));
    if v_channel_code is null then
      perform app.raise_error('HMT_NGUON_SAI', 'Kênh không có trong danh mục hoặc không thuộc nguồn.');
    end if;
  elsif exists (select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
                 where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active and s.catalog_code = 'SOURCE' and s.code = v_source_code) then
    perform app.raise_error('HMT_THIEU_NGUON', 'Nguồn này bắt buộc có kênh (cột medium).');
  end if;

  -- Luật: giai đoạn L1 đến L8, nhóm con thuộc đúng giai đoạn. Nạp thẳng giai đoạn, không đi qua luật chuyển giai đoạn.
  v_stage := upper(app.import_text(p_row ->> 'giai_doan'));
  if v_stage is null or not exists (select from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_stage and is_active) then
    perform app.raise_error('HMT_GIAI_DOAN_SAI', 'Giai đoạn cơ hội không có trong danh mục.');
  end if;
  v_substage := upper(app.import_text(p_row ->> 'nhom_con'));
  if v_substage is not null and not exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'OPP_SUBSTAGE' and c.code = v_substage and c.is_active
          and s.catalog_code = 'OPP_STAGE' and s.code = v_stage) then
    perform app.raise_error('HMT_NHOM_CON_SAI', 'Nhóm con không có trong danh mục hoặc không thuộc giai đoạn.');
  end if;
  select sort_order into v_stage_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_stage;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';

  -- Danh sách em: tối đa 5; tên trống vẫn nạp (cơ hội chưa có em). Năm sinh từng em tuỳ chọn.
  v_names := array(select btrim(x) from unnest(string_to_array(coalesce(p_row ->> 'danh_sach_em', ''), ';')) x where btrim(x) <> '');
  v_years := array(select btrim(x) from unnest(string_to_array(coalesce(p_row ->> 'nam_sinh', ''), ';')) x);
  if cardinality(v_names) > 5 then -- allow-number: tối đa 5 em mỗi cơ hội (R-CRM-26, Đ75)
    perform app.raise_error('HMT_QUA_NHIEU_EM', 'Một cơ hội có tối đa 5 em.');
  end if;
  for v_i in 1 .. cardinality(v_years) loop
    if v_years[v_i] <> '' and (v_years[v_i] !~ '^[0-9]{4}$' or v_years[v_i]::integer < 1900 or v_years[v_i]::integer > extract(year from current_date)::integer) then -- allow-number: năm sinh tối thiểu
      perform app.raise_error('HMT_NAM_SINH_SAI', 'Năm sinh em không hợp lệ (bốn chữ số).');
    end if;
  end loop;
  v_year := case when cardinality(v_years) >= 1 and v_years[1] <> '' then v_years[1]::integer end;
  -- Luật R-CRM-03 có NGOẠI LỆ CHỈ CHO LƯỢT NẠP (anh chốt 05/11): từ L5 trở lên thiếu tên và/hoặc năm sinh em vẫn nạp, đánh dấu
  -- student_info_missing + cảnh báo; năm sinh KHÔNG suy từ khối. Phải bổ sung trước khi sang bước tiếp theo hoặc ghi danh.
  v_missing := v_stage_order >= v_l5_order and (cardinality(v_names) = 0 or v_year is null);
  if v_missing then
    v_warnings := v_warnings || to_jsonb('Thiếu thông tin em (dữ liệu cũ), cần bổ sung tên và năm sinh em trước bước tiếp theo.'::text);
  end if;
  v_school := app.import_text(p_row ->> 'truong');
  -- Cơ hội L7, L8 chưa có phiếu kiểm tra: lý do bỏ qua test là "Nạp dữ liệu cũ".
  v_skip := case when v_stage in ('L7', 'L8') then 'NAP_CU' end;

  -- Luật (anh chốt 05/11): phụ huynh khớp theo SĐT chính hoặc thứ hai; có sẵn thì GẮN vào đó kèm cảnh báo, chưa có thì tạo mới (có mã cũ).
  select coalesce(p.merged_into_id, p.id), p.code into v_parent_id, v_parent_code
    from app.parent p
   where p.phone in (v_phone, coalesce(v_phone_2, v_phone)) or p.phone_2 in (v_phone, coalesce(v_phone_2, v_phone))
   order by (p.record_status = 'DANG_DUNG') desc, p.created_at, p.id limit 1;
  if v_parent_id is not null then
    v_attached := true;
    v_warnings := v_warnings || to_jsonb('Gắn vào phụ huynh có sẵn (mã ' || v_parent_code || ').');
  else
    v_parent_code := app.issue_person_code('PH');
    insert into app.parent (code, full_name, phone, phone_2, address, branch_id, opportunity_import)
    values (v_parent_code, v_parent_name, v_phone, v_phone_2, app.import_text(p_row ->> 'dia_chi'), v_branch, true)
    returning id into v_parent_id;
  end if;

  -- Lead gốc: về C4D "Tạo cơ hội thành công" (R-CRM-09), mang nguồn, người phụ trách như cơ hội.
  insert into app.lead (code, parent_name, parent_phone, parent_phone_2, address, need, parent_id, branch_id, owner_id,
                        source_type_code, source_code, channel_code, stage_code, substage_code, legacy_ref, legacy_created_at)
  values (app.issue_crm_code('LD'), v_parent_name, v_phone, v_phone_2, app.import_text(p_row ->> 'dia_chi'), app.import_text(p_row ->> 'nhu_cau'),
          v_parent_id, v_branch, v_owner, v_type_code, v_source_code, v_channel_code, 'C4', 'C4D', v_legacy, v_created)
  returning id into v_lead_id;

  v_code := app.issue_crm_code('CO');
  -- Tạo ở L1 rồi nâng thẳng lên giai đoạn trong file SAU khi có danh sách em: trigger R-CRM-03 (từ L5 cần em có tên, năm sinh) kiểm danh sách em
  -- (cơ hội có dấu thiếu thông tin em được miễn). Nâng một lần (L1 đến giai đoạn bất kỳ là đi tới, không vi phạm R-CRM-02).
  insert into app.opportunity (code, lead_id, parent_id, branch_id, owner_id, need,
                               source_type_code, source_code, channel_code, legacy_ref, legacy_created_at, student_info_missing)
  values (v_code, v_lead_id, v_parent_id, v_branch, v_owner, app.import_text(p_row ->> 'nhu_cau'),
          v_type_code, v_source_code, v_channel_code, v_legacy, v_created, v_missing)
  returning id into v_opp_id;

  -- Danh sách em (vị trí 1 đến 5) của lead gốc và của cơ hội: hồ sơ học sinh chưa có, em chỉ là chữ (nối hồ sơ học sinh ở lượt nạp Học sinh sau).
  for v_i in 1 .. cardinality(v_names) loop
    insert into app.prospect_student (lead_id, branch_id, position, full_name, birth_year, school)
    values (v_lead_id, v_branch, v_i, v_names[v_i],
            case when v_i <= cardinality(v_years) and v_years[v_i] <> '' then v_years[v_i]::integer end, v_school);
    insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year, school)
    values (v_opp_id, v_branch, v_i, v_names[v_i],
            case when v_i <= cardinality(v_years) and v_years[v_i] <> '' then v_years[v_i]::integer end, v_school);
  end loop;

  update app.opportunity
     set stage_code = v_stage, substage_code = v_substage, skip_reason_code = v_skip,
         skip_note = case when v_skip is not null then 'Nạp dữ liệu cũ' end
   where id = v_opp_id;

  -- Ghi chú gắn cơ hội: ghi chú gốc, tình trạng cũ, khối lớp, người phụ trách gốc (mỗi phần một dòng; chỉ lưu trong ghi chú của cơ hội).
  v_note := concat_ws(E'\n',
    app.import_text(p_row ->> 'ghi_chu'),
    case when app.import_text(p_row ->> 'tinh_trang_cu') is not null then 'Tình trạng cũ: ' || app.import_text(p_row ->> 'tinh_trang_cu') end,
    case when app.import_text(p_row ->> 'khoi') is not null then 'Khối: ' || app.import_text(p_row ->> 'khoi') end,
    case when app.import_text(p_row ->> 'nguoi_phu_trach_goc') is not null then 'Người phụ trách gốc: ' || app.import_text(p_row ->> 'nguoi_phu_trach_goc') end,
    case when v_type_defaulted and not v_type_raw_missing then 'Nguồn gốc (chữ gốc): ' || v_type_name end);
  if v_note is not null and btrim(v_note) <> '' then
    insert into app.note (entity_type, entity_id, body) values ('OPPORTUNITY', v_opp_id, v_note);
  end if;

  return jsonb_build_object('status', 'HOP_LE', 'code', v_code, 'initial', v_initial, 'message', null, 'warnings', v_warnings,
                            'stage', v_stage, 'student_missing', v_missing, 'attached_parent', v_attached, 'source_type_defaulted', v_type_defaulted);
end;
$$;

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
  v_def integer := 0;
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
  v_by_stage jsonb := '{}'::jsonb;
  v_miss integer := 0;
  v_att integer := 0;
begin
  -- Luật: chỉ Admin (đã xác thực hai bước) dùng màn Nhập.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được nạp dữ liệu cũ.');
  end if;
  if p_kind not in ('PHU_HUYNH', 'HOC_SINH', 'CO_HOI') then
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
      v_initial := case when jsonb_typeof(v_row) = 'object' then app.import_initial(coalesce(v_row ->> 'ho_ten', v_row ->> 'ho_ten_ph')) end;
      begin
        v_one := case p_kind when 'PHU_HUYNH' then app.import_one_parent(v_row) when 'HOC_SINH' then app.import_one_student(v_row)
                                else app.import_one_opportunity(v_row) end;
        if v_one ->> 'status' = 'TRUNG' then
          v_dup := v_dup + 1;
        else
          v_ok := v_ok + 1;
          -- Báo cáo nạp Cơ hội (chỉ số lượng): theo giai đoạn, số dòng thiếu thông tin em, số dòng gắn vào phụ huynh có sẵn.
          if p_kind = 'CO_HOI' then
            v_by_stage := jsonb_set(v_by_stage, array[v_one ->> 'stage'], to_jsonb(coalesce((v_by_stage ->> (v_one ->> 'stage'))::integer, 0) + 1));
            v_miss := v_miss + case when (v_one ->> 'student_missing')::boolean then 1 else 0 end;
            v_att := v_att + case when (v_one ->> 'attached_parent')::boolean then 1 else 0 end;
            v_def := v_def + case when (v_one ->> 'source_type_defaulted')::boolean then 1 else 0 end;
          end if;
        end if;
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s (%s.)', v_rown, coalesce(v_initial, '?')),
                                                   'initial', v_initial, 'status', v_one ->> 'status', 'code', v_one ->> 'code',
                                                   'message', v_one ->> 'message', 'warnings', coalesce(v_one -> 'warnings', '[]'::jsonb));
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
                                  'imported', v_ok, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result)
                  || case when p_kind = 'CO_HOI' then jsonb_build_object('summary', jsonb_build_object(
                       'by_stage', v_by_stage, 'missing_student_info', v_miss, 'attached_parent', v_att,
                       'source_type_defaulted', v_def)) else '{}'::jsonb end;
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

revoke execute on function app.import_one_opportunity(jsonb) from public, anon, authenticated;
revoke execute on function app.import_records(text, jsonb, boolean, text) from public, anon;
grant execute on function app.import_records(text, jsonb, boolean, text) to authenticated;

select set_config('hmt.migration', '', false);
