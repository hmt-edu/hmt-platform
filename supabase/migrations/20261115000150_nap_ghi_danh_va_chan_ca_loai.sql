-- Code B (15/11/2026), nạp dữ liệu CS5, PR 1: vá Ghi danh theo bảng đối chiếu tab script ↔ hàm (Chat chốt H1, H3, H6 lúc 11:25).
-- Luật: R-V2-30 (một dòng lỗi chặn cả loại với ghi danh), R-V2-32, R-V2-33, Q-177 (mỗi ghi danh một dòng "Số dư đầu kỳ", kể cả 0 giờ), Q-253.
-- Làm gì: (1) tình trạng ghi danh trống hoặc "Đã xếp lớp" không còn làm hỏng dòng; (2) giờ còn lại âm bị chặn; (3) nạp thật ghi danh còn một dòng lỗi
-- thì chặn cả loại ngay trong hàm (trước đây chỉ khoá nút ở giao diện); (4) giờ còn lại bằng 0 vẫn sinh dòng "Số dư đầu kỳ" (nới ràng buộc sổ giờ
-- chỉ cho loại DAU_KY; các loại dòng khác vẫn cấm 0 giờ).
-- Không thêm bảng hay chỉ mục.
select set_config('hmt.migration', 'on', false);

-- Sổ giờ: dòng Số dư đầu kỳ được phép 0 giờ (Q-177); mọi loại khác vẫn khác 0 (R-GD-04).
alter table app.hour_ledger drop constraint hour_ledger_hours_check;
alter table app.hour_ledger add constraint hour_ledger_hours_check check (hours <> 0 or entry_type = 'DAU_KY');

-- app.add_opening_hours: như bản D1e nhưng ghi cả dòng 0 giờ (chỉ bỏ qua khi không có số giờ).
create or replace function app.add_opening_hours(p_enrollment_id uuid, p_hours numeric, p_source_ref text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  if p_hours is null then
    return;
  end if;
  insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref, entry_date)
  values (e.id, e.branch_id, 'DAU_KY', p_hours, p_source_ref, app.get_setting('opening_balance_date')::date);
end;
$$;
revoke execute on function app.add_opening_hours(uuid, numeric, text) from public, anon, authenticated;

