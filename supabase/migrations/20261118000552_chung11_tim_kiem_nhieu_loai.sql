-- CHUNG-11 Tìm kiếm toàn hệ thống: nối thêm các loại bản ghi (Code F, 18/11/2026). Luật S03-15: tìm theo tên, số điện thoại, mã mới, mã cũ,
-- không cần gõ dấu. Mở rộng app.search_records (migration 016, mới chỉ có tài khoản) thành: học sinh, khách hàng (phụ huynh), lead, cơ hội,
-- đơn hàng, phiếu thu, lớp, tài khoản nhân viên. Chạy bằng quyền người gọi (không security definer) nên RLS tự cắt theo cơ sở và quyền.
-- Mỗi loại tối đa search_result_max dòng (nhóm theo loại ở giao diện). Chỉ mục: mọi bảng đã có chỉ mục gin trgm trên search_text.
-- Đầu vào: chữ cần tìm (đủ search_min_length ký tự). Kết quả: loại, id, tiêu đề, dòng phụ, mã. Loại: STUDENT, PARENT, LEAD, OPPORTUNITY, ORDER, RECEIPT, CLASS, USER_ACCOUNT.
create or replace function app.search_records(p_query text)
returns table (entity_type text, entity_id uuid, title text, subtitle text, code text)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_q text := app.fold_text(btrim(coalesce(p_query, '')));
  v_max integer := app.get_setting_int('search_result_max');
begin
  -- Luật S03-15: chữ quá ngắn thì không tìm (tránh quét cả bảng).
  if length(btrim(coalesce(p_query, ''))) < app.get_setting_int('search_min_length') then
    return;
  end if;
  return query
  (select 'STUDENT'::text, s.id, s.full_name, p.full_name, s.code
     from app.student s join app.parent p on p.id = s.parent_id
    where s.search_text like '%' || v_q || '%' order by s.full_name limit v_max)
  union all
  (select 'PARENT'::text, p.id, p.full_name, p.phone, p.code
     from app.parent p where p.search_text like '%' || v_q || '%' order by p.full_name limit v_max)
  union all
  (select 'LEAD'::text, l.id, coalesce(p.full_name, l.code), l.stage_code, l.code
     from app.lead l left join app.parent p on p.id = l.parent_id
    where l.search_text like '%' || v_q || '%' order by l.code desc limit v_max)
  union all
  (select 'OPPORTUNITY'::text, o.id, p.full_name, o.stage_code, o.code
     from app.opportunity o join app.parent p on p.id = o.parent_id
    where o.search_text like '%' || v_q || '%' order by o.code desc limit v_max)
  union all
  (select 'ORDER'::text, d.id, p.full_name, d.status_code, d.code
     from app.sales_order d join app.parent p on p.id = d.parent_id
    where d.search_text like '%' || v_q || '%' order by d.code desc limit v_max)
  union all
  (select 'RECEIPT'::text, r.id, p.full_name, r.status_code, r.code
     from app.receipt r join app.parent p on p.id = r.parent_id
    where r.search_text like '%' || v_q || '%' order by r.code desc limit v_max)
  union all
  (select 'CLASS'::text, c.id, c.code, c.status_code, c.code
     from app.class c where c.search_text like '%' || v_q || '%' order by c.code limit v_max)
  union all
  (select 'USER_ACCOUNT'::text, a.id, a.display_name, a.login_name, coalesce(a.staff_code, a.student_code)
     from app.user_account a where a.search_text like '%' || v_q || '%' order by a.display_name limit v_max);
end;
$$;
grant execute on function app.search_records(text) to authenticated;
