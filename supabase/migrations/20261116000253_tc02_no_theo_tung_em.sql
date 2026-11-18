-- TC-02 Thu nợ đầu kỳ, phần 3: nợ theo TỪNG EM theo canvas (Code C, 16/11/2026). Canvas 4 khung TC02_no_dau_ky_* tính nợ theo từng em: ô «Em» chọn, số tiền tối đa bằng nợ còn lại CỦA EM,
-- bảng nợ từng em, tiền thu thừa của em hiện riêng (không bù trừ). Dữ liệu nạp (R-V2-32) cũng ghi nợ theo học sinh (customer_balance_entry.student_id).
-- Chat 15:28 (b) khoá theo phụ huynh: GIỮ NGUYÊN (receipt.parent_id, is_opening_debt, trần phụ huynh của migration 251, 252). Migration này THÊM trần theo em KHI phiếu có em tham chiếu
-- (opening_debt_student_id); phiếu không có em thì chỉ kiểm theo phụ huynh như cũ → không đổi hành vi khi không truyền em.
--  (1) app.opening_student_debt_remaining(em, trừ phiếu): nợ đầu kỳ còn lại của em = nợ trong sổ số dư theo em trừ các phiếu ĐANG CHỜ của em.
--  (2) Trigger receipt_opening_student_cap: phiếu nợ đầu kỳ có em, đang Nháp, Đã gửi hoặc Chờ kế toán thì số tiền không vượt nợ còn lại của em (HMT_SO_TIEN_VUOT, nêu tên em).
--      Dùng trigger để phủ đủ đường tạo, sửa, gửi mà không viết lại bốn hàm của migration 251, 252. Không kiểm khi duyệt (phiếu chờ đã được trừ khỏi nợ còn lại lúc tạo và gửi).
--  (3) app.opening_debt_by_student(phụ huynh, phiếu): cho màn: nợ còn lại, tiền thu thừa, nợ sau khi duyệt dự kiến của từng em của phụ huynh; tổng nợ = cộng nợ các em, không trừ tiền thu thừa.
-- Cờ opening_debt_receipt_enabled (migration 251) vẫn TẮT mặc định.

-- (1) Nợ còn lại của một em (đồng, không âm).
create or replace function app.opening_student_debt_remaining(p_student_id uuid, p_except uuid default null)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select greatest(
           -coalesce((select sum(amount) from app.customer_balance_entry
                       where student_id = p_student_id and entry_type in ('DAU_KY_CONG_NO', 'THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY')), 0)
           - coalesce((select sum(amount) from app.receipt
                        where opening_debt_student_id = p_student_id and is_opening_debt and status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
                          and (p_except is null or id <> p_except)), 0),
           0)::bigint;
$$;

-- (2) Trần theo em cho phiếu nợ đầu kỳ có em tham chiếu.
create or replace function app.tg_receipt_opening_student_cap()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_remaining bigint;
  v_name text;
begin
  if new.is_opening_debt and new.opening_debt_student_id is not null and new.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN') then
    v_remaining := app.opening_student_debt_remaining(new.opening_debt_student_id, new.id);
    if new.amount > v_remaining then
      select full_name into v_name from app.student where id = new.opening_debt_student_id;
      perform app.raise_error('HMT_SO_TIEN_VUOT',
        format('Số tiền vượt nợ còn lại của %s (%s đ). Giảm số tiền hoặc chọn em khác.', coalesce(v_name, 'em đã chọn'), to_char(v_remaining, 'FM999G999G999G999')));
    end if;
  end if;
  return new;
end;
$$;
create trigger receipt_opening_student_cap before insert or update of amount, status_code, opening_debt_student_id on app.receipt
  for each row execute function app.tg_receipt_opening_student_cap();

-- (3) app.opening_debt_by_student(phụ huynh, phiếu): ai gọi: Phiếu thu · Xem ở cơ sở của phụ huynh. Kết quả
-- {students: [{id, code, name, remaining, credit, after_approval}], parent_remaining, parent_credit}. Số tiền do máy chủ tính, giao diện không cộng trừ.
--   remaining: nợ còn lại của em (đã trừ các phiếu đang chờ, không tính chính phiếu đang xem); credit: tiền thu thừa đầu kỳ của em, hiện riêng;
--   after_approval: nợ của em nếu phiếu đang xem được duyệt (chỉ khác remaining ở em của phiếu).
create or replace function app.opening_debt_by_student(p_parent_id uuid, p_receipt_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pa app.parent;
  v_rec app.receipt;
begin
  select * into pa from app.parent where id = p_parent_id;
  if pa.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  perform app.assert_can('RECEIPT', 'XEM', pa.branch_id);
  if p_receipt_id is not null then
    select * into v_rec from app.receipt where id = p_receipt_id and parent_id = p_parent_id and is_opening_debt;
  end if;
  return (
    with s as (
      select st.id, st.code, st.full_name,
             app.opening_student_debt_remaining(st.id, p_receipt_id) as remaining,
             coalesce((select sum(e.amount) from app.customer_balance_entry e where e.student_id = st.id and e.entry_type = 'DAU_KY_THU_THUA'), 0)::bigint as credit
        from app.student st
       where st.parent_id = p_parent_id
    ),
    r as (
      select s.*, case when v_rec.id is not null and v_rec.opening_debt_student_id = s.id
                       then greatest(s.remaining - v_rec.amount, 0) else s.remaining end as after_approval
        from s
    )
    select jsonb_build_object(
             'students', coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'name', r.full_name, 'remaining', r.remaining,
                                                               'credit', r.credit, 'after_approval', r.after_approval) order by r.full_name), '[]'::jsonb),
             'parent_remaining', coalesce(sum(r.remaining), 0)::bigint,
             'parent_credit', coalesce(sum(r.credit), 0)::bigint)
      from r);
end;
$$;

revoke execute on function app.opening_student_debt_remaining(uuid, uuid), app.opening_debt_by_student(uuid, uuid) from public, anon;
grant execute on function app.opening_student_debt_remaining(uuid, uuid), app.opening_debt_by_student(uuid, uuid) to authenticated;
