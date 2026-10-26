-- ===========================================================================
-- Cơ hội hiện ghi chú của lead gốc (lỗi 26/10, phương án A, anh OK): ghi chú gắn theo từng bản ghi nên trước đây khi tạo cơ hội từ lead,
-- ghi chú ở lead (cuộc gọi, trao đổi) không hiện ở cơ hội. Nay trang Cơ hội đọc xuyên: ghi chú của chính cơ hội cộng ghi chú của lead gốc,
-- kèm nhãn "Lead LDxxxxxx". Không sao chép dữ liệu: ghi chú vẫn một bản, nằm ở lead. Ghi chú mới viết ở cơ hội nằm ở cơ hội.
-- ===========================================================================

-- Đổi cột kết quả (thêm source_label) nên phải bỏ hàm cũ dựng lại.
drop function app.record_notes(text, uuid);

-- Ghi chú của một bản ghi, mới nhất trước. Ai gọi: người thấy được bản ghi (can_see_note_target).
-- Đầu vào: loại bản ghi, id. Kết quả: ghi chú chưa huỷ; source_label null với ghi chú của chính bản ghi;
-- với cơ hội, ghi chú của lead gốc có source_label "Lead <mã lead>" và chỉ hiện nếu người xem cũng thấy được lead đó.
-- Cần hàm riêng vì người đọc ghi chú có thể không có quyền xem bảng tài khoản để lấy tên người viết;
-- hàm chỉ trả tên hiển thị, không trả email hay mã.
create or replace function app.record_notes(p_entity_type text, p_entity_id uuid)
returns table (id uuid, at timestamptz, author_id uuid, author_name text, body text, mention_names text[], source_label text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_lead uuid;
  v_lead_code text;
begin
  -- Luật: không thấy bản ghi thì không đọc được ghi chú của nó.
  if not app.can_see_note_target(p_entity_type, p_entity_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem ghi chú của bản ghi này.');
  end if;
  -- Luật (26/10): cơ hội hiện thêm ghi chú của lead gốc, nếu người xem thấy được lead đó.
  if p_entity_type = 'OPPORTUNITY' then
    select o.lead_id into v_lead from app.opportunity o where o.id = p_entity_id;
    if v_lead is not null and not app.can_see_note_target('LEAD', v_lead) then
      v_lead := null;
    end if;
    select l.code into v_lead_code from app.lead l where l.id = v_lead;
  end if;
  return query
    select n.id, n.created_at, n.created_by, coalesce(a.display_name, 'Hệ thống'), n.body,
           coalesce((select array_agg(m.display_name order by m.display_name)
                       from app.note_mention nm join app.user_account m on m.id = nm.user_id
                      where nm.note_id = n.id), '{}'),
           case when n.entity_type = 'LEAD' and p_entity_type = 'OPPORTUNITY' then 'Lead ' || v_lead_code end
      from app.note n
      left join app.user_account a on a.id = n.created_by
     where not n.is_cancelled
       and ((n.entity_type = p_entity_type and n.entity_id = p_entity_id)
            or (v_lead is not null and n.entity_type = 'LEAD' and n.entity_id = v_lead))
     order by n.created_at desc, n.id;
end;
$$;

revoke execute on function app.record_notes(text, uuid) from public, anon;
grant execute on function app.record_notes(text, uuid) to authenticated;
