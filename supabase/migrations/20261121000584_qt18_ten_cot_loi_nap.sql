-- QT-18 (thẻ Chat 20:39, migration 584): báo TÊN CỘT LỖI cho từng dòng lỗi khi nạp dữ liệu cũ (khung QT18_ket_qua, QT18_chan_loai: «Cột ma_lop: không tìm thấy lớp»).
-- Luật áp dụng: R-V2-29, 30, 31 (nạp dữ liệu cũ), R-CRM-27 (màn Nhập chỉ Admin). Không đổi luật nạp, không đổi cách chặn; chỉ thêm khoá `column` vào mỗi dòng lỗi (cạnh `error_code`).
-- Cách làm: app.import_error_column(kind, mã lỗi, câu lỗi) trả tên cột hoặc NULL:
--   (1) câu lỗi nhóm đào tạo (Lớp, Ghi danh, Phiếu test, Số dư, Buổi, Điểm danh) đã nêu cột ở dạng «cột ten_cot» hoặc «Cột ten_cot»: lấy đúng tên đó (câu do ta viết, chỉ chứa tên cột, không chứa dữ liệu người);
--   (2) nhóm CRM (Phụ huynh, Học sinh, Cơ hội): mã lỗi chỉ về MỘT cột thì ánh xạ theo loại nạp (ví dụ HMT_SDT_SAI: sdt ở Phụ huynh, sdt_ph ở Học sinh, Cơ hội);
--   mã chung chung (HMT_NGUON_SAI, HMT_DONG_SAI...) trả NULL: màn chỉ hiện câu lỗi, không đoán cột.
-- Thay app.import_records (bản 155) và app.import_training_records (bản 217) bằng create or replace; không bảng mới, không chỉ mục (không đổi truy vấn).
select set_config('hmt.migration', 'on', false);

create or replace function app.import_error_column(p_kind text, p_code text, p_message text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_col text;
begin
  -- Cách 1: câu lỗi nêu sẵn tên cột (cột ma_lop_cu, Cột diem...).
  v_col := (regexp_match(coalesce(p_message, ''), '[Cc]ột ([a-z][a-z0-9_]*)'))[1];
  if v_col is not null then
    return v_col;
  end if;
  -- Cách 2: mã lỗi chỉ về một cột (nhóm CRM), có xét loại nạp.
  return case p_code
    when 'HMT_SDT_SAI' then case when p_kind = 'PHU_HUYNH' then 'sdt' else 'sdt_ph' end
    when 'HMT_THIEU_HO_TEN' then case when p_kind = 'CO_HOI' then 'ho_ten_ph' else 'ho_ten' end
    when 'HMT_THIEU_MA_CU' then 'ma_cu'
    when 'HMT_NGAY_SINH_SAI' then 'ngay_sinh'
    when 'HMT_NAM_SINH_SAI' then 'nam_sinh'
    when 'HMT_KHOI_SAI' then 'khoi'
    when 'HMT_GIOI_TINH_SAI' then 'gioi_tinh'
    when 'HMT_CO_SO_SAI' then 'co_so'
    when 'HMT_NGAY_SAI' then 'ngay_tao'
    when 'HMT_GIAI_DOAN_SAI' then 'giai_doan'
    when 'HMT_NHOM_CON_SAI' then 'nhom_con'
    when 'HMT_NGUOI_PHU_TRACH_SAI' then 'nguoi_phu_trach'
    else null
  end;
end;
$$;
revoke execute on function app.import_error_column(text, text, text) from public, anon, authenticated;


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
                                                   'initial', v_initial, 'status', 'LOI', 'code', null, 'message', v_msg,
                                                   'error_code', case when v_hint like 'HMT\_%' then v_hint end,
                                                   'column', case when v_hint like 'HMT\_%' then app.import_error_column(p_kind, v_hint, v_msg) end);
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

