-- P3e-1 (DB): dữ liệu cho màn Phiếu kiểm tra (TS-15 tạo và đổi lịch, TS-16 danh sách, Kanban, Lịch; TS-17 bản ghi; docs/spec/04
-- R-CRM-05, 06, 07, 10, 11, 15, 21, 29). Gồm: get_student_test (một lần gọi cho trang bản ghi), list_student_tests và
-- student_test_board thay thân (thêm lọc nhiều lựa chọn cùng nhóm HOẶC: "của tôi" tôi tạo, tôi phụ trách, tôi chấm; thời gian quá hạn,
-- hôm nay, sắp tới; môn, hình thức, cấp độ), student_test_group_counts (Group By), export_student_tests (Xuất), list_test_graders và
-- list_test_rooms (chọn giáo viên chấm, phòng). Không bảng mới, không chỉ mục mới (cột lọc đã có chỉ mục từ migration 030).

-- ---------------------------------------------------------------------------
-- Đọc một phiếu cho trang bản ghi (TS-17). Ai gọi: người có quyền Kiểm tra đầu vào · Xem theo phạm vi của phiếu (toàn hệ thống, cơ sở
-- của cơ hội, hoặc được phân công: giáo viên chấm, người phụ trách).
-- Kết quả: các cột của phiếu (trừ cột tìm kiếm) kèm: tên danh mục (trạng thái, môn, khối, hình thức, cấp độ, trình độ và phân loại đề
-- xuất, lý do huỷ), cơ sở của cơ hội và cơ sở test, phòng (tên, sức chứa), giáo viên chấm, người phụ trách, người tạo, người sửa, người
-- nhập kết quả (cờ "nhập thay"), học sinh, phụ huynh, cơ hội (mã, giai đoạn), lead gốc, số lịch hẹn (tổng, chưa làm).
-- Cần hàm riêng vì người xem phiếu có thể không đọc được bảng tài khoản, học sinh, phụ huynh để lấy tên, mã.
-- security definer có chủ ý: quyền kiểm bên trong bằng app.test_scope_ok.
-- ---------------------------------------------------------------------------
create or replace function app.get_student_test(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v app.student_test;
begin
  select * into v from app.student_test where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu kiểm tra.');
  end if;
  -- Luật: xem phiếu cần quyền Kiểm tra đầu vào · Xem theo phạm vi của phiếu.
  if not app.test_scope_ok('XEM', v) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu kiểm tra này.');
  end if;
  return (to_jsonb(v) - 'search_text') || jsonb_build_object(
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_STATUS' and c.code = v.status_code),
    'subject', (select c.name from app.catalog_item c where c.catalog_code = 'SUBJECT' and c.code = v.subject_code),
    'grade', (select c.name from app.catalog_item c where c.catalog_code = 'GRADE' and c.code = v.grade_code),
    'mode', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_MODE' and c.code = v.mode_code),
    'level', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_LEVEL' and c.code = v.level_code),
    'suggested_level', (select c.name from app.catalog_item c where c.catalog_code = 'LEVEL' and c.code = v.suggested_level_code),
    'suggested_framework', (select c.name from app.catalog_item c where c.catalog_code = 'FRAMEWORK_LEVEL' and c.code = v.suggested_framework_code),
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'TEST_CANCEL_REASON' and c.code = v.cancel_reason_code),
    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
    'branch_name', (select b.name from app.branch b where b.id = v.branch_id),
    'test_branch_code', (select b.code from app.branch b where b.id = v.test_branch_id),
    'test_branch_name', (select b.name from app.branch b where b.id = v.test_branch_id),
    'created_branch_code', (select b.code from app.branch b where b.id = v.created_branch_id),
    'created_branch_name', (select b.name from app.branch b where b.id = v.created_branch_id),
    'room_name', (select r.name from app.room r where r.id = v.room_id),
    'room_capacity', (select r.capacity from app.room r where r.id = v.room_id),
    'grader_name', app.staff_display_name(v.grader_id),
    'owner_name', app.staff_display_name(v.owner_id),
    'created_by_name', app.staff_display_name(v.created_by),
    'updated_by_name', app.staff_display_name(v.updated_by),
    'result_entered_by_name', app.staff_display_name(v.result_entered_by),
    'student_code', (select s.code from app.student s where s.id = v.student_id),
    'student_name', (select s.full_name from app.student s where s.id = v.student_id),
    'student_birth_year', (select s.birth_year from app.student s where s.id = v.student_id),
    'parent_code', (select p.code from app.parent p join app.student s on s.parent_id = p.id where s.id = v.student_id),
    'parent_name', (select p.full_name from app.parent p join app.student s on s.parent_id = p.id where s.id = v.student_id),
    'opportunity_code', (select o.code from app.opportunity o where o.id = v.opportunity_id),
    'opportunity_stage_code', (select o.stage_code from app.opportunity o where o.id = v.opportunity_id),
    'lead_id', (select o.lead_id from app.opportunity o where o.id = v.opportunity_id),
    'lead_code', (select l.code from app.opportunity o join app.lead l on l.id = o.lead_id where o.id = v.opportunity_id),
    'appointments_total', (select count(*) from app.appointment a where a.student_test_id = v.id),
    'appointments_open', (select count(*) from app.appointment a where a.student_test_id = v.id and a.status = 'CHUA_LAM'));
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách phiếu phân trang ở máy chủ (TS-16). Trả {total, rows}; chỉ các cột màn hiện. security definer có chủ ý (LIKE không
-- "leakproof" dưới RLS): phạm vi từ app.permission_scope('STUDENT_TEST', 'XEM'), gồm toàn hệ thống, đúng cơ sở của cơ hội, hoặc được
-- phân công (giáo viên chấm, người phụ trách).
-- Bộ lọc (p_filters): q (tìm không dấu: mã, học sinh, phụ huynh, SĐT, tên đề), status[], subject[], mode[], level[], branch_id (cơ
--   sở của cơ hội), test_branch_id, room_id, owner_id, grader_id, mine (tôi phụ trách), created_by_me (tôi tạo), grader_mine (tôi chấm
--   bài), mine_roles[] (OWNER, CREATOR, GRADER: cùng nhóm HOẶC, R-CRM-07), when[] (OVERDUE: phiếu Nháp quá giờ test, TODAY, UPCOMING: từ
--   ngày mai; cùng nhóm HOẶC; mốc hôm nay theo giờ Việt Nam tính trong DB), opportunity_id, student_id, from, to (giờ test), late_before.
-- Sắp xếp: time_asc (mặc định), time_desc, created_desc.
-- Thêm so với 030: bộ lọc subject, mode, level, mine_roles[], when[]; cột created_by_name (Người tạo), student_birth_year.
-- ---------------------------------------------------------------------------
create or replace function app.list_student_tests(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_subject text[] := array(select jsonb_array_elements_text(p_filters -> 'subject'));
  v_mode text[] := array(select jsonb_array_elements_text(p_filters -> 'mode'));
  v_level text[] := array(select jsonb_array_elements_text(p_filters -> 'level'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_test_branch uuid := nullif(p_filters ->> 'test_branch_id', '')::uuid;
  v_room uuid := nullif(p_filters ->> 'room_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_grader uuid := nullif(p_filters ->> 'grader_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_created_by_me boolean := coalesce((p_filters ->> 'created_by_me')::boolean, false);
  v_grader_mine boolean := coalesce((p_filters ->> 'grader_mine')::boolean, false);
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_when text[] := array(select jsonb_array_elements_text(p_filters -> 'when'));
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_late timestamptz := nullif(p_filters ->> 'late_before', '')::timestamptz;
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu kiểm tra.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select t.*
      from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or t.status_code = any (v_status))
       and (cardinality(v_subject) = 0 or t.subject_code = any (v_subject))
       and (cardinality(v_mode) = 0 or t.mode_code = any (v_mode))
       and (cardinality(v_level) = 0 or t.level_code = any (v_level))
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_room is null or t.room_id = v_room)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and t.owner_id = v_me)
        or ('CREATOR' = any (v_mine_roles) and t.created_by = v_me)
        or ('GRADER' = any (v_mine_roles) and t.grader_id = v_me))
       and (cardinality(v_when) = 0
        or ('OVERDUE' = any (v_when) and t.status_code = 'DRAFT' and t.scheduled_at < v_day_start)
        or ('TODAY' = any (v_when) and t.scheduled_at >= v_day_start and t.scheduled_at < v_day_end)
        or ('UPCOMING' = any (v_when) and t.scheduled_at >= v_day_end))
       and (v_opp is null or t.opportunity_id = v_opp)
       and (v_student is null or t.student_id = v_student)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
       and (v_late is null or (t.status_code = 'DRAFT' and t.scheduled_at < v_late))
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              case when p_sort = 'created_desc' then f.created_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_id', p.student_id, 'student_code', s.code, 'student_name', s.full_name,
             'student_birth_year', s.birth_year, 'parent_name', pa.full_name,
             'subject_code', p.subject_code, 'grade_code', p.grade_code, 'mode_code', p.mode_code, 'level_code', p.level_code,
             'exam_name', p.exam_name, 'scheduled_at', p.scheduled_at, 'status_code', p.status_code,
             'branch_code', b.code, 'test_branch_code', tb.code, 'room_id', p.room_id, 'room_name', r.name,
             'grader_id', p.grader_id, 'grader_name', app.staff_display_name(p.grader_id),
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'created_by_name', app.staff_display_name(p.created_by),
             'score', p.score, 'cancel_reason_code', p.cancel_reason_code, 'created_at', p.created_at)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc,
                      case when p_sort = 'created_desc' then p.created_at end desc,
                      p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.opportunity o on o.id = p.opportunity_id
    join app.student s on s.id = p.student_id
    join app.parent pa on pa.id = s.parent_id
    join app.branch b on b.id = p.branch_id
    join app.branch tb on tb.id = p.test_branch_id
    left join app.room r on r.id = p.room_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Kanban phiếu (TS-16 K2): một lần gọi trả các cột Nháp, Đang test, Chờ giáo viên chấm, Hoàn thành, Đã huỷ: tổng của cột và N phiếu
