-- Lead đổi giai đoạn sang giai đoạn có nhóm con chọn tay (C2, C3, C4) thì bắt buộc chọn nhóm con (R-CRM-41, QĐ-Đ183, Đ185).
-- C1 không có nhóm con. C4D do hệ thống gắn khi tạo cơ hội nên không tính là nhóm con chọn tay (R-CRM-09).
-- Danh sách nhóm con lấy từ danh mục LEAD_SUBSTAGE (không viết cứng).
-- Migration này đặt SAU 048 (#97) khi gộp.

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
  -- Luật R-CRM-41: giai đoạn có nhóm con chọn tay thì phải chọn một nhóm con.
  if p_substage_code is null and exists (
       select from app.catalog_item s
         join app.catalog_item st on st.id = s.parent_id and st.catalog_code = 'LEAD_STAGE'
        where s.catalog_code = 'LEAD_SUBSTAGE' and st.code = p_stage_code and s.is_active and s.code <> 'C4D') then
    perform app.raise_error('HMT_THIEU_NHOM_CON',
      format('Chọn nhóm con khi chuyển lead sang giai đoạn %s.', p_stage_code));
  end if;
  update app.lead set stage_code = p_stage_code, substage_code = p_substage_code where id = p_id;
end;
$$;
