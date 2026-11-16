-- Code B (15/11/2026), nạp dữ liệu CS5, bước 2: nạp Phiếu test cũ (tab 06_PHIEUTEST).
-- Luật: R-V2-29 (Phiếu test nạp sau Cơ hội), R-V2-30 (nhóm CRM: dòng lỗi không chặn dòng đúng; trùng mã cũ thì bỏ qua), R-V2-31 (phiếu cũ đã xong:
-- trạng thái "Hoàn thành (dữ liệu cũ)", giữ điểm cũ, không bắt trình độ hay xếp loại). Quyết định mặc định H5 (code-b.md, chờ anh): hình thức test
-- OFFLINE và cấp độ đề CO_BAN chỉ là giá trị giữ chỗ vì cột bắt buộc, script không có hai thông tin này.
-- Làm gì: thêm trạng thái danh mục COMPLETED_LEGACY; hàm app.import_one_student_test(hàng); hàm nạp chung app.import_training_records nhận thêm loại PHIEU_TEST.
-- Chỉ mục: không thêm (đã có chỉ mục legacy_ref).
select set_config('hmt.migration', 'on', false);

-- Nhật ký nạp nhận loại PHIEU_TEST.
alter table app.import_log drop constraint import_log_kind_check;
alter table app.import_log add constraint import_log_kind_check
  check (kind in ('PHU_HUYNH', 'HOC_SINH', 'NGUOI_DUNG', 'CO_HOI', 'LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH', 'PHIEU_TEST'));


-- Trạng thái "Hoàn thành (dữ liệu cũ)": thêm vào danh mục và vào ràng buộc cột trạng thái của phiếu.
-- Trạng thái Ngừng (is_active = false): người dùng không chọn được và Kanban (chỉ lấy trạng thái đang dùng) không thêm cột; tên vẫn hiện ở danh sách và hồ sơ.
insert into app.catalog_item (catalog_code, code, name, sort_order, is_active)
values ('TEST_STATUS', 'COMPLETED_LEGACY', 'Hoàn thành (dữ liệu cũ)', 7, false);
alter table app.student_test drop constraint student_test_status_code_check;
alter table app.student_test add constraint student_test_status_code_check
  check (status_code in ('DRAFT', 'TESTING', 'TEACHER_REVIEW', 'COMPLETED', 'CANCELLED', 'COMPLETED_LEGACY'));
-- Tra trùng theo mã cũ dùng chỉ mục student_test_legacy_ref_idx có sẵn (app.apply_standard tạo cho cột legacy_ref).

