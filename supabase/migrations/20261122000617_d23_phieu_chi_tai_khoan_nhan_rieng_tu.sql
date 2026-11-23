-- D-23-05 (anh Trường duyệt 23/11/2026 01:54; migration 617; rủi ro CAO: phiếu chi, tiền ra). Phần còn thiếu của TC-10/TC-11 sau migration 564 và 581
-- (các cột «Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến» và hàm ghi đã có từ đó). Hai luật còn thiếu:
--  (1) Tài khoản nhận (payout_account_note) KHÔNG ghi vào nhật ký: trigger audit riêng của bảng phiếu chi chép «đã đổi» thay cho nội dung (cả khi xoá).
--  (2) Tài khoản nhận chỉ thấy với vai trò có quyền chi (Đối soát kế toán · Duyệt): list_payment_vouchers và get_payment_voucher trả null cho vai khác;
--      đọc thẳng bảng cũng bị chặn bằng quyền theo cột (thu hồi select cột này của authenticated).
-- Không nối ngân hàng, chỉ lưu văn bản. Chỉ mục: không thêm (không thêm cột). list/get chép từ migration 604/581, chỉ đổi dòng payout_account_note.
select set_config('hmt.migration', 'on', false);

-- (1) Trigger audit riêng cho bảng phiếu chi: như app.tg_audit nhưng che nội dung cột payout_account_note.
-- Ai: trigger hệ thống. Luật: nhật ký chỉ ghi tên trường đổi, không ghi số tài khoản.
create or replace function app.tg_audit_payment_voucher()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table_id smallint := TG_ARGV[0]::smallint;
  v_mask constant text := '«đã đổi»';
  v_old jsonb;
  v_new jsonb;
  v_changes jsonb;
begin
  if TG_OP = 'INSERT' then
    insert into app.audit_log (table_id, record_id, action, actor)
    values (v_table_id, new.id, 'I', app.current_actor());
    return new;
  end if;

  if TG_OP = 'DELETE' then
    insert into app.audit_log (table_id, record_id, action, changes, actor)
    values (v_table_id, old.id, 'D',
            jsonb_build_object('row', to_jsonb(old) - 'payout_account_note', 'reason', nullif(current_setting('hmt.hard_delete_reason', true), '')),
            app.current_actor());
    return old;
  end if;

  v_old := to_jsonb(old) - array['created_at', 'created_by', 'updated_at', 'updated_by'];
  v_new := to_jsonb(new) - array['created_at', 'created_by', 'updated_at', 'updated_by'];
  select jsonb_object_agg(n.key,
           case when n.key = 'payout_account_note' then jsonb_build_array(to_jsonb(v_mask), to_jsonb(v_mask))
                else jsonb_build_array(v_old -> n.key, n.value) end)
    into v_changes
    from jsonb_each(v_new) as n
   where (v_old -> n.key) is distinct from n.value;

  if v_changes is not null then
    insert into app.audit_log (table_id, record_id, action, changes, actor)
    values (v_table_id, new.id, 'U', v_changes, app.current_actor());
  end if;
  return new;
end;
$$;

drop trigger payment_voucher_audit on app.payment_voucher;
-- Tham số trigger phải là hằng, nên dựng bằng khối do (không phải SQL động theo dữ liệu người dùng: chỉ id bảng cố định).
do $do$
declare
  v_table_id smallint;
begin
  select id into v_table_id from app.audited_table where table_name = 'app.payment_voucher';
  execute format('create trigger payment_voucher_audit after insert or update or delete on app.payment_voucher for each row execute function app.tg_audit_payment_voucher(%L)', v_table_id);
end;
$do$;

-- (2a) Quyền theo cột: authenticated đọc mọi cột trừ payout_account_note (hàm security definer vẫn đọc đủ).
revoke select on app.payment_voucher from authenticated;
grant select (id, code, refund_request_id, branch_id, parent_id, amount, status_code, paid_at, paid_by, pay_note,
              created_at, created_by, updated_at, updated_by, payment_method_catalog, payment_method_code, planned_on)
  on app.payment_voucher to authenticated;

-- (2b) Hai hàm đọc: tài khoản nhận chỉ trả khi người gọi có Đối soát kế toán · Duyệt.
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
  -- C95: hình thức chi (mảng mã PAYMENT_METHOD); dùng để mở một nhóm Group By «Hình thức».
  v_method text[] := array(select jsonb_array_elements_text(p_filters -> 'payment_method'));
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
       and (cardinality(v_method) = 0 or v.payment_method_code = any (v_method))
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
                    'planned_on', v.planned_on, 'payout_account_note', case when (select app.has_permission('ACCOUNTING', 'DUYET')) then v.payout_account_note end,
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
      'planned_on', v.planned_on, 'payout_account_note', case when app.has_permission('ACCOUNTING', 'DUYET') then v.payout_account_note end,
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
