-- GV-14 Tạo ticket từ cổng giáo viên + ticket lớp tôi (canvas GV14, R-CS-10, AS-05, AS-09, AS-13). Chỉ thêm ba hàm đọc/ghi mỏng trên nền Aftersale (migration 156, 157):
-- giáo viên và trợ giảng CHỈ TẠO ticket loại Ticket giáo viên (GV) cho LỚP CỦA MÌNH và theo dõi ticket trong lớp mình; không duyệt, không đổi trạng thái.
-- Cờ: phân hệ AFTERSALE theo cơ sở (đã có, mặc định tắt); kiểm trong hàm. Ô Ảnh "Làm sau" (Q-233): chưa tải ảnh. Giáo viên trả lời trong ticket: sau 17/11.

-- app.teacher_ticket_options() -> {categories, classes}
-- Dữ liệu cho form tạo ticket: nhóm con loại GV còn dùng (kèm nhóm, tính chất Cần hỗ trợ/Phản ánh, có bắt buộc học sinh, lớp) và các lớp ĐÃ DUYỆT mà người gọi được phân công
-- kèm học sinh đang học trong lớp. Ai gọi: giáo viên, trợ giảng (vai Giáo viên, Trợ giảng) ở cơ sở có bật AFTERSALE.
create or replace function app.teacher_ticket_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := app.current_branch_id();
begin
  -- Chỉ giáo viên, trợ giảng (R-CS-10, AS-05).
  if not exists (select from app.user_role ur where ur.user_id = (select auth.uid()) and ur.is_active and ur.role_code in ('TEACHER', 'TA')) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ giáo viên, trợ giảng dùng được màn này.');
  end if;
  perform app.require_feature('AFTERSALE', v_branch);
  return jsonb_build_object(
    'categories', coalesce((select jsonb_agg(jsonb_build_object(
        'code', c.code, 'name', c.name, 'group_code', g.code, 'group_name', g.name, 'nature_code', c.nature_code,
        'requires_student', c.requires_student, 'requires_class', c.requires_class) order by g.sort_order, c.sort_order)
      from app.ticket_category c join app.ticket_category g on g.code = c.parent_code
     where c.kind = 'SUBGROUP' and c.ticket_type = 'GV' and c.is_active and g.is_active), '[]'::jsonb),
    'classes', coalesce((select jsonb_agg(jsonb_build_object(
        'id', k.id, 'code', k.code,
        'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = k.subject_code),
        'students', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.full_name) order by s.full_name)
                                from app.student s
                               where s.id in (select e.student_id from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                               where ec.class_id = k.id and ec.end_date is null)), '[]'::jsonb)) order by k.code)
      from app.class k where k.status_code = 'DA_DUYET' and k.branch_id = v_branch and app.is_assigned_to_class(k.id)), '[]'::jsonb));
end;
$$;

-- app.teacher_create_ticket(dữ liệu) -> {id, code}
-- Giáo viên, trợ giảng tạo Ticket giáo viên (loại GV, kênh Giáo viên báo) cho lớp mình. Dữ liệu (jsonb): category_code, class_id, student_id (tuỳ nhóm con), title, description.
-- Luật R-CS-10: chỉ tạo cho LỚP CỦA MÌNH (được phân công); học sinh phải đang học trong lớp đó. Phần còn lại (mã, hạn, nhóm con bắt buộc) do app.create_ticket kiểm.
create or replace function app.teacher_create_ticket(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_class uuid := nullif(p_data ->> 'class_id', '')::uuid;
  v_student uuid := nullif(p_data ->> 'student_id', '')::uuid;
  k app.class;
begin
  if not exists (select from app.user_role ur where ur.user_id = (select auth.uid()) and ur.is_active and ur.role_code in ('TEACHER', 'TA')) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ giáo viên, trợ giảng tạo được ticket giáo viên.');
  end if;
  if v_class is not null then
    select * into k from app.class where id = v_class;
    -- Luật R-CS-10: lớp phải thuộc cơ sở của người tạo và người tạo được phân công ở lớp đó.
    if k.id is null or k.branch_id is distinct from app.current_branch_id() or not app.is_assigned_to_class(k.id) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ tạo ticket cho lớp mình được phân công.');
    end if;
    if v_student is not null and not exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                              where ec.class_id = k.id and ec.end_date is null and e.student_id = v_student) then
      perform app.raise_error('HMT_EM_KHONG_TRONG_LOP', 'Học sinh này không đang học trong lớp đã chọn.');
    end if;
  elsif v_student is not null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn lớp trước khi chọn học sinh.');
  end if;
  return app.create_ticket(p_data || jsonb_build_object('ticket_type', 'GV', 'channel_code', 'GIAO_VIEN_BAO'));
end;
$$;

-- app.teacher_class_tickets(giới hạn, vị trí) -> {total, rows}
-- Ticket trong các lớp của tôi (mọi loại: đề nghị, khiếu nại, ticket giáo viên) và ticket tôi tạo; CHỈ XEM (R-CS-10). Mỗi dòng như app.ticket_row kèm lớp, học sinh.
-- Ai gọi: giáo viên, trợ giảng; cần AFTERSALE bật. Phân trang ở máy chủ (mặc định theo cài đặt).
create or replace function app.teacher_class_tickets(p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total bigint;
  v_rows jsonb;
begin
  if not exists (select from app.user_role ur where ur.user_id = (select auth.uid()) and ur.is_active and ur.role_code in ('TEACHER', 'TA')) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ giáo viên, trợ giảng xem được ticket lớp mình.');
  end if;
  perform app.require_feature('AFTERSALE', app.current_branch_id());
  with f as (
    select t from app.ticket t
     where t.branch_id = app.current_branch_id()
       and (t.created_by = (select auth.uid()) or (t.class_id is not null and app.is_assigned_to_class(t.class_id)))
  ), page as (
    select * from f order by (t).created_at desc, (t).id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(app.ticket_row(p.t)
           || jsonb_build_object('class_code', (select k.code from app.class k where k.id = (p.t).class_id),
                                 'student_name', (select s.full_name from app.student s where s.id = (p.t).student_id))
           order by (p.t).created_at desc, (p.t).id), '[]'::jsonb)
    into v_total, v_rows
    from page p;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.teacher_ticket_options(), app.teacher_create_ticket(jsonb), app.teacher_class_tickets(integer, integer) from public, anon, authenticated;
grant execute on function app.teacher_ticket_options(), app.teacher_create_ticket(jsonb), app.teacher_class_tickets(integer, integer) to authenticated;