create or replace function app.import_training_records(
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
  v_hint text;
  v_msg text;
  v_state text;
  v_detail text;
  v_final jsonb;
  v_by_type jsonb := '{}'::jsonb;
  v_no_teacher jsonb := '[]'::jsonb;
  v_blocked boolean;
begin
  -- Luật: chỉ Admin (đã xác thực hai bước) nạp dữ liệu cũ.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được nạp dữ liệu cũ.');
  end if;
  if p_kind not in ('LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH', 'PHIEU_TEST', 'SO_DU') then
    perform app.raise_error('HMT_LOAI_NAP_SAI', 'Loại dữ liệu nạp không hợp lệ.');
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nạp.');
  end if;
  v_total := jsonb_array_length(p_rows);
  if v_total > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_DONG', format('File có %s dòng, tối đa %s dòng mỗi lần nạp.', v_total, v_max));
  end if;

  -- Xem trước và nạp dùng chung một đường mã: xem trước chạy hết rồi hoàn tác (ném lỗi mang kết quả ra ngoài).
  begin
    for v_row in select value from jsonb_array_elements(p_rows) loop
      v_i := v_i + 1;
      v_rown := case when jsonb_typeof(v_row) = 'object' and (v_row ->> 'row') ~ '^[0-9]{1,9}$' then (v_row ->> 'row')::integer else v_i end;
      begin
        v_one := case p_kind when 'LOP' then app.import_one_class(v_row) when 'GHI_DANH' then app.import_one_enrollment(v_row)
                             when 'BUOI_HOC' then app.import_one_legacy_session(v_row) when 'PHIEU_TEST' then app.import_one_student_test(v_row)
                             when 'SO_DU' then app.import_one_balance(v_row) else app.import_one_legacy_attendance(v_row) end;
        if v_one ->> 'status' = 'TRUNG' then
          v_dup := v_dup + 1;
        else
          v_ok := v_ok + 1;
          if coalesce((v_one ->> 'no_teacher')::boolean, false) then
            v_no_teacher := v_no_teacher || to_jsonb(v_one ->> 'legacy_ref');
          end if;
        end if;
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s', v_rown), 'status', v_one ->> 'status',
                                                   'code', v_one ->> 'code', 'message', v_one ->> 'message',
                                                   'warnings', coalesce(v_one -> 'warnings', '[]'::jsonb));
      exception when others then
        get stacked diagnostics v_hint = pg_exception_hint, v_msg = message_text, v_state = returned_sqlstate;
        v_err := v_err + 1;
        -- Chỉ lấy câu lỗi nghiệp vụ của ta (HMT_*); lỗi lạ chỉ báo mã, không chép nội dung (có thể chứa dữ liệu cá nhân).
        if v_hint not like 'HMT\_%' then
          v_msg := format('Không ghi được dòng này (lỗi hệ thống, mã %s).', v_state);
          v_hint := 'LOI_HE_THONG';
        end if;
        v_by_type := jsonb_set(v_by_type, array[v_hint], coalesce(v_by_type -> v_hint, '[]'::jsonb) || to_jsonb(v_rown));
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s', v_rown), 'status', 'LOI', 'code', null,
                                                   'error_code', v_hint, 'message', v_msg,
                                                   'column', case when v_hint like 'HMT\_%' then app.import_error_column(p_kind, v_hint, v_msg) end);
      end;
    end loop;
    -- Luật R-V2-30: ghi danh: một dòng lỗi thì chặn cả loại, kể cả khi gọi thẳng hàm (không chỉ nút ở giao diện).
    v_blocked := p_commit and p_kind in ('GHI_DANH', 'SO_DU') and v_err > 0;
    v_final := jsonb_build_object('mode', case when v_blocked then 'CHAN_CA_LOAI' when p_commit then 'NHAP' else 'XEM_TRUOC' end, 'kind', p_kind, 'total', v_total,
                                  'imported', case when v_blocked then 0 else v_ok end, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result,
                                  'summary', jsonb_build_object('errors_by_type', v_by_type, 'classes_without_teacher', v_no_teacher));
    if not p_commit or v_blocked then
      raise exception using errcode = 'HMT01', message = 'Xem trước hoặc chặn cả loại nạp dữ liệu (hoàn tác)', detail = v_final::text;
    end if;
  exception when sqlstate 'HMT01' then
    get stacked diagnostics v_detail = pg_exception_detail;
    v_final := v_detail::jsonb;
  end;

  if p_commit then
    insert into app.import_log (kind, importer_id, file_name, rows_total, imported_count, duplicate_count, error_count)
    values (p_kind, auth.uid(), left(nullif(btrim(coalesce(p_file_name, '')), ''), 200), v_total, (v_final ->> 'imported')::integer, v_dup, v_err); -- allow-number: độ dài tối đa tên file ghi nhật ký
  end if;
  return v_final;
end;
$$;

grant execute on function app.import_records(text, jsonb, boolean, text) to authenticated;
grant execute on function app.import_training_records(text, jsonb, boolean, text) to authenticated;

select set_config('hmt.migration', '', false);
