-- C87 (Anh Trường duyệt 20/11 20:38, thư Chat 20:39/20:44; migration 578, rủi ro CAO: tiền, giờ). TC-17: «Chia tiền vào dòng đơn» hiện từ bước Đã trình với cột Lớp, Giờ cấp, nhãn Dồn trước.
-- Làm gì: (1) tách thuật toán chia tiền của allocate_money_in ra hàm tính chung app.compute_money_in_allocation (chỉ tính, không ghi), allocate_money_in gọi lại hàm này nên xem trước và ghi thật KHÔNG thể lệch nhau;
-- (2) app.preview_receipt_allocation(p_receipt_id): chỉ đọc, trả theo dòng đơn tiền chia và giờ cấp của đúng phiếu này.
-- Luật: R-TIEN-22, R-TIEN-23 (dòng cấn nhận trước, tối đa phần còn nhận được; phần thừa chia theo tỉ lệ phần còn nhận được; dòng cuối nhận phần dư làm tròn);
-- R-TIEN-21 (giờ cấp của dòng = số giờ dòng × tiền chia ÷ thành tiền dòng, làm tròn 2 chữ số); R-TIEN-24 (giờ tặng chỉ cấp khi đơn thu đủ: hàm xem trước chỉ nói về giờ mua).
-- Không đổi bảng, không thêm chỉ mục (đọc theo khoá đã có: order_line_id của money_in_allocation).
select set_config('hmt.migration', 'on', false);