-- (N theo kanban_cards_per_column, tối đa list_page_size_max). Bộ lọc như list_student_tests (bỏ status). Cột đang làm xếp theo giờ
-- test gần nhất trước; Hoàn thành, Đã huỷ xếp theo giờ test mới nhất trước.
-- Thêm so với 030: cùng các bộ lọc mới của list_student_tests; thẻ có cấp độ, mã người phụ trách, giáo viên chấm, người tạo (để hiện nhãn "Tôi"); mỗi cột có bar = số đếm cho thanh đầu cột TÍNH TRÊN
-- CẢ CỘT (không chỉ N thẻ): upcoming = giờ test từ ngày mai, today = hôm nay, overdue = phiếu Nháp quá giờ test (nhãn "Quá giờ").
-- ---------------------------------------------------------------------------
create or replace function app.student_test_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_subject text[] := array(select jsonb_array_elements_text(p_filters -> 'subject'));
  v_mode text[] := array(select jsonb_array_elements_text(p_filters -> 'mode'));
  v_level text[] := array(select jsonb_array_elements_text(p_filters -> 'level'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_test_branch uuid := nullif(p_filters ->> 'test_branch_id', '')::uuid;
  v_room uuid := nullif(p_filters ->> 'room_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_grader uuid := nullif(p_filters ->> 'grader_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_created_by_me boolean := coalesce((p_filters ->> 'created_by_me')::boolean, false);
  v_grader_mine boolean := coalesce((p_filters ->> 'grader_mine')::boolean, false);
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_when text[] := array(select jsonb_array_elements_text(p_filters -> 'when'));
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_late timestamptz := nullif(p_filters ->> 'late_before', '')::timestamptz;
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_per integer := least(greatest(coalesce(p_per_column, app.get_setting_int('kanban_cards_per_column')), 1),
                         app.get_setting_int('list_page_size_max'));
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu kiểm tra.');
  end if;
  with f as not materialized (
    select t.*
      from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (cardinality(v_subject) = 0 or t.subject_code = any (v_subject))
       and (cardinality(v_mode) = 0 or t.mode_code = any (v_mode))
       and (cardinality(v_level) = 0 or t.level_code = any (v_level))
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_room is null or t.room_id = v_room)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and t.owner_id = v_me)
        or ('CREATOR' = any (v_mine_roles) and t.created_by = v_me)
        or ('GRADER' = any (v_mine_roles) and t.grader_id = v_me))
       and (cardinality(v_when) = 0
        or ('OVERDUE' = any (v_when) and t.status_code = 'DRAFT' and t.scheduled_at < v_day_start)
        or ('TODAY' = any (v_when) and t.scheduled_at >= v_day_start and t.scheduled_at < v_day_end)
        or ('UPCOMING' = any (v_when) and t.scheduled_at >= v_day_end))
       and (v_opp is null or t.opportunity_id = v_opp)
       and (v_student is null or t.student_id = v_student)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
       and (v_late is null or (t.status_code = 'DRAFT' and t.scheduled_at < v_late))
  ),
  counts as (
    select status_code, count(*) as n,
           count(*) filter (where scheduled_at >= v_day_end) as n_upcoming,
           count(*) filter (where scheduled_at >= v_day_start and scheduled_at < v_day_end) as n_today,
           count(*) filter (where status_code = 'DRAFT' and scheduled_at < v_day_start) as n_overdue
      from f group by status_code)
  select coalesce(jsonb_agg(jsonb_build_object(
           'status_code', s.code, 'name', s.name, 'total', coalesce(c.n, 0),
           'bar', jsonb_build_object('upcoming', coalesce(c.n_upcoming, 0), 'today', coalesce(c.n_today, 0),
                                     'overdue', coalesce(c.n_overdue, 0)),
           'rows', cards.rows) order by s.sort_order),
           '[]'::jsonb)
    into v_result
    from app.catalog_item s
    left join counts c on c.status_code = s.code
    cross join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', t.id, 'code', t.code, 'student_name', st.full_name, 'parent_name', pa.full_name,
               'subject_code', t.subject_code, 'grade_code', t.grade_code, 'mode_code', t.mode_code, 'level_code', t.level_code,
               'scheduled_at', t.scheduled_at, 'test_branch_code', tb.code, 'room_name', r.name,
               'grader_id', t.grader_id, 'grader_name', app.staff_display_name(t.grader_id),
               'owner_id', t.owner_id, 'owner_name', app.staff_display_name(t.owner_id),
               'created_by', t.created_by, 'created_by_name', app.staff_display_name(t.created_by),
               'score', t.score, 'status_code', t.status_code)
               order by case when s.code in ('COMPLETED', 'CANCELLED') then t.scheduled_at end desc,
                        t.scheduled_at asc, t.id), '[]'::jsonb) as rows
        from (select * from f where f.status_code = s.code
               order by case when s.code in ('COMPLETED', 'CANCELLED') then f.scheduled_at end desc, f.scheduled_at asc, f.id
               limit v_per) t
        join app.student st on st.id = t.student_id
        join app.parent pa on pa.id = st.parent_id
        join app.branch tb on tb.id = t.test_branch_id
        left join app.room r on r.id = t.room_id
    ) cards
   where s.catalog_code = 'TEST_STATUS' and s.is_active;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tên hiển thị của một giá trị nhóm (Group By) của phiếu; chỗ rỗng là "Chưa có". Hàm nội bộ cho student_test_group_counts.
