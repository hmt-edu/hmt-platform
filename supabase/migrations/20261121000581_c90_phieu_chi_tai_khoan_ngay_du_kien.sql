-- C90 (KHO-VIEC dòng 14; anh Trường duyệt 20/11 20:38, thư Chat 20:44; migration 581, rủi ro CAO: phiếu chi, tiền ra). TC-10, TC-11 Phiếu chi theo canvas: «Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến».
-- Anh chốt: Tài khoản nhận = CHỮ TỰ DO (payout_account_note, tài khoản của người nhận hoàn tiền, KHÔNG dùng danh mục RECEIVING_ACCOUNT của trung tâm); Ngày chi dự kiến chỉ CẢNH BÁO ở giao diện, KHÔNG chặn chi.
-- Hình thức chi: cột payment_method_code đã có từ migration 564 (ghi lúc «Ghi nhận đã chi»); nay Kế toán có thể ghi trước khi chi, và lúc chi không chọn lại thì giữ giá trị đã ghi.
-- Làm gì: (1) thêm cột planned_on, payout_account_note; (2) app.set_payment_voucher_plan: Kế toán ghi ba trường trên phiếu CHỜ CHI; (3) pay_payment_voucher giữ hình thức đã ghi; (4) list_payment_vouchers, get_payment_voucher trả thêm hai trường.
-- Chỉ mục: không thêm (hai cột chỉ hiển thị, không lọc hay sắp xếp). Mọi sửa ghi vào audit_log qua trigger chuẩn của bảng.
select set_config('hmt.migration', 'on', false);

alter table app.payment_voucher
  add column planned_on date,
  add column payout_account_note text,
  add constraint payment_voucher_account_note_len check (payout_account_note is null or char_length(payout_account_note) <= 200); -- allow-number: độ dài tối đa ghi chú tài khoản nhận (chữ tự do)
comment on column app.payment_voucher.planned_on is 'Ngày chi dự kiến (TC-11); chỉ cảnh báo, không chặn chi (anh Trường chốt 20/11/2026).';
comment on column app.payment_voucher.payout_account_note is 'Tài khoản nhận của người nhận hoàn tiền, chữ tự do (TC-11); khác danh mục RECEIVING_ACCOUNT của phiếu thu.';

-- app.set_payment_voucher_plan(phiếu chi, hình thức, tài khoản nhận, ngày dự kiến): ghi trước khi chi. Ai gọi: Đối soát kế toán · Duyệt (như pay_payment_voucher), theo cơ sở của phiếu.
-- Đầu vào: p_method_code (danh mục PAYMENT_METHOD, trống = xoá), p_account_note (chữ tự do, tối đa 200 ký tự, trống = xoá), p_planned_on (ngày, trống = xoá; KHÔNG kiểm với hôm nay).
-- Lỗi: HMT_KHONG_TIM_THAY, HMT_PHIEU_CHI_DA_CHI (phiếu đã chi không sửa), HMT_HINH_THUC_KHONG_HOP_LE, HMT_TAI_KHOAN_NHAN_DAI (quá dài). Luật R-TIEN-34 (Kế toán lập, chi; mọi thao tác ghi nhật ký).
create or replace function app.set_payment_voucher_plan(p_voucher_id uuid, p_method_code text, p_account_note text, p_planned_on date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pv app.payment_voucher;
  v_method text := nullif(btrim(coalesce(p_method_code, '')), '');
  v_note text := nullif(btrim(coalesce(p_account_note, '')), '');
begin
  select * into pv from app.payment_voucher where id = p_voucher_id for update;
  if pv.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chi.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', pv.branch_id);
  -- Luật: phiếu đã chi là chứng từ chốt, không sửa.
  if pv.status_code <> 'CHO_CHI' then
    perform app.raise_error('HMT_PHIEU_CHI_DA_CHI', 'Phiếu chi này đã chi rồi, không sửa được.');
  end if;
  -- Luật: hình thức chi dùng chung danh mục PAYMENT_METHOD với phiếu thu (mục còn dùng).
  if v_method is not null and not exists (
       select from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = v_method and c.is_active) then
    perform app.raise_error('HMT_HINH_THUC_KHONG_HOP_LE', 'Hình thức chi không có trong danh mục hình thức thanh toán.');
  end if;
  if v_note is not null and char_length(v_note) > 200 then -- allow-number: độ dài tối đa ghi chú tài khoản nhận (chữ tự do)
    perform app.raise_error('HMT_TAI_KHOAN_NHAN_DAI', 'Tài khoản nhận quá dài (tối đa 200 ký tự).'); -- allow-number: như trên
  end if;
  update app.payment_voucher set payment_method_code = v_method, payout_account_note = v_note, planned_on = p_planned_on where id = pv.id;
end;
$$;

-- app.pay_payment_voucher: như migration 564, nhưng lúc chi không chọn hình thức thì GIỮ hình thức đã ghi trước (set_payment_voucher_plan).
create or replace function app.pay_payment_voucher(p_voucher_id uuid, p_note text default null, p_method_code text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  pv app.payment_voucher;
  v_method text := nullif(btrim(coalesce(p_method_code, '')), '');
begin
  select * into pv from app.payment_voucher where id = p_voucher_id for update;
  if pv.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chi.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', pv.branch_id);
  if pv.status_code <> 'CHO_CHI' then
    perform app.raise_error('HMT_PHIEU_CHI_DA_CHI', 'Phiếu chi này đã chi rồi.');
  end if;
  -- Hình thức chi dùng CHUNG danh mục PAYMENT_METHOD với Phiếu thu (anh Trường chốt 20/11/2026); không bắt buộc ở máy chủ, giao diện luôn hỏi.
  if v_method is not null and not exists (
       select from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = v_method and c.is_active) then
    perform app.raise_error('HMT_HINH_THUC_KHONG_HOP_LE', 'Hình thức chi không có trong danh mục hình thức thanh toán.');
  end if;
  update app.payment_voucher set status_code = 'DA_CHI', paid_at = now(), paid_by = (select auth.uid()), pay_note = nullif(btrim(p_note), ''),
         payment_method_code = coalesce(v_method, pv.payment_method_code) -- C90: giữ hình thức đã ghi trước khi chi (set_payment_voucher_plan) nếu lúc chi không chọn lại
   where id = pv.id;
  update app.refund_request set status_code = 'DA_CHI' where id = pv.refund_request_id;
end;
$$;

-- app.list_payment_vouchers: như migration 564, thêm planned_on, payout_account_note mỗi dòng.
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
                    'created_at', v.created_at, 'paid_at', v.paid_at,
                    'planned_on', v.planned_on, 'payout_account_note', v.payout_account_note,
                    'payment_method_code', v.payment_method_code,
                    'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = v.payment_method_code)) order by v.created_at desc, v.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.payment_voucher v on v.id = x.id
                   join app.refund_request r on r.id = v.refund_request_id
                   join app.parent p on p.id = v.parent_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.get_payment_voucher: như migration 564, thêm planned_on, payout_account_note vào khối voucher.
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
      'planned_on', v.planned_on, 'payout_account_note', v.payout_account_note,
      'payment_method_code', v.payment_method_code,
      'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = v.payment_method_code),
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

revoke execute on function app.set_payment_voucher_plan(uuid, text, text, date) from public, anon;
grant execute on function app.set_payment_voucher_plan(uuid, text, text, date) to authenticated;

select set_config('hmt.migration', '', false);