-- app.compute_money_in_allocation(đơn, số tiền, dòng cấn): HÀM TRONG, chỉ tính. Ai gọi: allocate_money_in và preview_receipt_allocation (không cấp cho người dùng).
-- Kết quả: bảng (order_line_id, amount) chỉ các dòng nhận > 0. Lỗi: HMT_DON_KHONG_DONG (đơn không dòng nhận tiền), HMT_SO_TIEN_VUOT (vượt phần còn nhận được). Luật R-TIEN-22, R-TIEN-23.
create or replace function app.compute_money_in_allocation(p_order_id uuid, p_amount bigint, p_target uuid)
returns table (order_line_id uuid, amount bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
  v_room bigint[];
  v_give bigint[];
  v_rest bigint := p_amount;
  v_total_room bigint := 0;
  v_i integer;
  v_part bigint;
  v_last integer;
begin
  select array_agg(l.id order by l.line_no), array_agg(greatest(l.line_total - coalesce(a.paid, 0), 0) order by l.line_no)
    into v_ids, v_room
    from app.sales_order_line l
    left join lateral (select sum(m.amount) paid from app.money_in_allocation m where m.order_line_id = l.id) a on true
   where l.order_id = p_order_id and l.is_live and l.line_total > 0;
  if v_ids is null then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn không có dòng nào nhận tiền.');
  end if;
  v_give := array_fill(0::bigint, array[cardinality(v_ids)]);
  -- Luật R-TIEN-23: cấn vào dòng được chọn trước, tối đa phần còn nhận được của dòng đó.
  if p_target is not null then
    v_i := array_position(v_ids, p_target);
    if v_i is not null then
      v_part := least(v_rest, v_room[v_i]);
      v_give[v_i] := v_part;
      v_room[v_i] := v_room[v_i] - v_part;
      v_rest := v_rest - v_part;
    end if;
  end if;
  -- Luật R-TIEN-22: phần còn lại chia theo tỉ lệ phần còn nhận được của các dòng; dòng cuối nhận phần dư làm tròn.
  for v_i in 1 .. cardinality(v_ids) loop
    v_total_room := v_total_room + v_room[v_i];
    if v_room[v_i] > 0 then
      v_last := v_i;
    end if;
  end loop;
  if v_rest > 0 then
    if v_total_room < v_rest then
      perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền vượt phần còn nhận được của các dòng đơn.');
    end if;
    declare
      v_assigned bigint := 0;
    begin
      for v_i in 1 .. cardinality(v_ids) loop
        if v_room[v_i] > 0 then
          if v_i = v_last then
            v_part := v_rest - v_assigned;
          else
            v_part := least(floor(v_rest::numeric * v_room[v_i] / v_total_room)::bigint, v_room[v_i]);
          end if;
          v_give[v_i] := v_give[v_i] + v_part;
          v_assigned := v_assigned + v_part;
        end if;
      end loop;
    end;
  end if;
  for v_i in 1 .. cardinality(v_ids) loop
    if v_give[v_i] > 0 then
      order_line_id := v_ids[v_i];
      amount := v_give[v_i];
      return next;
    end if;
  end loop;
end;
$$;
revoke execute on function app.compute_money_in_allocation(uuid, bigint, uuid) from public, anon, authenticated;

-- app.allocate_money_in: giữ chữ ký và kết quả cũ (ghi money_in_allocation); phần tính nay do compute_money_in_allocation làm (một thuật toán duy nhất).
create or replace function app.allocate_money_in(p_money_in_id uuid, p_order_id uuid, p_amount bigint, p_target uuid, p_branch uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into app.money_in_allocation (money_in_id, order_line_id, branch_id, amount)
  select p_money_in_id, c.order_line_id, p_branch, c.amount
    from app.compute_money_in_allocation(p_order_id, p_amount, p_target) c;
end;
$$;

-- app.preview_receipt_allocation(p_receipt_id): TC-17 «Chia tiền vào dòng đơn». Chỉ đọc. Ai gọi: người xem được phiếu thu (Xem phiếu thu trong phạm vi cơ sở, như get_receipt).
-- Kết quả jsonb {actual, note, lines[{line_id, line_no, student_name, package_name, line_total, amount, hours, hours_total, first}]}.
--   Phiếu Nháp, Đã gửi, Chờ kế toán có đơn: tính bằng compute_money_in_allocation đúng như lúc duyệt (actual = false); first = dòng cấn trước của phiếu (nhãn «Dồn trước»).
--   Phiếu Đã duyệt: đọc phần tiền đã chia thật của khoản tiền vào (actual = true).
--   Phiếu Huỷ, phiếu thu nợ đầu kỳ (không đơn): lines rỗng.
-- hours = giờ cấp của dòng cho PHIẾU NÀY = số giờ dòng × tiền chia ÷ thành tiền dòng (R-TIEN-21), làm tròn 2 chữ số; hours_total = số giờ dòng.
-- Số tiền không chia được (vượt phần còn nhận được vì đơn có phiếu khác đã duyệt trước): không báo lỗi, trả lines rỗng và note có câu tiếng Việt.
create or replace function app.preview_receipt_allocation(p_receipt_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_lines jsonb;
  v_actual boolean := false;
  v_note text;
begin
  select * into r from app.receipt where id = p_receipt_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  -- Quyền: như get_receipt (R-HT phạm vi cơ sở).
  perform app.assert_can_wide('RECEIPT', 'XEM', r.branch_id);
  if r.order_id is null or r.status_code = 'HUY' then
    return jsonb_build_object('actual', false, 'note', null, 'lines', '[]'::jsonb);
  end if;
  if r.status_code = 'DA_DUYET' then
    -- Phiếu đã duyệt: tiền đã chia thật.
    v_actual := true;
    select coalesce(jsonb_agg(app.receipt_alloc_line(l.id, a.amount, false) order by l.line_no), '[]'::jsonb) into v_lines
      from app.money_in m
      join app.money_in_allocation a on a.money_in_id = m.id
      join app.sales_order_line l on l.id = a.order_line_id
     where m.receipt_id = r.id;
  else
    begin
      select coalesce(jsonb_agg(app.receipt_alloc_line(c.order_line_id, c.amount, c.order_line_id is not distinct from r.target_line_id)
                                order by l.line_no), '[]'::jsonb) into v_lines
        from app.compute_money_in_allocation(r.order_id, r.amount, r.target_line_id) c
        join app.sales_order_line l on l.id = c.order_line_id;
    exception when others then
      -- Luật R-TIEN-22: vượt phần còn nhận được thì không có bản xem trước; câu hiện thẳng cho người dùng.
      v_lines := '[]'::jsonb;
      v_note := 'Chưa chia được tiền vào các dòng: số tiền vượt phần còn nhận được của đơn.';
    end;
  end if;
  return jsonb_build_object('actual', v_actual, 'note', v_note, 'lines', v_lines);
end;
$$;

-- app.receipt_alloc_line(dòng, tiền chia, cờ dồn trước): HÀM TRONG, ghép một dòng kết quả cho preview_receipt_allocation (giờ cấp theo R-TIEN-21).
create or replace function app.receipt_alloc_line(p_line_id uuid, p_amount bigint, p_first boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'line_id', l.id, 'line_no', l.line_no,
           'student_name', coalesce(s.full_name, v.full_name),
           'package_name', l.package_name,
           'line_total', l.line_total, 'amount', p_amount,
           'hours', case when l.line_total = 0 then 0 else round(l.quantity * p_amount::numeric / l.line_total, 2) end,
           'hours_total', l.quantity, 'first', p_first)
    from app.sales_order_line l
    left join app.prospect_student_v v on v.id = l.prospect_student_id
    left join app.student s on s.id = l.student_id
   where l.id = p_line_id;
$$;
revoke execute on function app.receipt_alloc_line(uuid, bigint, boolean) from public, anon, authenticated;

select set_config('hmt.migration', '', false);
revoke execute on function app.preview_receipt_allocation(uuid) from public, anon;
grant execute on function app.preview_receipt_allocation(uuid) to authenticated;