-- ---------------------------------------------------------------------------
create or replace function app.student_test_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then coalesce((select name from app.catalog_item where catalog_code = 'TEST_STATUS' and code = p_key), p_key)
    when p_field = 'subject' then coalesce((select name from app.catalog_item where catalog_code = 'SUBJECT' and code = p_key), p_key)
    when p_field = 'mode' then coalesce((select name from app.catalog_item where catalog_code = 'TEST_MODE' and code = p_key), p_key)
    when p_field = 'level' then coalesce((select name from app.catalog_item where catalog_code = 'TEST_LEVEL' and code = p_key), p_key)
    when p_field in ('owner', 'grader') then coalesce(app.staff_display_name(p_key::uuid), p_key)
    when p_field = 'test_branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    else p_key end;
$$;

-- ---------------------------------------------------------------------------
-- Đếm nhóm cho Group By của danh sách Phiếu (một đến hai cấp, không tải cả bảng). p_fields: status, subject, mode, level, owner, grader,
-- test_branch (tối đa hai, khác nhau). Bộ lọc như list_student_tests. Kết quả: {total, groups: [{k1, l1, k2, l2, count}]}.
-- Mở một nhóm thì giao diện gọi list_student_tests với bộ lọc của nhóm đó. Chỗ rỗng là "Chưa có".
-- ---------------------------------------------------------------------------
create or replace function app.student_test_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_subject text[] := array(select jsonb_array_elements_text(p_filters -> 'subject'));
  v_mode text[] := array(select jsonb_array_elements_text(p_filters -> 'mode'));
  v_level text[] := array(select jsonb_array_elements_text(p_filters -> 'level'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_test_branch uuid := nullif(p_filters ->> 'test_branch_id', '')::uuid;
  v_room uuid := nullif(p_filters ->> 'room_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_grader uuid := nullif(p_filters ->> 'grader_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_created_by_me boolean := coalesce((p_filters ->> 'created_by_me')::boolean, false);
  v_grader_mine boolean := coalesce((p_filters ->> 'grader_mine')::boolean, false);
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_when text[] := array(select jsonb_array_elements_text(p_filters -> 'when'));
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_late timestamptz := nullif(p_filters ->> 'late_before', '')::timestamptz;
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu kiểm tra.');
  end if;
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'subject', 'mode', 'level', 'owner', 'grader', 'test_branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (trạng thái, môn, hình thức, cấp độ, người phụ trách, giáo viên chấm, cơ sở test).');
  end if;
  with f as not materialized (
    select t.*
      from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or t.status_code = any (v_status))
       and (cardinality(v_subject) = 0 or t.subject_code = any (v_subject))
       and (cardinality(v_mode) = 0 or t.mode_code = any (v_mode))
       and (cardinality(v_level) = 0 or t.level_code = any (v_level))
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_room is null or t.room_id = v_room)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and t.owner_id = v_me)
        or ('CREATOR' = any (v_mine_roles) and t.created_by = v_me)
        or ('GRADER' = any (v_mine_roles) and t.grader_id = v_me))
       and (cardinality(v_when) = 0
        or ('OVERDUE' = any (v_when) and t.status_code = 'DRAFT' and t.scheduled_at < v_day_start)
        or ('TODAY' = any (v_when) and t.scheduled_at >= v_day_start and t.scheduled_at < v_day_end)
        or ('UPCOMING' = any (v_when) and t.scheduled_at >= v_day_end))
       and (v_opp is null or t.opportunity_id = v_opp)
       and (v_student is null or t.student_id = v_student)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
       and (v_late is null or (t.status_code = 'DRAFT' and t.scheduled_at < v_late))
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'subject' then f.subject_code when 'mode' then f.mode_code
                     when 'level' then f.level_code when 'owner' then f.owner_id::text when 'grader' then f.grader_id::text
                     when 'test_branch' then f.test_branch_id::text end as k1,
           case v_f2 when 'status' then f.status_code when 'subject' then f.subject_code when 'mode' then f.mode_code
                     when 'level' then f.level_code when 'owner' then f.owner_id::text when 'grader' then f.grader_id::text
                     when 'test_branch' then f.test_branch_id::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.student_test_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.student_test_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xuất danh sách phiếu ra file (CHUNG-18). Ai gọi: người có quyền Kiểm tra đầu vào · Xuất theo ma trận quyền (hiện: Trưởng cơ sở trong
-- cơ sở mình, Admin). Gom việc kiểm quyền, ghi nhật ký xuất (app.log_export) và lấy dữ liệu trong MỘT giao dịch: ghi nhật ký không được
-- thì không có dữ liệu. Chỉ lấy tối đa export_max_rows dòng (giờ test mới nhất trước); quá thì truncated = true.
-- Bộ lọc (p_filters): q (tìm không dấu: mã, học sinh, phụ huynh, SĐT, tên đề), status[], subject[], mode[], level[], branch_id (cơ
--   sở của cơ hội), test_branch_id, room_id, owner_id, grader_id, mine (tôi phụ trách), created_by_me (tôi tạo), grader_mine (tôi chấm
--   bài), mine_roles[] (OWNER, CREATOR, GRADER: cùng nhóm HOẶC, R-CRM-07), when[] (OVERDUE: phiếu Nháp quá giờ test, TODAY, UPCOMING: từ
--   ngày mai; cùng nhóm HOẶC; mốc hôm nay theo giờ Việt Nam tính trong DB), opportunity_id, student_id, from, to (giờ test), late_before.
-- Kết quả: {total, exported, truncated, rows}; rows có tên danh mục (không phải mã) cho người đọc file.
-- ---------------------------------------------------------------------------
create or replace function app.export_student_tests(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_scope text;
  v_my_branch uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_subject text[] := array(select jsonb_array_elements_text(p_filters -> 'subject'));
  v_mode text[] := array(select jsonb_array_elements_text(p_filters -> 'mode'));
  v_level text[] := array(select jsonb_array_elements_text(p_filters -> 'level'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_test_branch uuid := nullif(p_filters ->> 'test_branch_id', '')::uuid;
  v_room uuid := nullif(p_filters ->> 'room_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_grader uuid := nullif(p_filters ->> 'grader_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_created_by_me boolean := coalesce((p_filters ->> 'created_by_me')::boolean, false);
  v_grader_mine boolean := coalesce((p_filters ->> 'grader_mine')::boolean, false);
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_when text[] := array(select jsonb_array_elements_text(p_filters -> 'when'));
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_late timestamptz := nullif(p_filters ->> 'late_before', '')::timestamptz;
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất (không phải Xem).
  v_scope := app.permission_scope('STUDENT_TEST', 'XUAT');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách phiếu kiểm tra.');
  end if;
  select count(*) into v_total
    from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or t.status_code = any (v_status))
       and (cardinality(v_subject) = 0 or t.subject_code = any (v_subject))
       and (cardinality(v_mode) = 0 or t.mode_code = any (v_mode))
       and (cardinality(v_level) = 0 or t.level_code = any (v_level))
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_room is null or t.room_id = v_room)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and t.owner_id = v_me)
        or ('CREATOR' = any (v_mine_roles) and t.created_by = v_me)
        or ('GRADER' = any (v_mine_roles) and t.grader_id = v_me))
       and (cardinality(v_when) = 0
        or ('OVERDUE' = any (v_when) and t.status_code = 'DRAFT' and t.scheduled_at < v_day_start)
        or ('TODAY' = any (v_when) and t.scheduled_at >= v_day_start and t.scheduled_at < v_day_end)
        or ('UPCOMING' = any (v_when) and t.scheduled_at >= v_day_end))
       and (v_opp is null or t.opportunity_id = v_opp)
       and (v_student is null or t.student_id = v_student)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
       and (v_late is null or (t.status_code = 'DRAFT' and t.scheduled_at < v_late));
  with f as (
    select t.*
      from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or t.status_code = any (v_status))
       and (cardinality(v_subject) = 0 or t.subject_code = any (v_subject))
       and (cardinality(v_mode) = 0 or t.mode_code = any (v_mode))
       and (cardinality(v_level) = 0 or t.level_code = any (v_level))
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_room is null or t.room_id = v_room)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and t.owner_id = v_me)
        or ('CREATOR' = any (v_mine_roles) and t.created_by = v_me)
        or ('GRADER' = any (v_mine_roles) and t.grader_id = v_me))
       and (cardinality(v_when) = 0
        or ('OVERDUE' = any (v_when) and t.status_code = 'DRAFT' and t.scheduled_at < v_day_start)
        or ('TODAY' = any (v_when) and t.scheduled_at >= v_day_start and t.scheduled_at < v_day_end)
        or ('UPCOMING' = any (v_when) and t.scheduled_at >= v_day_end))
       and (v_opp is null or t.opportunity_id = v_opp)
       and (v_student is null or t.student_id = v_student)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
       and (v_late is null or (t.status_code = 'DRAFT' and t.scheduled_at < v_late))
     order by t.scheduled_at desc, t.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code, 'opportunity', o.code, 'student_name', s.full_name, 'student_birth_year', s.birth_year,
           'parent_name', pa.full_name, 'parent_phone', pa.phone,
           'subject', su.name, 'grade', gr.name, 'mode', mo.name, 'level', le.name, 'exam_name', f.exam_name,
           'scheduled_at', f.scheduled_at, 'status', st.name,
           'branch', b.code, 'test_branch', tb.code, 'room', r.name,
           'grader', app.staff_display_name(f.grader_id), 'owner', app.staff_display_name(f.owner_id),
           'created_by', app.staff_display_name(f.created_by),
           'score', f.score, 'suggested_level', sl.name, 'suggested_framework', sf.name,
           'cancel_reason', cr.name, 'created_at', f.created_at) order by f.scheduled_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.opportunity o on o.id = f.opportunity_id
    join app.student s on s.id = f.student_id
    join app.parent pa on pa.id = s.parent_id
    join app.branch b on b.id = f.branch_id
    join app.branch tb on tb.id = f.test_branch_id
    left join app.room r on r.id = f.room_id
    left join app.catalog_item st on st.catalog_code = 'TEST_STATUS' and st.code = f.status_code
    left join app.catalog_item su on su.catalog_code = 'SUBJECT' and su.code = f.subject_code
    left join app.catalog_item gr on gr.catalog_code = 'GRADE' and gr.code = f.grade_code
    left join app.catalog_item mo on mo.catalog_code = 'TEST_MODE' and mo.code = f.mode_code
    left join app.catalog_item le on le.catalog_code = 'TEST_LEVEL' and le.code = f.level_code
    left join app.catalog_item sl on sl.catalog_code = 'LEVEL' and sl.code = f.suggested_level_code
    left join app.catalog_item sf on sf.catalog_code = 'FRAMEWORK_LEVEL' and sf.code = f.suggested_framework_code
    left join app.catalog_item cr on cr.catalog_code = 'TEST_CANCEL_REASON' and cr.code = f.cancel_reason_code;
  -- Ghi nhật ký xuất TRƯỚC khi trả dữ liệu (cùng giao dịch): lỗi ở đây thì không có file.
  perform app.log_export('STUDENT_TEST', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách để chọn trong hộp tạo, sửa phiếu (TS-15, TS-17).
-- list_test_graders: giáo viên (vai trò TEACHER) đang hoạt động của một cơ sở; người gọi cần quyền Kiểm tra đầu vào · Tạo hoặc Sửa.
--   Giáo viên không thuộc cổng CRM nên không có trong list_assignable_staff; hàm kiểm chọn giáo viên chấm (assert_grader) là luật thật.
-- list_test_rooms: phòng đang dùng của một cơ sở test, kèm sức chứa; cùng điều kiện quyền.
-- ---------------------------------------------------------------------------
create or replace function app.list_test_graders(p_branch_id uuid default null)
returns table (id uuid, display_name text, branch_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.current_branch_id());
begin
  if not (app.has_permission('STUDENT_TEST', 'TAO') or app.has_permission('STUDENT_TEST', 'SUA')) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền chọn giáo viên chấm.');
  end if;
  return query
    select u.id, u.display_name, b.code
      from app.user_account u
      join app.branch b on b.id = u.branch_id
     where u.branch_id = v_branch and not u.is_locked and u.student_code is null
       and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TEACHER')
     order by u.display_name, u.id;
end;
$$;

create or replace function app.list_test_rooms(p_branch_id uuid default null)
returns table (id uuid, name text, capacity integer, branch_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.current_branch_id());
begin
  if not (app.has_permission('STUDENT_TEST', 'TAO') or app.has_permission('STUDENT_TEST', 'SUA')) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền chọn phòng test.');
  end if;
  return query
    select r.id, r.name, r.capacity, b.code
      from app.room r join app.branch b on b.id = r.branch_id
     where r.branch_id = v_branch and r.is_active
     order by r.sort_order, r.name, r.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi: chỉ người đã đăng nhập; mỗi hàm tự kiểm quyền bên trong. Hàm trợ giúp nội bộ không cấp cho giao diện.
-- ---------------------------------------------------------------------------
revoke execute on function app.student_test_group_label(text, text) from public, anon, authenticated;
revoke execute on function
  app.get_student_test(uuid), app.list_student_tests(jsonb, text, integer, integer), app.student_test_board(jsonb, integer),
  app.student_test_group_counts(jsonb, text[]), app.export_student_tests(jsonb),
  app.list_test_graders(uuid), app.list_test_rooms(uuid)
  from public, anon;
grant execute on function
  app.get_student_test(uuid), app.list_student_tests(jsonb, text, integer, integer), app.student_test_board(jsonb, integer),
  app.student_test_group_counts(jsonb, text[]), app.export_student_tests(jsonb),
  app.list_test_graders(uuid), app.list_test_rooms(uuid)
  to authenticated;
