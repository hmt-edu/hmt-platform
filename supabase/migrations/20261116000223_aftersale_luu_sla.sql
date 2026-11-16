-- Code B (16/11/2026), Aftersale lát 5, migration 223: lưu cấu hình SLA (canvas 9189: CSN09_sla, CSN09_chua_luu).
-- Luật: docs/spec/de-xuat-luat-aftersale.md AS-07 (hạn phản hồi đầu và hạn xử lý xong theo loại × mức độ; hạn riêng nhóm con đè lên), AS-13 (công tắc).
-- Ticket đã tạo giữ nguyên hạn đã chụp lúc tạo (không tính lại); chỉ ticket tạo sau khi lưu theo số mới. Mọi sửa ghi nhật ký (trigger audit của apply_standard).
select set_config('hmt.migration', 'on', false);

-- app.save_ticket_sla(bảng hạn, hạn riêng): lưu một lần cả bảng loại × mức độ và các hạn riêng của nhóm con. Ai gọi: Quản trị · Sửa (Admin).
-- p_rules: [{ticket_type, priority_code, response_hours, resolve_hours}] (có thể chỉ gửi các dòng đổi). p_overrides: [{category_code, resolve_hours}] ; resolve_hours null là «Bỏ hạn riêng».
-- Luật: giờ là số nguyên dương; hạn xử lý xong không nhỏ hơn hạn phản hồi đầu (AS-07). Cả lô một giao dịch: một dòng sai thì không lưu dòng nào.
create or replace function app.save_ticket_sla(p_rules jsonb default '[]'::jsonb, p_overrides jsonb default '[]'::jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r jsonb;
  v_type text;
  v_priority text;
  v_resp integer;
  v_res integer;
  v_cat text;
  v_hours integer;
  v_cur_resp integer;
  v_cur_res integer;
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  -- Luật AS-07: bảng loại × mức độ.
  for r in select * from jsonb_array_elements(coalesce(p_rules, '[]'::jsonb)) loop
    v_type := r ->> 'ticket_type';
    v_priority := r ->> 'priority_code';
    select s.response_hours, s.resolve_hours into v_cur_resp, v_cur_res from app.ticket_sla_rule s where s.ticket_type = v_type and s.priority_code = v_priority;
    if not found then
      perform app.raise_error('HMT_SLA_DONG_SAI', 'Không có dòng hạn cho loại ticket và mức độ này.');
    end if;
    v_resp := coalesce(nullif(r ->> 'response_hours', '')::integer, v_cur_resp);
    v_res := coalesce(nullif(r ->> 'resolve_hours', '')::integer, v_cur_res);
    if v_resp < 1 or v_res < 1 then
      perform app.raise_error('HMT_SLA_GIO_SAI', 'Số giờ phải là số nguyên từ 1 trở lên.');
    end if;
    if v_res < v_resp then
      perform app.raise_error('HMT_SLA_GIO_SAI', 'Hạn xử lý xong không được nhỏ hơn hạn phản hồi đầu tiên.');
    end if;
    update app.ticket_sla_rule set response_hours = v_resp, resolve_hours = v_res where ticket_type = v_type and priority_code = v_priority;
  end loop;
  -- Luật AS-07: hạn riêng của nhóm con (đè lên bảng trên); null là bỏ hạn riêng.
  for r in select * from jsonb_array_elements(coalesce(p_overrides, '[]'::jsonb)) loop
    v_cat := r ->> 'category_code';
    if not exists (select from app.ticket_category c where c.code = v_cat and c.kind = 'SUBGROUP') then
      perform app.raise_error('HMT_TICKET_NHOM_SAI', 'Nhóm con không có.');
    end if;
    v_hours := nullif(r ->> 'resolve_hours', '')::integer;
    if v_hours is not null and v_hours < 1 then
      perform app.raise_error('HMT_SLA_GIO_SAI', 'Số giờ phải là số nguyên từ 1 trở lên.');
    end if;
    update app.ticket_category set resolve_hours_override = v_hours where code = v_cat;
  end loop;
end;
$$;
revoke execute on function app.save_ticket_sla(jsonb, jsonb) from public, anon, authenticated;
grant execute on function app.save_ticket_sla(jsonb, jsonb) to authenticated;

select set_config('hmt.migration', '', false);
