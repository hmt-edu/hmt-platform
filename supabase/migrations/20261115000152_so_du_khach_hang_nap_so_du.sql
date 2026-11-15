-- Code B (15/11/2026), nạp dữ liệu CS5, bước 3: Sổ số dư khách hàng và nạp Số dư tiền (tab 09_SODU).
-- Luật: R-TIEN-33 (sổ số dư của phụ huynh, chỉ thêm dòng, không sửa, không xoá), R-V2-32 (chỉ nạp số dư đầu kỳ: công nợ phải thu là SỐ ÂM trong sổ,
-- tiền thu thừa là số dương; tiền trong file đã tính bằng đồng), R-V2-30 (một dòng lỗi chặn cả loại, trùng mã cũ thì bỏ qua), Q-227 (ngày 17/11 chỉ nạp giờ:
-- loại này chỉ chạy khi anh Trường cho, không có nút nào tự bật nó). Quyết định mặc định H4 (code-b.md, chờ anh): sổ theo phụ huynh, giữ học sinh ở từng dòng.
-- Làm gì: bảng app.customer_balance_entry; hàm app.import_one_balance(hàng); hàm nạp chung nhận loại SO_DU (một dòng lỗi chặn cả loại); báo cáo đối soát thêm số tiền ở migration 154.
-- Phiếu "Thu nợ đầu kỳ" (R-V2-15) KHÔNG nằm ở đây: làm ở cụm Thu chi (B2).
select set_config('hmt.migration', 'on', false);

-- Nhật ký nạp nhận loại SO_DU.
alter table app.import_log drop constraint import_log_kind_check;
alter table app.import_log add constraint import_log_kind_check
  check (kind in ('PHU_HUYNH', 'HOC_SINH', 'NGUOI_DUNG', 'CO_HOI', 'LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH', 'PHIEU_TEST', 'SO_DU'));


create table app.customer_balance_entry (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  parent_id uuid not null references app.parent (id),
  student_id uuid references app.student (id),
  branch_id uuid not null references app.branch (id),
  -- DAU_KY_THU_THUA: tiền khách đóng thừa (dương); DAU_KY_CONG_NO: công nợ phải thu đầu kỳ (âm).
  entry_type text not null check (entry_type in ('DAU_KY_THU_THUA', 'DAU_KY_CONG_NO')),
  amount bigint not null check (amount <> 0),
  entry_date date not null,
  source_ref text,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((entry_type = 'DAU_KY_THU_THUA' and amount > 0) or (entry_type = 'DAU_KY_CONG_NO' and amount < 0))
);
comment on table app.customer_balance_entry is 'Sổ số dư khách hàng (của phụ huynh), chỉ thêm dòng (R-TIEN-33). Số dương: tiền thu thừa; số âm: công nợ phải thu đầu kỳ (R-V2-32). Tiền bằng đồng.';
-- Chỉ mục (lý do): số dư của một phụ huynh theo thứ tự ghi (màn khách hàng, "Dùng số dư"); học sinh và cơ sở là khoá ngoại và cột trong chính sách đọc.
create index customer_balance_parent_idx on app.customer_balance_entry (parent_id, seq);
create index customer_balance_student_idx on app.customer_balance_entry (student_id) where student_id is not null;
create index customer_balance_branch_idx on app.customer_balance_entry (branch_id);
select app.apply_standard('app.customer_balance_entry');

-- Luật R-TIEN-33: sổ chỉ thêm, không sửa (apply_standard đã chặn xoá).
create or replace function app.tg_customer_balance_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_SO_DU_CHI_THEM', 'Sổ số dư khách hàng chỉ thêm dòng, không sửa. Điều chỉnh bằng dòng ngược dấu.');
  return null;
end;
$$;
create trigger customer_balance_no_update before update on app.customer_balance_entry
  for each row execute function app.tg_customer_balance_append_only();

-- RLS (bật cho mọi bảng): giai đoạn nạp chỉ Admin đọc; màn khách hàng đọc qua hàm riêng ở cụm Thu chi.
alter table app.customer_balance_entry enable row level security;
revoke all on app.customer_balance_entry from public, anon, authenticated;
grant select on app.customer_balance_entry to authenticated;
create policy customer_balance_admin_read on app.customer_balance_entry for select to authenticated
  using ((select app.has_permission('ADMIN', 'TAO')));

