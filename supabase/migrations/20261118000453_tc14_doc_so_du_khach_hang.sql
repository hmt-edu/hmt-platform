-- Migration 453 (Code D, 18/11/2026): hàm ĐỌC số dư khách hàng cho màn TC-14 (danh sách, xem lịch sử). Chỉ đọc, không đổi dữ liệu.
-- Luật: R-TIEN-33 (sổ số dư chỉ thêm), R-CS-03. Quyền đọc: Xem phiếu thu/phiếu chi (RECEIPT · XEM) theo phạm vi, như app.customer_balance (migration 232).
-- Không có chỉ mục mới: dùng customer_balance_parent_idx (phụ huynh, thứ tự ghi) và customer_balance_branch_idx (cơ sở).
-- Nút «Cấn vào đơn mới» (TC-16) làm ở PR sau cùng Code C (đổi khoản tiền vào).

-- app.list_customer_balances(bộ lọc, số dòng, bỏ qua): mỗi phụ huynh một dòng (số dư = tổng sổ), phân trang ở máy chủ. Ai gọi: quyền RECEIPT · XEM.
-- Bộ lọc (jsonb, tuỳ chọn): q (tên, mã, điện thoại phụ huynh), branch_id, only_positive (true: chỉ phụ huynh còn tiền dư dương). Sắp theo số dư giảm dần, rồi mã.
-- Kết quả {total, rows[]}; mỗi dòng: phụ huynh, cơ sở, số dư, ngày phát sinh gần nhất, số dòng sổ.
create or replace function app.list_customer_balances(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
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
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_positive boolean := coalesce((p_filters ->> 'only_positive')::boolean, false);
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem số dư khách hàng.');
  end if;
  with g as (
    select e.parent_id, sum(e.amount)::bigint as balance, max(e.entry_date) as last_date, count(*)::int as entries
      from app.customer_balance_entry e
      join app.parent p on p.id = e.parent_id
     where (v_scope = 'TOAN_HE_THONG' or p.branch_id = v_my_branch)
       and (v_branch is null or p.branch_id = v_branch)
       and (v_q is null or p.full_name ilike '%' || v_q || '%' or p.code ilike '%' || v_q || '%' or p.phone like '%' || v_q || '%')
     group by e.parent_id
    having (not v_positive or sum(e.amount) > 0)
  )
  select (select count(*) from g),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'parent_id', x.parent_id, 'parent_code', p.code, 'parent_name', p.full_name,
                    'branch_code', (select b.code from app.branch b where b.id = p.branch_id),
                    'balance', x.balance, 'last_date', x.last_date, 'entries', x.entries) order by x.balance desc, x.parent_id)
                   from (select g.* from g order by g.balance desc, g.parent_id limit v_limit offset v_offset) x
                   join app.parent p on p.id = x.parent_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.get_customer_balance_history(phụ huynh): số dư và lịch sử sổ (mới nhất trước) của một phụ huynh, một lần gọi. Ngoài phạm vi: HMT_KHONG_TIM_THAY.
-- Kết quả {parent, balance, entries[]}: mỗi dòng có loại, số tiền, ngày, mã nguồn (source_ref), ghi chú, mã ghi danh (nếu có).
create or replace function app.get_customer_balance_history(p_parent_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  p app.parent;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem số dư khách hàng.');
  end if;
  select * into p from app.parent where id = p_parent_id;
  if p.id is null or not (v_scope = 'TOAN_HE_THONG' or p.branch_id = v_my_branch) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  return jsonb_build_object(
    'parent', jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name,
                                 'branch_code', (select b.code from app.branch b where b.id = p.branch_id)),
    'balance', coalesce((select sum(e.amount) from app.customer_balance_entry e where e.parent_id = p.id), 0)::bigint,
    'entries', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'entry_type', e.entry_type, 'amount', e.amount, 'entry_date', e.entry_date,
        'source_ref', e.source_ref, 'note', e.note,
        'enrollment_code', (select en.code from app.enrollment en where en.id = e.enrollment_id),
        'student_name', (select s.full_name from app.student s where s.id = e.student_id)) order by e.seq desc)
      from app.customer_balance_entry e where e.parent_id = p.id), '[]'::jsonb));
end;
$$;

revoke execute on function app.list_customer_balances(jsonb, integer, integer), app.get_customer_balance_history(uuid) from public, anon, authenticated;
grant execute on function app.list_customer_balances(jsonb, integer, integer), app.get_customer_balance_history(uuid) to authenticated;
