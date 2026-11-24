-- D-23-49 (Chat giao 24/11/2026 14:08; anh Trường chốt 14:04 phương án A; rủi ro CAO: tiền). Cho ghi danh «Chờ xếp lớp» được HOÀN PHÍ và DỪNG HỌC.
-- Luật: R-TIEN-28, R-TIEN-31, R-GD-16, R-GD-05 (spec không cấm; chỉ code chặn). Mọi chỗ kiểm tình trạng ghi danh trong luồng Hoàn học phí và Dừng học thêm CHO_XEP_LOP vào danh sách được phép;
-- DA_KET_THUC, DA_HUY, DUNG, HOAN_PHI... vẫn bị chặn. KHÔNG đổi công thức tiền (app.compute_refund, app.compute_stop_balance giữ nguyên: giờ đã học = 0 nên tiền hoàn = tiền đã đóng - phí xử lý).
-- Chặn «đã có hoàn phí dở» của migration 659 và 662 giữ nguyên. Mỗi hàm dưới đây là bản MỚI NHẤT trước đó, chỉ đổi danh sách tình trạng ghi danh (không đổi gì khác).
-- Chỉ mục: không thêm (không đổi truy vấn).
select set_config('hmt.migration', 'on', false);

-- app.create_refund_request: Tạo yêu cầu hoàn phí (R-TIEN-28, R-TIEN-31). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.create_refund_request(
  p_enrollment_id uuid, p_kind text, p_hours numeric, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('HOAN_PHI', e.branch_id);
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để hoàn phí.');
  end if;
  perform app.assert_catalog_code_active('REFUND_REASON', p_reason_code);
  if exists (select from app.refund_request where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET')) then
    perform app.raise_error('HMT_HOAN_PHI_DANG_MO', 'Ghi danh này đã có một yêu cầu hoàn phí chưa xong.');
  end if;
  v := app.compute_refund(e.id, p_kind, p_hours);
  -- Luật R-V2-24 (T6): bắt buộc ticket Aftersale Hoàn học phí đúng học sinh (đặt sau các kiểm cũ để mã lỗi cũ không đổi).
  perform app.assert_refund_ticket(p_ticket_ref, e.student_id, 'HOAN_PHI', e.branch_id);
  insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, note, ticket_ref,
                                  hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net,
                                  base_amount, fee_percent, fee_amount, refund_amount)
  values (e.id, e.student_id, e.branch_id, p_kind, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_refund')::numeric, (v ->> 'paid_amount')::bigint, (v ->> 'hours_used')::numeric,
          (v ->> 'unit_price_base')::bigint, round((v ->> 'unit_price_net')::numeric, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
          (v ->> 'base_amount')::bigint,
          (v ->> 'fee_percent')::numeric, (v ->> 'fee_amount')::bigint, (v ->> 'refund_amount')::bigint)
  returning id into v_id;
  return v_id;
end;
$$;

-- app.apply_refund_request: Thực hiện hoàn phí thẳng qua phiếu (R-TIEN-28, R-V2-24). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.apply_refund_request(
  p_enrollment_id uuid, p_kind text, p_hours numeric, p_reason_code text, p_note text default null, p_ticket_ref text default null,
  p_manager_by uuid default null, p_accountant_by uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
  v_pv uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.require_feature('HOAN_PHI', e.branch_id);
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để hoàn phí.');
  end if;
  perform app.assert_catalog_code_active('REFUND_REASON', p_reason_code);
  if exists (select from app.refund_request where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET')) then
    perform app.raise_error('HMT_HOAN_PHI_DANG_MO', 'Ghi danh này đã có một yêu cầu hoàn phí chưa xong.');
  end if;
  v := app.compute_refund(e.id, p_kind, p_hours);
  insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, note, ticket_ref,
                                  hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net,
                                  base_amount, fee_percent, fee_amount, refund_amount, status_code, manager_by, manager_at)
  values (e.id, e.student_id, e.branch_id, p_kind, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_refund')::numeric, (v ->> 'paid_amount')::bigint, (v ->> 'hours_used')::numeric,
          (v ->> 'unit_price_base')::bigint, round((v ->> 'unit_price_net')::numeric, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
          (v ->> 'base_amount')::bigint,
          (v ->> 'fee_percent')::numeric, (v ->> 'fee_amount')::bigint, (v ->> 'refund_amount')::bigint,
          'CHO_KE_TOAN', p_manager_by, now())
  returning id into v_id;
  v_pv := app.finish_refund_request(v_id);
  -- Ghi kế toán duyệt đúng người đã duyệt cấp kế toán ở phiếu (lõi ghi người gọi; người gọi ở đây là người bấm Thực hiện).
  if p_accountant_by is not null then
    update app.refund_request set accountant_by = p_accountant_by where id = v_id;
  end if;
  return v_pv;
end;
$$;

-- app.finish_refund_request: Kế toán duyệt xong, ra phiếu chi (R-TIEN-28, R-TIEN-31). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.finish_refund_request(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
  e app.enrollment;
  v jsonb;
  v_left numeric;
  v_hours numeric;
  v_branch_code text;
  v_code text;
  v_voucher uuid;
begin
  r := app.refund_request_for_update(p_id, array['CHO_KE_TOAN']);
  select * into e from app.enrollment where id = r.enrollment_id for update;
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh không còn hiệu lực để hoàn phí.');
  end if;
  -- Luật chụp lại số tiền: tính lại, lệch thì chặn.
  v := app.compute_refund(e.id, r.kind_code, case when r.kind_code = 'MOT_PHAN' then r.hours_refund end);
  if (v ->> 'refund_amount')::bigint <> r.refund_amount or (v ->> 'hours_used')::numeric <> r.hours_used then
    perform app.raise_error('HMT_HOAN_PHI_SO_LIEU_DOI', 'Số liệu đã thay đổi từ lúc tạo yêu cầu (giờ đã học hoặc tiền đã đóng). Hãy huỷ và tạo yêu cầu mới.');
  end if;
  -- Sổ giờ ngược dấu (R-GD-04): hoàn toàn bộ trừ hết giờ còn lại (giờ tặng bị huỷ, R-TIEN-28); hoàn một phần trừ đúng giờ hoàn.
  v_left := app.enrollment_hours_balance(e.id);
  v_hours := case when r.kind_code = 'TOAN_BO' then greatest(v_left, 0) else r.hours_refund end;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('PC', v_branch_code);
  if v_hours > 0 then
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, source_ref)
    values (e.id, e.branch_id, 'DIEU_CHINH', -v_hours, 'KHAC', 'Hoàn phí ' || v_code, v_code); -- lý do «Khác» (bắt buộc ghi chú); không thêm mục vào danh mục lý do điều chỉnh
  end if;
  -- Hoàn toàn bộ: ghi danh sang Hoàn phí, đóng dòng xếp lớp đang mở.
  if r.kind_code = 'TOAN_BO' then
    update app.enrollment_class set end_date = greatest(current_date, start_date), end_reason = 'DUNG'
     where enrollment_id = e.id and end_date is null;
    update app.enrollment set status_code = 'HOAN_PHI' where id = e.id;
  end if;
  insert into app.payment_voucher (code, refund_request_id, branch_id, parent_id, amount)
  values (v_code, r.id, r.branch_id, e.parent_id, r.refund_amount)
  returning id into v_voucher;
  update app.refund_request set status_code = 'DA_DUYET', accountant_by = (select auth.uid()), accountant_at = now() where id = r.id;
  return v_voucher;
end;
$$;

-- app.create_enrollment_stop: Tạo yêu cầu dừng học (R-GD-16). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.create_enrollment_stop(p_enrollment_id uuid, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('DUNG_HOC', e.branch_id);
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_DUNG_HOC_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để dừng học.');
  end if;
  perform app.assert_catalog_code_active('STOP_REASON', p_reason_code);
  -- Chưa kiểm chéo với yêu cầu Hoàn phí đang mở (bảng nằm ở migration 231); ghi danh sang Dừng/Hoàn phí khi duyệt nên yêu cầu thứ hai bị chặn ở bước duyệt.
  if exists (select from app.enrollment_stop where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN')) then
    perform app.raise_error('HMT_DUNG_HOC_DANG_MO', 'Ghi danh này đã có một yêu cầu dừng học chưa xong.');
  end if;
  v := app.compute_stop_balance(e.id);
  -- Luật R-V2-24 (T6): bắt buộc ticket Aftersale Dừng học đúng học sinh.
  perform app.assert_refund_ticket(p_ticket_ref, e.student_id, 'DUNG_HOC', e.branch_id);
  insert into app.enrollment_stop (enrollment_id, student_id, parent_id, branch_id, reason_code, note, ticket_ref,
                                   hours_left, hours_paid_left, hours_cancelled, unit_price_net, balance_amount)
  values (e.id, e.student_id, e.parent_id, e.branch_id, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_left')::numeric, (v ->> 'hours_paid_left')::numeric, (v ->> 'hours_cancelled')::numeric,
          (v ->> 'unit_price_net')::numeric, (v ->> 'balance_amount')::bigint)
  returning id into v_id;
  return v_id;
end;
$$;

-- app.apply_enrollment_stop: Thực hiện dừng học thẳng qua phiếu (R-GD-16). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.apply_enrollment_stop(p_enrollment_id uuid, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.require_feature('DUNG_HOC', e.branch_id);
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_DUNG_HOC_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để dừng học.');
  end if;
  perform app.assert_catalog_code_active('STOP_REASON', p_reason_code);
  if exists (select from app.enrollment_stop where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN')) then
    perform app.raise_error('HMT_DUNG_HOC_DANG_MO', 'Ghi danh này đã có một yêu cầu dừng học chưa xong.');
  end if;
  v := app.compute_stop_balance(e.id);
  insert into app.enrollment_stop (enrollment_id, student_id, parent_id, branch_id, reason_code, note, ticket_ref,
                                   hours_left, hours_paid_left, hours_cancelled, unit_price_net, balance_amount,
                                   status_code, manager_by, manager_at)
  values (e.id, e.student_id, e.parent_id, e.branch_id, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_left')::numeric, (v ->> 'hours_paid_left')::numeric, (v ->> 'hours_cancelled')::numeric,
          (v ->> 'unit_price_net')::numeric, (v ->> 'balance_amount')::bigint, 'CHO_KE_TOAN', null, now())
  returning id into v_id;
  perform app.finish_enrollment_stop(v_id);
  return v_id;
end;
$$;

-- app.finish_enrollment_stop: Kế toán duyệt xong dừng học, giữ số dư (R-GD-16). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.finish_enrollment_stop(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
  e app.enrollment;
  v jsonb;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_KE_TOAN']);
  select * into e from app.enrollment where id = s.enrollment_id for update;
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_DUNG_HOC_GHI_DANH_SAI', 'Ghi danh không còn hiệu lực để dừng học.');
  end if;
  v := app.compute_stop_balance(e.id);
  if (v ->> 'balance_amount')::bigint <> s.balance_amount or (v ->> 'hours_left')::numeric <> s.hours_left then
    perform app.raise_error('HMT_DUNG_HOC_SO_LIEU_DOI', 'Số liệu đã thay đổi từ lúc tạo yêu cầu (giờ đã học hoặc tiền đã đóng). Hãy huỷ và tạo yêu cầu mới.');
  end if;
  if s.hours_left > 0 then
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, source_ref)
    values (e.id, e.branch_id, 'DIEU_CHINH', -s.hours_left, 'KHAC', 'Dừng học, giữ số dư', 'STOP-' || s.id::text); -- lý do «Khác» (bắt buộc ghi chú)
  end if;
  update app.enrollment_class set end_date = greatest(current_date, start_date), end_reason = 'DUNG'
   where enrollment_id = e.id and end_date is null;
  update app.enrollment set status_code = 'DUNG' where id = e.id;
  if s.balance_amount > 0 then
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, enrollment_id, source_ref, note)
    values (s.parent_id, s.student_id, s.branch_id, 'TU_DUNG_HOC', s.balance_amount, (now() at time zone 'Asia/Ho_Chi_Minh')::date, e.id, 'STOP-' || s.id::text, 'Dừng học, giữ thành số dư');
  end if;
  update app.enrollment_stop set status_code = 'DA_DUYET', accountant_by = (select auth.uid()), accountant_at = now() where id = s.id;
end;
$$;

-- app.create_ticket_task: Tạo phiếu nghiệp vụ (kiểm tình trạng ghi danh sớm). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
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
      -- D-23-50: Chuyển phí chưa cho ghi danh Chờ xếp lớp (chờ anh Trường chốt): giữ danh sách cũ.
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
      -- R-CS-03 (thẻ C-23-13): chuyển lớp cùng cơ sở chỉ sang lớp CÙNG MÔN; khác môn đi nhánh Chuyển phí. Chặn ngay lúc tạo phiếu.
      if p_payload ->> 'kind_code' is distinct from 'CHUYEN_CO_SO'
         and exists (select from app.class tc where tc.id = nullif(p_payload ->> 'to_class_id', '')::uuid
                      and tc.subject_code is distinct from app.enrollment_current_subject(v_enr.id)) then
        perform app.raise_error('HMT_CHUYEN_LOP_KHAC_MON', 'Khác môn: dùng Chuyển phí.');
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

-- app.ticket_task_check_scope: Trigger phạm vi dữ liệu phiếu nghiệp vụ (migration 636). Chỉ thêm CHO_XEP_LOP vào danh sách tình trạng ghi danh được phép.
create or replace function app.ticket_task_check_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  e app.enrollment;
  v_enr uuid;
  v_to uuid;
  v_status_check boolean;
begin
  if new.task_type not in ('HOAN_PHI', 'DUNG_HOC', 'CHUYEN_PHI') then
    return new;
  end if;
  -- Di chuyển dữ liệu (migration, cờ hmt.migration) không đi qua luật phạm vi: người dùng không bật được cờ này.
  if app.is_migration() then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    -- Luật: payload của ba loại phiếu này không đổi sau khi tạo (người duyệt thấy gì thì thực hiện đúng cái đó).
    if new.payload is distinct from old.payload then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Không sửa nội dung phiếu sau khi đã tạo. Huỷ phiếu và tạo phiếu mới.');
    end if;
    -- Chỉ kiểm lại lúc trình duyệt (Nháp sang Chờ duyệt: ghi danh phải còn hiệu lực lúc người duyệt nhận phiếu). Payload đã khoá nên các bước sau không cần kiểm lại.
    if new.status_code is not distinct from old.status_code or new.status_code <> 'CHO_DUYET' then
      return new;
    end if;
  end if;
  select * into t from app.ticket where id = new.ticket_id;
  begin
    v_enr := nullif(new.payload ->> 'enrollment_id', '')::uuid;
  exception when others then
    v_enr := null;
  end;
  select * into e from app.enrollment where id = v_enr;
  -- Luật phạm vi: ghi danh phải của đúng học sinh gắn với ticket và đúng cơ sở của ticket (chặn em khác, cơ sở khác).
  if e.id is null or t.student_id is null or e.student_id is distinct from t.student_id or e.branch_id is distinct from t.branch_id or e.branch_id is distinct from new.branch_id then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn ghi danh của học sinh gắn với ticket (cùng cơ sở).');
  end if;
  -- Luật trạng thái: ghi danh còn hiệu lực lúc tạo và lúc trình duyệt (sau khi thực hiện, ghi danh đổi trạng thái nên không kiểm lại).
  v_status_check := tg_op = 'INSERT' or new.status_code = 'CHO_DUYET';
  -- D-23-50: chỉ phiếu Hoàn học phí và Dừng học nhận ghi danh Chờ xếp lớp (anh chốt 24/11); Bảo lưu, Chuyển lớp, Chuyển phí... giữ danh sách cũ để không tạo, gửi duyệt rồi mới bị chặn ở bước Thực hiện.
  if v_status_check and e.status_code not in (case when new.task_type in ('HOAN_PHI', 'DUNG_HOC') then 'CHO_XEP_LOP' else 'DA_XEP_LOP' end, 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không còn hiệu lực.');
  end if;
  if tg_op = 'INSERT' then
    -- Luật R-TIEN-28 (Hoàn học phí): kiểm sớm loại hoàn và giờ hoàn bằng đúng hàm tính hoàn phí; lỗi trả mã của hàm đó.
    if new.task_type = 'HOAN_PHI' then
      if coalesce(nullif(new.payload ->> 'kind', ''), '') not in ('TOAN_BO', 'MOT_PHAN') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn loại hoàn: toàn bộ hoặc một phần.');
      end if;
      perform app.compute_refund(e.id, new.payload ->> 'kind', nullif(new.payload ->> 'hours', '')::numeric);
    end if;
    -- Luật R-TIEN-33 (Chuyển phí): phụ huynh nhận số dư (tuỳ chọn) phải tồn tại và thuộc cùng cơ sở của ticket.
    if new.task_type = 'CHUYEN_PHI' and nullif(new.payload ->> 'to_parent_id', '') is not null then
      begin
        v_to := (new.payload ->> 'to_parent_id')::uuid;
      exception when others then
        v_to := null;
      end;
      if v_to is null or not exists (select from app.parent pa where pa.id = v_to and pa.branch_id = t.branch_id) then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phụ huynh nhận số dư phải thuộc cùng cơ sở với ticket.');
      end if;
    end if;
  end if;
  return new;
end;
$$;

-- app.get_task_form_options: danh sách ghi danh trong hộp tạo phiếu. Chỉ thêm CHO_XEP_LOP (không ẩn ghi danh Chờ xếp lớp khỏi danh sách chọn).
create or replace function app.get_task_form_options(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_ticket_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  return jsonb_build_object(
    -- Ghi danh của học sinh gắn ticket, cùng cơ sở (đúng điều kiện create_ticket_task kiểm).
    'enrollments', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'code', e.code, 'status_code', e.status_code, 'subject_code', e.subject_code,
               'class_id', ec.class_id, 'class_code', c.code,
               'remaining_hours', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = e.id), 0)::numeric(6, 2))
             order by e.code)
        from app.enrollment e
        left join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
        left join app.class c on c.id = ec.class_id
       where e.student_id = t.student_id and e.branch_id = t.branch_id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')), '[]'::jsonb),
    -- C30: bảo lưu đang chạy của học sinh (để chọn khi Gia hạn bảo lưu, R-GD-09); hàm áp dụng kiểm lại bản này đang chạy và đúng ghi danh.
    'holds', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'enrollment_id', h.enrollment_id, 'start_date', h.start_date, 'end_date', h.end_date) order by h.end_date)
                         from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id
                        where e.student_id = t.student_id and h.branch_id = t.branch_id and h.status_code = 'DANG_BAO_LUU'), '[]'::jsonb),
    -- C60: lý do dừng học (danh mục STOP_REASON) cho phiếu Dừng học.
    'stop_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'STOP_REASON' and i.is_active), '[]'::jsonb),
    -- C60 CS-11: buổi sắp tới của các lớp học sinh đang học (để chọn buổi cần dời).
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'class_code', x.class_code, 'session_no', x.session_no, 'date', x.session_date,
                                          'start', x.start_time, 'end', x.end_time) order by x.session_date, x.start_time)
        from (select distinct s.id, c.code as class_code, s.session_no, s.session_date, s.start_time, s.end_time
                from app.enrollment e
                join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                join app.class c on c.id = ec.class_id
                join app.class_session s on s.class_id = c.id and s.status_code in ('NHAP', 'DA_CHOT')
                                        and s.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
               where e.student_id = t.student_id and e.branch_id = t.branch_id and c.branch_id = t.branch_id) x), '[]'::jsonb),
    'hold_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'HOLD_REASON' and i.is_active), '[]'::jsonb),
    'transfer_reasons', coalesce((select jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.name)
                                from app.catalog_item i where i.catalog_code = 'TRANSFER_REASON' and i.is_active), '[]'::jsonb),
    -- Lớp mới: lớp đã duyệt cùng cơ sở, còn chỗ; giao diện lọc theo môn của ghi danh. Hàm áp dụng kiểm lại trùng lớp, hết chỗ, trùng giờ.
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'code', c.code, 'subject_code', c.subject_code, 'seats_left', app.class_seats_left(c.id),
               'upcoming', coalesce((select jsonb_agg(jsonb_build_object('date', u.session_date, 'session_no', u.session_no) order by u.session_date)
                                       from (select x.session_date, x.session_no from app.class_session x
                                              where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT')
                                                and x.session_date >= (now() at time zone 'Asia/Ho_Chi_Minh')::date
                                              order by x.session_date limit 8) u), '[]'::jsonb)) -- allow-number: số buổi sắp tới gợi ý trong hộp chọn ngày vào lớp
             order by c.code)
        from app.class c
       where c.branch_id = t.branch_id and c.status_code = 'DA_DUYET' and coalesce(app.class_seats_left(c.id), 1) > 0), '[]'::jsonb)
  );
