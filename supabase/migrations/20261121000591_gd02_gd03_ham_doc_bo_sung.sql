-- GD-02, GD-03: năm chỗ chỉ đọc canvas 9933 ghi số liệu mà hàm đọc chưa trả (anh Trường duyệt 20/11, đề xuất trong #428). Một migration, chỉ đọc, KHÔNG đổi quyền, bộ lọc, bảng.
-- (1) app.enrollment_record: hours.negative_limit_sessions/hours (R-GD-12), enrollment.hold_start/hold_end (R-GD-09), enrollment.refund_voucher_code (R-TIEN-34). Thân hàm lấy từ migration 113.
-- (2) app.enrollment_assign_options: sibling_hint (nhắc mềm thiếu môn Đại hoặc Hình, KHÔNG chặn xếp lớp). Thân hàm lấy từ migration 114.
-- (3) app.enrollment_matching_classes: clash_first (buổi trùng đầu tiên: ngày, giờ, mã lớp). Thân hàm lấy từ migration 574.
-- Chỉ mục: không thêm; các tra cứu theo khoá ngoại enrollment_id đã có chỉ mục (enrollment_hold_enrollment_idx, refund_request.enrollment_id).
select set_config('hmt.migration', 'on', false);

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
        'expected_end_date', null, 'package_deadline', null,
        -- GD-02 (canvas GD02_bao_luu, GD02_hoan_phi): ngày bảo lưu đang chạy và mã phiếu chi hoàn phí; chỉ đọc.
        'hold_start', (select h.start_date from app.enrollment_hold h where h.enrollment_id = e.id and h.status_code = 'DANG_BAO_LUU'
                        order by h.created_at desc limit 1),
        'hold_end', (select h.end_date from app.enrollment_hold h where h.enrollment_id = e.id and h.status_code = 'DANG_BAO_LUU'
                      order by h.created_at desc limit 1),
        'refund_voucher_code', (select pv.code from app.refund_request rr join app.payment_voucher pv on pv.refund_request_id = rr.id
                                 where rr.enrollment_id = e.id order by pv.created_at desc limit 1))
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
      'remaining', app.enrollment_hours_balance(e.id),
      -- GD-02 (canvas GD02_hoc_truoc, R-GD-12): hạn mức âm của «cho học trước» = max_sessions_ahead buổi × giờ một buổi của lớp đang học; null khi ghi danh không học trước.
      'negative_limit_sessions', case when e.pay_later_enabled then app.get_setting_int('max_sessions_ahead', e.branch_id) end,
      'negative_limit_hours', case when e.pay_later_enabled then
         (select app.get_setting_int('max_sessions_ahead', e.branch_id)
                 * max(extract(epoch from (s.end_time - s.start_time)) / 3600.0) -- allow-number: 3600 giây một giờ
            from app.enrollment_class ec join app.class_slot s on s.class_id = ec.class_id and s.is_active
           where ec.enrollment_id = e.id and ec.end_date is null) end),
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

