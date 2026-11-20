-- KH-07 Gộp phụ huynh, học sinh (anh Trường chốt 20/11/2026): R-CRM-25.
-- Gộp chuyển TOÀN BỘ dữ liệu có khoá phụ huynh hoặc học sinh sang hồ sơ giữ lại, kể cả tiền; trong cùng giao dịch kiểm tổng
-- số dư, công nợ, tiền, giờ trước = sau, lệch thì huỷ gộp. Chặn khi hai học sinh cùng có ghi danh còn hiệu lực ở cùng một lớp hoặc
-- đang học hai lớp trùng giờ. Rủi ro CAO (tiền, điểm danh).
-- Phần này: hàm chuyển, hàm kiểm tổng, điều kiện chặn, vá trigger sổ số dư; hộp so sánh (candidates/side/items) làm ở migration sau.

-- ---------------------------------------------------------------------------
-- 1. Sổ số dư khách hàng chỉ-thêm: cho phép DUY NHẤT việc đổi parent_id / student_id khi đang gộp hồ sơ (cờ giao dịch hmt.merge = on).
--    Mọi trường khác vẫn không sửa được; ngoài lúc gộp vẫn chặn như cũ (Luật: sổ chỉ thêm, điều chỉnh bằng dòng ngược dấu).
-- ---------------------------------------------------------------------------
create or replace function app.tg_customer_balance_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' and coalesce(current_setting('hmt.merge', true), '') = 'on'
     and (to_jsonb(new) - 'parent_id' - 'student_id' - 'updated_at' - 'updated_by')
         = (to_jsonb(old) - 'parent_id' - 'student_id' - 'updated_at' - 'updated_by') then
    return new;
  end if;
  perform app.raise_error('HMT_SO_DU_CHI_THEM', 'Sổ số dư khách hàng chỉ thêm dòng, không sửa. Điều chỉnh bằng dòng ngược dấu.');
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. app.merge_totals(loại, danh sách id): các tổng cần giữ nguyên khi gộp (số dư, tiền, giờ, số chứng từ).
--    Gọi nội bộ (không cấp cho giao diện). Phụ huynh: sổ số dư, đơn, phiếu thu, tiền vào, phiếu chi, giờ còn theo ghi danh.
--    Học sinh: sổ số dư theo em, ghi danh, giờ theo sổ giờ, dòng đơn, phiếu thu nợ đầu kỳ theo em, hoàn phí.
-- ---------------------------------------------------------------------------
create or replace function app.merge_totals(p_entity text, p_ids uuid[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_entity = 'PARENT' then
    return jsonb_build_object(
      'balance', (select coalesce(sum(amount), 0) from app.customer_balance_entry where parent_id = any (p_ids)),
      'orders_n', (select count(*) from app.sales_order where parent_id = any (p_ids)),
      'orders_total', (select coalesce(sum(total_amount), 0) from app.sales_order where parent_id = any (p_ids)),
      'receipts_n', (select count(*) from app.receipt where parent_id = any (p_ids)),
      'receipts_total', (select coalesce(sum(amount), 0) from app.receipt where parent_id = any (p_ids)),
      'money_in_total', (select coalesce(sum(amount), 0) from app.money_in where parent_id = any (p_ids)),
      'vouchers_total', (select coalesce(sum(amount), 0) from app.payment_voucher where parent_id = any (p_ids)),
      'enrollments_n', (select count(*) from app.enrollment where parent_id = any (p_ids)),
      'hours', (select coalesce(sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id where e.parent_id = any (p_ids)));
  end if;
  return jsonb_build_object(
    'balance', (select coalesce(sum(amount), 0) from app.customer_balance_entry where student_id = any (p_ids)),
    'enrollments_n', (select count(*) from app.enrollment where student_id = any (p_ids)),
    'hours', (select coalesce(sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id where e.student_id = any (p_ids)),
    'order_lines_n', (select count(*) from app.sales_order_line where student_id = any (p_ids)),
    'opening_receipts_total', (select coalesce(sum(amount), 0) from app.receipt where opening_debt_student_id = any (p_ids)),
    'opening_money_in_total', (select coalesce(sum(amount), 0) from app.money_in where opening_debt_student_id = any (p_ids)),
    'refunds_total', (select coalesce(sum(refund_amount), 0) from app.refund_request where student_id = any (p_ids)),
    'attendance_n', (select count(*) from app.session_attendance where student_id = any (p_ids)));
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. app.merge_move_refs(loại, giữ, bị gộp): chuyển mọi dòng đang trỏ hồ sơ bị gộp sang hồ sơ giữ lại.
--    SQL ĐỘNG CÓ CHỦ ĐÍCH (CLAUDE.md, mục 6): danh sách bảng đọc từ pg_constraint (mọi khoá ngoại một cột trỏ app.parent hoặc
--    app.student, trừ merged_into_id) để bảng thêm về sau tự được chuyển, không sót; tên bảng, cột lấy từ catalog và đi qua %I.
--    Lead đã huỷ (DA_HUY) chỉ xem được, không chuyển. Vi phạm ràng buộc duy nhất giữa hai hồ sơ: dừng, nêu bảng (HMT_GOP_XUNG_DOT).
--    Trong lúc chuyển bật cờ giao dịch hmt.migration, hmt.merge (chỉ tới hết hàm) để các trigger khoá chứng từ, sổ chỉ-thêm cho phép
--    đúng việc đổi khoá hồ sơ; không đổi trường nào khác. Kết quả: {tên bảng: số dòng chuyển} (chỉ bảng có dòng chuyển).
-- ---------------------------------------------------------------------------
create or replace function app.merge_move_refs(p_entity text, p_keep uuid, p_merge uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_target regclass := case p_entity when 'PARENT' then 'app.parent'::regclass else 'app.student'::regclass end;
  v_n integer;
  v_result jsonb := '{}'::jsonb;
  v_prev_mig text := coalesce(current_setting('hmt.migration', true), '');
  v_prev_merge text := coalesce(current_setting('hmt.merge', true), '');
  v_extra text;
begin
  if p_entity not in ('PARENT', 'STUDENT') then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chỉ chuyển dữ liệu khi gộp phụ huynh, học sinh.');
  end if;
  perform set_config('hmt.migration', 'on', true);
  perform set_config('hmt.merge', 'on', true);
  for r in
    select c.conrelid::regclass as tbl, c.conrelid as tbl_oid, a.attname as col
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and c.confrelid = v_target and array_length(c.conkey, 1) = 1
       and a.attname <> 'merged_into_id'
       and c.connamespace = 'app'::regnamespace
     order by c.conrelid::regclass::text, a.attname
  loop
    v_extra := case when r.tbl = 'app.lead'::regclass then ' and record_status <> ''DA_HUY''' else '' end;
    begin
      execute format('update %s set %I = $1 where %I = $2%s', r.tbl, r.col, r.col, v_extra) using p_keep, p_merge;
      get diagnostics v_n = row_count;
    exception when unique_violation then
      perform app.raise_error('HMT_GOP_XUNG_DOT',
        format('Không gộp được: dữ liệu ở bảng %s của hai hồ sơ bị trùng nhau, cần xử lý tay trước.', r.tbl::text));
    end;
    if v_n > 0 then
      v_result := v_result || jsonb_build_object(r.tbl::text || '.' || r.col, v_n);
    end if;
  end loop;
  perform set_config('hmt.migration', v_prev_mig, true);
  perform set_config('hmt.merge', v_prev_merge, true);
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. app.merge_assert_totals(loại, giữ, bị gộp, tổng trước): so tổng sau gộp với tổng hai hồ sơ trước gộp; lệch thì dừng cả giao dịch.
-- ---------------------------------------------------------------------------
create or replace function app.merge_assert_totals(p_entity text, p_keep uuid, p_before jsonb)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_after jsonb := app.merge_totals(p_entity, array[p_keep]);
begin
  if v_after is distinct from p_before then
    perform app.raise_error('HMT_GOP_LECH_TIEN', 'Gộp bị huỷ: tổng số dư, tiền hoặc giờ trước và sau khi gộp không bằng nhau.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Điều kiện chặn gộp HỌC SINH (R-CRM-25, anh chốt 20/11): (a) cùng ghi danh còn hiệu lực ở cùng một lớp;
--    (b) đang học hai lớp khác nhau có khung giờ trùng (cùng thứ trong tuần, giờ giao nhau; bỏ qua chu kỳ lặp tuần).
--    Khác phụ huynh vẫn chặn như cũ (gộp phụ huynh trước).
-- ---------------------------------------------------------------------------
create or replace function app.merge_check_students(p_keep uuid, p_merge uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_same boolean;
  v_blockers jsonb := '[]'::jsonb;
  v_same_class text;
  v_clash text;
begin
  select k.parent_id = m.parent_id into v_same from app.student k, app.student m where k.id = p_keep and m.id = p_merge;
  if not coalesce(v_same, false) then
    v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code', 'HMT_GOP_KHAC_PHU_HUYNH',
                    'message', 'Hai học sinh khác phụ huynh: gộp phụ huynh trước.'));
  end if;

  -- (a) Cùng ghi danh còn hiệu lực ở cùng một lớp.
  select string_agg(distinct c.code, ', ' order by c.code) into v_same_class
    from app.enrollment e1
    join app.enrollment_class ec1 on ec1.enrollment_id = e1.id and ec1.end_date is null
    join app.class c on c.id = ec1.class_id
    join app.enrollment_class ec2 on ec2.class_id = ec1.class_id and ec2.end_date is null
    join app.enrollment e2 on e2.id = ec2.enrollment_id
   where e1.student_id = p_keep and e2.student_id = p_merge
     and e1.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC') and e2.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC');
  if v_same_class is not null then
    v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code', 'HMT_GOP_CUNG_LOP',
                    'message', format('Hai học sinh cùng có ghi danh còn hiệu lực ở lớp %s: xử lý ghi danh trước khi gộp.', v_same_class)));
  end if;

  -- (b) Hai lớp khác nhau đang học có khung giờ trùng.
  select string_agg(distinct c1.code || ' và ' || c2.code, '; ' order by c1.code || ' và ' || c2.code) into v_clash
    from app.enrollment e1
    join app.enrollment_class ec1 on ec1.enrollment_id = e1.id and ec1.end_date is null
    join app.class c1 on c1.id = ec1.class_id
    join app.class_slot s1 on s1.class_id = c1.id and s1.is_active
    join app.enrollment e2 on e2.student_id = p_merge and e2.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')
    join app.enrollment_class ec2 on ec2.enrollment_id = e2.id and ec2.end_date is null and ec2.class_id <> ec1.class_id
    join app.class c2 on c2.id = ec2.class_id
    join app.class_slot s2 on s2.class_id = c2.id and s2.is_active
   where e1.student_id = p_keep and e1.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')
     and s1.weekday = s2.weekday and s1.start_time < s2.end_time and s2.start_time < s1.end_time;
  if v_clash is not null then
    v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code', 'HMT_GOP_TRUNG_GIO',
                    'message', format('Hai học sinh đang học hai lớp trùng giờ (%s): xử lý ghi danh trước khi gộp.', v_clash)));
  end if;

  return jsonb_build_object('blockers', v_blockers, 'warnings', '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Gộp HỌC SINH: chuyển toàn bộ dữ liệu có khoá học sinh (danh sách em, phiếu kiểm tra, ghi danh, sổ số dư, điểm danh, BTVN...),
--    kiểm tổng, ghi chú, bản bị gộp thành Đã gộp. Kết quả: {keep_code, merge_code, moved, tables}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_students(p_keep uuid, p_merge uuid, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info jsonb := app.merge_common('STUDENT', p_keep, p_merge, true);
  m app.student;
  v_before jsonb;
  v_tables jsonb;
  v_notes integer;
begin
  perform app.merge_raise_first_blocker(app.merge_check_students(p_keep, p_merge));
  perform app.merge_require_confirm(p_confirm);
  select * into m from app.student where id = p_merge;
  -- Luật anh chốt 20/11: tổng trước = tổng sau trong cùng giao dịch.
  v_before := app.merge_totals('STUDENT', array[p_keep, p_merge]);
  v_tables := app.merge_move_refs('STUDENT', p_keep, p_merge);
  perform app.merge_assert_totals('STUDENT', p_keep, v_before);
  v_notes := app.move_notes('STUDENT', p_merge, p_keep);
  update app.student set birth_date = coalesce(birth_date, m.birth_date), school = coalesce(school, m.school),
         self_rating = coalesce(self_rating, m.self_rating), goal = coalesce(goal, m.goal)
   where id = p_keep;
  update app.student set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.student set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  perform app.merge_write_notes('STUDENT', p_keep, p_merge, v_info);
  return v_info || jsonb_build_object(
    'moved', jsonb_build_object('opportunities', coalesce((v_tables ->> 'app.prospect_student.student_id')::integer, 0),
                                'tests', coalesce((v_tables ->> 'app.student_test.student_id')::integer, 0), 'notes', v_notes),
    'tables', v_tables);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Gộp PHỤ HUYNH: chuyển toàn bộ dữ liệu có khoá phụ huynh (lead, cơ hội, học sinh, báo giá, đơn, phiếu thu, tiền vào, số dư, ghi danh...),
--    kiểm tổng, ghi chú; KHÔNG tự gộp học sinh, sau gộp báo các cặp học sinh trùng tên và năm sinh (R-CRM-37c).
-- ---------------------------------------------------------------------------
create or replace function app.merge_parents(p_keep uuid, p_merge uuid, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info jsonb := app.merge_common('PARENT', p_keep, p_merge, true);
  v_before jsonb;
  v_tables jsonb;
  v_notes integer;
  v_dup jsonb;
begin
  perform app.merge_require_confirm(p_confirm);
  v_before := app.merge_totals('PARENT', array[p_keep, p_merge]);
  v_tables := app.merge_move_refs('PARENT', p_keep, p_merge);
  perform app.merge_assert_totals('PARENT', p_keep, v_before);
  v_notes := app.move_notes('PARENT', p_merge, p_keep);
  update app.parent set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.parent set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  -- Ô tìm kiếm của phiếu có tên phụ huynh: tính lại cho các học sinh vừa chuyển sang.
  update app.student_test t set search_text = app.student_test_search_text(t)
   where t.student_id in (select s.id from app.student s where s.parent_id = p_keep);
  perform app.merge_write_notes('PARENT', p_keep, p_merge, v_info);
  select coalesce(jsonb_agg(jsonb_build_object('student_name', d.student_name, 'birth_year', d.birth_year,
                                                'student_codes', d.student_codes)), '[]'::jsonb)
    into v_dup from app.duplicate_students_of_parent(p_keep) d;
  return v_info || jsonb_build_object(
           'moved', jsonb_build_object('leads', coalesce((v_tables ->> 'app.lead.parent_id')::integer, 0),
                                       'opportunities', coalesce((v_tables ->> 'app.opportunity.parent_id')::integer, 0),
                                       'students', coalesce((v_tables ->> 'app.student.parent_id')::integer, 0), 'notes', v_notes),
           'tables', v_tables)
         || jsonb_build_object('duplicate_students', v_dup);
end;
$$;

-- Quyền gọi: hàm nội bộ không cấp cho giao diện; merge_students, merge_parents giữ quyền cũ (create or replace giữ grant).
revoke execute on function app.merge_totals(text, uuid[]), app.merge_move_refs(text, uuid, uuid), app.merge_assert_totals(text, uuid, jsonb)
  from public, anon, authenticated;
