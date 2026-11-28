-- Migration 714 (C-27-19 bước 2, anh Trường OK 28/11 09:12): màn «Điểm danh» là MỘT bảng, mỗi dòng một học sinh trong một buổi (R-DD-07).
-- Thay app.attendance_board: thêm phụ huynh, giáo viên tích lúc nào, phụ trách (CSKH của lớp); lọc giáo viên, phụ trách; lọc nhanh nhiều giá trị (HOẶC);
-- sắp và đếm theo nhóm ở máy chủ. Quyền, phạm vi cơ sở và khoảng ngày tối đa giữ như migration 701. Chỉ hàm đọc, không đổi dữ liệu.
-- app.attendance_call_list giữ nguyên (cùng quy tắc «Chưa vào lớp»).

-- app.attendance_board. Ai gọi: người có Buổi học · Xem toàn hệ thống hoặc cơ sở mình.
-- Vào: {from, to, branch_id, class_id, teacher_id, cskh_id, quick: [CHUA_VAO_LOP, VANG, DI_MUON, CHUA_DIEM_DANH, LECH],
--       group: tối đa hai trong [date, class, teacher, cskh]; thiếu khoá group thì theo ngày rồi lớp, mảng rỗng là không nhóm}.
-- Ra: {from, to, total, rows, groups: [{k1, k2, count}], summary, classes, teachers, owners}. Trạng thái để đếm và lọc lấy ô Giáo viên,
-- trống thì ô Vận hành (R-DD-02). «Chưa vào lớp» đúng quy tắc danh sách gọi nhắc: buổi đã bắt đầu và còn vắng, đi muộn hoặc chưa ai điểm danh.
-- summary và danh sách chọn tính trên khoảng ngày sau lọc cơ sở, lớp, giáo viên, phụ trách; không phụ thuộc lọc nhanh.
-- Số điện thoại phụ huynh chỉ trả khi người gọi còn có Phụ huynh · Xem ở cơ sở của phụ huynh.
create or replace function app.attendance_board(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_cskh uuid := nullif(p_filters ->> 'cskh_id', '')::uuid;
  v_quick text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'quick', '[]'::jsonb)));
  v_group text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'group', '["date", "class"]'::jsonb)));
  v_g1 text;
  v_g2 text;
  r record;
  v_result jsonb;
