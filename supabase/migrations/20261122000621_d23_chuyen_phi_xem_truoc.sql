-- D-23-08 (Chat chốt 23/11/2026 02:52; migration 621; rủi ro CAO: tiền). CS-10 Chuyển phí theo canvas CSN06d: XEM TRƯỚC bảng tính và kiểm đơn nhận. THỰC HIỆN vẫn như migration 567
-- (chuyển số dư cho phụ huynh nhận), CHƯA trừ vào đơn nhận. Làm gì: (1) app.compute_fee_transfer (nội bộ): giờ mua, giờ đã học, giá sau chiết khấu, đã đóng, giá trị chuyển, giờ tặng huỷ,
-- và nếu có đơn nhận: giá trị đơn, phụ huynh đóng thêm; chặn HMT_CHUYEN_PHI_AM khi giá trị chuyển lớn hơn giá trị đơn nhận, HMT_CHUYEN_PHI_DON_SAI khi đơn không hợp lệ;
-- (2) app.preview_fee_transfer (giao diện gọi, Ticket · Sửa); (3) app.list_fee_transfer_orders (đơn chọn được); (4) create_ticket_task (bản 618) kiểm kind_code và order_id của phiếu Chuyển phí.
-- Luật: R-TIEN-32, R-TIEN-33, R-GD-16, R-V2-24. Chỉ mục: không thêm (không bảng, cột mới; đọc đơn theo khoá parent_id đã có chỉ mục).
select set_config('hmt.migration', 'on', false);

