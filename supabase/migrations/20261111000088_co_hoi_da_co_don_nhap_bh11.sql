-- Q-181 (BH-11, R-TIEN-39): tạo đơn thẳng từ cơ hội mà cơ hội đã có đơn Nháp thì chặn kèm mã đơn Nháp cũ; xác nhận mới tạo thêm.
-- Hàm trợ giúp: app.opportunity_draft_order_code (mã đơn Nháp mới nhất của cơ hội) và app.get_opportunity_draft_order (cho hộp BH-11).
-- Đổi chữ ký app.create_order_from_opportunity: thêm p_confirm_existing_draft (mặc định false).

create or replace function app.opportunity_draft_order_code(p_opportunity_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  -- Đơn Nháp còn sống của cơ hội: lấy đơn mới nhất. Đơn Huỷ không tính (R-CRM-19: đơn Nháp không dùng nữa thì Huỷ).
  select o.code from app.sales_order o
   where o.opportunity_id = p_opportunity_id and o.status_code = 'NHAP'
   order by o.created_at desc, o.code desc limit 1;
$$;
revoke execute on function app.opportunity_draft_order_code(uuid) from public, anon, authenticated;

-- Dữ liệu cho hộp BH-11: đơn Nháp mới nhất của cơ hội (id, mã, phụ huynh, tổng tiền, tạo lúc, người tạo) hoặc null.
-- Ai được gọi: người có quyền Tạo đơn hàng ở cơ sở của cơ hội (cùng điều kiện tạo đơn).
create or replace function app.get_opportunity_draft_order(p_opportunity_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_out jsonb;
begin
  select * into v_opp from app.opportunity where id = p_opportunity_id;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', v_opp.branch_id);
  select jsonb_build_object('id', o.id, 'code', o.code, 'parent_name', p.full_name, 'parent_code', p.code,
                            'total_amount', o.total_amount, 'created_at', o.created_at, 'created_by_name', app.staff_display_name(o.created_by))
    into v_out
    from app.sales_order o
    left join app.parent p on p.id = o.parent_id
   where o.opportunity_id = v_opp.id and o.status_code = 'NHAP'
   order by o.created_at desc, o.code desc limit 1;
  return v_out;
end;
$$;
revoke execute on function app.get_opportunity_draft_order(uuid) from public, anon;
grant execute on function app.get_opportunity_draft_order(uuid) to authenticated;

drop function app.create_order_from_opportunity(uuid, jsonb, uuid);

create or replace function app.create_order_from_opportunity(p_opportunity_id uuid, p_lines jsonb, p_payment_term_id uuid default null, p_confirm_existing_draft boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_draft_code text;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
  end if;
  select * into v_opp from app.opportunity where id = p_opportunity_id;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', v_opp.branch_id);
  perform app.require_feature('BAN_HANG', v_opp.branch_id); -- Luật Đ173
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo đơn được.');
  end if;
  -- Luật R-CRM-16: chưa ở L8 thì không tạo được đơn từ cơ hội.
  if v_opp.stage_code <> 'L8' then
    perform app.raise_error('HMT_CHUA_O_L8', 'Cơ hội cần ở L8 (phụ huynh đã thanh toán) mới tạo được đơn hàng.');
  end if;
  -- Luật R-TIEN-39 (BH-11, Q-181): cơ hội đã có đơn Nháp mà chưa xác nhận thì từ chối, kèm mã đơn Nháp cũ; giao diện hiện hộp
  -- "Mở đơn cũ" / "Vẫn tạo" (gửi lại với p_confirm_existing_draft = true). Chỉ áp cho đơn tạo thẳng từ cơ hội, không áp cho đơn từ báo giá.
  if not coalesce(p_confirm_existing_draft, false) then
    v_draft_code := app.opportunity_draft_order_code(v_opp.id);
    if v_draft_code is not null then
      perform app.raise_error('HMT_CO_DON_NHAP', format('Cơ hội này đã có đơn Nháp %s. Mở đơn cũ hoặc xác nhận vẫn tạo thêm.', v_draft_code));
    end if;
  end if;
  select code into v_branch_code from app.branch where id = v_opp.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  insert into app.sales_order (code, branch_id, opportunity_id, parent_id, priced_on)
  values (v_code, v_opp.branch_id, v_opp.id, v_opp.parent_id, v_on)
  returning id into v_id;
  perform app.order_write_priced_lines(v_id, v_opp.id, v_opp.branch_id, p_lines, v_on);
  -- Luật Đ260, R-CRM-19: điều khoản thanh toán áp ngay trong cùng giao dịch tạo đơn; điều khoản sai thì cả giao dịch lùi.
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  -- Nhật ký (Q-145): dòng ưu đãi linh hoạt nhập thẳng ở đơn.
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, app.order_flexible_note(v_id, false));
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

revoke execute on function app.create_order_from_opportunity(uuid, jsonb, uuid, boolean) from public, anon;
grant execute on function app.create_order_from_opportunity(uuid, jsonb, uuid, boolean) to authenticated;
