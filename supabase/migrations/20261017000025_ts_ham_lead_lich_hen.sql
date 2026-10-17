-- P3b1 (3/3): hàm nghiệp vụ lead và lịch hẹn, hàm danh sách phân trang (docs/spec/04 R-CRM-01, 04, 09; TS-03, 05, 11, 13, 14).
-- Mỗi hàm: một giao dịch, kiểm quyền bên trong, lỗi có mã HMT_* và câu tiếng Việt. Ghi trực tiếp vào bảng bị chặn (chỉ qua hàm).
-- Hàm danh sách chạy với quyền người gọi (RLS áp dụng), phân trang ở máy chủ, chỉ lấy cột màn hiện.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Hàm trợ giúp.
-- ---------------------------------------------------------------------------

-- Chuẩn hoá số điện thoại: bỏ chữ, dấu cách, dấu chấm; +84 hoặc 84 đầu thành 0.
create or replace function app.normalize_phone(p_phone text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
begin
  if v like '+84%' then
    v := '0' || substr(v, 4); -- allow-number: cấu trúc số điện thoại Việt Nam (+84…), không phải số nghiệp vụ
  elsif v like '84%' and length(v) = 11 then -- allow-number: 84 + 9 số = 11 ký tự, cấu trúc số điện thoại Việt Nam
    v := '0' || substr(v, 3); -- allow-number: bỏ mã nước 84 (2 ký tự)
  end if;
  return regexp_replace(v, '[^0-9]', '', 'g');
end;
$$;

-- Người dùng có quyền (phân hệ, hành động) ở cơ sở đó không; báo lỗi nếu không.
create or replace function app.assert_can(p_module text, p_action text, p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.can_see_branch(p_module, p_action, p_branch_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này ở cơ sở này.');
  end if;
end;
$$;

-- Tên hiển thị của nhân sự (người phụ trách) cho danh sách: người xem danh sách có thể không có quyền xem tài khoản.
create or replace function app.staff_display_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select display_name from app.user_account where id = p_user_id;
$$;

-- Nhân sự dùng được làm người phụ trách ở cơ sở đó: tài khoản không khoá, đúng cơ sở, không phải học sinh.
create or replace function app.assert_staff_in_branch(p_user_id uuid, p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select from app.user_account
                  where id = p_user_id and not is_locked and student_code is null and branch_id = p_branch_id) then
    perform app.raise_error('HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách phải là nhân sự đang hoạt động của đúng cơ sở này.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Kiểm trùng số điện thoại (TS-03, TS-14).
-- Làm gì: trả lead và phụ huynh có cùng số. Hồ sơ ngoài phạm vi xem chỉ lộ mã và cơ sở (không lộ tên) để vẫn cảnh báo
--   trùng giữa các cơ sở mà không lộ dữ liệu khách.
-- Ai gọi: người có quyền Lead · Tạo. Đầu vào: số điện thoại, lead cần loại trừ (khi sửa).
-- ---------------------------------------------------------------------------
create or replace function app.find_duplicate_contacts(p_phone text, p_exclude_lead_id uuid default null)
returns table (kind text, id uuid, code text, label text, branch_code text, visible boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_phone text := app.normalize_phone(p_phone);
begin
  if app.permission_scope('LEAD', 'TAO') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo lead.');
  end if;
  if v_phone !~ '^0[0-9]{9}$' then
    return;
  end if;
  return query
    select * from (
      select 'LEAD'::text as kind, l.id as id, l.code as code,
             case when app.can_see_branch('LEAD', 'XEM', l.branch_id)
                  then l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), '') end as label,
             b.code as branch_code, app.can_see_branch('LEAD', 'XEM', l.branch_id) as visible
        from app.lead l join app.branch b on b.id = l.branch_id
       where l.parent_phone = v_phone and l.record_status = 'DANG_DUNG' and l.id is distinct from p_exclude_lead_id
      union all
      select 'PARENT'::text, p.id, p.code,
             case when app.can_see_branch('PARENT', 'XEM', p.branch_id)
                  then p.full_name || ' · ' || (select count(*) from app.student s where s.parent_id = p.id) || ' con' end,
             b.code, app.can_see_branch('PARENT', 'XEM', p.branch_id)
        from app.parent p join app.branch b on b.id = p.branch_id
       where p.phone = v_phone
    ) q
    order by q.kind, q.code
    limit app.get_setting_int('search_result_max');
end;
$$;

-- ---------------------------------------------------------------------------
-- Tạo lead (R-CRM-19: mã cấp lúc Lưu; R-CRM-09: giai đoạn đầu C1).
-- Ai gọi: người có quyền Lead · Tạo ở cơ sở của lead; đặt người phụ trách khác mình cần quyền Giao việc.
-- Đầu vào: p_data (khoá của app.lead: parent_name, parent_phone, ward_code, province_code, address, need, student_*, school,
--   self_rating, goal, branch_id, owner_id, supporter_id, source_type_code, source_code, channel_code, campaign_id);
--   p_confirm_duplicate: người dùng đã xem cảnh báo trùng SĐT và chọn "Vẫn tạo mới";
--   p_parent_id: chọn "Gắn vào hồ sơ có sẵn" của một phụ huynh (TS-14).
-- Kết quả: {id, code}.
-- ---------------------------------------------------------------------------
create or replace function app.create_lead(
  p_data jsonb, p_confirm_duplicate boolean default false, p_parent_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v app.lead;
  v_parent app.parent;
  v_dup integer;
  v_id uuid;
  v_code text;
begin
  v := jsonb_populate_record(null::app.lead, p_data);
  v.parent_phone := app.normalize_phone(p_data ->> 'parent_phone');
  v.branch_id := coalesce(v.branch_id, app.current_branch_id());

  -- Luật: thông tin bắt buộc (TS-03).
  if btrim(coalesce(v.parent_name, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập họ tên phụ huynh.');
  end if;
  if v.parent_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  if v.branch_id is null then
    perform app.raise_error('HMT_THIEU_CO_SO', 'Chọn cơ sở của lead.');
  end if;

  -- Luật: quyền tạo lead ở cơ sở này.
  perform app.assert_can('LEAD', 'TAO', v.branch_id);

  -- Luật: người phụ trách mặc định là người tạo; giao cho người khác cần quyền Giao việc (R-CRM, TS-05).
  v.owner_id := coalesce(v.owner_id, auth.uid());
  if v.owner_id <> auth.uid() then
    perform app.assert_can('LEAD', 'GIAO_VIEC', v.branch_id);
  end if;
  perform app.assert_staff_in_branch(v.owner_id, v.branch_id);
  if v.supporter_id is not null then
    perform app.assert_staff_in_branch(v.supporter_id, v.branch_id);
  end if;

  -- Luật: nguồn bắt buộc loại và nguồn; kênh bắt buộc khi nguồn có kênh con (spec 06 mục 1.1).
  if v.source_type_code is null or v.source_code is null then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn loại nguồn và nguồn của lead.');
  end if;
  if v.channel_code is null and exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active and s.catalog_code = 'SOURCE' and s.code = v.source_code) then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn kênh (sub-source) của nguồn này.');
  end if;
  if v.campaign_id is not null and not exists (select from app.campaign where id = v.campaign_id and is_active) then
    perform app.raise_error('HMT_CHIEN_DICH_SAI', 'Chiến dịch không có hoặc đã ngừng.');
  end if;

  -- Luật: phụ huynh có sẵn được chọn gắn vào phải nhìn thấy được.
  if p_parent_id is not null then
    select * into v_parent from app.parent where id = p_parent_id;
    if v_parent.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh để gắn vào.');
    end if;
    perform app.assert_can('PARENT', 'XEM', v_parent.branch_id);
  end if;

  -- Luật: số điện thoại đã có lead hoặc phụ huynh thì phải xác nhận lần hai (TS-03, TS-14), trừ khi gắn vào hồ sơ có sẵn.
  if p_parent_id is null and not coalesce(p_confirm_duplicate, false) then
    select (select count(*) from app.lead where parent_phone = v.parent_phone and record_status = 'DANG_DUNG')
         + (select count(*) from app.parent where phone = v.parent_phone) into v_dup;
    if v_dup > 0 then
      perform app.raise_error('HMT_SDT_TRUNG', 'Số điện thoại này đã có hồ sơ. Gắn vào hồ sơ có sẵn hoặc xác nhận vẫn tạo mới.');
    end if;
  end if;

  v_code := app.issue_crm_code('LD');
  insert into app.lead (
    code, parent_name, parent_phone, ward_code, province_code, address, need,
    student_name, student_birth_date, student_birth_year, school, self_rating, goal,
    parent_id, branch_id, owner_id, supporter_id, source_type_code, source_code, channel_code, campaign_id,
    stage_code, substage_code, legacy_ref)
  values (
    v_code, btrim(v.parent_name), v.parent_phone, v.ward_code, v.province_code, v.address, v.need,
    nullif(btrim(coalesce(v.student_name, '')), ''), v.student_birth_date, v.student_birth_year, v.school, v.self_rating, v.goal,
    p_parent_id, v.branch_id, v.owner_id, v.supporter_id, v.source_type_code, v.source_code, v.channel_code, v.campaign_id,
    'C1', null, v.legacy_ref)
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- ---------------------------------------------------------------------------
-- Sửa lead. Ai gọi: người có quyền Lead · Sửa ở cơ sở của lead. Chỉ sửa các ô thông tin; giai đoạn, người phụ trách,
-- cơ sở, trạng thái bản ghi có hàm riêng. Bản "Đã gộp" chỉ đọc (R-CRM-22).
-- ---------------------------------------------------------------------------
create or replace function app.update_lead(p_id uuid, p_data jsonb, p_confirm_duplicate boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.lead;
  v app.lead;
begin
  select * into v_old from app.lead where id = p_id;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  perform app.assert_can('LEAD', 'SUA', v_old.branch_id);
  if v_old.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, chỉ xem được.');
  end if;

  v := jsonb_populate_record(v_old, p_data);
  v.parent_phone := app.normalize_phone(v.parent_phone);

  if btrim(coalesce(v.parent_name, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập họ tên phụ huynh.');
  end if;
  if v.parent_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  if v.supporter_id is not null and v.supporter_id is distinct from v_old.supporter_id then
    perform app.assert_staff_in_branch(v.supporter_id, v_old.branch_id);
  end if;
  if v.source_type_code is null or v.source_code is null then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn loại nguồn và nguồn của lead.');
  end if;
  if v.channel_code is null and exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active and s.catalog_code = 'SOURCE' and s.code = v.source_code) then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn kênh (sub-source) của nguồn này.');
  end if;
  -- Luật: đổi số điện thoại sang số đã có hồ sơ thì xác nhận lần hai.
  if v.parent_phone <> v_old.parent_phone and not coalesce(p_confirm_duplicate, false)
     and (exists (select from app.lead where parent_phone = v.parent_phone and record_status = 'DANG_DUNG' and id <> p_id)
          or exists (select from app.parent where phone = v.parent_phone)) then
    perform app.raise_error('HMT_SDT_TRUNG', 'Số điện thoại này đã có hồ sơ. Xác nhận nếu vẫn muốn dùng số này.');
  end if;

  update app.lead set
    parent_name = btrim(v.parent_name), parent_phone = v.parent_phone, ward_code = v.ward_code,
    province_code = v.province_code, address = v.address, need = v.need,
    student_name = nullif(btrim(coalesce(v.student_name, '')), ''), student_birth_date = v.student_birth_date,
    student_birth_year = v.student_birth_year, school = v.school, self_rating = v.self_rating, goal = v.goal,
    supporter_id = v.supporter_id, source_type_code = v.source_type_code, source_code = v.source_code,
    channel_code = v.channel_code, campaign_id = v.campaign_id
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Đổi giai đoạn lead (R-CRM-09): đổi tự do cả hai chiều, mọi lần đổi ghi lịch sử (nhật ký). Nhóm con C4D "Tạo cơ hội
-- thành công" do hệ thống tự gắn khi tạo cơ hội, người dùng không chọn được.
-- Ai gọi: người có quyền Lead · Sửa ở cơ sở của lead.
-- ---------------------------------------------------------------------------
create or replace function app.change_lead_stage(p_id uuid, p_stage_code text, p_substage_code text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
begin
  select * into v_lead from app.lead where id = p_id;
  if v_lead.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  perform app.assert_can('LEAD', 'SUA', v_lead.branch_id);
  if v_lead.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, chỉ xem được.');
  end if;
  -- Luật R-CRM-09: C4D chỉ hệ thống gắn.
  if p_substage_code = 'C4D' then
    perform app.raise_error('HMT_C4D_HE_THONG', 'Nhóm con "Tạo cơ hội thành công" do hệ thống tự gắn, không chọn được.');
  end if;
  perform app.assert_catalog_code_active('LEAD_STAGE', p_stage_code);
  if p_substage_code is not null then
    perform app.assert_catalog_code_active('LEAD_SUBSTAGE', p_substage_code);
  end if;
  update app.lead set stage_code = p_stage_code, substage_code = p_substage_code where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Giao người phụ trách (TS-05): một hoặc nhiều bản ghi. Ai gọi: người có quyền Giao việc ở cơ sở của bản ghi.
-- Đầu vào: loại bản ghi (hiện có LEAD), danh sách id (tối đa theo list_page_size_max), người phụ trách mới (cùng cơ sở).
-- Kết quả: số bản ghi đã giao.
-- ---------------------------------------------------------------------------
create or replace function app.assign_owner(p_entity_type text, p_ids uuid[], p_owner_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v_id uuid;
  v_count integer := 0;
begin
  if p_entity_type <> 'LEAD' then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chưa giao việc được cho loại bản ghi này.');
  end if;
  if coalesce(cardinality(p_ids), 0) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ít nhất một bản ghi để giao.');
  end if;
  if cardinality(p_ids) > app.get_setting_int('list_page_size_max') then
    perform app.raise_error('HMT_QUA_NHIEU_BAN_GHI', 'Giao quá nhiều bản ghi một lần, hãy chia nhỏ.');
  end if;
  for v_id in select distinct unnest(p_ids) loop
    select * into v_lead from app.lead where id = v_id;
    if v_lead.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead cần giao.');
    end if;
    perform app.assert_can('LEAD', 'GIAO_VIEC', v_lead.branch_id);
    if v_lead.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', format('Lead %s đã gộp vào bản khác, không giao được.', v_lead.code));
    end if;
    perform app.assert_staff_in_branch(p_owner_id, v_lead.branch_id);
    update app.lead set owner_id = p_owner_id, assigned_at = now() where id = v_id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lịch hẹn (R-CRM-04). Hoàn thành, Huỷ, Mở lại không đổi giai đoạn, không tạo việc, không gửi thông báo.
-- ---------------------------------------------------------------------------

-- Tạo lịch hẹn gắn một lead. Ai gọi: quyền Lịch hẹn · Tạo ở cơ sở của lead; đặt người phụ trách khác mình cần Giao việc.
create or replace function app.create_appointment(
  p_lead_id uuid, p_activity_code text, p_scheduled_at timestamptz, p_title text,
  p_note text default null, p_owner_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v_owner uuid := coalesce(p_owner_id, auth.uid());
  v_id uuid;
begin
  -- Luật: lịch hẹn luôn gắn một hồ sơ, không có lịch hẹn mồ côi.
  select * into v_lead from app.lead where id = p_lead_id;
  if v_lead.id is null then
    perform app.raise_error('HMT_LICH_HEN_MO_COI', 'Lịch hẹn phải gắn với một hồ sơ.');
  end if;
  perform app.assert_can('APPOINTMENT', 'TAO', v_lead.branch_id);
  if v_lead.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, không thêm lịch hẹn được.');
  end if;
  if v_owner <> auth.uid() then
    perform app.assert_can('APPOINTMENT', 'GIAO_VIEC', v_lead.branch_id);
  end if;
  perform app.assert_staff_in_branch(v_owner, v_lead.branch_id);
  perform app.assert_catalog_code_active('ACTIVITY_TYPE', p_activity_code);
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày giờ của lịch hẹn.');
  end if;
  if btrim(coalesce(p_title, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập nội dung lịch hẹn.');
  end if;
  insert into app.appointment (lead_id, activity_code, scheduled_at, title, note, owner_id, branch_id)
  values (p_lead_id, p_activity_code, p_scheduled_at, btrim(p_title), p_note, v_owner, v_lead.branch_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- Đọc một lịch hẹn và kiểm quyền với cơ sở của nó (dùng chung cho các hàm dưới).
create or replace function app.appointment_for_update(p_id uuid, p_action text)
returns app.appointment
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment;
begin
  select * into v_appt from app.appointment where id = p_id;
  if v_appt.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lịch hẹn.');
  end if;
  perform app.assert_can('APPOINTMENT', p_action, v_appt.branch_id);
  return v_appt;
end;
$$;

-- Dời lịch hẹn: chỉ lịch Chưa làm.
create or replace function app.reschedule_appointment(p_id uuid, p_scheduled_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
begin
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ dời được lịch hẹn chưa làm. Mở lại trước nếu cần dời.');
  end if;
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày giờ mới của lịch hẹn.');
  end if;
  update app.appointment set scheduled_at = p_scheduled_at where id = p_id;
end;
$$;

-- Hoàn thành lịch hẹn: bấm một lần, từ Chưa làm. Hoàn thành ⇄ Huỷ không chuyển thẳng (phải Mở lại).
create or replace function app.complete_appointment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
begin
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ hoàn thành được lịch hẹn chưa làm.');
  end if;
  update app.appointment set status = 'HOAN_THANH', completed_at = now(), completed_by = auth.uid() where id = p_id;
end;
$$;

-- Huỷ lịch hẹn: từ Chưa làm, bắt buộc lý do danh mục 34; "Khác" bắt ghi chú (R-HT-04).
create or replace function app.cancel_appointment(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'HUY');
begin
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI',
      'Chỉ huỷ được lịch hẹn chưa làm. Lịch đã hoàn thành phải mở lại trước.');
  end if;
  if p_reason_code is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Chọn lý do huỷ lịch hẹn.');
  end if;
  perform app.assert_catalog_code_active('APPOINTMENT_CANCEL_REASON', p_reason_code);
  if (select requires_note from app.catalog_item
       where catalog_code = 'APPOINTMENT_CANCEL_REASON' and code = p_reason_code)
     and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_THIEU_GHI_CHU', 'Chọn "Khác" thì phải ghi chú lý do.');
  end if;
  update app.appointment
     set status = 'HUY', cancel_reason_code = p_reason_code, cancel_note = nullif(btrim(coalesce(p_note, '')), ''),
         cancelled_at = now(), cancelled_by = auth.uid()
   where id = p_id;
end;
$$;

-- Mở lại lịch hẹn Hoàn thành hoặc Huỷ về Chưa làm: không giới hạn thời gian; ghi lịch sử (nhật ký); mở lại tính là Sửa.
create or replace function app.reopen_appointment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
begin
  if v_appt.status = 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Lịch hẹn này chưa làm, không cần mở lại.');
  end if;
  update app.appointment
     set status = 'CHUA_LAM', cancel_reason_code = null, cancel_note = null,
         completed_at = null, completed_by = null, cancelled_at = null, cancelled_by = null,
         reopened_at = now(), reopened_by = auth.uid()
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách phân trang ở máy chủ. Trả {total, rows}; chỉ các cột màn hiện.
-- Cỡ trang: mặc định list_page_size_default, tối đa list_page_size_max. Lọc, sắp xếp, tìm kiếm làm ở DB.
-- security definer có chủ ý (đo bằng EXPLAIN trên 50.000 lead): với RLS, toán tử LIKE không "leakproof" nên Postgres không
-- cho chỉ mục trigram xử lý ô tìm kiếm (quét cả bảng, 25–60 ms và tăng theo số dòng). Hàm tự áp đúng luật của chính sách đọc:
-- phạm vi từ app.permission_scope (một nơi duy nhất), toàn hệ thống hoặc đúng cơ sở của người gọi; không quyền thì báo lỗi.
-- ---------------------------------------------------------------------------

-- Lead. Bộ lọc (p_filters): q (tìm không dấu), stage[], substage[], source_type[], source[], branch_id, owner_id, mine (true:
-- tôi phụ trách), supporter_mine, created_from, created_to, include_merged (hiện bản "Đã gộp").
-- Sắp xếp: created_desc (mặc định), created_asc, next_appointment_asc, name_asc.
create or replace function app.list_leads(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách lead.');
  end if;
  with f as (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
       and (v_merged or l.record_status = 'DANG_DUNG')
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then f.parent_name end asc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'parent_name', p.parent_name, 'parent_phone', p.parent_phone,
             'student_name', p.student_name, 'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'source_type_code', p.source_type_code, 'source_code', p.source_code, 'channel_code', p.channel_code,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'branch_code', b.code,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then p.parent_name end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead m on m.id = p.merged_into_id;
  return v_result;
end;
$$;

-- Lịch hẹn (security definer vì cùng lý do với list_leads; phạm vi từ app.permission_scope('APPOINTMENT', 'XEM')). Bộ lọc: from, to (khoảng giờ hẹn; "Tuần này" do giao diện truyền), status[], activity[], mine (tôi phụ trách),
-- lead_id, branch_id. Sắp xếp: time_asc (mặc định), time_desc.
create or replace function app.list_appointments(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  with f as (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_branch is null or a.branch_id = v_branch)
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'activity_code', p.activity_code, 'scheduled_at', p.scheduled_at, 'title', p.title,
             'status', p.status, 'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'lead_id', p.lead_id, 'lead_code', l.code,
             'lead_label', l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id;
  return v_result;
end;
$$;

-- Dải nhắc "Còn N lịch Quá hạn từ các tuần trước": đếm lịch Chưa làm hẹn trước mốc p_before (mine: chỉ lịch của tôi).
create or replace function app.appointment_overdue_count(p_before timestamptz, p_mine boolean default true)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer from app.appointment a
   where a.status = 'CHUA_LAM' and a.scheduled_at < p_before and (not p_mine or a.owner_id = auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi: chỉ người đã đăng nhập; mỗi hàm tự kiểm quyền bên trong. Hàm trợ giúp nội bộ không cấp cho giao diện.
-- ---------------------------------------------------------------------------
revoke execute on function
  app.normalize_phone(text), app.assert_can(text, text, uuid), app.staff_display_name(uuid),
  app.assert_staff_in_branch(uuid, uuid), app.find_duplicate_contacts(text, uuid),
  app.create_lead(jsonb, boolean, uuid), app.update_lead(uuid, jsonb, boolean),
  app.change_lead_stage(uuid, text, text), app.assign_owner(text, uuid[], uuid),
  app.create_appointment(uuid, text, timestamptz, text, text, uuid), app.appointment_for_update(uuid, text),
  app.reschedule_appointment(uuid, timestamptz), app.complete_appointment(uuid),
  app.cancel_appointment(uuid, text, text), app.reopen_appointment(uuid),
  app.list_leads(jsonb, text, integer, integer), app.list_appointments(jsonb, text, integer, integer),
  app.appointment_overdue_count(timestamptz, boolean), app.refresh_lead_next_appointment(uuid)
  from public, anon;
grant execute on function
  app.normalize_phone(text), app.find_duplicate_contacts(text, uuid),
  app.create_lead(jsonb, boolean, uuid), app.update_lead(uuid, jsonb, boolean),
  app.change_lead_stage(uuid, text, text), app.assign_owner(text, uuid[], uuid),
  app.create_appointment(uuid, text, timestamptz, text, text, uuid),
  app.reschedule_appointment(uuid, timestamptz), app.complete_appointment(uuid),
  app.cancel_appointment(uuid, text, text), app.reopen_appointment(uuid),
  app.list_leads(jsonb, text, integer, integer), app.list_appointments(jsonb, text, integer, integer),
  app.appointment_overdue_count(timestamptz, boolean)
  to authenticated;
-- Hàm trợ giúp được các hàm trên và chính sách gọi: cấp để chạy trong ngữ cảnh người dùng (kết quả vẫn kiểm quyền).
grant execute on function app.assert_can(text, text, uuid), app.staff_display_name(uuid),
  app.assert_staff_in_branch(uuid, uuid), app.appointment_for_update(uuid, text) to authenticated;

select set_config('hmt.migration', '', false);
