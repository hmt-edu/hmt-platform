-- C-27-13 (anh Trường chốt 27/11/2026 23:30; mig 709; rủi ro CAO, quyền).
-- (1) Trưởng cơ sở được xử lý phiếu tái tục của cơ sở mình: bật ô Phiếu tái tục · Sửa (Cơ sở). Đủ để chuyển giai đoạn, ghi chú, tạo báo giá, tạo đơn
--     (R-GD-13); tạo báo giá, tạo đơn vẫn cần thêm Báo giá · Tạo, Đơn hàng · Tạo.
-- (2) Phụ huynh có thêm email (Zalo dùng số điện thoại, không thêm trường): không bắt buộc, kiểm định dạng, lưu chữ thường.
select set_config('hmt.migration', 'on', false);

insert into app.permission (role_code, module_code, action_code, scope_code)
values ('BRANCH_MANAGER', 'UPSALE', 'SUA', 'CO_SO')
on conflict (role_code, module_code, action_code) do update set scope_code = excluded.scope_code, is_active = true;

alter table app.parent add column email text
  constraint parent_email_format check (email is null or (email = lower(email) and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'));
comment on column app.parent.email is 'Email phụ huynh (không bắt buộc), chữ thường. Sửa theo quyền Phụ huynh · Sửa.';

select set_config('hmt.migration', '', false);

-- app.update_parent: chép bản 570, chỉ thêm email. Ai gọi: Phụ huynh · Sửa ở cơ sở của hồ sơ. Luật: R-CRM-25, 27, 28, R-V2-04.
create or replace function app.update_parent(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.parent;
  v app.parent;
  v_other app.parent;
begin
  select * into v_old from app.parent where id = p_id;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  perform app.assert_can('PARENT', 'SUA', v_old.branch_id);
  -- Luật R-CRM-25: bản đã gộp chỉ đọc.
  if v_old.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Phụ huynh này đã gộp vào hồ sơ khác, chỉ xem được.');
  end if;

  v := jsonb_populate_record(v_old, coalesce(p_data, '{}'::jsonb));
  v.full_name := btrim(coalesce(v.full_name, ''));
  v.phone := app.normalize_phone(v.phone);
  v.phone_2 := nullif(app.normalize_phone(coalesce(v.phone_2, '')), '');
  v.relative_name := nullif(btrim(coalesce(v.relative_name, '')), '');
  v.address := nullif(btrim(coalesce(v.address, '')), '');
  -- Email không bắt buộc, lưu chữ thường (anh Trường chốt 27/11).
  v.email := nullif(lower(btrim(coalesce(v.email, ''))), '');

  -- Luật: họ tên bắt buộc.
  if v.full_name = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Bắt buộc nhập họ tên.');
  end if;
  -- Luật R-V2-04: số chính và số thứ hai (nếu có) đúng 10 số, bắt đầu bằng 0.
  if v.phone !~ '^0[0-9]{9}$' or (v.phone_2 is not null and v.phone_2 !~ '^0[0-9]{9}$') then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  -- Luật email: có nhập thì phải đúng định dạng. Câu lỗi không nhắc lại địa chỉ đã nhập.
  if v.email is not null and v.email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    perform app.raise_error('HMT_EMAIL_SAI', 'Email không đúng định dạng.');
  end if;
  -- Luật R-CRM-27: một số điện thoại chỉ thuộc một phụ huynh (khớp theo số chính hoặc số thứ hai).
  if v.phone <> v_old.phone or v.phone_2 is distinct from v_old.phone_2 then
    select * into v_other from app.parent o
     where o.id <> p_id and o.record_status = 'DANG_DUNG'
       and (o.phone in (v.phone, coalesce(v.phone_2, '')) or o.phone_2 in (v.phone, coalesce(v.phone_2, '')))
     order by o.created_at limit 1;
    if v_other.id is not null then
      -- Chỉ nêu tên và mã khi người sửa xem được cơ sở của hồ sơ trùng; ngoài phạm vi thì báo chung, không lộ tên, mã, cơ sở.
      if app.can_see_branch('PARENT', 'XEM', v_other.branch_id) then
        perform app.raise_error('HMT_SDT_TRUNG',
          'Số điện thoại đã có ở phụ huynh khác: ' || v_other.full_name || ' (' || v_other.code || ').');
      end if;
      perform app.raise_error('HMT_SDT_TRUNG', 'Số điện thoại đã có ở phụ huynh khác.');
    end if;
  end if;
  -- Luật: phường, tỉnh phải là mục đang dùng trong danh mục.
  if v.ward_code is distinct from v_old.ward_code and v.ward_code is not null then
    perform app.assert_catalog_code_active('WARD', v.ward_code);
  end if;
  if v.province_code is distinct from v_old.province_code and v.province_code is not null then
    perform app.assert_catalog_code_active('PROVINCE', v.province_code);
  end if;
  -- Luật R-CRM-28: cơ sở tiếp nhận chỉ Admin sửa.
  if v.branch_id is distinct from v_old.branch_id and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_CHI_ADMIN_DOI_CO_SO', 'Chỉ Admin được sửa cơ sở tiếp nhận.');
  end if;

  update app.parent set full_name = v.full_name, phone = v.phone, phone_2 = v.phone_2, relative_name = v.relative_name,
         ward_code = v.ward_code, province_code = v.province_code, address = v.address, email = v.email,
         branch_id = v.branch_id
   where id = p_id;
  -- Ô tìm kiếm của phiếu có tên phụ huynh: tính lại cho các em của phụ huynh này.
  if v.full_name <> v_old.full_name then
    update app.student_test t set search_text = app.student_test_search_text(t)
     where t.student_id in (select s.id from app.student s where s.parent_id = p_id);
  end if;
end;
$$;

-- app.get_parent_record: chép bản 684, chỉ thêm email. Ai gọi: người có quyền Xem phụ huynh.
create or replace function app.get_parent_record(p_parent_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p app.parent;
begin
  -- Luật R-CRM-26 và chính sách parent_read (migration 422): chỉ phạm vi Toàn hệ thống, Cơ sở đọc được hồ sơ phụ huynh.
  if coalesce(app.permission_scope('PARENT', 'XEM'), '') not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  select * into p from app.parent where id = p_parent_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  return jsonb_build_object(
    'id', p.id, 'code', p.code, 'full_name', p.full_name, 'phone', p.phone, 'phone_2', p.phone_2, 'relative_name', p.relative_name,
    'email', p.email,
    'address', p.address,
    'ward_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'WARD' and ci.code = p.ward_code),
    'province_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'PROVINCE' and ci.code = p.province_code),
    'branch_code', (select b.code from app.branch b where b.id = p.branch_id),
    'record_status', p.record_status, 'merged_into_id', p.merged_into_id,
    'created_at', p.created_at,
    'is_studying', exists (select from app.enrollment e where e.parent_id = p.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')),
    'studying_at', coalesce((select jsonb_agg(distinct eb.code order by eb.code) from app.enrollment e join app.branch eb on eb.id = e.branch_id
                              where e.parent_id = p.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb),
    'children', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'full_name', s.full_name, 'grade', s.grade, 'status', app.student_status(s.id)) order by s.full_name)
                            from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code, 'status_code', o.status_code, 'total_amount', o.total_amount, 'created_at', o.created_at) order by o.created_at desc)
                          from (select * from app.sales_order x
                                 where x.parent_id = p.id and app.can_see_branch_wide('SALES_ORDER', 'XEM', x.branch_id) -- quyền Xem đơn hàng
                                 order by x.created_at desc limit 50) o), '[]'::jsonb), -- allow-number: 50 dòng mới nhất mỗi loại trên bản ghi
    'receipts', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'status_code', r.status_code, 'amount', r.amount, 'paid_on', r.paid_on) order by r.created_at desc)
                            from (select * from app.receipt x
                                   where x.parent_id = p.id and app.can_see_branch_wide('RECEIPT', 'XEM', x.branch_id) -- quyền Xem phiếu thu
                                   order by x.created_at desc limit 50) r), '[]'::jsonb), -- allow-number: 50 dòng mới nhất mỗi loại trên bản ghi
    'counts', jsonb_build_object(
      'children', (select count(*) from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'),
      'opportunities', (select count(*) from app.opportunity o where o.parent_id = p.id and o.record_status = 'DANG_DUNG'),
      'tests', (select count(*) from app.student_test t join app.student s on s.id = t.student_id where s.parent_id = p.id),
      'enrollments', (select count(*) from app.enrollment e where e.parent_id = p.id),
      'orders', (select count(*) from app.sales_order o where o.parent_id = p.id and app.can_see_branch_wide('SALES_ORDER', 'XEM', o.branch_id)),
      'receipts', (select count(*) from app.receipt r where r.parent_id = p.id and app.can_see_branch_wide('RECEIPT', 'XEM', r.branch_id))));
