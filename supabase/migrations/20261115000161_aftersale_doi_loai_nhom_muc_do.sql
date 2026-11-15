-- Code B (16/11/2026), Aftersale lát 4, migration 161: đổi loại, đổi nhóm con, đổi mức độ ticket (canvas 9189: CSN04_doi_loai, CSN04_doi_nhom_con, CSN03 «Đổi mức độ thì hạn tính lại từ lúc tạo»).
-- Luật: docs/spec/de-xuat-luat-aftersale.md AS-02 (nhật ký), AS-05 (loại), AS-07 (hạn chụp, tính lại từ lúc tạo), AS-08 (mức độ mặc định theo nhóm con), AS-13 (công tắc).
-- Làm gì: ba hàm đổi, chung một hàm trong lõi app.reclassify_ticket (kiểm luật, tính lại hạn, ghi nhật ký). Mã ticket KHÔNG đổi (AS-01).
select set_config('hmt.migration', 'on', false);

-- Thêm cột lưu giá trị cũ cho nhật ký đổi: dùng cột note (chữ). Không thêm cột.

-- app.reclassify_ticket (nội bộ): đổi loại, nhóm con, mức độ của một ticket rồi tính lại hạn.
-- Luật AS-07: hạn tính lại từ lúc tạo theo loại/mức độ/nhóm con mới, GIỮ phần dời hạn do thời gian Chờ thông tin (độ lệch giữa hạn cũ và công thức cũ).
-- Luật AS-02: ticket đã đóng hoặc huỷ chỉ xem. Luật AS-05: chỉ đổi giữa Đề nghị và Khiếu nại, và chỉ khi chưa Đang xử lý (đang tiếp nhận); ticket giáo viên không đổi loại.
-- Người gọi đã được kiểm quyền ở hàm bọc bên ngoài; hàm này không cấp cho người dùng.
create or replace function app.reclassify_ticket(p_id uuid, p_type text, p_category text, p_priority text, p_event text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_cat app.ticket_category;
  v_old_res integer;
  v_old_resp integer;
  v_new_res integer;
  v_new_resp integer;
  v_note text;
begin
  select * into t from app.ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  -- Luật AS-02: ticket đã đóng hoặc huỷ chỉ xem.
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không đổi được.');
  end if;
  -- Luật AS-05: đổi loại chỉ giữa Đề nghị và Khiếu nại, khi đang tiếp nhận (Mới, Đã giao).
  if p_type <> t.ticket_type then
    if t.ticket_type = 'GV' or p_type not in ('DN', 'KN') then
      perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Chỉ đổi qua lại giữa Đề nghị và Khiếu nại; ticket giáo viên không đổi loại.');
    end if;
    if t.status_code not in ('MOI', 'DA_GIAO') then
      perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Chỉ đổi loại khi ticket đang tiếp nhận (Mới, Đã giao).');
    end if;
  end if;
  select * into v_cat from app.ticket_category where code = p_category and kind = 'SUBGROUP' and is_active;
  if v_cat.id is null or v_cat.ticket_type <> p_type then
    perform app.raise_error('HMT_TICKET_NHOM_SAI', 'Nhóm con không có, đã Ngừng hoặc không thuộc loại ticket này.');
  end if;
  perform app.assert_catalog_code_active('TICKET_PRIORITY', p_priority);
  -- Luật AS-10, AS-05: nhóm con mới vẫn đòi học sinh, lớp đã có trên ticket.
  if v_cat.requires_student and t.student_id is null then
    perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Nhóm con này bắt buộc chọn học sinh.');
  end if;
  if v_cat.requires_class and t.class_id is null then
    perform app.raise_error('HMT_TICKET_THIEU_LOP', 'Nhóm con này bắt buộc chọn lớp.');
  end if;
  -- Luật AS-07: độ lệch hạn do thời gian chờ thông tin = hạn hiện tại trừ công thức cũ; giữ độ lệch khi tính hạn mới.
  v_old_res := app.ticket_resolve_hours(t.ticket_type, t.priority_code, t.category_code);
  select r.response_hours into v_old_resp from app.ticket_sla_rule r where r.ticket_type = t.ticket_type and r.priority_code = t.priority_code;
  v_new_res := app.ticket_resolve_hours(p_type, p_priority, p_category);
  select r.response_hours into v_new_resp from app.ticket_sla_rule r where r.ticket_type = p_type and r.priority_code = p_priority;
  v_note := case p_event
              when 'DOI_LOAI' then t.ticket_type || ' → ' || p_type
              when 'DOI_NHOM_CON' then t.category_code || ' → ' || p_category
              else t.priority_code || ' → ' || p_priority end;
  update app.ticket set
    ticket_type = p_type, category_code = p_category, priority_code = p_priority,
    resolve_due_at = created_at + make_interval(hours => v_new_res) + (t.resolve_due_at - (t.created_at + make_interval(hours => v_old_res))),
    response_due_at = created_at + make_interval(hours => v_new_resp) + (t.response_due_at - (t.created_at + make_interval(hours => v_old_resp)))
   where id = p_id;
  -- Luật AS-02: mọi lần đổi có dòng nhật ký (loại sự kiện theo việc đổi; đổi loại ghi chung DOI_NHOM_CON kèm ghi chú).
  insert into app.ticket_event (ticket_id, branch_id, event_type, note)
  values (p_id, t.branch_id, case p_event when 'DOI_MUC_DO' then 'DOI_MUC_DO' else 'DOI_NHOM_CON' end,
          case p_event when 'DOI_LOAI' then 'Đổi loại: ' || v_note else v_note end);
end;
$$;
revoke execute on function app.reclassify_ticket(uuid, text, text, text, text) from public, anon, authenticated;

-- app.change_ticket_category(mã ticket, nhóm con mới): đổi nhóm con trong cùng loại; mức độ giữ nguyên. Ai gọi: Ticket · Sửa ở cơ sở đó.
create or replace function app.change_ticket_category(p_id uuid, p_category text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.reclassify_ticket(p_id, t.ticket_type, p_category, t.priority_code, 'DOI_NHOM_CON');
end;
$$;

-- app.change_ticket_priority(mã ticket, mức độ mới): đổi mức độ (Khẩn, Cao, Thường, Thấp); hạn tính lại từ lúc tạo (AS-07).
create or replace function app.change_ticket_priority(p_id uuid, p_priority text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.reclassify_ticket(p_id, t.ticket_type, t.category_code, p_priority, 'DOI_MUC_DO');
end;
$$;

-- app.change_ticket_type(mã ticket, loại mới, nhóm con mới): đổi qua lại Đề nghị và Khiếu nại khi đang tiếp nhận; bắt buộc chọn lại nhóm con của loại mới (AS-05).
-- Mức độ đặt lại theo mặc định của nhóm con mới (AS-08).
create or replace function app.change_ticket_type(p_id uuid, p_type text, p_category text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_priority text;
begin
  select * into t from app.ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  select coalesce(c.default_priority, t.priority_code) into v_priority from app.ticket_category c where c.code = p_category;
  perform app.reclassify_ticket(p_id, p_type, p_category, coalesce(v_priority, t.priority_code), 'DOI_LOAI');
end;
$$;

revoke execute on function app.change_ticket_category(uuid, text), app.change_ticket_priority(uuid, text), app.change_ticket_type(uuid, text, text)
  from public, anon, authenticated;
grant execute on function app.change_ticket_category(uuid, text), app.change_ticket_priority(uuid, text), app.change_ticket_type(uuid, text, text) to authenticated;

select set_config('hmt.migration', '', false);
