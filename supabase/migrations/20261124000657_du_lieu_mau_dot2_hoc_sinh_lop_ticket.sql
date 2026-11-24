-- Dữ liệu mẫu staging, ĐỢT 2, mảnh học sinh, lớp, ghi danh, ticket (Code C, 24/11/2026; thẻ C-23-41, C-23-42). CAO: đụng quyền (nhánh bỏ qua kiểm quyền) và dữ liệu đào tạo.
-- Thiết kế: docs/nghiep-vu/du-lieu-mau-dot2-thiet-ke.md (#654, mục 8 là quyết định); khung: 648; lead/cơ hội: 655; báo giá/đơn/phiếu thu: 656.
-- Làm gì:
--   (a) thêm cờ is_demo cho phụ huynh, ghi danh, sổ giờ; mở rộng demo_data_item và app.demo_tag cho PARENT, ENROLLMENT, HOUR_LEDGER;
--   (b) app.demo_assert_caller_set: một chỗ kiểm «chỉ gọi từ hàm tạo bộ» cho các hàm con của mảnh này;
--   (c) app.demo_make_parents (4 phụ huynh), app.demo_make_students (6 học sinh, hai cặp anh chị em),
--       app.demo_make_classes (2 lớp Toán, Tiếng Anh: một lớp DUYỆT bằng hàm chuyển trạng thái thật, một lớp dừng ở Đã trình),
--       app.demo_make_enrollments (3 em vào lớp đã duyệt, giờ mẫu ở sổ giờ is_demo), app.demo_make_tickets (3 ticket + 1 phiếu «Cập nhật hồ sơ» chờ duyệt);
--   (d) app.demo_make_education: hàm gom, đặt và xoá cờ giao dịch; app.create_demo_data_set thêm ĐÚNG MỘT dòng perform.
-- Luật an toàn:
--   1. Kế toán, Giáo viên, Trợ giảng cũng tạo được bộ (quyết định 5): không đòi quyền tạo lớp/ticket của người gọi. Dùng lại đúng nhánh bỏ qua kiểm quyền
--      của migration 656 (cờ giao dịch hmt.demo_sales + app.demo_data_is_allowed()); không thêm nhánh mới vào app.assert_can.
--   2. Cờ chỉ do app.demo_make_education đặt (set_config local) và xoá ngay sau khi gọi xong, kể cả khi lỗi.
--   3. Hàm con là security definer, không cấp cho giao diện; mỗi hàm kiểm bộ là của chính người gọi, còn DANG_DUNG, chưa đổ loại bản ghi đó.
--   4. Lớp, duyệt lớp, sinh buổi, ghi danh, xếp lớp đi qua hàm nghiệp vụ THẬT (create_class, transition_class, assign_enrollment_class):
--      mã và luật giống bản thật. Không đơn, không phiếu thu, không trừ giờ thật; giờ mẫu ghi ở sổ giờ có cờ is_demo.
--   5. Ticket chèn trực tiếp (sao đúng các bước app.create_ticket: mã, hạn xử lý chụp lúc tạo, nhật ký) vì create_ticket chặn Giáo viên, Trợ giảng
--      tạo Đề nghị; phiếu nghiệp vụ tạo và trình bằng create_ticket_task, submit_ticket_task thật.
-- SĐT dải 0999 000 001-999 từ bộ đếm DEMO_PHONE; không email; không gửi tin.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- (a) Cờ is_demo và loại bản ghi mới của bộ.
-- ---------------------------------------------------------------------------
alter table app.parent add column is_demo boolean not null default false;
alter table app.enrollment add column is_demo boolean not null default false;
alter table app.hour_ledger add column is_demo boolean not null default false;
-- Chỉ mục từng phần: chỉ chứa dòng mẫu, để bộ lọc «Ẩn dữ liệu mẫu» rẻ (cùng cách với bảng đã có cờ ở migration 648).
create index parent_demo_idx on app.parent (id) where is_demo;
create index enrollment_demo_idx on app.enrollment (id) where is_demo;
create index hour_ledger_demo_idx on app.hour_ledger (id) where is_demo;

alter table app.demo_data_item drop constraint demo_data_item_entity_type_check;
alter table app.demo_data_item add constraint demo_data_item_entity_type_check
  check (entity_type in ('LEAD', 'OPPORTUNITY', 'QUOTATION', 'ORDER', 'RECEIPT', 'PARENT', 'STUDENT', 'CLASS', 'SESSION', 'ENROLLMENT', 'HOUR_LEDGER', 'TICKET'));

-- ---------------------------------------------------------------------------
-- Đánh dấu bản ghi thuộc bộ mẫu: giữ nguyên các loại cũ, thêm PARENT, ENROLLMENT, HOUR_LEDGER.
-- Sổ giờ chỉ thêm, không sửa (trigger append-only): cờ is_demo đặt lúc chèn, ở đây chỉ ghi dòng demo_data_item.
-- ---------------------------------------------------------------------------
create or replace function app.demo_tag(p_set_id uuid, p_entity_type text, p_entity_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Luật: chỉ đánh dấu vào bộ đang dùng.
  if not exists (select 1 from app.demo_data_set where id = p_set_id and status_code = 'DANG_DUNG') then
    perform app.raise_error('HMT_DEMO_KHONG_THAY_BO', 'Không thấy bộ dữ liệu mẫu đang dùng.');
  end if;
  -- Luật: cờ is_demo trên đúng bảng của loại (bảng cố định, không SQL động).
  case p_entity_type
    when 'LEAD' then update app.lead set is_demo = true where id = p_entity_id;
    when 'OPPORTUNITY' then update app.opportunity set is_demo = true where id = p_entity_id;
    when 'QUOTATION' then update app.quotation set is_demo = true where id = p_entity_id;
    when 'ORDER' then update app.sales_order set is_demo = true where id = p_entity_id;
    when 'RECEIPT' then update app.receipt set is_demo = true where id = p_entity_id;
    when 'PARENT' then update app.parent set is_demo = true where id = p_entity_id;
    when 'STUDENT' then update app.student set is_demo = true where id = p_entity_id;
    when 'CLASS' then update app.class set is_demo = true where id = p_entity_id;
    when 'SESSION' then update app.class_session set is_demo = true where id = p_entity_id;
    when 'ENROLLMENT' then update app.enrollment set is_demo = true where id = p_entity_id;
    when 'HOUR_LEDGER' then null;  -- sổ giờ chỉ thêm: cờ đã đặt lúc chèn
    when 'TICKET' then update app.ticket set is_demo = true where id = p_entity_id;
    else perform app.raise_error('HMT_DEMO_LOAI_SAI', 'Loại bản ghi mẫu không hợp lệ.');
  end case;
  insert into app.demo_data_item (set_id, entity_type, entity_id, created_by, updated_by)
  values (p_set_id, p_entity_type, p_entity_id, auth.uid(), auth.uid())
  on conflict (set_id, entity_type, entity_id) do nothing;
end;
$$;
revoke all on function app.demo_tag(uuid, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (b) Kiểm chung cho hàm con của mảnh này: khoá môi trường, bộ của chính người gọi, còn dùng, chưa đổ loại bản ghi p_entity_type.
-- ---------------------------------------------------------------------------
create or replace function app.demo_assert_caller_set(p_set_id uuid, p_branch_id uuid, p_entity_type text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Luật khoá: chạy thật hoặc công tắc tắt thì từ chối.
  perform app.assert_demo_data_allowed();
  -- Luật: chỉ gọi từ hàm tạo bộ: bộ phải của chính người gọi, còn dùng, chưa đổ loại này (p_entity_type null = chỉ kiểm chủ bộ:
  -- học sinh có thể đã có từ việc duyệt đơn của mảnh báo giá, nên loại STUDENT không dùng kiểm «chưa đổ»).
  if auth.uid() is null
     or not exists (select 1 from app.demo_data_set where id = p_set_id and created_by = auth.uid()
                       and status_code = 'DANG_DUNG' and branch_id = p_branch_id)
     or (p_entity_type is not null and exists (select 1 from app.demo_data_item where set_id = p_set_id and entity_type = p_entity_type)) then
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Không tạo được dữ liệu mẫu này cho bộ này.');
  end if;
end;
$$;
revoke all on function app.demo_assert_caller_set(uuid, uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Số điện thoại mẫu kế tiếp, dải 0999 000 001-999 (bộ đếm DEMO_PHONE, không nhảy, không trùng giữa các bộ).
-- ---------------------------------------------------------------------------
create or replace function app.demo_next_phone()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seq bigint := app.next_counter_value('DEMO_PHONE', 1);
begin
  if v_seq > 999 then  -- allow-number: hết dải số điện thoại mẫu 0999 000 001-999 (dải cố định của thiết kế)
    perform app.raise_error('HMT_DEMO_HET_SO_DIEN_THOAI', 'Đã dùng hết dải số điện thoại mẫu. Báo quản trị.');
  end if;
  return '0999000' || lpad(v_seq::text, 3, '0');  -- allow-number: độ rộng 3 chữ số của dải số mẫu
end;
$$;
revoke all on function app.demo_next_phone() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tạo 4 phụ huynh mẫu. Ai gọi: chỉ app.demo_make_education. Kết quả: mảng id phụ huynh, theo thứ tự tạo.
-- Phụ huynh 1 và 2 mỗi người có hai con (hai cặp anh chị em); phụ huynh 3, 4 mỗi người một con.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_parents(p_set_id uuid, p_branch_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_names constant text[] := array['Trần Văn Hùng', 'Lê Thị Mai', 'Phạm Quốc Bảo', 'Vũ Thị Hoa'];
  v_ids uuid[] := '{}';
  v_id uuid;
  v_n integer;
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, 'PARENT');
  for v_n in 1 .. array_length(v_names, 1) loop
    insert into app.parent (code, full_name, phone, branch_id, created_by, updated_by, is_demo)
    values (app.issue_person_code('PH'), '[MẪU] ' || v_names[v_n], app.demo_next_phone(), p_branch_id, v_user, v_user, true)
    returning id into v_id;
    perform app.demo_tag(p_set_id, 'PARENT', v_id);
    v_ids := v_ids || v_id;
  end loop;
  return v_ids;
end;
$$;
revoke all on function app.demo_make_parents(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Khối dùng cho học sinh và lớp mẫu: khối cao nhất còn dưới «Khối bắt đầu tách Đại/Hình» trong danh mục đang dùng
-- (để lớp chung Toán hợp lệ cả khi bật kiểm môn theo khối R-LOP-14); không có thì khối đầu tiên đang dùng.
-- ---------------------------------------------------------------------------
create or replace function app.demo_grade_code(p_branch_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_split integer := app.get_setting_int('algebra_geometry_split_grade', p_branch_id);
  v_code text;
begin
  select g.code into v_code from app.catalog_item g
   where g.catalog_code = 'GRADE' and g.is_active and g.code ~ '^K[0-9]+$'
     and substring(g.code from 2)::integer < v_split  -- allow-number: vị trí ký tự thứ hai trong mã khối (K08 -> 08)
   order by substring(g.code from 2)::integer desc limit 1;  -- allow-number: vị trí ký tự thứ hai trong mã khối
  if v_code is null then
    select g.code into v_code from app.catalog_item g where g.catalog_code = 'GRADE' and g.is_active order by g.sort_order, g.code limit 1;
  end if;
  if v_code is null then
    perform app.raise_error('HMT_DEMO_THIEU_DANH_MUC', 'Danh mục khối chưa có mục nào đang dùng.');
  end if;
  return v_code;
end;
$$;
revoke all on function app.demo_grade_code(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tạo 6 học sinh mẫu cho 4 phụ huynh. Kết quả: mảng id học sinh, theo thứ tự tạo (em 1, 2 cùng phụ huynh 1; em 3, 4 cùng phụ huynh 2;
-- em 5 của phụ huynh 3; em 6 của phụ huynh 4). Năm sinh quanh tuổi của khối mẫu; anh chị em khác năm sinh.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_students(p_set_id uuid, p_branch_id uuid, p_parent_ids uuid[])
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_names constant text[] := array['Trần Minh An', 'Trần Gia Bảo', 'Lê Hoài Chi', 'Lê Đức Duy', 'Phạm Khánh Linh', 'Vũ Hải Nam'];
  -- Phụ huynh của từng em (chỉ số trong mảng phụ huynh): hai cặp anh chị em là (1, 2) và (3, 4).
  v_owner constant integer[] := array[1, 1, 2, 2, 3, 4];  -- allow-number: chỉ số phụ huynh trong kế hoạch dữ liệu mẫu
  -- Chênh lệch tuổi so với tuổi chuẩn của khối (năm): anh chị em hơn kém nhau một tuổi.
  v_offset constant integer[] := array[0, 1, 0, 1, 0, 0];
  v_grade text := app.demo_grade_code(p_branch_id);
  v_year integer := extract(year from (now() at time zone 'Asia/Ho_Chi_Minh'))::integer;
  v_base integer;
  v_ids uuid[] := '{}';
  v_id uuid;
  v_n integer;
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, null);
  if coalesce(array_length(p_parent_ids, 1), 0) < 4 then  -- allow-number: kế hoạch dữ liệu mẫu (4 phụ huynh)
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Thiếu phụ huynh mẫu để tạo học sinh mẫu.');
  end if;
  -- Năm sinh chuẩn = năm nay - (số của khối + 5): học sinh khối 8 sinh khoảng 13 năm trước (tuổi vào lớp 1 là 6).
  v_base := v_year - (substring(v_grade from 2)::integer + 5);  -- allow-number: vị trí ký tự thứ hai của mã khối; 5 = tuổi vào lớp 1 trừ một
  for v_n in 1 .. array_length(v_names, 1) loop
    insert into app.student (code, parent_id, full_name, birth_year, school, branch_id, created_by, updated_by, is_demo)
    values (app.issue_person_code('HS'), p_parent_ids[v_owner[v_n]], '[MẪU] ' || v_names[v_n], v_base - v_offset[v_n], '[MẪU] Trường thử nghiệm',
            p_branch_id, v_user, v_user, true)
    returning id into v_id;
    perform app.demo_tag(p_set_id, 'STUDENT', v_id);
    v_ids := v_ids || v_id;
  end loop;
  return v_ids;
end;
$$;
revoke all on function app.demo_make_students(uuid, uuid, uuid[]) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tạo 2 lớp mẫu: Toán và Tiếng Anh, cùng khối, qua app.create_class (mã, thời khoá biểu, luật giống bản thật).
-- Lớp Toán đi hết đường duyệt (Đã trình, Đã xác nhận, Đã duyệt) bằng app.transition_class THẬT nên buổi học sinh đúng R-LOP-03;
-- lớp Tiếng Anh dừng ở Đã trình (chờ duyệt) để người duyệt có việc thử. Kết quả: mảng id lớp (Toán trước, Anh sau).
-- Năm học, phân loại, trình độ lấy mục đầu tiên đang dùng trong danh mục; không gán giáo viên thật.
-- Lớp online/OMO không tạo (quyết định 2: chỉ thêm khi danh mục có và anh cần; chưa có yêu cầu).
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_classes(p_set_id uuid, p_branch_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_subjects constant text[] := array['TOAN', 'ANH'];
  v_grade text := app.demo_grade_code(p_branch_id);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_start date;
  v_year text;
  v_type text;
  v_level text;
  v_ids uuid[] := '{}';
  v_id uuid;
  v_n integer;
  v_session uuid;
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, 'CLASS');
  select a.code into v_year from app.academic_year a where a.is_active order by a.code desc limit 1;
  select c.code into v_type from app.catalog_item c where c.catalog_code = 'CLASS_TYPE' and c.is_active and c.code <> 'LR' order by c.sort_order, c.code limit 1;
  select c.code into v_level from app.catalog_item c where c.catalog_code = 'LEVEL' and c.is_active order by c.sort_order, c.code limit 1;
  if v_year is null or v_type is null or v_level is null then
    perform app.raise_error('HMT_DEMO_THIEU_DANH_MUC', 'Chưa có năm học, phân loại lớp hoặc trình độ đang dùng để tạo lớp mẫu.');
  end if;
  -- Khai giảng sau hôm nay đúng tuần sau (cùng thứ với hôm nay): buổi đầu rơi đúng ngày này.
  v_start := v_today + 7;  -- allow-number: một tuần sau hôm nay (thiết kế: khai giảng sau hôm nay ít nhất một tuần)

  for v_n in 1 .. array_length(v_subjects, 1) loop
    v_id := (app.create_class(jsonb_build_object(
      'branch_id', p_branch_id, 'year_code', v_year, 'subject_code', v_subjects[v_n], 'grade_code', v_grade,
      'class_type_code', v_type, 'level_code', v_level, 'max_students', 20, 'start_date', v_start,  -- allow-number: sĩ số tối đa lớp mẫu
      'total_sessions', 8,  -- allow-number: số buổi lớp mẫu
      'slots', jsonb_build_array(jsonb_build_object(
        'weekday', extract(isodow from v_start)::integer, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1, 'first_date', v_start))
    )) ->> 'id')::uuid;
    perform app.demo_tag(p_set_id, 'CLASS', v_id);
    -- Cả hai lớp đi đến Đã trình; riêng lớp đầu (Toán) đi tiếp đến Đã duyệt.
    perform app.transition_class(v_id, 'DA_TRINH');
    if v_n = 1 then
      perform app.transition_class(v_id, 'DA_XAC_NHAN');
      perform app.transition_class(v_id, 'DA_DUYET');
      -- Buổi do duyệt lớp sinh ra cũng thuộc bộ (ẩn khi xoá bộ).
      for v_session in select s.id from app.class_session s where s.class_id = v_id loop
        perform app.demo_tag(p_set_id, 'SESSION', v_session);
      end loop;
    end if;
    v_ids := v_ids || v_id;
  end loop;
  return v_ids;
end;
$$;
revoke all on function app.demo_make_classes(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Ghi danh 3 em đầu vào lớp đã duyệt (lớp Toán). Ghi danh và dòng sổ giờ mang cờ is_demo; xếp lớp qua app.assign_enrollment_class THẬT.
-- KHÔNG đơn, KHÔNG phiếu thu, KHÔNG trừ giờ thật: giờ mua ghi ở sổ giờ mẫu (CAP_MUA) để màn Học tập có số giờ để hiện.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_enrollments(p_set_id uuid, p_branch_id uuid, p_student_ids uuid[], p_class_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_hours constant numeric := 20;  -- allow-number: số giờ mẫu mỗi ghi danh (dữ liệu mẫu, không phải cấu hình nghiệp vụ)
  v_students integer := 3;  -- allow-number: kế hoạch dữ liệu mẫu (3 em vào lớp đã duyệt)
  v_class app.class;
  v_student app.student;
  v_enrol uuid;
  v_ledger uuid;
  v_n integer;
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, 'ENROLLMENT');
  select * into v_class from app.class where id = p_class_id and is_demo and status_code = 'DA_DUYET';
  if v_class.id is null or coalesce(array_length(p_student_ids, 1), 0) < v_students then
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Thiếu lớp đã duyệt hoặc học sinh mẫu để ghi danh.');
  end if;
  for v_n in 1 .. v_students loop
    select * into v_student from app.student where id = p_student_ids[v_n];
    insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, purchased_hours, created_by, updated_by, is_demo)
    values (app.issue_enrollment_code(), v_student.id, v_student.parent_id, p_branch_id, v_class.subject_code, v_class.delivery_mode_code, v_hours, v_user, v_user, true)
    returning id into v_enrol;
    perform app.demo_tag(p_set_id, 'ENROLLMENT', v_enrol);
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref, note, created_by, updated_by, is_demo)
    values (v_enrol, p_branch_id, 'CAP_MUA', v_hours, 'DU_LIEU_MAU', '[MẪU] Giờ mẫu, không phải giờ mua thật', v_user, v_user, true)
    returning id into v_ledger;
    perform app.demo_tag(p_set_id, 'HOUR_LEDGER', v_ledger);
    -- Xếp lớp bằng hàm thật: ngày vào lớp = ngày khai giảng (buổi đầu).
    perform app.assign_enrollment_class(v_enrol, p_class_id, v_class.start_date);
  end loop;
end;
$$;
revoke all on function app.demo_make_enrollments(uuid, uuid, uuid[], uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tạo một ticket mẫu (chèn trực tiếp, sao các bước của app.create_ticket: mã, hạn phản hồi và xử lý chụp lúc tạo, dòng nhật ký TAO).
-- Dùng nội bộ cho app.demo_make_tickets. Kết quả: id ticket.
-- ---------------------------------------------------------------------------
create or replace function app.demo_insert_ticket(
  p_branch_id uuid, p_type text, p_category_code text, p_title text, p_description text, p_channel text,
  p_parent_id uuid, p_student_id uuid, p_class_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_priority text;
  v_branch_code text;
  v_resp integer;
  v_res integer;
  v_now timestamptz := now();
  v_id uuid;
begin
  select default_priority into v_priority from app.ticket_category where code = p_category_code;
  select code into v_branch_code from app.branch where id = p_branch_id;
  select r.response_hours into v_resp from app.ticket_sla_rule r where r.ticket_type = p_type and r.priority_code = v_priority;
  v_res := app.ticket_resolve_hours(p_type, v_priority, p_category_code);
  insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, parent_id,
                          student_id, class_id, response_due_at, resolve_due_at, created_by, updated_by)
  values (app.issue_document_number(p_type, v_branch_code), p_type, p_branch_id, p_title, p_description, p_channel, p_category_code, v_priority,
          p_parent_id, p_student_id, p_class_id, v_now + make_interval(hours => v_resp), v_now + make_interval(hours => v_res), auth.uid(), auth.uid())
  returning id into v_id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, to_status) values (v_id, p_branch_id, 'TAO', 'MOI');
  return v_id;
end;
$$;
revoke all on function app.demo_insert_ticket(uuid, text, text, text, text, text, uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tạo 3 ticket mẫu và 1 phiếu «Cập nhật hồ sơ» chờ duyệt.
--   Ticket 1: Đề nghị (nhóm con đang dùng, không bắt học sinh/lớp), phụ huynh 1.
--   Ticket 2: Khiếu nại (nhóm con đang dùng, không bắt học sinh/lớp), phụ huynh 2.
--   Ticket 3: Đề nghị Cập nhật thông tin hồ sơ, gắn học sinh 1 và lớp Toán, kèm phiếu CAP_NHAT_HO_SO đã TRÌNH (chờ duyệt, không tự duyệt)
--             để thử màn «Việc chờ tôi duyệt». Phiếu thuộc ticket nên bị ẩn cùng ticket khi xoá bộ.
-- Nhóm con, kênh tiếp nhận lấy mục đầu tiên đang dùng trong cấu hình (không viết cứng mã). Không tự duyệt, không gửi tin.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_tickets(p_set_id uuid, p_branch_id uuid, p_parent_ids uuid[], p_student_ids uuid[], p_class_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_channel text;
  v_dn text;
  v_kn text;
  v_profile text;
  v_id uuid;
  v_task jsonb;
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, 'TICKET');
  if coalesce(array_length(p_parent_ids, 1), 0) < 2 or coalesce(array_length(p_student_ids, 1), 0) < 1  -- allow-number: kế hoạch dữ liệu mẫu (cần ít nhất 2 phụ huynh, 1 học sinh, 1 lớp)
     or coalesce(array_length(p_class_ids, 1), 0) < 1 then
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Thiếu phụ huynh, học sinh hoặc lớp mẫu để tạo ticket mẫu.');
  end if;
  perform app.require_feature('AFTERSALE', p_branch_id);
  select c.code into v_channel from app.catalog_item c where c.catalog_code = 'TICKET_CHANNEL' and c.is_active order by c.sort_order, c.code limit 1;
  select k.code into v_dn from app.ticket_category k
   where k.kind = 'SUBGROUP' and k.is_active and k.ticket_type = 'DN' and k.business_type is null
     and not k.requires_student and not k.requires_class order by k.sort_order, k.code limit 1;
  select k.code into v_kn from app.ticket_category k
   where k.kind = 'SUBGROUP' and k.is_active and k.ticket_type = 'KN'
     and not k.requires_student and not k.requires_class order by k.sort_order, k.code limit 1;
  select k.code into v_profile from app.ticket_category k
   where k.kind = 'SUBGROUP' and k.is_active and k.ticket_type = 'DN' and k.business_type = 'CAP_NHAT_HO_SO' order by k.sort_order, k.code limit 1;
  if v_channel is null or v_dn is null or v_kn is null or v_profile is null then
    perform app.raise_error('HMT_DEMO_THIEU_DANH_MUC', 'Chưa có kênh tiếp nhận hoặc nhóm con ticket đang dùng để tạo ticket mẫu.');
  end if;

  v_id := app.demo_insert_ticket(p_branch_id, 'DN', v_dn, '[MẪU] Đề nghị tư vấn lộ trình học', '[MẪU] Phụ huynh nhờ tư vấn lộ trình học cho con.',
                                 v_channel, p_parent_ids[1], null, null);
  perform app.demo_tag(p_set_id, 'TICKET', v_id);
  v_id := app.demo_insert_ticket(p_branch_id, 'KN', v_kn, '[MẪU] Khiếu nại về lịch học', '[MẪU] Phụ huynh phản ánh lịch học chưa phù hợp.',
                                 v_channel, p_parent_ids[2], null, null);  -- allow-number: chỉ số phụ huynh trong kế hoạch dữ liệu mẫu
  perform app.demo_tag(p_set_id, 'TICKET', v_id);
  v_id := app.demo_insert_ticket(p_branch_id, 'DN', v_profile, '[MẪU] Đề nghị cập nhật trường học của con', '[MẪU] Phụ huynh nhờ sửa tên trường của con trong hồ sơ.',
                                 v_channel, p_parent_ids[1], p_student_ids[1], p_class_ids[1]);
  perform app.demo_tag(p_set_id, 'TICKET', v_id);
  -- Phiếu Cập nhật hồ sơ đi qua hàm thật (kiểm trường được sửa, cấp duyệt theo phiên bản hiệu lực) rồi TRÌNH, dừng ở Chờ duyệt.
  v_task := app.create_ticket_task(v_id, 'CAP_NHAT_HO_SO', '[MẪU] Cập nhật tên trường theo đề nghị của phụ huynh',
              jsonb_build_object('entity', 'STUDENT', 'changes', jsonb_build_object('school', '[MẪU] Trường thử nghiệm mới')));
  perform app.submit_ticket_task((v_task ->> 'id')::uuid);
end;
$$;
revoke all on function app.demo_make_tickets(uuid, uuid, uuid[], uuid[], uuid[]) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (d) Hàm gom của mảnh này: đặt cờ giao dịch (dùng lại nhánh bỏ qua kiểm quyền của migration 656), gọi các hàm con theo thứ tự, xoá cờ.
-- Ai gọi: chỉ app.create_demo_data_set. Mọi đường ra (kể cả lỗi) đều xoá cờ.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_education(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parents uuid[];
  v_students uuid[];
  v_classes uuid[];
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, 'PARENT');
  perform set_config('hmt.demo_sales', 'on', true);
  v_parents := app.demo_make_parents(p_set_id, p_branch_id);
  v_students := app.demo_make_students(p_set_id, p_branch_id, v_parents);
  v_classes := app.demo_make_classes(p_set_id, p_branch_id);
  perform app.demo_make_enrollments(p_set_id, p_branch_id, v_students, v_classes[1]);
  perform app.demo_make_tickets(p_set_id, p_branch_id, v_parents, v_students, v_classes);
  perform set_config('hmt.demo_sales', '', true);
exception when others then
  perform set_config('hmt.demo_sales', '', true);
  raise;
end;
$$;
revoke all on function app.demo_make_education(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hàm tạo bộ: giữ nguyên bản 656, thêm đúng một dòng perform app.demo_make_education.
-- ---------------------------------------------------------------------------
create or replace function app.create_demo_data_set()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_branch uuid := app.current_branch_id();
  v_id uuid;
begin
  -- Luật (1): khoá môi trường và công tắc.
  perform app.assert_demo_data_allowed();
  if v_user is null or not app.current_user_active() then
    perform app.raise_error('HMT_DEMO_CHUA_DANG_NHAP', 'Cần đăng nhập để tạo dữ liệu mẫu.');
  end if;
  if v_branch is null then
    perform app.raise_error('HMT_DEMO_THIEU_CO_SO', 'Chọn cơ sở trước khi tạo dữ liệu mẫu.');
  end if;
  -- Luật (5): hạn mức theo người và theo cơ sở (chỉ tính bộ chưa xoá).
  if (select count(*) from app.demo_data_set where created_by = v_user and status_code = 'DANG_DUNG')
       >= app.get_setting_int('demo_data_max_per_user') then
    perform app.raise_error('HMT_DEMO_QUA_HAN_MUC_NGUOI', 'Bạn đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.');
  end if;
  if (select count(*) from app.demo_data_set where branch_id = v_branch and status_code = 'DANG_DUNG')
       >= app.get_setting_int('demo_data_max_per_branch') then
    perform app.raise_error('HMT_DEMO_QUA_HAN_MUC_CO_SO', 'Cơ sở này đã có đủ số bộ dữ liệu mẫu cho phép. Xoá bớt một bộ trước.');
  end if;
  insert into app.demo_data_set (branch_id, created_by, updated_by)
  values (v_branch, v_user, v_user)
  returning id into v_id;
  -- Đợt 2: đổ chuỗi dữ liệu cố định vào bộ v_id tại đây (mỗi mảnh một hàm con).
  perform app.demo_make_leads(v_id, v_branch);
  perform app.demo_make_sales(v_id, v_branch);
  perform app.demo_make_education(v_id, v_branch);
  return v_id;
end;
$$;

select set_config('hmt.migration', '', false);
