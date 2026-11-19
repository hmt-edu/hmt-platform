-- C69 (KHO-VIEC dòng 18, TC-10 Phiếu chi): Group By ở máy chủ (canvas K1_nhom, tối đa hai cấp), theo mẫu appointment_group_counts (Đ35).
-- Trường nhóm: status (tình trạng phiếu chi: Chờ chi, Đã chi), branch (cơ sở). «Hình thức» của gợi ý F65 CHƯA làm: phiếu chi chưa lưu hình thức chi (chuyển khoản, tiền mặt), cần chốt mô hình dữ liệu (CẦN CHAT).
-- Ai gọi: người có quyền Phiếu thu · Xem (như list_payment_vouchers); bộ lọc cùng khoá. Chỉ đọc. Lỗi: HMT_KHONG_CO_QUYEN, HMT_NHOM_SAI.
select set_config('hmt.migration', 'on', false);

create or replace function app.voucher_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then case p_key when 'CHO_CHI' then 'Chờ chi' when 'DA_CHI' then 'Đã chi' else p_key end
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    else p_key end;
$$;

create or replace function app.voucher_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu chi.');
  end if;
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở).');
  end if;
  with f as (
    select v.status_code, v.branch_id
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
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'branch' then f.branch_id::text end as k1,
           case v_f2 when 'status' then f.status_code when 'branch' then f.branch_id::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.voucher_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.voucher_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

-- Vỏ bọc cho nhóm lá của Group By: khung mở nhóm luôn gửi p_sort, còn list_payment_vouchers không có tham số sắp xếp (phiếu chi luôn mới nhất trước). Không đổi hàm gốc.
create or replace function app.list_payment_vouchers_grouped(p_filters jsonb default '{}'::jsonb, p_sort text default null, p_limit integer default null, p_offset integer default 0)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.list_payment_vouchers(p_filters, p_limit, p_offset);
$$;

revoke execute on function app.voucher_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.voucher_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.voucher_group_counts(jsonb, text[]) to authenticated;
revoke execute on function app.list_payment_vouchers_grouped(jsonb, text, integer, integer) from public, anon;
grant execute on function app.list_payment_vouchers_grouped(jsonb, text, integer, integer) to authenticated;
select set_config('hmt.migration', '', false);
