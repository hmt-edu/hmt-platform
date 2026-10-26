-- ===========================================================================
-- Lead chỉ tạo được cơ hội khi ở C4C (lỗi 26/10, anh Trường chốt): nhóm con C4C "Đủ điều kiện tạo cơ hội" là cửa vào cơ hội.
-- Lead ở C1, C2, C3, C4A, C4B không tạo được; lead đã ở C4D vẫn tạo thêm được theo R-CRM-01 (xác nhận lần hai). Chặn trong hàm
-- tạo cơ hội (chặn thật); nút mờ ở giao diện chỉ là gợi ý. Luật MỚI, chưa vào docs/spec (chờ "OK ĐƯA VÀO LUẬT").
-- Các luật khác của hàm giữ nguyên (danh sách em, nguồn, người phụ trách, R-CRM-01, 09, 27, 28).
-- ===========================================================================

CREATE OR REPLACE FUNCTION app.create_opportunity(p_lead_id uuid, p_data jsonb DEFAULT '{}'::jsonb, p_confirm_existing boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_lead app.lead;
  v app.opportunity;
  v_existing text;
  v_parent_id uuid;
  v_parent_code text;
  v_owner uuid;
  v_id uuid;
  v_code text;
begin
  select * into v_lead from app.lead where id = p_lead_id;
  if v_lead.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: quyền tạo cơ hội và xem lead ở cơ sở của lead.
  perform app.assert_can('OPPORTUNITY', 'TAO', v_lead.branch_id);
  perform app.assert_can('LEAD', 'XEM', v_lead.branch_id);
  if v_lead.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, không tạo cơ hội được.');
  end if;
  -- Luật mới (26/10, anh Trường chốt): lead chỉ tạo được cơ hội khi ở nhóm con C4C "Đủ điều kiện tạo cơ hội". Lead đã ở C4D
  -- (đã tạo cơ hội thành công) vẫn tạo thêm được theo R-CRM-01 (cảnh báo kèm mã cũ, xác nhận lần hai). Nút mờ ở giao diện chỉ là gợi ý.
  if v_lead.substage_code is null or v_lead.substage_code not in ('C4C', 'C4D') then
    perform app.raise_error('HMT_LEAD_CHUA_DU_DIEU_KIEN',
      'Lead cần ở nhóm con C4C "Đủ điều kiện tạo cơ hội" mới tạo được cơ hội. Đổi giai đoạn của lead trước.');
  end if;

  -- Luật R-CRM-01: lead đã có cơ hội đang dùng thì cảnh báo kèm mã cũ; xác nhận lần hai mới tạo thêm.
  select string_agg(code, ', ' order by created_at) into v_existing
    from app.opportunity where lead_id = p_lead_id and record_status = 'DANG_DUNG';
  if v_existing is not null and not coalesce(p_confirm_existing, false) then
    perform app.raise_error('HMT_LEAD_DA_CO_CO_HOI',
      format('Lead này đã có cơ hội %s. Xác nhận nếu vẫn muốn tạo thêm.', v_existing));
  end if;

  v := jsonb_populate_record(null::app.opportunity, p_data);

  -- Luật: người phụ trách mặc định là người phụ trách lead; giao cho người khác cần quyền Giao việc.
  v_owner := coalesce(v.owner_id, v_lead.owner_id);
  if v_owner <> v_lead.owner_id and v_owner <> auth.uid() then
    perform app.assert_can('OPPORTUNITY', 'GIAO_VIEC', v_lead.branch_id);
  end if;
  perform app.assert_staff_in_branch(v_owner, v_lead.branch_id);
  if coalesce(v.supporter_id, v_lead.supporter_id) is not null then
    perform app.assert_staff_in_branch(coalesce(v.supporter_id, v_lead.supporter_id), v_lead.branch_id);
  end if;

  -- Luật R-CRM-27, 28: phụ huynh có sẵn (lead đã gắn) hoặc khớp theo SĐT; không thì tạo mới. Không ghi đè tên.
  v_parent_id := coalesce(v_lead.parent_id,
    app.find_or_create_parent(v_lead.parent_phone, v_lead.parent_name, v_lead.ward_code, v_lead.province_code,
                              v_lead.address, v_lead.branch_id));
  select code into v_parent_code from app.parent where id = v_parent_id;

  v_code := app.issue_crm_code('CO');
  insert into app.opportunity (
    code, lead_id, parent_id, branch_id, owner_id, supporter_id, need,
    source_type_code, source_code, channel_code, campaign_id, stage_code, substage_code)
  values (
    v_code, p_lead_id, v_parent_id, v_lead.branch_id, v_owner, coalesce(v.supporter_id, v_lead.supporter_id),
    case when p_data ? 'need' then v.need else v_lead.need end,
    v_lead.source_type_code, v_lead.source_code, v_lead.channel_code, v_lead.campaign_id, 'L1', null)
  returning id into v_id;

  -- Danh sách em (Đ81): em đầu của lead chép sang cơ hội; ô nào p_data có thì lấy, không thì chép từ lead.
  -- (Chọn nhiều em từ lead đưa sang làm ở DB-2.) Có ngày sinh mà không có năm sinh thì năm lấy từ ngày sinh.
  perform app.set_first_prospect('OPPORTUNITY', v_id,
    (select jsonb_strip_nulls(jsonb_build_object('student_name', f.full_name, 'student_birth_date', f.birth_date,
                               'student_birth_year', case when p_data ? 'student_birth_date' and not p_data ? 'student_birth_year'
                                                          then null else f.birth_year end,
                               'school', f.school, 'self_rating', f.self_rating, 'goal', f.goal))
       from (select (app.lead_first(p_lead_id)).*) f)
    || coalesce((select jsonb_object_agg(k, p_data -> k)
                   from unnest(array['student_name', 'student_birth_date', 'student_birth_year', 'school', 'self_rating', 'goal']) k
                  where p_data ? k), '{}'::jsonb),
    true);

  -- Luật R-CRM-09: lead tự về C4D "Tạo cơ hội thành công" (người dùng không chọn được nhóm con này) và nhận phụ huynh.
  update app.lead set stage_code = 'C4', substage_code = 'C4D', parent_id = v_parent_id where id = p_lead_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'parent_id', v_parent_id, 'parent_code', v_parent_code);
end;
$function$;
