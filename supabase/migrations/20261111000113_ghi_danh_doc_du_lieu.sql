-- Cụm Ghi danh (GD-01, GD-02, GD-04, GD-06): các hàm ĐỌC cho giao diện. Không đổi luật, không ghi dữ liệu.
-- Luật: R-GD-05 (tình trạng ghi danh; hàng chờ xếp lớp CHỈ gồm ghi danh Chờ xếp lớp), R-GD-04 (sổ giờ chỉ thêm, hiện mọi dòng cộng trừ),
-- R-GD-16 (Hoàn thành, Chuyển lớp, Dừng), R-GD-18 (dòng chuyển phí: nguồn "Phiếu chuyển phí" kèm mã ticket, chưa có thì trống), R-GV-13 (giáo viên
-- không đọc sổ giờ, giờ mua: các hàm này chỉ cho vai trò xem ghi danh phạm vi toàn hệ thống hoặc cơ sở), R-HT-07 (ngày theo giờ Việt Nam).
-- Phân trang ở máy chủ: mặc định list_page_size_default, tối đa list_page_size_max (CLAUDE.md, Hiệu năng).
-- Giờ cấp = tổng dòng sổ giờ CAP_MUA, CAP_TANG, DAU_KY; đã học = tổng giờ trừ buổi (TRU_BUOI) đổi dấu; còn lại = tổng mọi dòng sổ giờ (R-GD-03).

-- Phạm vi đọc ghi danh của người gọi: toàn hệ thống, hoặc cơ sở của mình; không có quyền (hoặc chỉ "được phân công", như giáo viên) thì báo lỗi.
create or replace function app.enrollment_read_scope()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'XEM');
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem ghi danh.');
  end if;
  return v_scope;
end;
$$;

-- app.enrollment_list(bộ lọc, sắp xếp, số dòng, bỏ qua): GD-01. Bộ lọc: q (mã ghi danh hoặc tên học sinh), status (mảng mã tình trạng), branch_id,
-- class_id (lớp hiện tại), student_id, parent_id. Sắp xếp: code_desc (mặc định), code_asc, student_asc, student_desc, remaining_asc, remaining_desc.
-- Kết quả: {total, rows: [{id, code, student_id, student_name, student_code, package_code, package_name, delivery_mode_code, delivery_mode_name,
--   class_id, class_code, granted_hours, used_hours, remaining_hours, status_code, status_name}]}.
create or replace function app.enrollment_list(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'code_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_result jsonb;
begin
  -- Luật phạm vi: không phải toàn hệ thống thì chỉ thấy cơ sở của mình.
  with f as not materialized (
    select e.*, st.full_name as student_name, st.code as student_code,
           (select ec.class_id from app.enrollment_class ec where ec.enrollment_id = e.id and ec.end_date is null limit 1) as cur_class_id
      from app.enrollment e
      join app.student st on st.id = e.student_id
     where (v_scope = 'TOAN_HE_THONG' or e.branch_id = v_my_branch)
       and (v_branch is null or e.branch_id = v_branch)
       and (cardinality(v_status) = 0 or e.status_code = any (v_status))
       and (v_student is null or e.student_id = v_student)
       and (v_parent is null or e.parent_id = v_parent)
       and (v_q is null or e.search_text like '%' || v_q || '%' or app.fold_text(st.full_name) like '%' || v_q || '%')
  ), g as not materialized (
    select f.*, coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = f.id), 0)::numeric(6, 2) as remaining_hours
      from f where (v_class is null or f.cur_class_id = v_class)
  ), page as (
    select o.* from (
      select g.*, row_number() over (
        order by case p_sort when 'code_asc' then g.code end asc, case p_sort when 'student_asc' then g.student_name end asc,
                 case p_sort when 'student_desc' then g.student_name end desc, case p_sort when 'remaining_asc' then g.remaining_hours end asc,
                 case p_sort when 'remaining_desc' then g.remaining_hours end desc, g.code desc) as ord
        from g) o
     order by o.ord limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'student_id', p.student_id, 'student_name', p.student_name, 'student_code', p.student_code,
             'package_code', pk.code, 'package_name', pk.name, 'delivery_mode_code', p.delivery_mode_code, 'delivery_mode_name', dm.name,
             'class_id', p.cur_class_id, 'class_code', cl.code,
             'granted_hours', (select coalesce(sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = p.id and l.entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')),
             'used_hours', (select coalesce(-sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = p.id and l.entry_type = 'TRU_BUOI'),
             'remaining_hours', p.remaining_hours, 'status_code', p.status_code, 'status_name', sn.name)
             order by p.ord), '[]'::jsonb))
    into v_result
    from page p
    left join app.sales_package pk on pk.id = p.package_id
    left join app.catalog_item dm on dm.catalog_code = 'STUDY_MODE' and dm.code = p.delivery_mode_code
    left join app.class cl on cl.id = p.cur_class_id
    left join app.catalog_item sn on sn.catalog_code = p.status_catalog and sn.code = p.status_code;
  return v_result;