create or replace function app.enrollment_assign_options(p_enrollment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'SUA');
  e app.enrollment;
  v_siblings jsonb;
  v_groups jsonb := '[]'::jsonb;
  v_pairs jsonb;
  g record;
  s record;
  v_pick jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xếp lớp.');
  end if;
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null or (v_scope = 'CO_SO' and e.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'code', x.code, 'package_id', x.package_id, 'package_code', pk.code, 'package_name', pk.name,
           'delivery_mode_code', x.delivery_mode_code) order by x.created_at, x.code), '[]'::jsonb) into v_siblings
    from app.enrollment x left join app.sales_package pk on pk.id = x.package_id
   where x.student_id = e.student_id and x.branch_id = e.branch_id and x.status_code = 'CHO_XEP_LOP';

  -- Nhóm lớp: với từng nhóm, mỗi ghi danh chờ chọn lớp phù hợp đầu tiên thuộc nhóm.
  for g in select distinct c ->> 'group_id' as group_id, c ->> 'group_name' as group_name
             from app.enrollment x
             cross join lateral jsonb_array_elements(app.enrollment_matching_classes(x.package_id, x.branch_id, x.student_id)) c
            where x.student_id = e.student_id and x.branch_id = e.branch_id and x.status_code = 'CHO_XEP_LOP' and x.package_id is not null
              and c ->> 'group_id' is not null
            order by group_name, group_id
  loop
    v_pairs := '[]'::jsonb;
    for s in select x.id, x.code, x.package_id, x.package_id is not null as has_pkg from app.enrollment x
              where x.student_id = e.student_id and x.branch_id = e.branch_id and x.status_code = 'CHO_XEP_LOP' order by x.created_at, x.code loop
      select c into v_pick from jsonb_array_elements(app.enrollment_matching_classes(s.package_id, e.branch_id, e.student_id)) c
       where c ->> 'group_id' = g.group_id and (c ->> 'clash_sessions')::integer = 0 limit 1;
      if v_pick is not null then
        v_pairs := v_pairs || jsonb_build_array(jsonb_build_object('enrollment_id', s.id, 'enrollment_code', s.code, 'class', v_pick));
      end if;
    end loop;
    if jsonb_array_length(v_pairs) > 0 then
      v_groups := v_groups || jsonb_build_array(jsonb_build_object('group_id', g.group_id, 'group_name', g.group_name, 'pairs', v_pairs));
    end if;
  end loop;

  return jsonb_build_object(
    'enrollment', jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code, 'student_id', e.student_id,
                    'student_name', (select full_name from app.student where id = e.student_id), 'package_id', e.package_id,
                    'delivery_mode_code', e.delivery_mode_code),
    'siblings', v_siblings,
    -- GD-03 (canvas GD03_nhac_mem): nhắc mềm, KHÔNG chặn: em chỉ có ghi danh một trong hai môn Đại, Hình (Toán 7+) mà chưa có môn kia.
    'sibling_hint', (select jsonb_build_object('have_subject_code', e.subject_code, 'missing_subject_code', m.code,
                                               'have_subject_name', hv.name, 'missing_subject_name', m.name)
                       from (select case e.subject_code when 'DAI' then 'HINH' when 'HINH' then 'DAI' end as code) o
                       join app.catalog_item m on m.catalog_code = 'SUBJECT' and m.code = o.code
                       join app.catalog_item hv on hv.catalog_code = 'SUBJECT' and hv.code = e.subject_code
                      where o.code is not null
                        and not exists (select from app.enrollment x
                                         where x.student_id = e.student_id and x.branch_id = e.branch_id and x.id <> e.id and x.subject_code = o.code
                                           and x.status_code not in ('DUNG', 'HOAN_PHI', 'CHUYEN_LOP', 'HOAN_THANH'))),
    'classes', case when e.package_id is null then '[]'::jsonb else app.enrollment_matching_classes(e.package_id, e.branch_id, e.student_id) end,
    'groups', v_groups);
end;
$$;

