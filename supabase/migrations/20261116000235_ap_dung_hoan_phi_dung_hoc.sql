-- Migration 235 (Code D, 16/11/2026): hàm «áp dụng» hoàn phí và dừng học cho phiếu nghiệp vụ Aftersale (Code B, migration 226), như migration 234 làm cho
-- bảo lưu và chuyển lớp. Phiếu Dừng học, Hoàn học phí đã có cấp quản lý cơ sở và kế toán ở ticket_task (R-CS-07), nên khi thực hiện KHÔNG duyệt lần hai ở bản ghi.
-- Cách làm: tách LÕI kế toán (kiểm lại số liệu, ghi sổ giờ ngược dấu, đổi tình trạng ghi danh, phiếu chi hoặc số dư) của approve_refund_accountant (migration 231)
-- và approve_stop_accountant (migration 232) thành app.finish_refund_request, app.finish_enrollment_stop; hai hàm duyệt cũ gọi lại lõi (HÀNH VI KHÔNG ĐỔI, các bài
-- pgTAP 231, 232 giữ nguyên); hai hàm apply_* tạo yêu cầu ở trạng thái Chờ kế toán với người duyệt quản lý là người gọi rồi gọi lõi. Tất cả NỘI BỘ (không cấp cho giao diện).
-- Chưa nối vào execute_ticket_task: Code B nối khi sẵn sàng (docs/nghiep-vu/ap-dung-phieu-cho-code-b.md).

-- Lõi duyệt kế toán của hoàn phí (tách ra để dùng chung với app.apply_refund_request): kiểm lại số liệu, ghi sổ giờ ngược dấu, đổi tình trạng ghi danh
-- (hoàn toàn bộ), lập phiếu chi PC. NỘI BỘ. Đầu vào: bản ghi đã khoá, đang Chờ kế toán. Kết quả: id phiếu chi.
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
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
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

-- app.approve_refund_accountant: kế toán duyệt (R-CS-07, R-TIEN-34). Ai: Đối soát kế toán · Duyệt (chỉ Kế toán). Việc ghi sổ ở app.finish_refund_request.
create or replace function app.approve_refund_accountant(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['CHO_KE_TOAN']);
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  perform app.require_feature('HOAN_PHI', r.branch_id);
  return app.finish_refund_request(r.id);
end;
$$;

-- Lõi duyệt kế toán của dừng học giữ số dư (dùng chung với app.apply_enrollment_stop): kiểm lại số liệu, ghi sổ giờ ngược dấu, ghi danh sang Dừng,
-- đóng dòng xếp lớp, ghi dòng số dư khách hàng. NỘI BỘ.
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
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
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

-- app.approve_stop_accountant: kế toán duyệt (R-CS-07). Ai: Đối soát kế toán · Duyệt (chỉ Kế toán). Việc ghi sổ ở app.finish_enrollment_stop.
create or replace function app.approve_stop_accountant(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_KE_TOAN']);
  perform app.assert_can('ACCOUNTING', 'DUYET', s.branch_id);
  perform app.require_feature('DUNG_HOC', s.branch_id);
  perform app.finish_enrollment_stop(s.id);
end;
$$;

-- app.apply_refund_request: hoàn phí đã qua cấp quản lý cơ sở và kế toán ở phiếu nghiệp vụ Aftersale (ticket_task): tạo yêu cầu, tính tiền, đặt người duyệt
-- rồi chạy lõi kế toán (ghi sổ giờ ngược dấu, ghi danh, phiếu chi PC). NỘI BỘ. Kết quả: id phiếu chi. Luật: R-TIEN-28, 31, 34; R-V2-24.
create or replace function app.apply_refund_request(
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
  perform app.require_feature('HOAN_PHI', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
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
          'CHO_KE_TOAN', null, now())
  returning id into v_id;
  return app.finish_refund_request(v_id);
end;
$$;

-- app.apply_enrollment_stop: dừng học giữ số dư đã qua cấp quản lý cơ sở và kế toán ở phiếu nghiệp vụ Aftersale: tạo yêu cầu, chụp số liệu, đặt người duyệt
-- rồi chạy lõi kế toán (ghi sổ giờ ngược dấu, ghi danh sang Dừng, số dư khách hàng). NỘI BỘ. Kết quả: id yêu cầu. Luật: R-GD-16, R-TIEN-33; R-V2-24.
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
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
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

revoke execute on function app.finish_refund_request(uuid), app.finish_enrollment_stop(uuid) from public, anon, authenticated;
revoke execute on function app.apply_refund_request(uuid, text, numeric, text, text, text) from public, anon, authenticated;
revoke execute on function app.apply_enrollment_stop(uuid, text, text, text) from public, anon, authenticated;