-- app.compute_fee_transfer: tính bảng chuyển phí, không ghi gì. NỘI BỘ. Đầu vào: ghi danh nguồn, phụ huynh nhận (trống = phụ huynh của ghi danh), đơn nhận (tuỳ chọn).
-- Kết quả jsonb: hours_bought, hours_used, unit_price_net, paid_amount, transfer_value, hours_gift_cancelled, order_total, extra_to_pay (hai khoá cuối null khi không có đơn nhận).
create or replace function app.compute_fee_transfer(p_enrollment_id uuid, p_to_parent_id uuid default null, p_order_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  l app.sales_order_line;
  o app.sales_order;
  v_bal jsonb;
  v_ref jsonb;
  v_parent uuid;
  v_used numeric;
  v_transfer bigint;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  select * into l from app.sales_order_line where id = e.order_line_id;
  -- Luật R-GD-16, R-TIEN-33: giá trị chuyển = giờ mua còn lại × giá sau chiết khấu chụp lúc mua; giờ tặng còn lại bị huỷ, không thành tiền (hàm tính số dư dùng chung với Dừng học).
  v_bal := app.compute_stop_balance(e.id);
  v_transfer := (v_bal ->> 'balance_amount')::bigint;
  select coalesce(sum(-g.hours), 0) into v_used from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type = 'TRU_BUOI';
  -- Số đã đóng của ghi danh lấy từ hàm tính hoàn phí toàn bộ (cùng nguồn với phiếu Hoàn học phí).
  v_ref := app.compute_refund(e.id, 'TOAN_BO');
  if p_order_id is not null then
    v_parent := coalesce(p_to_parent_id, e.parent_id);
    select * into o from app.sales_order where id = p_order_id;
    -- Luật: đơn nhận phải của đúng phụ huynh nhận số dư (chính phụ huynh hoặc anh chị em), cùng cơ sở, còn hiệu lực.
    if o.id is null or o.parent_id <> v_parent or o.branch_id <> e.branch_id or o.status_code = 'HUY' then
      perform app.raise_error('HMT_CHUYEN_PHI_DON_SAI', 'Đơn nhận phải là đơn còn hiệu lực của phụ huynh nhận số dư, cùng cơ sở.');
    end if;
    -- Luật (anh chốt): giá trị chuyển lớn hơn giá trị đơn nhận thì chặn.
    if v_transfer > o.total_amount then
      perform app.raise_error('HMT_CHUYEN_PHI_AM', 'Giá trị chuyển lớn hơn giá trị đơn nhận. Chọn đơn khác hoặc đổi kiểu chuyển.');
    end if;
  end if;
  return jsonb_build_object(
    'hours_bought', l.quantity, 'hours_used', v_used, 'unit_price_net', v_bal -> 'unit_price_net',
    'paid_amount', v_ref -> 'paid_amount', 'transfer_value', v_transfer, 'hours_gift_cancelled', v_bal -> 'hours_cancelled',
    'order_total', o.total_amount, 'extra_to_pay', case when o.id is null then null else o.total_amount - v_transfer end);
end;
$$;
revoke execute on function app.compute_fee_transfer(uuid, uuid, uuid) from public, anon, authenticated;

-- app.preview_fee_transfer: xem trước bảng chuyển phí cho giao diện. Ai: Ticket · Sửa theo cơ sở của ghi danh. Lỗi: HMT_KHONG_CO_QUYEN, HMT_CHUYEN_PHI_AM, HMT_CHUYEN_PHI_DON_SAI.
create or replace function app.preview_fee_transfer(p_enrollment_id uuid, p_to_parent_id uuid default null, p_order_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from app.enrollment where id = p_enrollment_id;
  if v_branch is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('TICKET', 'SUA', v_branch);
  return app.compute_fee_transfer(p_enrollment_id, p_to_parent_id, p_order_id);
end;
$$;
grant execute on function app.preview_fee_transfer(uuid, uuid, uuid) to authenticated;

-- app.list_fee_transfer_orders: đơn chọn làm «Đơn nhận» (đơn còn hiệu lực của phụ huynh nhận, cùng cơ sở). Ai: Ticket · Sửa. Kết quả: mảng {id, code, status_code, total_amount}, mới nhất trước, tối đa cỡ trang mặc định.
create or replace function app.list_fee_transfer_orders(p_enrollment_id uuid, p_to_parent_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('TICKET', 'SUA', e.branch_id);
  return coalesce((select jsonb_agg(x order by x.created_at desc) from (
            select o.id, o.code, o.status_code, o.total_amount, o.created_at
              from app.sales_order o
             where o.parent_id = coalesce(p_to_parent_id, e.parent_id) and o.branch_id = e.branch_id and o.status_code <> 'HUY'
             order by o.created_at desc
             limit app.get_setting_int('list_page_size_default')) x), '[]'::jsonb);
end;
$$;
grant execute on function app.list_fee_transfer_orders(uuid, uuid) to authenticated;

create or replace function app.create_ticket_task(p_ticket_id uuid, p_type text, p_reason text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_biz text;
  v_levels text[];
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_entity text;
  v_key text;
  v_enr app.enrollment;
  v_enr_id uuid;
  v_dest uuid;
begin
  select * into t from app.ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không tạo phiếu được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập lý do của phiếu.');
  end if;
  -- QT-15: cấp duyệt theo phiên bản có hiệu lực tại ngày lập phiếu (app.ticket_task_levels); phiếu chụp lại cấp duyệt lúc tạo (ticket_task.levels).
  v_levels := app.ticket_task_levels(p_type, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  if v_levels is null then
    perform app.raise_error('HMT_PHIEU_LOAI_SAI', 'Loại phiếu nghiệp vụ không có.');
  end if;
  -- Luật R-V2-24: nhóm con của ticket phải có phiếu nghiệp vụ đúng loại.
  select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
  if v_biz is distinct from p_type then
    perform app.raise_error('HMT_PHIEU_KHAC_NHOM', 'Nhóm con của ticket này không dùng loại phiếu đã chọn.');
  end if;
  -- Luật AS-10: mỗi ticket một phiếu đang mở.
  if exists (select from app.ticket_task k where k.ticket_id = t.id and k.status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO', 'Ticket này đã có một phiếu đang mở. Xong hoặc huỷ phiếu đó trước.');
  end if;
  -- CS-14 (anh chốt 23/11/2026, thẻ D-23-07): phiếu Dừng học chọn «Xử lý tiền còn lại» (HOAN_TIEN hoặc GIU_SO_DU, trống = GIU_SO_DU như trước) và «Ngày dừng»
  -- (chỉ ghi nhận, không đổi cách tính giờ; không sau hôm nay quá tham số stop_date_max_days_ahead). Luật R-GD-16, R-TIEN-28, R-TIEN-33.
  if p_type = 'DUNG_HOC' then
    if nullif(p_payload ->> 'money_mode', '') is not null and p_payload ->> 'money_mode' not in ('HOAN_TIEN', 'GIU_SO_DU') then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Xử lý tiền còn lại chỉ chọn Hoàn tiền hoặc Giữ số dư.');
    end if;
    if nullif(p_payload ->> 'stop_date', '') is not null then
      begin
        if (p_payload ->> 'stop_date')::date > (now() at time zone 'Asia/Ho_Chi_Minh')::date + app.get_setting_int('stop_date_max_days_ahead', t.branch_id)::integer then
          perform app.raise_error('HMT_DUNG_HOC_NGAY_SAI', 'Ngày dừng không được sau hôm nay quá số ngày cho phép.');
        end if;
      exception when invalid_datetime_format or datetime_field_overflow then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ngày dừng không hợp lệ.');
      end;
    end if;
  end if;
  -- Kiểm sớm dữ liệu phiếu Cập nhật hồ sơ.
  if p_type = 'CAP_NHAT_HO_SO' then
    v_entity := p_payload ->> 'entity';
    if v_entity is null or v_entity not in ('PARENT', 'STUDENT') or jsonb_typeof(p_payload -> 'changes') is distinct from 'object' or (p_payload -> 'changes') = '{}'::jsonb then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn hồ sơ (phụ huynh hoặc học sinh) và ít nhất một trường cần sửa.');
    end if;
    if v_entity = 'STUDENT' and t.student_id is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.');
    end if;
    for v_key in select jsonb_object_keys(p_payload -> 'changes') loop
      if not exists (select from app.ticket_task_field f where f.entity = v_entity and f.field_code = v_key and f.is_active) then
        perform app.raise_error('HMT_PHIEU_TRUONG_SAI', 'Trường này không được sửa bằng phiếu Cập nhật hồ sơ.');
      end if;
    end loop;
  -- Luật R-V2-24, R-CS-02: phiếu Bảo lưu, Chuyển lớp mang dữ liệu để thực hiện bằng hàm của cụm Ghi danh (migration 234); kiểm sớm để báo lỗi ngay lúc tạo.
  elsif p_type in ('BAO_LUU', 'CHUYEN_LOP', 'CHUYEN_PHI') then
    begin
      v_enr_id := nullif(p_payload ->> 'enrollment_id', '')::uuid;
    exception when others then
      v_enr_id := null;
    end;
    select * into v_enr from app.enrollment where id = v_enr_id;
    if v_enr.id is null or t.student_id is null or v_enr.student_id is distinct from t.student_id or v_enr.branch_id <> t.branch_id then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn ghi danh của học sinh gắn với ticket (cùng cơ sở).');
    end if;
    if nullif(btrim(coalesce(p_payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lý do.');
    end if;
    if p_type = 'CHUYEN_PHI' then
      -- CS-10 (anh chốt 23:17, R-GD-10 mục 9): ghi danh cũ phải còn hiệu lực; phụ huynh nhận số dư tuỳ chọn (anh chị em), trống thì giữ ở phụ huynh của ghi danh.
      if v_enr.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không còn hiệu lực để chuyển phí.');
      end if;
      if nullif(p_payload ->> 'to_parent_id', '') is not null
         and not exists (select from app.parent pa where pa.id = nullif(p_payload ->> 'to_parent_id', '')::uuid) then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phụ huynh nhận số dư không tồn tại.');
      end if;
      -- D-23-08 (Chat chốt 02:52): kiểu chuyển (môn khác, gói khác, anh chị em) và đơn nhận (tuỳ chọn) kiểm sớm; đơn nhận chỉ để tham khảo, KHÔNG trừ vào đơn lúc thực hiện.
      if nullif(p_payload ->> 'kind_code', '') is not null and p_payload ->> 'kind_code' not in ('SANG_MON', 'SANG_GOI', 'SANG_ANH_CHI_EM') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Kiểu chuyển chỉ chọn Sang môn khác, Sang gói khác hoặc Sang anh chị em.');
      end if;
      if nullif(p_payload ->> 'order_id', '') is not null then
        perform app.compute_fee_transfer(v_enr.id, nullif(p_payload ->> 'to_parent_id', '')::uuid, (p_payload ->> 'order_id')::uuid);
      end if;
    elsif p_type = 'BAO_LUU' then
      if p_payload ->> 'resume' = 'true' then
        -- C30/C31 (R-GD-09, R-CS-02): Tiếp tục học (quay lại sớm) là hành động thứ ba của phiếu Bảo lưu; ghi danh phải đang có bảo lưu chạy.
        if not exists (select from app.enrollment_hold h where h.enrollment_id = v_enr.id and h.status_code = 'DANG_BAO_LUU') then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không có bảo lưu đang chạy để tiếp tục học.');
        end if;
      elsif coalesce(nullif(p_payload ->> 'months', '')::integer, 0) < 1 then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Nhập số tháng bảo lưu (từ 1).');
      end if;
    else
      -- CS-07 (anh chốt 23:17, R-GD-10, R-CS-07): Chuyển cơ sở đi hai cấp duyệt tuần tự (quản lý cơ sở ĐI rồi quản lý cơ sở ĐẾN); lớp mới và ngày bắt đầu do quản lý cơ sở ĐẾN chọn ở cấp của họ, nên lúc tạo chỉ cần cơ sở đích.
      if p_payload ->> 'kind_code' = 'CHUYEN_CO_SO' then
        begin
          v_dest := nullif(p_payload ->> 'dest_branch_id', '')::uuid;
        exception when others then
          v_dest := null;
        end;
        if v_dest is null or v_dest = t.branch_id
           or not exists (select from app.branch b where b.id = v_dest and b.is_active and not b.is_office) then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn cơ sở đích: cơ sở dạy học đang hoạt động, khác cơ sở của ticket.');
        end if;
        v_levels := array['QUAN_LY_CO_SO', 'QUAN_LY_CO_SO_DICH'];
      elsif nullif(p_payload ->> 'to_class_id', '') is null or nullif(p_payload ->> 'start_date', '') is null or nullif(p_payload ->> 'kind_code', '') is null then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp mới, ngày bắt đầu và loại chuyển.');
      end if;
    end if;
  end if;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('PNV', v_branch_code);
  insert into app.ticket_task (code, ticket_id, branch_id, task_type, reason, payload, levels, dest_branch_id)
  values (v_code, t.id, t.branch_id, p_type, v_reason, coalesce(p_payload, '{}'::jsonb), v_levels, v_dest) returning id into v_id;
  perform app.ticket_task_log((select k from app.ticket_task k where k.id = v_id), 'TAO', null, 'NHAP', null);
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

select set_config('hmt.migration', '', false);