create or replace function app.import_one_enrollment(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_ref text := app.import_txt(p_row, 'hoc_sinh_ma_cu');
  v_class_ref text := app.import_txt(p_row, 'ma_lop_cu');
  v_legacy text;
  v_existing text;
  st app.student;
  c app.class;
  v_status text;
  v_start date;
  v_planned numeric;
  v_studied numeric;
  v_remaining numeric;
  v_hours numeric;
  v_id uuid;
  v_code text;
  v_warnings jsonb := '[]'::jsonb;
begin
  if v_student_ref is null or v_class_ref is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu cột hoc_sinh_ma_cu hoặc ma_lop_cu.');
  end if;
  v_legacy := v_student_ref || '|' || v_class_ref;
  select code into v_existing from app.enrollment where legacy_ref = v_legacy limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'message', null, 'warnings', '[]'::jsonb);
  end if;
  select * into st from app.student where legacy_ref = v_student_ref order by created_at, id limit 1;
  if st.id is null then
    perform app.raise_error('HMT_NAP_HOC_SINH_CHUA_CO', 'Không tìm thấy học sinh theo hoc_sinh_ma_cu. Nạp tab Học sinh trước.');
  end if;
  select * into c from app.class where legacy_ref = v_class_ref limit 1;
  if c.id is null then
    perform app.raise_error('HMT_NAP_LOP_CHUA_CO', 'Không tìm thấy lớp theo ma_lop_cu. Nạp tab Lớp trước.');
  end if;
  if st.branch_id is distinct from c.branch_id then
    perform app.raise_error('HMT_NAP_KHAC_CO_SO', 'Học sinh và lớp thuộc hai cơ sở khác nhau.');
  end if;
  -- Luật (anh duyệt mặc định H1, 15/11): tình trạng trống thì Chờ xếp lớp; "Đã xếp lớp" (có trong danh mục, mã DA_XEP_LOP) được đổi sang
  -- trạng thái cuối vì ghi danh nạp thẳng trạng thái đang học: Đang học nếu có ngày vào lớp, không thì Chờ xếp lớp. Báo cảnh báo để Admin biết.
  if app.import_txt(p_row, 'tinh_trang_moi') is null then
    v_status := 'CHO_XEP_LOP';
    v_warnings := v_warnings || to_jsonb('Tình trạng trống: đặt Chờ xếp lớp.'::text);
  elsif app.fold_text(app.import_txt(p_row, 'tinh_trang_moi')) = 'da xep lop' then
    v_status := case when app.import_txt(p_row, 'ngay_vao_lop') is not null then 'DANG_HOC' else 'CHO_XEP_LOP' end;
    v_warnings := v_warnings || to_jsonb('Tình trạng "Đã xếp lớp" đổi thành tình trạng có trong danh mục.'::text);
  else
    v_status := app.import_match_catalog('ENROLLMENT_STATUS', app.import_txt(p_row, 'tinh_trang_moi'));
  end if;
  if v_status is null then
    perform app.raise_error('HMT_NAP_TINH_TRANG_SAI', 'Cột tinh_trang_moi không đúng tình trạng ghi danh trong danh mục (ví dụ Đang học).');
  end if;
  v_planned := app.import_num(p_row, 'gio_du_kien');
  v_studied := app.import_num(p_row, 'gio_da_hoc');
  v_remaining := app.import_num(p_row, 'gio_con_lai');
  -- Luật Q-253 (H6 mặc định): giờ còn lại không âm; học vượt giờ đã mua phải xử lý ở file nguồn trước khi nạp.
  if v_remaining < 0 then
    perform app.raise_error('HMT_NAP_GIO_AM', 'Giờ còn lại không được âm. Sửa số dư trong file nguồn rồi nạp lại.');
  end if;
  -- Luật R-V2-32: số dư giờ phải khớp dự kiến trừ đã học (sai lệch tối đa 0,01 giờ do làm tròn).
  if abs(v_remaining - (v_planned - v_studied)) > 0.01 then -- allow-number: sai số làm tròn của giờ học
    perform app.raise_error('HMT_NAP_GIO_LECH', 'Giờ còn lại phải bằng giờ dự kiến trừ giờ đã học.');
  end if;
  v_hours := app.import_num(p_row, 'thoi_luong_buoi');
  v_start := app.import_date(p_row, 'ngay_vao_lop', v_status in ('DANG_HOC', 'BAO_LUU'));
  v_code := app.issue_enrollment_code();
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code, start_date, legacy_ref)
  values (v_code, st.id, st.parent_id, c.branch_id, c.subject_code, v_status, v_start, v_legacy)
  returning id into v_id;
  -- Tình trạng đang học, bảo lưu: có dòng xếp lớp đang mở (ngày vào lớp). Tình trạng khác: chỉ ghi danh, không xếp lớp.
  if v_status in ('DANG_HOC', 'BAO_LUU') then
    insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (v_id, c.id, c.branch_id, v_start);
  end if;
  -- Dòng Số dư đầu kỳ, mỗi ghi danh một dòng (R-V2-33). Số dư âm là học trước, vẫn nạp.
  perform app.add_opening_hours(v_id, v_remaining, 'NAP-' || to_char(now(), 'YYYYMMDD'));
  insert into app.legacy_enrollment_check (enrollment_id, branch_id, class_id, student_id, student_legacy_ref, class_legacy_ref, session_hours,
                                           studied_before_hours, planned_hours, studied_hours, remaining_hours, source_tab, source_row)
  values (v_id, c.branch_id, c.id, st.id, v_student_ref, v_class_ref, v_hours, coalesce(app.import_num(p_row, 'gio_da_hoc_cu', false), 0),
          v_planned, v_studied, v_remaining, app.import_txt(p_row, 'nguon_tab'), nullif(app.import_txt(p_row, 'nguon_dong'), '')::integer);
  if v_status in ('DANG_HOC', 'BAO_LUU') and c.status_code <> 'DA_DUYET' then
    v_warnings := v_warnings || to_jsonb('Lớp đã đóng nhưng ghi danh còn đang học.'::text);
  end if;
  return jsonb_build_object('status', 'HOP_LE', 'code', v_code, 'message', null, 'warnings', v_warnings);
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
  if p_kind not in ('LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH') then
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
                             when 'BUOI_HOC' then app.import_one_legacy_session(v_row) else app.import_one_legacy_attendance(v_row) end;
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
                                                   'error_code', v_hint, 'message', v_msg);
      end;
    end loop;
    -- Luật R-V2-30: ghi danh: một dòng lỗi thì chặn cả loại, kể cả khi gọi thẳng hàm (không chỉ nút ở giao diện).
    v_blocked := p_commit and p_kind = 'GHI_DANH' and v_err > 0;
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

revoke execute on function app.import_one_enrollment(jsonb), app.import_training_records(text, jsonb, boolean, text) from public, anon, authenticated;
grant execute on function app.import_training_records(text, jsonb, boolean, text) to authenticated;

select set_config('hmt.migration', '', false);
