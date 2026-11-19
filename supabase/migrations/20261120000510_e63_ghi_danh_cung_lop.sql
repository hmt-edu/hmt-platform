-- E63 (20/11/2026): khối «Em có N ghi danh ở lớp này» của GD-02 (canvas 9933, khung GD02_dang_hoc).
-- app.enrollment_same_class_peers: các ghi danh KHÁC của cùng học sinh đang học cùng lớp với ghi danh này, kèm giờ còn của từng ghi danh
-- và tổng giờ còn của lớp (cộng cả ghi danh đang xem). Hàm mới riêng, không sửa app.enrollment_record.
-- Ai gọi: người có quyền Ghi danh · Xem (toàn hệ thống hoặc cơ sở mình); giáo viên không đọc (R-GV-13). Chỉ đọc.
-- Vào: p_id ghi danh. Ra: {class_id, class_code, total_remaining, peers: [{id, code, remaining}]}; không có lớp hiện tại thì class_id null, peers rỗng.
create or replace function app.enrollment_same_class_peers(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  e app.enrollment;
  v_class uuid;
  v_total numeric;
  v_peers jsonb;
begin
  select * into e from app.enrollment where id = p_id;
  -- Luật: ngoài phạm vi cơ sở thì coi như không có.
  if e.id is null or (v_scope = 'CO_SO' and e.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  -- Lớp hiện tại: dòng xếp lớp chưa kết thúc.
  select ec.class_id into v_class from app.enrollment_class ec where ec.enrollment_id = e.id and ec.end_date is null limit 1;
  if v_class is null then
    return jsonb_build_object('class_id', null, 'class_code', null, 'total_remaining', null, 'peers', '[]'::jsonb);
  end if;
  -- Luật: «cùng lớp» = cùng học sinh, dòng xếp lớp chưa kết thúc ở cùng lớp, ghi danh khác.
  select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code, 'remaining', app.enrollment_hours_balance(o.id)) order by o.code), '[]'::jsonb)
    into v_peers
    from app.enrollment o
    join app.enrollment_class oc on oc.enrollment_id = o.id and oc.class_id = v_class and oc.end_date is null
   where o.student_id = e.student_id and o.id <> e.id;
  -- Luật: giờ còn của lớp = tổng giờ còn của các ghi danh cùng học sinh ở lớp này (kể cả ghi danh đang xem).
  select app.enrollment_hours_balance(e.id) + coalesce(sum((p ->> 'remaining')::numeric), 0)
    into v_total from jsonb_array_elements(v_peers) p;
  return jsonb_build_object('class_id', v_class, 'class_code', (select c.code from app.class c where c.id = v_class),
                            'total_remaining', v_total, 'peers', v_peers);
end;
$$;
revoke execute on function app.enrollment_same_class_peers(uuid) from public, anon;
grant execute on function app.enrollment_same_class_peers(uuid) to authenticated;
