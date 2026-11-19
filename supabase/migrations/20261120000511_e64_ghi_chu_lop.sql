-- E64 (20/11/2026): cột «Ghi chú và hoạt động» (CHUNG-22) cho Lớp (LOP-02), theo báo cáo T2-3 của Tester 2 và canvas 9933 (LOP02_*).
-- Loại ghi chú mới CLASS đăng ký ở note_target (bảng app.class đã có nhật ký thay đổi); thêm một nhánh vào app.can_see_note_target.
-- Thân hàm lấy từ migration 509 (bản hiện hành, đã gồm các nhánh của 509), chỉ thêm nhánh CLASS.
insert into app.note_target (entity_type, table_name, name) values ('CLASS', 'app.class', 'Lớp');

CREATE OR REPLACE FUNCTION app.can_see_note_target(p_entity_type text, p_entity_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_branch_id uuid;
  v_test app.student_test;
begin
  if not app.current_user_ready() then
    return false;
  end if;
  if not app.mfa_satisfied() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  if p_entity_type = 'USER_ACCOUNT' then
    select branch_id into v_branch_id from app.user_account where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('ACCOUNT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'LEAD' then
    select branch_id into v_branch_id from app.lead where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('LEAD', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'OPPORTUNITY' then
    select branch_id into v_branch_id from app.opportunity where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('OPPORTUNITY', 'XEM', v_branch_id);
  end if;
  -- Luật: phiếu theo quyền Kiểm tra đầu vào · Xem và phạm vi của phiếu (cơ sở, hoặc được phân công).
  if p_entity_type = 'STUDENT_TEST' then
    select * into v_test from app.student_test where id = p_entity_id;
    return v_test.id is not null and app.test_scope_ok('XEM', v_test);
  end if;
  -- Luật: phụ huynh, học sinh theo quyền Xem của phân hệ: toàn hệ thống, hoặc đúng cơ sở tiếp nhận.
  -- Luật (27/10): báo giá theo quyền Báo giá · Xem ở cơ sở của báo giá (BH-02, Ghi chú và hoạt động).
  if p_entity_type = 'QUOTATION' then
    select branch_id into v_branch_id from app.quotation where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('QUOTATION', 'XEM', v_branch_id);
  end if;
  -- Luật (28/10): đơn hàng theo quyền Đơn hàng · Xem ở cơ sở của đơn, giống hệt báo giá (BH-05, Ghi chú và hoạt động).
  if p_entity_type = 'SALES_ORDER' then
    select branch_id into v_branch_id from app.sales_order where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('SALES_ORDER', 'XEM', v_branch_id);
  end if;
  -- Luật (07/11, Q-52): phiếu thu theo quyền Phiếu thu · Xem ở cơ sở của phiếu (cơ sở của đơn), giống hệt đơn hàng; Kế toán (toàn hệ thống) thấy mọi cơ sở.
  if p_entity_type = 'RECEIPT' then
    select branch_id into v_branch_id from app.receipt where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('RECEIPT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'PARENT' then
    select branch_id into v_branch_id from app.parent where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('PARENT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'STUDENT' then
    select branch_id into v_branch_id from app.student where id = p_entity_id;
    -- Luật R-GV-13 (E10, Soát G1): phạm vi DUOC_PHAN_CONG (giáo viên, trợ giảng) chỉ thấy ghi chú của em trong lớp mình, không phải cả cơ sở.
    if (select app.permission_scope('STUDENT', 'XEM')) = 'DUOC_PHAN_CONG' then
      return app.student_assigned_to_me(p_entity_id);
    end if;
    return v_branch_id is not null and app.can_see_branch('STUDENT', 'XEM', v_branch_id);
  end if;
  -- Luật (E61, 19/11): ghi danh theo quyền Ghi danh · Xem ở cơ sở của ghi danh (GD-02, Ghi chú và hoạt động).
  -- Giáo viên, trợ giảng (phạm vi «được phân công») không đọc ghi danh (R-GV-13).
  if p_entity_type = 'ENROLLMENT' then
    if (select app.permission_scope('ENROLLMENT', 'XEM')) = 'DUOC_PHAN_CONG' then
      return false;
    end if;
    select branch_id into v_branch_id from app.enrollment where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('ENROLLMENT', 'XEM', v_branch_id);
  end if;
  -- Luật (E61, 19/11): buổi học theo quyền Buổi học · Xem ở cơ sở của buổi (BUOI-02). Phạm vi «được phân công» (giáo viên,
  -- trợ giảng) không đọc ghi chú vận hành của buổi: cổng Giáo viên không có cột ghi chú này.
  if p_entity_type = 'CLASS_SESSION' then
    if (select app.permission_scope('SESSION', 'XEM')) = 'DUOC_PHAN_CONG' then
      return false;
    end if;
    select branch_id into v_branch_id from app.class_session where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('SESSION', 'XEM', v_branch_id);
  end if;
  -- Luật (E64, 20/11): lớp theo quyền Lớp · Xem ở cơ sở của lớp (LOP-02, Ghi chú và hoạt động). Giáo viên, trợ giảng
  -- (phạm vi «được phân công») không đọc ghi chú vận hành của lớp trong cột này.
  if p_entity_type = 'CLASS' then
    if (select app.permission_scope('CLASS', 'XEM')) = 'DUOC_PHAN_CONG' then
      return false;
    end if;
    select branch_id into v_branch_id from app.class where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('CLASS', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'BRANCH' then
    v_branch_id := p_entity_id;
  elsif p_entity_type = 'ROOM' then
    select branch_id into v_branch_id from app.room where id = p_entity_id;
  else
    return false;
  end if;
  -- R3 (Soát S16): ghi chú gắn Phòng, Cơ sở chỉ dành cho nhân viên (Học sinh, Phụ huynh không đọc).
  return app.is_staff()
    and (v_branch_id is not distinct from app.current_branch_id()
         or exists (select from app.role r where r.code = any (app.current_roles()) and r.default_scope = 'TOAN_HE_THONG'));
end;
$function$;