end;
$$;-- D-23-50: app.ticket_task_check_waiting_enrollment: phiếu Bảo lưu, Chuyển lớp, Đổi lịch... KHÔNG nhận ghi danh «Chờ xếp lớp» (chưa có lớp; chỉ Hoàn học phí và Dừng học nhận, anh chốt 24/11).
-- Báo NGAY lúc tạo và lúc gửi duyệt thay vì chờ bước Thực hiện. NỘI BỘ (trigger). Lỗi: HMT_PHIEU_DU_LIEU_SAI. Hoàn học phí, Dừng học, Chuyển phí do trigger phạm vi (ticket_task_check_scope) kiểm.
create or replace function app.ticket_task_check_waiting_enrollment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enr uuid;
begin
  if new.task_type in ('HOAN_PHI', 'DUNG_HOC', 'CHUYEN_PHI') or app.is_migration() then
    return new;
  end if;
  -- Chỉ kiểm lúc tạo và lúc Nháp sang Chờ duyệt.
  if tg_op = 'UPDATE' and (new.status_code is not distinct from old.status_code or new.status_code <> 'CHO_DUYET') then
    return new;
  end if;
  begin
    v_enr := nullif(new.payload ->> 'enrollment_id', '')::uuid;
  exception when others then
    v_enr := null;
  end;
  if v_enr is not null and exists (select from app.enrollment e where e.id = v_enr and e.status_code = 'CHO_XEP_LOP') then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh Chờ xếp lớp chưa có lớp nên chỉ hoàn phí hoặc dừng học được. Hãy xếp lớp trước.');
  end if;
  return new;
end;
$$;
revoke execute on function app.ticket_task_check_waiting_enrollment() from public, anon, authenticated;

drop trigger if exists ticket_task_kiem_cho_xep_lop on app.ticket_task;
create trigger ticket_task_kiem_cho_xep_lop
  before insert or update of status_code on app.ticket_task
  for each row execute function app.ticket_task_check_waiting_enrollment();

select set_config('hmt.migration', '', false);
