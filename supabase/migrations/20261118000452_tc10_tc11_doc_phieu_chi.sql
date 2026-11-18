-- Migration 452 (Code D, 18/11/2026): hàm ĐỌC phiếu chi cho màn TC-10 (danh sách) và TC-11 (bản ghi, bảng tính hoàn). Chỉ đọc, không đổi dữ liệu.
-- Luật: R-TIEN-28 (bảng tính hoàn), R-TIEN-34 (phiếu chi). Quyền đọc: Xem phiếu thu/phiếu chi (RECEIPT · XEM) theo phạm vi, như chính sách của bảng (migration 231).
-- Không có chỉ mục mới: dùng payment_voucher_branch_idx (cơ sở, tình trạng, ngày lập) cho lọc cơ sở và tình trạng, sắp theo ngày lập.

-- app.list_payment_vouchers(bộ lọc, số dòng, bỏ qua): danh sách phiếu chi, phân trang ở máy chủ, mới nhất trước (TC-10). Ai gọi: người có quyền RECEIPT · XEM.
-- Bộ lọc (jsonb, tuỳ chọn): q (mã phiếu, mã ticket, tên hoặc mã phụ huynh), status (mảng CHO_CHI, DA_CHI), branch_id, created_from, created_to.
-- Kết quả {total, rows[]}; mỗi dòng: mã phiếu, ticket hoàn tiền (ticket_ref của yêu cầu), phụ huynh, số tiền hoàn, ngày lập, cơ sở, tình trạng, ngày chi.
create or replace function app.list_payment_vouchers(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu chi.');
  end if;
  with f as (
    select v.id, v.created_at
      from app.payment_voucher v
      join app.refund_request r on r.id = v.refund_request_id
      join app.parent p on p.id = v.parent_id
     where (v_scope = 'TOAN_HE_THONG' or v.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or v.status_code = any (v_status))
       and (v_branch is null or v.branch_id = v_branch)
       and (v_from is null or v.created_at >= v_from)
       and (v_to is null or v.created_at < v_to)
       and (v_q is null or v.code ilike '%' || v_q || '%' or r.ticket_ref ilike '%' || v_q || '%'
            or p.full_name ilike '%' || v_q || '%' or p.code ilike '%' || v_q || '%')
  )
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'id', v.id, 'code', v.code, 'status_code', v.status_code, 'amount', v.amount,
                    'ticket_ref', r.ticket_ref, 'refund_request_id', r.id, 'kind_code', r.kind_code,
                    'parent_id', p.id, 'parent_code', p.code, 'parent_name', p.full_name,
                    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
                    'created_at', v.created_at, 'paid_at', v.paid_at) order by v.created_at desc, v.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.payment_voucher v on v.id = x.id
                   join app.refund_request r on r.id = v.refund_request_id
                   join app.parent p on p.id = v.parent_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.get_payment_voucher(id): bản ghi phiếu chi và bảng tính hoàn (TC-11), một lần gọi. Không thấy (ngoài phạm vi) thì HMT_KHONG_TIM_THAY.
-- Kết quả {voucher, refund, enrollment}: số liệu bảng tính là số CHỤP lúc tạo yêu cầu hoàn (CLAUDE.md, cấu hình có hiệu lực), không tính lại.
-- «can_pay»: người xem có quyền ghi nhận đã chi (Đối soát kế toán · Duyệt) và phiếu đang Chờ chi; hàm app.pay_payment_voucher kiểm lại.
create or replace function app.get_payment_voucher(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v app.payment_voucher;
  r app.refund_request;
  e app.enrollment;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu chi.');
  end if;
  select * into v from app.payment_voucher where id = p_id;
  if v.id is null or not (v_scope = 'TOAN_HE_THONG' or v.branch_id = v_my_branch) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chi.');
  end if;
  select * into r from app.refund_request where id = v.refund_request_id;
  select * into e from app.enrollment where id = r.enrollment_id;
  return jsonb_build_object(
    'voucher', jsonb_build_object(
      'id', v.id, 'code', v.code, 'status_code', v.status_code, 'amount', v.amount, 'pay_note', v.pay_note,
      'created_at', v.created_at, 'paid_at', v.paid_at, 'created_by_name', app.staff_display_name(v.created_by),
      'paid_by_name', app.staff_display_name(v.paid_by),
      'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
      'parent_id', v.parent_id,
      'parent_code', (select p.code from app.parent p where p.id = v.parent_id),
      'parent_name', (select p.full_name from app.parent p where p.id = v.parent_id),
      'can_pay', v.status_code = 'CHO_CHI' and app.has_permission('ACCOUNTING', 'DUYET')),
    'refund', jsonb_build_object(
      'id', r.id, 'kind_code', r.kind_code, 'reason_code', r.reason_code, 'note', r.note, 'ticket_ref', r.ticket_ref,
      'hours_refund', r.hours_refund, 'paid_amount', r.paid_amount, 'hours_used', r.hours_used,
      'unit_price_base', r.unit_price_base, 'unit_price_net', r.unit_price_net, 'base_amount', r.base_amount,
      'fee_percent', r.fee_percent, 'fee_amount', r.fee_amount, 'refund_amount', r.refund_amount),
    'enrollment', jsonb_build_object(
      'id', e.id, 'code', e.code, 'status_code', e.status_code,
      'student_name', (select s.full_name from app.student s where s.id = e.student_id)));
end;
$$;

revoke execute on function app.list_payment_vouchers(jsonb, integer, integer), app.get_payment_voucher(uuid) from public, anon, authenticated;
grant execute on function app.list_payment_vouchers(jsonb, integer, integer), app.get_payment_voucher(uuid) to authenticated;