create or replace function app.enrollment_matching_classes(p_package_id uuid, p_branch_id uuid default null, p_student_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text;
  v_branch uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  p app.sales_package;
  v_result jsonb;
begin
  v_scope := coalesce(app.permission_scope('ENROLLMENT', 'SUA'), app.permission_scope('SALES_ORDER', 'SUA'));
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền chọn lớp.');
  end if;
  v_branch := case when v_scope = 'TOAN_HE_THONG' then coalesce(p_branch_id, app.current_branch_id()) else app.current_branch_id() end;
  select * into p from app.sales_package where id = p_package_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy gói.');
  end if;

  select coalesce(jsonb_agg(x.j order by x.code), '[]'::jsonb) into v_result
    from (
      select c.code,
             jsonb_build_object(
               'id', c.id, 'code', c.code, 'subject_name', sub.name, 'class_type_name', ct.name, 'level_name', lv.name, 'grade_code', c.grade_code,
               'group_id', c.group_id, 'group_name', g.display_name, 'delivery_mode_code', c.delivery_mode_code,
               'schedule_text', (select string_agg(format('%s %s–%s', app.weekday_label(s.weekday::integer), to_char(s.start_time, 'HH24:MI'), to_char(s.end_time, 'HH24:MI')),
                                                         '; ' order by s.weekday, s.start_time)
                                   from app.class_slot s where s.class_id = c.id and s.is_active),
               'teacher_name', (select ua.display_name from app.class_slot s join app.user_account ua on ua.id = s.teacher_id
                                 where s.class_id = c.id and s.is_active order by s.weekday, s.start_time limit 1),
               'seats_left', app.class_seats_left(c.id),
               'has_sessions', exists (select from app.class_session x where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT', 'DONE')),
               'class_start_date', c.start_date,
               'weekdays', coalesce((select jsonb_agg(distinct s.weekday) from app.class_slot s where s.class_id = c.id and s.is_active), '[]'::jsonb),
               'upcoming', coalesce((select jsonb_agg(jsonb_build_object('date', u.session_date, 'session_no', u.session_no) order by u.session_date, u.start_time)
                                       from (select * from app.class_session x where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT')
                                                and x.session_date >= v_today order by x.session_date, x.start_time limit 8) u), '[]'::jsonb), -- allow-number: số buổi sắp tới gợi ý trong hộp chọn ngày vào lớp
               'clash_sessions', case when p_student_id is null then 0 else (
                 select count(*) from app.enrollment e
                   join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null and ec.class_id <> c.id
                   join app.class_session b on b.class_id = ec.class_id and b.status_code in ('NHAP', 'DA_CHOT')
                   join app.class_session a on a.class_id = c.id and a.status_code in ('NHAP', 'DA_CHOT') and a.session_date = b.session_date
                        and b.start_time < a.end_time and a.start_time < b.end_time
                  where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') and a.session_date >= v_today) end
               ,
               -- GD-03 (canvas GD03_trung_gio): buổi trùng đầu tiên (ngày, giờ, lớp em đang học) để hiện câu «Trùng buổi …».
               'clash_first', case when p_student_id is null then null else (
                 select jsonb_build_object('date', a.session_date, 'start_time', a.start_time, 'end_time', a.end_time, 'class_code', bc.code)
                   from app.enrollment e
                   join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null and ec.class_id <> c.id
                   join app.class bc on bc.id = ec.class_id
                   join app.class_session b on b.class_id = ec.class_id and b.status_code in ('NHAP', 'DA_CHOT')
                   join app.class_session a on a.class_id = c.id and a.status_code in ('NHAP', 'DA_CHOT') and a.session_date = b.session_date
                        and b.start_time < a.end_time and a.start_time < b.end_time
                  where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') and a.session_date >= v_today
                  order by a.session_date, a.start_time limit 1) end
             ) as j
        from app.class c
        join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
        join app.catalog_item ct on ct.catalog_code = c.class_type_catalog and ct.code = c.class_type_code
        left join app.catalog_item lv on lv.catalog_code = c.level_catalog and lv.code = c.level_code
        left join app.class_group g on g.id = c.group_id
       -- Luật R-GD-08: lớp đã duyệt, đúng cơ sở, còn chỗ; R-GD-06: đúng môn và khối của gói.
       where c.status_code = 'DA_DUYET' and c.branch_id = v_branch
         and app.package_matches_class_subject(p.subject_code, c.subject_code)
         and (p.grade_from_code is null or (c.grade_code >= p.grade_from_code and c.grade_code <= coalesce(p.grade_to_code, p.grade_from_code)))
         and coalesce(app.class_seats_left(c.id), 1) > 0
    ) x;
  return v_result;
end;
$$;