end;
$$;

-- app.get_upsale_ticket: bản 708, chỉ đổi phụ huynh trả email thật (bỏ ô zalo luôn trống).
create or replace function app.get_upsale_ticket(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_open boolean;
begin
  select * into t from app.upsale_ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', t.branch_id);
  v_open := t.stage_code not in ('L5', 'L8');
  return jsonb_build_object(
    'ticket', app.upsale_ticket_row(t) || jsonb_build_object(
      'lost_reason_code', t.lost_reason_code, 'lost_note', t.lost_note, 'next_goal', t.next_goal, 'next_roadmap', t.next_roadmap,
      'closed_at', t.closed_at, 'created_by_name', app.staff_display_name(t.created_by),
      'branch_id', t.branch_id), -- cho form báo giá từ phiếu: hạn hiệu lực theo cơ sở của phiếu
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', p.email)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name, 'birth_year', s.birth_year)
                  from app.student s where s.id = t.student_id),
    'class', app.upsale_class_info(t),
    'enrollments', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code,
                       'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) order by e.code)
                  from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                 where e.student_id = t.student_id), '[]'::jsonb),
    'hours', app.upsale_hours_info(t),
    'contact', app.upsale_contact_info(t),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end,
      -- Luật R-GD-13 (27/11): tạo báo giá, tạo đơn ở mọi giai đoạn, theo quyền.
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('QUOTATION', 'TAO', t.branch_id) then 'tao_bao_gia' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('SALES_ORDER', 'TAO', t.branch_id) then 'tao_don' end], null)));
end;
$$;