-- Số nguyên đồng không âm từ một ô; sai dạng hoặc có phần lẻ thì báo lỗi nêu tên cột (không in giá trị).
create or replace function app.import_money(p_row jsonb, p_key text)
returns bigint
language plpgsql
immutable
set search_path = ''
as $$
declare
  v numeric := app.import_num(p_row, p_key, false);
begin
  if v is null then
    return 0;
  end if;
  if v < 0 or v <> trunc(v) then
    perform app.raise_error('HMT_NAP_TIEN_SAI', format('Cột %s phải là số tiền đồng nguyên, từ 0 trở lên.', p_key));
  end if;
  return v::bigint;
end;
$$;

-- app.import_one_balance(hàng): một hàng 09_SODU.
-- Cột nhận: hoc_sinh_ma_cu, cong_no_phai_thu_dong, tien_thu_thua_dong, ngay_chot (không bắt buộc: lấy tham số opening_balance_date nếu trống).
-- Cột khác (giờ, tong_hoc_phi_dong, da_thanh_toan_dong, hoc_phi_con_du_dong...) bỏ qua: giờ nạp ở Ghi danh (Q-227), hoc_phi_con_du_dong đã nằm trong tien_thu_thua_dong.
-- Luật: học sinh phải có (nạp Học sinh trước); trùng mã học sinh cũ đã có dòng số dư thì TRUNG (R-V2-30); công nợ ghi số âm, thu thừa số dương (R-V2-32);
-- cả hai đều lớn hơn 0 thì nạp cả hai kèm cảnh báo; cả hai bằng 0 thì không ghi dòng nào, kèm cảnh báo.
create or replace function app.import_one_balance(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ref text := app.import_txt(p_row, 'hoc_sinh_ma_cu');
  v_debt bigint := app.import_money(p_row, 'cong_no_phai_thu_dong');
  v_credit bigint := app.import_money(p_row, 'tien_thu_thua_dong');
  v_date date := coalesce(app.import_date(p_row, 'ngay_chot', false), app.get_setting('opening_balance_date')::date);
  st app.student;
  v_warnings jsonb := '[]'::jsonb;
begin
  if v_ref is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột hoc_sinh_ma_cu.');
  end if;
  select * into st from app.student where legacy_ref = v_ref order by created_at, id limit 1;
  if st.id is null then
    perform app.raise_error('HMT_NAP_HOC_SINH_CHUA_CO', 'Không tìm thấy học sinh theo hoc_sinh_ma_cu. Nạp tab Học sinh trước.');
  end if;
  -- Luật R-V2-30: trùng thì bỏ qua, không ghi đè.
  if exists (select from app.customer_balance_entry where legacy_ref = v_ref) then
    return jsonb_build_object('status', 'TRUNG', 'code', null, 'message', null, 'warnings', '[]'::jsonb);
  end if;
  if v_debt = 0 and v_credit = 0 then
    return jsonb_build_object('status', 'HOP_LE', 'code', null, 'message', null,
                              'warnings', to_jsonb(array['Không có công nợ hay tiền thu thừa: không ghi dòng nào.']));
  end if;
  if v_debt > 0 and v_credit > 0 then
    v_warnings := v_warnings || to_jsonb('Vừa có công nợ vừa có tiền thu thừa: kiểm lại file nguồn kẻo cộng trùng.'::text);
  end if;
  -- Luật R-V2-32: công nợ đầu kỳ là số âm, tiền thu thừa là số dương.
  if v_debt > 0 then
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref, legacy_ref)
    values (st.parent_id, st.id, st.branch_id, 'DAU_KY_CONG_NO', -v_debt, v_date, 'NAP-' || to_char(now(), 'YYYYMMDD'), v_ref);
  end if;
  if v_credit > 0 then
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref, legacy_ref)
    values (st.parent_id, st.id, st.branch_id, 'DAU_KY_THU_THUA', v_credit, v_date, 'NAP-' || to_char(now(), 'YYYYMMDD'), v_ref);
  end if;
  return jsonb_build_object('status', 'HOP_LE', 'code', null, 'message', null, 'warnings', v_warnings);
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
                                                   'error_code', v_hint, 'message', v_msg);
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
revoke execute on function app.import_money(jsonb, text), app.import_one_balance(jsonb), app.import_training_records(text, jsonb, boolean, text) from public, anon, authenticated;
grant execute on function app.import_training_records(text, jsonb, boolean, text) to authenticated;

select set_config('hmt.migration', '', false);