begin
  -- Luật Đ35: nhóm tối đa hai cấp, khác nhau, chỉ theo trường cho phép.
  if cardinality(v_group) > 2 -- allow-number: luật Group By tối đa hai cấp, không phải số nghiệp vụ cấu hình
     or exists (select from unnest(v_group) x where x not in ('date', 'class', 'teacher', 'cskh'))
     or v_group[1] = v_group[2] then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn tối đa hai trường nhóm khác nhau (ngày, lớp, giáo viên, phụ trách).');
  end if;
  v_g1 := v_group[1];
  v_g2 := v_group[2];
  select * into r from app.attendance_range(p_filters);
  with base as materialized (
    select a.*, c.code as class_code, c.cskh_id
      from app.attendance_rows(r.d_from, r.d_to, nullif(p_filters ->> 'branch_id', '')::uuid, v_scope = 'TOAN_HE_THONG') a
      join app.class c on c.id = a.class_id
  ), f as materialized (
    select * from base
     where (v_class is null or class_id = v_class) and (v_teacher is null or teacher_id = v_teacher) and (v_cskh is null or cskh_id = v_cskh)
  ), g as materialized (
    select f.*, tu.display_name as teacher_name, cu.display_name as cskh_name
      from f
      left join app.user_account tu on tu.id = f.teacher_id
      left join app.user_account cu on cu.id = f.cskh_id
     where cardinality(v_quick) = 0
        or ('CHUA_VAO_LOP' = any (v_quick) and f.needs_call and (f.session_date + f.start_time) <= (now() at time zone 'Asia/Ho_Chi_Minh'))
        or ('VANG' = any (v_quick) and f.effective in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP'))
        or ('DI_MUON' = any (v_quick) and f.effective = 'DI_MUON')
        or ('CHUA_DIEM_DANH' = any (v_quick) and f.effective is null)
        or ('LECH' = any (v_quick) and f.ops_status <> f.teacher_status)
  ), k as materialized (
    select g.*,
           case v_g1 when 'date' then g.session_date::text when 'class' then g.class_code when 'teacher' then coalesce(g.teacher_name, '')
                     when 'cskh' then coalesce(g.cskh_name, '') end as k1,
           case v_g2 when 'date' then g.session_date::text when 'class' then g.class_code when 'teacher' then coalesce(g.teacher_name, '')
                     when 'cskh' then coalesce(g.cskh_name, '') end as k2
      from g
  ), ordered as (
    -- Nhóm ngày: ngày mới trước; nhóm chữ: theo bảng chữ cái, trống sau cùng. Trong nhóm: ngày mới trước, giờ, lớp, tên.
    select k.*, st.code as student_code, st.full_name as student_name, st.parent_id,
           row_number() over (order by
             case when v_g1 = 'date' then k.session_date end desc, nullif(case when v_g1 <> 'date' then k.k1 end, '') asc nulls last,
             case when v_g2 = 'date' then k.session_date end desc, nullif(case when v_g2 <> 'date' then k.k2 end, '') asc nulls last,
             k.session_date desc, k.start_time, k.class_code, k.session_id, st.full_name, k.attendance_id) as pos
      from k join app.student st on st.id = k.student_id
  ), page as (
    select * from ordered order by pos limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'from', r.d_from, 'to', r.d_to,
    'total', (select count(*) from g),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
               'session_id', p.session_id, 'student_id', p.student_id, 'student_code', p.student_code, 'student_name', p.student_name,
               'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
               'class_id', p.class_id, 'class_code', p.class_code, 'subject_name', sub.name, 'grade_code', c.grade_code,
               'parent_name', pa.full_name,
               'parent_phone', case when app.can_see_branch_wide('PARENT', 'XEM', pa.branch_id) then pa.phone end,
               'teacher_name', p.teacher_name, 'cskh_name', p.cskh_name,
               'locked', p.session_status = 'DONE',
               'ops_status_code', p.ops_status, 'teacher_status_code', p.teacher_status, 'teacher_marked_at', sa.teacher_marked_at,
               'contact_reason_code', p.contact_reason_code, 'contact_reason_name', rs.name, 'ops_note', p.ops_note,
               'k1', p.k1, 'k2', p.k2)
             order by p.pos)
        from page p
        join app.class c on c.id = p.class_id
        join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
        join app.session_attendance sa on sa.id = p.attendance_id
        join app.parent pa on pa.id = p.parent_id
        left join app.catalog_item rs on rs.catalog_code = p.contact_reason_catalog and rs.code = p.contact_reason_code), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(jsonb_build_object('k1', x.k1, 'k2', x.k2, 'count', x.n) order by x.k1, x.k2)
        from (select k1, k2, count(*) as n from k where v_g1 is not null group by k1, k2) x), '[]'::jsonb),
    'summary', (
      select jsonb_build_object(
               'present', count(*) filter (where effective = 'CO_MAT'),
               'late', count(*) filter (where effective = 'DI_MUON'),
               'absent', count(*) filter (where effective in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')),
               'unmarked', count(*) filter (where effective is null),
               'mismatch', count(*) filter (where ops_status <> teacher_status),
               'not_in_class', count(*) filter (where needs_call and (session_date + start_time) <= (now() at time zone 'Asia/Ho_Chi_Minh')))
        from f),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'code', c.code) order by c.code)
        from app.class c where c.id in (select class_id from base)), '[]'::jsonb),
    'teachers', coalesce((
      select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name) order by u.display_name, u.id)
        from app.user_account u where u.id in (select teacher_id from base)), '[]'::jsonb),
    'owners', coalesce((
      select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name) order by u.display_name, u.id)
        from app.user_account u where u.id in (select cskh_id from base)), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;
revoke execute on function app.attendance_board(jsonb, integer, integer) from public, anon;
grant execute on function app.attendance_board(jsonb, integer, integer) to authenticated;