end;
$$;

-- app.enrollment_queue(bộ lọc, số dòng, bỏ qua): GD-06 Hàng chờ xếp lớp. Luật R-GD-05 (đã chốt 10/11): CHỈ ghi danh tình trạng Chờ xếp lớp;
-- em đã có lớp, em học trước chưa đóng tiền, em Toán 7+ mới xếp một lớp KHÔNG vào hàng chờ (đó là cảnh báo ở GD-02, GD-03).
-- Cần quyền Ghi danh · Sửa (người xếp lớp). Bộ lọc: q, branch_id, delivery_mode_code. Xếp theo "chờ từ" cũ nhất trước.
-- Kết quả: {total, rows: [{id, code, student_id, student_name, package_code, package_name, delivery_mode_code, delivery_mode_name, waiting_since}]}.
create or replace function app.enrollment_queue(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'SUA');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_mode text := nullif(p_filters ->> 'delivery_mode_code', '');
  v_result jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem hàng chờ xếp lớp.');
  end if;
  with f as not materialized (
    select e.id, e.code, e.student_id, st.full_name as student_name, e.package_id, e.delivery_mode_code, e.created_at
      from app.enrollment e join app.student st on st.id = e.student_id
     where e.status_code = 'CHO_XEP_LOP'
       and (v_scope = 'TOAN_HE_THONG' or e.branch_id = v_my_branch)
       and (v_branch is null or e.branch_id = v_branch)
       and (v_mode is null or e.delivery_mode_code = v_mode)
       and (v_q is null or e.search_text like '%' || v_q || '%' or app.fold_text(st.full_name) like '%' || v_q || '%')
  ), page as (
    select * from f order by f.created_at, f.code limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'student_id', p.student_id, 'student_name', p.student_name,
             'package_code', pk.code, 'package_name', pk.name, 'delivery_mode_code', p.delivery_mode_code, 'delivery_mode_name', dm.name,
             'waiting_since', (p.created_at at time zone 'Asia/Ho_Chi_Minh')::date) order by p.created_at, p.code), '[]'::jsonb))
    into v_result
    from page p
    left join app.sales_package pk on pk.id = p.package_id
    left join app.catalog_item dm on dm.catalog_code = 'STUDY_MODE' and dm.code = p.delivery_mode_code;
  return v_result;
end;
$$;

