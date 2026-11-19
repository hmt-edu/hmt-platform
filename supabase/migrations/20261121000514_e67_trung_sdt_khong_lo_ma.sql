-- E67 (20/11/2026, KHẨN): cảnh báo trùng SĐT (TS-03) không được lộ MÃ, ID, TÊN, CƠ SỞ của hồ sơ ngoài phạm vi người xem (Tester báo sau #353, Chat 22:52/23:17).
-- app.find_duplicate_contacts: hồ sơ ngoài phạm vi trả id, code, label, branch_code = null và visible = false; người xem chỉ biết «đã có trong hệ thống».
-- Hồ sơ trong phạm vi (visible = true) trả đủ như cũ. Thân hàm lấy từ migration 065 (bản hiện hành), chỉ thêm lớp che ở câu chọn ngoài.
-- Lưu ý: bài 017 cũ ghi «chỉ lộ mã và cơ sở» là luật cũ, đã sửa theo quyết định mới.

create or replace function app.find_duplicate_contacts(p_phone text, p_exclude_lead_id uuid default null)
returns table (kind text, id uuid, code text, label text, branch_code text, visible boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_phone text := app.normalize_phone(p_phone);
begin
  if app.permission_scope('LEAD', 'TAO') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo lead.');
  end if;
  if v_phone !~ '^0[0-9]{9}$' then
    return;
  end if;
  -- E67 (KHẨN, Tester báo TS-03 lộ mã): hồ sơ ngoài phạm vi chỉ cho biết «có hồ sơ» (visible = false): KHÔNG trả id, mã, tên, cơ sở. Sắp xếp theo mã thật bên trong.
  return query
    select q.kind, case when q.visible then q.id end, case when q.visible then q.code end, q.label,
           case when q.visible then q.branch_code end, q.visible
      from (
      select 'LEAD'::text as kind, l.id as id, l.code as code,
             case when app.can_see_branch('LEAD', 'XEM', l.branch_id)
                  then l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), '') end as label,
             b.code as branch_code, app.can_see_branch('LEAD', 'XEM', l.branch_id) as visible
        from app.lead l join app.branch b on b.id = l.branch_id
       where (l.parent_phone = v_phone or l.parent_phone_2 = v_phone)
         and l.record_status = 'DANG_DUNG' and l.id is distinct from p_exclude_lead_id
      union all
      select 'PARENT'::text, r.id, r.code,
             case when app.can_see_branch('PARENT', 'XEM', r.branch_id)
                  then r.full_name || ' · ' || (select count(*) from app.student s where s.parent_id = r.id and s.record_status = 'DANG_DUNG') || ' con' end,
             b.code, app.can_see_branch('PARENT', 'XEM', r.branch_id)
        -- Hồ sơ đã gộp thì trỏ về bản giữ lại (R-CRM-25): số điện thoại vẫn báo trùng, nhưng với hồ sơ còn dùng.
        from (select distinct coalesce(p.merged_into_id, p.id) as rid from app.parent p
               where p.phone = v_phone or p.phone_2 = v_phone) x
        join app.parent r on r.id = x.rid
        join app.branch b on b.id = r.branch_id
    ) q
    order by q.kind, q.code
    limit app.get_setting_int('search_result_max');
end;
$$;
