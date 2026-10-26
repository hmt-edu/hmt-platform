-- Kiểm sau khi chuyển danh sách em lên hmt-staging (migration 043, bổ sung e): chỉ đọc, không đổi dữ liệu.
-- Sai thì báo lỗi kèm số liệu; đúng thì in tóm tắt.
do $$
declare
  v_leads bigint;
  v_opps bigint;
  v_lines_lead bigint;
  v_lines_opp bigint;
  v_orphan_test bigint;
  v_copy bigint;
  v_branch bigint;
  v_l5 bigint;
begin
  select count(*) into v_leads from app.lead;
  select count(*) into v_opps from app.opportunity;
  select count(*) into v_lines_lead from app.prospect_student where lead_id is not null;
  select count(*) into v_lines_opp from app.prospect_student where opportunity_id is not null;
  -- Mọi phiếu kiểm tra phải trỏ tới dòng em của đúng cơ hội của nó.
  select count(*) into v_orphan_test from app.student_test t
   where not exists (select 1 from app.prospect_student ps where ps.id = t.prospect_student_id and ps.opportunity_id = t.opportunity_id);
  -- Đ86: dòng đã gắn hồ sơ học sinh không giữ bản sao chữ.
  select count(*) into v_copy from app.prospect_student
   where student_id is not null and (full_name is not null or birth_year is not null or birth_date is not null);
  -- Dòng em cùng cơ sở với hồ sơ cha.
  select count(*) into v_branch from app.prospect_student ps
   where ps.branch_id is distinct from coalesce((select l.branch_id from app.lead l where l.id = ps.lead_id),
                                                 (select o.branch_id from app.opportunity o where o.id = ps.opportunity_id));
  -- R-CRM-03: cơ hội từ L5 trở lên có em đầu đủ tên và năm sinh.
  select count(*) into v_l5 from app.opportunity o
   where app.stage_is_l5_or_later(o.stage_code)
     and ((app.opp_first(o.id)).full_name is null or (app.opp_first(o.id)).birth_year is null);
  if v_orphan_test + v_copy + v_branch + v_l5 > 0 then
    raise exception 'Danh sách em lệch: phiếu mồ côi %, dòng giữ bản sao %, dòng lệch cơ sở %, cơ hội L5+ thiếu em %',
      v_orphan_test, v_copy, v_branch, v_l5;
  end if;
  raise notice 'lead % (dòng em %), cơ hội % (dòng em %): khớp', v_leads, v_lines_lead, v_opps, v_lines_opp;
end;
$$;