-- app.import_one_student_test(hàng): một hàng 06_PHIEUTEST.
-- Cột nhận: ma_cu, sdt_ph, sdt_2, ngay_test (yyyy-mm-dd), gio_test (hh:mm), ho_ten_hs, khoi, mon, diem, trang_thai_phieu, ly_do_huy, ghi_chu.
-- Cột khác của script (co_hoi_tim_thay, giai_doan_co_hoi_moi, gv_cham, nguoi_hen...) bỏ qua; không lưu tên giáo viên chấm (Q: chỉ để đối chiếu).
-- Luật: trùng mã cũ thì TRUNG; phiếu gắn vào cơ hội có mã cũ = SĐT phụ huynh (nạp Cơ hội trước), không có cơ hội thì LỖI (tạo cơ hội từ phiếu: chờ anh, HOI-ANH H7);
-- học sinh tìm theo phụ huynh của cơ hội và tên chuẩn hoá (cơ hội không còn cột học sinh) (nạp Học sinh trước). Trạng thái: Hoàn thành có điểm → COMPLETED_LEGACY (không đặt trình độ, xếp loại);
-- Hoàn thành không điểm → Chờ giáo viên chấm; Huỷ cần lý do có trong danh mục; trống → Nháp kèm cảnh báo. Ghi thẳng bảng (cố ý bỏ qua luật giờ test tương lai).
create or replace function app.import_one_student_test(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_legacy text := app.import_txt(p_row, 'ma_cu');
  v_existing text;
  v_phone text;
  v_phone2 text;
  v_opp app.opportunity;
  v_student uuid;
  v_prospect uuid;
  v_name text := app.import_txt(p_row, 'ho_ten_hs');
  v_date date := app.import_date(p_row, 'ngay_test');
  v_time text := app.import_txt(p_row, 'gio_test');
  v_subject text;
  v_grade text;
  v_score numeric;
  v_state text := app.fold_text(coalesce(app.import_txt(p_row, 'trang_thai_phieu'), ''));
  v_status text;
  v_cancel text;
  v_warnings jsonb := '[]'::jsonb;
  v_code text;
begin
  if v_legacy is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột ma_cu.');
  end if;
  -- Luật R-V2-30: trùng mã cũ thì bỏ qua, không ghi đè.
  select code into v_existing from app.student_test where legacy_ref = v_legacy limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'message', null, 'warnings', '[]'::jsonb);
  end if;
  if v_name is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột ho_ten_hs.');
  end if;
  if v_time is not null and v_time !~ '^[0-9]{1,2}:[0-9]{2}$' then
    perform app.raise_error('HMT_NAP_GIO_SAI', 'Cột gio_test phải có dạng hh:mm, ví dụ 17:30.');
  end if;
  -- Cơ hội: mã cũ của cơ hội là số điện thoại phụ huynh (số chính, không thấy thì số thứ hai).
  v_phone := app.import_phone(p_row ->> 'sdt_ph', true);
  v_phone2 := app.import_phone(p_row ->> 'sdt_2', false);
  select * into v_opp from app.opportunity where legacy_ref = v_phone order by created_at, id limit 1;
  if v_opp.id is null and v_phone2 is not null then
    select * into v_opp from app.opportunity where legacy_ref = v_phone2 order by created_at, id limit 1;
  end if;
  if v_opp.id is null then
    perform app.raise_error('HMT_NAP_CO_HOI_CHUA_CO', 'Không tìm thấy cơ hội theo số điện thoại. Nạp tab Cơ hội trước.');
  end if;
  -- Học sinh: cùng phụ huynh của cơ hội và cùng tên chuẩn hoá.
  -- Phiếu gắn vào em trong danh sách em của cơ hội (cột prospect_student_id bắt buộc), tên chuẩn hoá khớp ho_ten_hs.
  select v.id, v.student_id into v_prospect, v_student from app.prospect_student_v v
   where v.opportunity_id = v_opp.id and app.normalize_person_name(v.full_name) = app.normalize_person_name(v_name)
   order by v.position limit 1;
  if v_prospect is null then
    perform app.raise_error('HMT_NAP_EM_CHUA_CO', 'Tên học sinh của phiếu không có trong danh sách em của cơ hội.');
  end if;
  if v_student is null then
    select id into v_student from app.student
     where parent_id = v_opp.parent_id and app.normalize_person_name(full_name) = app.normalize_person_name(v_name)
     order by created_at, id limit 1;
  end if;
  if v_student is null then
    perform app.raise_error('HMT_NAP_HOC_SINH_CHUA_CO', 'Không tìm thấy học sinh của phiếu trong hồ sơ phụ huynh. Nạp tab Học sinh trước.');
  end if;
  v_subject := app.import_match_catalog('SUBJECT', coalesce(app.import_txt(p_row, 'mon'), 'Toán'));
  if v_subject is null then
    perform app.raise_error('HMT_NAP_MON_SAI', 'Cột mon không có trong danh mục môn.');
  end if;
  if app.import_txt(p_row, 'khoi') !~ '^[0-9]{1,2}$' then
    perform app.raise_error('HMT_NAP_KHOI_SAI', 'Cột khoi phải là số khối, ví dụ 6.');
  end if;
  v_grade := 'K' || lpad(app.import_txt(p_row, 'khoi'), 2, '0'); -- allow-number: độ rộng 2 chữ số của mã khối
  if not exists (select from app.catalog_item where catalog_code = 'GRADE' and code = v_grade and is_active) then
    perform app.raise_error('HMT_NAP_KHOI_SAI', 'Khối không có trong danh mục khối.');
  end if;
  v_score := app.import_num(p_row, 'diem', false);
  if v_score is not null and (v_score < 0 or v_score > 10) then -- allow-number: thang điểm 0 đến 10 của R-CRM-10
    perform app.raise_error('HMT_NAP_SO_SAI', 'Cột diem phải từ 0 đến 10.');
  end if;
  -- Trạng thái (R-V2-31).
  if v_state = '' then
    v_status := 'DRAFT';
    v_warnings := v_warnings || to_jsonb('Trạng thái phiếu trống: đặt Nháp.'::text);
  elsif v_state like 'hoan thanh%' then
    v_status := case when v_score is null then 'TEACHER_REVIEW' else 'COMPLETED_LEGACY' end;
  elsif v_state like 'cho gv%' or v_state like 'cho giao vien%' then
    v_status := 'TEACHER_REVIEW';
  elsif v_state like 'huy%' then
    v_status := 'CANCELLED';
    -- Ô trống không được khớp với mục danh mục nào (hàm tra khớp coi chữ rỗng bằng mã cũ rỗng).
    if app.import_txt(p_row, 'ly_do_huy') is not null then
      v_cancel := app.import_match_catalog('TEST_CANCEL_REASON', app.import_txt(p_row, 'ly_do_huy'));
    end if;
    if v_cancel is null then
      perform app.raise_error('HMT_NAP_LY_DO_HUY_SAI', 'Phiếu huỷ cần cột ly_do_huy có trong danh mục lý do huỷ test.');
    end if;
  elsif v_state like 'nhap%' then
    v_status := 'DRAFT';
  else
    perform app.raise_error('HMT_NAP_TINH_TRANG_SAI', 'Cột trang_thai_phieu không đúng (Nháp, Hoàn thành, Chờ GV chấm, Huỷ).');
  end if;
  v_code := app.issue_crm_code('PKT');
  insert into app.student_test (code, opportunity_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code, grade_code, mode_code,
                                level_code, scheduled_at, owner_id, prospect_student_id, status_code, cancel_reason_code, cancelled_at, completed_at, score, result_note, legacy_ref)
  values (v_code, v_opp.id, v_student, v_opp.branch_id, v_opp.branch_id, v_opp.branch_id, v_subject, v_grade, 'OFFLINE', 'CO_BAN',
          (v_date::text || ' ' || coalesce(v_time, '00:00'))::timestamp at time zone 'Asia/Ho_Chi_Minh', v_opp.owner_id, v_prospect, v_status, v_cancel,
          case when v_status = 'CANCELLED' then now() end, case when v_status = 'COMPLETED_LEGACY' then now() end, v_score,
          app.import_txt(p_row, 'ghi_chu'), v_legacy);
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
  if p_kind not in ('LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH', 'PHIEU_TEST') then
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
                             when 'BUOI_HOC' then app.import_one_legacy_session(v_row) when 'PHIEU_TEST' then app.import_one_student_test(v_row) else app.import_one_legacy_attendance(v_row) end;
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
revoke execute on function app.import_one_student_test(jsonb), app.import_training_records(text, jsonb, boolean, text) from public, anon, authenticated;
grant execute on function app.import_training_records(text, jsonb, boolean, text) to authenticated;

select set_config('hmt.migration', '', false);