-- app.enrollment_record(id): GD-02 bản ghi ghi danh. Kết quả: {enrollment: {...}, hours: {granted, gifted, used, remaining},
--   classes: [{class_id, class_code, start_date, end_date, end_reason, studied_hours}], tickets: 0}.
-- "Ngày hết giờ dự kiến" và "Hạn gói (chỉ dự báo)": CHƯA tính (trả null); khung có ô, nhưng luật chỉ dự báo, không chặn.
-- Ticket: chưa có phân hệ Chăm sóc khách hàng (sau 17/11): số ticket luôn 0.
create or replace function app.enrollment_record(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  e app.enrollment;
begin
  select * into e from app.enrollment where id = p_id;
  if e.id is null or (v_scope = 'CO_SO' and e.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  return jsonb_build_object(
    'enrollment', (select jsonb_build_object(
        'id', e.id, 'code', e.code, 'legacy_ref', e.legacy_ref, 'status_code', e.status_code, 'status_name', sn.name,
        'student_id', st.id, 'student_code', st.code, 'student_name', st.full_name,
        'parent_id', pa.id, 'parent_code', pa.code, 'parent_name', pa.full_name,
        'package_code', pk.code, 'package_name', pk.name, 'delivery_mode_code', e.delivery_mode_code, 'delivery_mode_name', dm.name,
        'order_id', e.order_id, 'order_code', so.code, 'branch_code', br.code, 'branch_name', br.name,
        'enrolled_on', (e.created_at at time zone 'Asia/Ho_Chi_Minh')::date, 'start_date', e.start_date,
        'expected_end_date', null, 'package_deadline', null)
      from app.student st, app.parent pa, app.branch br
      left join app.sales_package pk on pk.id = e.package_id
      left join app.catalog_item dm on dm.catalog_code = 'STUDY_MODE' and dm.code = e.delivery_mode_code
      left join app.sales_order so on so.id = e.order_id
      left join app.catalog_item sn on sn.catalog_code = e.status_catalog and sn.code = e.status_code
      where st.id = e.student_id and pa.id = e.parent_id and br.id = e.branch_id),
    'hours', jsonb_build_object(
      'granted', (select coalesce(sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = e.id and l.entry_type in ('CAP_MUA', 'DAU_KY')),
      'gifted', (select coalesce(sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = e.id and l.entry_type = 'CAP_TANG'),
      'used', (select coalesce(-sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = e.id and l.entry_type = 'TRU_BUOI'),
      'remaining', app.enrollment_hours_balance(e.id)),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'class_id', ec.class_id, 'class_code', c.code, 'start_date', ec.start_date, 'end_date', ec.end_date, 'end_reason', ec.end_reason,
               'studied_hours', (select coalesce(-sum(l.hours), 0) from app.hour_ledger l join app.class_session s on s.id = l.session_id
                                  where l.enrollment_id = e.id and l.entry_type = 'TRU_BUOI' and s.class_id = ec.class_id))
             order by ec.start_date, ec.created_at)
        from app.enrollment_class ec join app.class c on c.id = ec.class_id where ec.enrollment_id = e.id), '[]'::jsonb),
    'tickets', 0);
end;
$$;

-- app.enrollment_ledger(id, số dòng, bỏ qua): GD-04 Sổ giờ của ghi danh (chỉ thêm, không sửa; R-GD-04). Mới nhất trước, kèm số dư sau mỗi dòng.
-- Cột nguồn: Trừ buổi → lớp và số buổi; Điều chỉnh → người điều chỉnh và lý do; Chuyển phí → nguồn "Phiếu chuyển phí" kèm mã ticket (source_ref, trống nếu chưa có).
-- "Phiếu thu", "Khoản tiền" của dòng cấp giờ: sổ giờ chưa lưu liên kết tới phiếu thu nên chưa trả (null).
-- Kết quả: {total, rows: [{id, on_date, entry_type, entry_name, class_code, session_no, session_date, receipt_code, adjusted_by, reason_name, note, ticket_code, hours, balance}]}.
create or replace function app.enrollment_ledger(p_id uuid, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  e app.enrollment;
  v_result jsonb;
begin
  select * into e from app.enrollment where id = p_id;
  if e.id is null or (v_scope = 'CO_SO' and e.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  with run as (
    select l.*, sum(l.hours) over (order by l.seq) as balance from app.hour_ledger l where l.enrollment_id = e.id
  ), page as (
    select * from run order by seq desc limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from run),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'on_date', (p.created_at at time zone 'Asia/Ho_Chi_Minh')::date, 'entry_type', p.entry_type,
             'entry_name', case p.entry_type when 'CAP_MUA' then 'Cấp từ phiếu thu' when 'CAP_TANG' then 'Cấp giờ tặng' when 'DAU_KY' then 'Số dư đầu kỳ'
                                              when 'TRU_BUOI' then 'Trừ buổi' when 'DIEU_CHINH' then 'Điều chỉnh' when 'CHUYEN_PHI' then 'Phiếu chuyển phí' end,
             'class_code', c.code, 'session_no', s.session_no, 'session_date', s.session_date, 'receipt_code', null,
             'adjusted_by', case when p.entry_type = 'DIEU_CHINH' then ua.display_name end,
             'reason_name', rn.name, 'note', p.note,
             'ticket_code', case when p.entry_type = 'CHUYEN_PHI' then p.source_ref end,
             'hours', p.hours, 'balance', p.balance) order by p.seq desc), '[]'::jsonb))
    into v_result
    from page p
    left join app.class_session s on s.id = p.session_id
    left join app.class c on c.id = s.class_id
    left join app.user_account ua on ua.id = p.created_by
    left join app.catalog_item rn on rn.catalog_code = p.reason_catalog and rn.code = p.reason_code;
  return v_result;
end;
$$;

revoke all on function app.enrollment_read_scope(), app.enrollment_list(jsonb, text, integer, integer), app.enrollment_queue(jsonb, integer, integer),
  app.enrollment_record(uuid), app.enrollment_ledger(uuid, integer, integer) from public, anon;
grant execute on function app.enrollment_read_scope(), app.enrollment_list(jsonb, text, integer, integer), app.enrollment_queue(jsonb, integer, integer),
  app.enrollment_record(uuid), app.enrollment_ledger(uuid, integer, integer) to authenticated;

-- Chỉ mục (lý do): không thêm mới ở đây. enrollment(code) unique và enrollment_order_idx có từ migration 101; truy vấn lọc theo cơ sở và tình trạng dùng
-- enrollment_branch_idx, enrollment_status_idx (migration 101, kiểm bằng EXPLAIN trong PR); hour_ledger theo enrollment_id (hour_ledger_enrollment_idx).
