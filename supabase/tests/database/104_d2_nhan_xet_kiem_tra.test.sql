-- D2 (migration 103): nhận xét 9 tiêu chí, buổi Kiểm tra, dấu Đã xuất, mức gợi ý lời nhắn phụ huynh, điều kiện Done.
-- Luật: R-V2-18 (Q-176), R-V2-19, R-V2-20, R-V2-38, R-V2-39, R-GV-02, 03, 04, 08, R-GIO-06, R-V2-35. Dữ liệu giả; ngày tính từ hôm nay.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('cskh1'), ('sales1'), ('gv1'), ('gv2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1c.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d1c.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('cskh1', 'CS1'), ('sales1', 'CS1'), ('gv1', 'CS1'), ('gv2', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'),
  ('sales1', 'SALES'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
-- Q-198: đặt rõ nhánh Bật (không dựa vào mặc định): Done cần nhận xét, điểm.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'session_done_requires_review'$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
-- Thứ Hai 4 tuần trước (buổi quá khứ để Done được) và thứ Hai 2 tuần sau (buổi tương lai).
create function pg_temp.past() returns date language sql stable as $$ select (date_trunc('week', current_date) - interval '28 days')::date $$;
create function pg_temp.fut() returns date language sql stable as $$ select (date_trunc('week', current_date) + interval '14 days')::date $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
create function pg_temp.mkclass(p_key text, p_type text, p_first date, p_total integer, p_teacher text default 'gv1') returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', p_type, 'level_code', case when p_type = 'LR' then null else 'A' end, 'max_students', 0, 'start_date', p_first,
    'total_sessions', p_total,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', p_first, 'teacher_id', pg_temp.uid(p_teacher)))));
  insert into cl values (p_key, (v ->> 'id')::uuid);
  perform app.transition_class((v ->> 'id')::uuid, 'DA_TRINH');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_XAC_NHAN');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_DUYET');
end $$;
-- Buổi thứ n (theo ngày) của lớp.
create function pg_temp.s(p_key text, p_n integer) returns uuid language sql stable security definer as $$
  select id from app.class_session where class_id = pg_temp.c(p_key) and session_no = p_n and status_code not in ('HUY_KHONG_PHI', 'DA_THAY') $$;
create temp table en (key text primary key, id uuid);
grant all on en to public;
create function pg_temp.e(p_key text) returns uuid language sql stable as $$ select id from en where key = p_key $$;
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSD1C0' || p_n $$;
-- Ghi danh giả; p_old = true thì lùi ngày tạo 60 ngày (tắt tạm trigger điền cột chuẩn) để vào được danh sách buổi quá khứ (R-GIO-02).
create function pg_temp.mke(p_key text, p_n integer, p_old boolean, p_hours numeric) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('GDC' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs('CS1'), 'TOAN')
  returning id into v_id;
  if p_old then
    alter table app.enrollment disable trigger enrollment_fill_standard;
    update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
    alter table app.enrollment enable trigger enrollment_fill_standard;
  end if;
  insert into en values (p_key, v_id);
  if p_hours <> 0 then
    perform app.add_opening_hours(v_id, p_hours, 'DOT-D1C');
  end if;
end $$;
grant execute on all functions in schema pg_temp to public;

-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;

-- ---------- Hồ sơ giả ----------
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả D2', '0900101002', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả D2 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('p', 'CB', pg_temp.past(), 3);
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('p'), pg_temp.past());
select app.close_session(pg_temp.s('p', 1));
select app.close_session(pg_temp.s('p', 2));
select app.close_session(pg_temp.s('p', 3));
-- Buổi 2 và 3 là buổi Kiểm tra (R-V2-18, Q-176).
select pg_temp.sudo($$update app.class_session set type_code = 'KIEM_TRA' where id in (pg_temp.s('p', 2), pg_temp.s('p', 3))$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'DI_MUON'), jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'VANG_CO_PHEP')));
select app.set_attendance_teacher(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT'), jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'VANG_CO_PHEP')));
select app.set_attendance_teacher(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT'), jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'VANG_CO_PHEP')));

-- Q-231 (migration 107): buổi thường (buổi 1) có một dòng nội dung buổi để Done được; buổi Kiểm tra không cần.
select pg_temp.sudo($$insert into app.session_content_line (session_id, branch_id, sort_order, line_text) select id, branch_id, 1, 'Nội dung buổi giả' from app.class_session where id = pg_temp.s('p', 1)$$);

-- ================= Dữ liệu nạp sẵn (R-V2-19, R-V2-39) =================
select is((select count(*)::int from app.review_criteria_for_subject('TOAN')), 9, 'Toán có đúng 9 tiêu chí: 3 Thái độ chung + 3 Tiếp thu + 3 Vận dụng (R-V2-19)');
select is((select count(*)::int from app.review_criteria_for_subject('DAI')), 9, 'Đại số dùng bộ Toán (Q-186)');
select is((select count(*)::int from app.review_criteria_for_subject('LY')), 9, 'Môn phụ (Vật lý) có đúng 9 tiêu chí chung (Q-189)');
select is((select count(*)::int from app.review_criteria_for_subject('SAT')), 9, 'Môn phụ (SAT) có đúng 9 tiêu chí chung (Q-189)');
select is((select count(*)::int from app.review_criteria_for_subject('LY') where code like 'TOAN\_%'), 0, 'Môn phụ không nhận tiêu chí riêng của Toán');
select is((select count(*)::int from app.review_criteria_for_subject('TOAN') where code like 'TT\_%' or code like 'VD\_%'), 0, 'Toán không nhận tiêu chí của bộ môn phụ');
select is((select count(*)::int from app.review_criterion where is_active and subject_set = 'MOI_MON' and group_code = 'THAI_DO'), 3, 'Nhóm Thái độ có 3 tiêu chí chung mọi môn (R-V2-19)');
select is((select string_agg(name, ' | ' order by sort_order) from app.review_criterion where subject_set = 'MON_PHU'),
          'Ghi nhớ kiến thức | Hiểu bản chất | Nhận biết dạng bài | Làm bài vận dụng | Tư duy lập luận | Trình bày chính xác', 'Tên 6 tiêu chí môn phụ đúng thứ tự (Q-189)');
-- Từ migration 503 mô tả có phiên bản (bộ Thái độ nằm ở cả hai bản): đếm cặp (tiêu chí, mức) khác nhau.
select is((select count(distinct (criterion_id, level))::int from app.review_level_desc), 75, 'Mỗi tiêu chí (15) có mô tả đủ 5 mức (Q-190)');
select is((select d.description from app.review_level_desc d join app.review_criterion rc on rc.id = d.criterion_id where rc.code = 'TOAN_GHI_NHO' and d.level = 3 and d.version_id = (select id from app.review_rubric_version where subject_set = 'TOAN' and version_no = 1)), 'Nhớ kiến thức cơ bản', 'Tiêu chí Toán "Ghi nhớ công thức" dùng mô tả của "Ghi nhớ kiến thức" (Q-190)');
select is((select count(*)::int from app.review_hint), 42, 'Biểu hiện gợi ý: 7 môn phụ × 6 tiêu chí (Q-189)');
select is((select h.hint from app.review_hint h join app.review_criterion rc on rc.id = h.criterion_id where rc.code = 'VD_LAM_BAI' and h.subject_code = 'HOA'), 'Giải bài tập, cân bằng, tính toán', 'Gợi ý theo môn hiện dưới tiêu chí (Q-189)');
select is((select count(*)::int from app.parent_phrase), 24, 'Có 24 mẫu câu: 2 loại buổi × 4 mức × 3 câu (R-V2-39, Q-190)');
select is((select count(distinct (kind, level))::int from app.parent_phrase), 8, 'Mẫu câu phủ đủ 2 loại × 4 mức (R-V2-39)');
select is((select phrase from app.parent_phrase where kind = 'KIEM_TRA' and level = 1 and seq = 2), 'Con còn hổng kiến thức ở phần này, cần ôn thêm ở nhà.', 'Mẫu câu chính thức Kiểm tra · Cần cố gắng (Q-190)');
select is(app.session_type_deducts_hours('KIEM_TRA'), true, 'Buổi Kiểm tra trừ giờ như buổi Chính (R-V2-20, Q-176)');
select is(app.session_type_deducts_hours('HOC_BU'), false, 'Học bù vẫn không trừ giờ (R-BUOI-01)');

-- ================= Nhận xét 9 tiêu chí: mở, công tắc, chấm (R-V2-19, R-GV-02, R-GV-04, R-GV-08) =================
select is(app.session_pending_reason(pg_temp.s('p', 1)), 'Giáo viên chưa mở phần nhận xét của buổi.', 'Chặn Done: giáo viên chưa mở nhận xét (R-GIO-06, R-V2-19)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.open_session_review(pg_temp.s('p', 1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không mở nhận xét (R-GV-08)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.open_session_review(pg_temp.s('p', 1)), 9, 'Đúng: mở nhận xét chụp 9 tiêu chí của môn (R-V2-19)');
select is(jsonb_array_length(app.session_review_sheet(pg_temp.s('p', 1))), 9, 'Màn chấm lấy đủ 9 tiêu chí trong một lần gọi');
select is(app.session_review_sheet(pg_temp.s('p', 1)) -> 0 -> 'levels' ->> 4, 'Tập trung cao, tự ghi chép ý quan trọng', 'Màn chấm có mô tả mức 5 của tiêu chí (Q-190)');
-- CH-07 (migration 503): sửa mô tả sau khi buổi đã mở nhận xét KHÔNG đổi buổi đó (buổi giữ bản chụp lúc mở).
select pg_temp.sudo($$update app.review_level_desc set description = 'Mô tả đã sửa sau' where level = 5 and criterion_id = (select id from app.review_criterion where code = 'TD_TAP_TRUNG')$$);
select is(app.session_review_sheet(pg_temp.s('p', 1)) -> 0 -> 'levels' ->> 4, 'Tập trung cao, tự ghi chép ý quan trọng', 'CH-07: buổi đã mở giữ mô tả cũ sau khi rubric được sửa');
select is(app.open_session_review(pg_temp.s('p', 1)), 9, 'Mở lại không nhân đôi tiêu chí');
select is(pg_temp.err($$select app.open_session_review(pg_temp.s('p', 2))$$), 'HMT_SAI_LOAI_BUOI', 'Chặn: buổi kiểm tra không dùng 9 tiêu chí (R-V2-20)');
select is(pg_temp.err($$select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_TAP_TRUNG'), 'state', 'DA_DANH_GIA', 'score', 6)))$$),
          'HMT_DIEM_KHONG_HOP_LE', 'Chặn: điểm ngoài thang 1 đến 5 (R-V2-19)');
select is(pg_temp.err($$select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_TAP_TRUNG'), 'state', 'DA_DANH_GIA')))$$),
          'HMT_DIEM_KHONG_HOP_LE', 'Chặn: Đã đánh giá mà không có điểm; ô trống khác điểm 0 (R-GV-02)');
select is(pg_temp.err($$select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(3), 'criterion_id', (select id from app.review_criterion where code = 'TD_TAP_TRUNG'), 'state', 'DA_DANH_GIA', 'score', 3)))$$),
          'HMT_EM_KHONG_CO_MAT', 'Chặn: em vắng không phải chấm (R-GV-04)');
select is(pg_temp.err($$select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_TAP_TRUNG'), 'state', 'KHONG_AP_DUNG')))$$),
          'HMT_TRANG_THAI_CHAM_SAI', 'Chặn: Không áp dụng đặt bằng công tắc tiêu chí, không đặt từng em (R-V2-19)');
-- Công tắc tiêu chí: tắt Tập trung cho cả buổi.
select is(app.set_review_criteria(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('criterion_id', (select id from app.review_criterion where code = 'TD_TAP_TRUNG'), 'enabled', false))), 1, 'Đúng: tắt một tiêu chí cho cả buổi (Không áp dụng cả lớp)');
select is(pg_temp.err($$select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_TAP_TRUNG'), 'state', 'DA_DANH_GIA', 'score', 3)))$$),
          'HMT_TIEU_CHI_KHONG_TIM_THAY', 'Chặn: chấm tiêu chí đã tắt');
select is(pg_temp.err($$select app.set_review_criteria(pg_temp.s('p', 1), (select jsonb_agg(jsonb_build_object('criterion_id', criterion_id, 'enabled', false)) from app.session_review_criterion where session_id = pg_temp.s('p', 1)))$$),
          'HMT_NHAN_XET_CAN_TIEU_CHI', 'Chặn: tắt hết tiêu chí');
-- Hai em có mặt (em 1 Có mặt, em 2 Đi muộn); 8 tiêu chí đang bật → 16 ô cần chấm.
select is(app.session_pending_reason(pg_temp.s('p', 1)), 'Còn 16 ô nhận xét chưa đánh giá.', 'Chặn Done: còn ô Chưa đánh giá, em vắng không tính (R-GV-04, R-V2-19)');
select is(pg_temp.err($$select app.set_review_all_class(pg_temp.s('p', 1), (select id from app.review_criterion where code = 'TD_CHU_DONG'), 9)$$), 'HMT_DIEM_KHONG_HOP_LE', 'Chặn: nút Cả lớp với mức ngoài 1 đến 5');
select is(app.set_review_all_class(pg_temp.s('p', 1), (select id from app.review_criterion where code = 'TD_CHU_DONG')), 2, 'Đúng: nút Cả lớp gán cho 2 em có mặt (không gán em vắng)');
select is((select score::int from app.session_review_score sc join app.session_attendance sa on sa.id = sc.attendance_id
            where sa.session_id = pg_temp.s('p', 1) and sa.student_id = pg_temp.st(1) limit 1), 3, 'Nút Cả lớp dùng mức mặc định 3 từ Cài đặt (review_all_class_level)');
select is(app.session_pending_reason(pg_temp.s('p', 1)), 'Còn 14 ô nhận xét chưa đánh giá.', 'Còn 14 ô sau khi chấm 1 tiêu chí cho cả lớp');
-- "Chưa đủ căn cứ" là một lựa chọn đã xử lý; "Chưa đánh giá" thì chưa.
select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_TU_GIAC'), 'state', 'CHUA_DU_CAN_CU')));
select is(app.session_pending_reason(pg_temp.s('p', 1)), 'Còn 13 ô nhận xét chưa đánh giá.', 'Chưa đủ căn cứ tính là đã xử lý ô đó');
-- Chấm các tiêu chí còn lại bằng nút Cả lớp rồi sửa em khác biệt.
select app.set_review_all_class(pg_temp.s('p', 1), rc.criterion_id) from app.session_review_criterion rc where rc.session_id = pg_temp.s('p', 1) and rc.enabled;
-- Em 1: tiêu chí Chủ động 5, còn lại 3 (Tự giác vừa bị Cả lớp ghi đè thành 3): 7×3 + 5 = 26 → 26 ÷ 8 = 3,25.
select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_CHU_DONG'), 'state', 'DA_DANH_GIA', 'score', 5)));
select is(app.review_average((select id from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1))), 3.25::numeric, 'Điểm trung bình do DB tính, không làm tròn: 26 ÷ 8 = 3,25 (R-GV-03)');
-- Em 2: bốn tiêu chí 5 và bốn tiêu chí 4 → 36 ÷ 8 = 4,5 đúng ngưỡng mức 4.
select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(2), 'criterion_id', c.id, 'state', 'DA_DANH_GIA', 'score', case when c.rn <= 4 then 5 else 4 end)))
  from (select rc.criterion_id as id, row_number() over (order by rc.sort_order) as rn from app.session_review_criterion rc where rc.session_id = pg_temp.s('p', 1) and rc.enabled) c;
select is(app.review_average((select id from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(2))), 4.5::numeric, 'Trung bình em 2 đúng 4,5');
select is((app.parent_message_hint(pg_temp.s('p', 1), pg_temp.st(2)) ->> 'level')::int, 4, 'Mức gợi ý 4 khi trung bình đúng 4,5 (R-V2-39: từ 4,5)');
select is((app.parent_message_hint(pg_temp.s('p', 1), pg_temp.st(1)) ->> 'level')::int, 2, 'Mức gợi ý 2 khi trung bình 3,25 (R-V2-39: từ 2,5 đến dưới 3,5)');
select is(jsonb_array_length(app.parent_message_hint(pg_temp.s('p', 1), pg_temp.st(1)) -> 'phrases'), 3, 'Mỗi mức gợi ý 3 câu mẫu (R-V2-39)');
select is(app.parent_message_hint(pg_temp.s('p', 1), pg_temp.st(3)) -> 'level', 'null'::jsonb, 'Em vắng chưa có điểm thì chưa có mức gợi ý');
-- Nhận xét của giáo viên không bắt buộc (R-V2-39, bỏ luật v1).
select is(app.session_pending_reason(pg_temp.s('p', 1)), null, 'Đủ điều kiện Done dù giáo viên không viết nhận xét nào (R-GV-04 sau 04/11)');
select is(pg_temp.err($$select app.set_student_review_note(pg_temp.s('p', 1), pg_temp.st(3), 'Em vắng')$$), 'HMT_EM_KHONG_CO_MAT', 'Chặn: nhận xét cho em vắng');
select lives_ok($$select app.set_student_review_note(pg_temp.s('p', 1), pg_temp.st(1), 'Em chú ý nghe giảng', 'Làm thêm bài tập dạng 2')$$, 'Đúng: giáo viên ghi nhận xét chung và định hướng');
select pg_temp.sudo($$select app.mark_session_done(pg_temp.s('p', 1))$$);
select is((select status_code from app.class_session where id = pg_temp.s('p', 1)), 'DONE', 'Buổi thường Done khi chấm xong, không cần BTVN (R-V2-35)');
select is(app.enrollment_hours_balance(pg_temp.e('a')), 8.50::numeric, 'Buổi thường Done trừ 1,5 giờ');
-- Sau Done giáo viên không sửa (R-GV-08).
select is(pg_temp.err($$select app.set_review_scores(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'criterion_id', (select id from app.review_criterion where code = 'TD_CHU_DONG'), 'state', 'DA_DANH_GIA', 'score', 1)))$$),
          'HMT_BUOI_DA_DONE', 'Chặn: giáo viên không sửa điểm nhận xét sau Done');
select is(pg_temp.err($$select app.set_student_review_note(pg_temp.s('p', 1), pg_temp.st(1), 'Sửa')$$), 'HMT_BUOI_DA_DONE', 'Chặn: giáo viên không sửa nhận xét sau Done');

-- ================= Dấu Đã xuất (R-V2-38) =================
select is((select count(*)::int from app.session_student_review where exported), 0, 'Mặc định chưa có em nào Đã xuất');
select lives_ok($$select app.set_review_exported(pg_temp.s('p', 1), pg_temp.st(1), true)$$, 'Đúng: giáo viên đặt dấu Đã xuất, kể cả sau Done');
select is((select exported from app.session_student_review r join app.session_attendance sa on sa.id = r.attendance_id where sa.session_id = pg_temp.s('p', 1) and sa.student_id = pg_temp.st(1)), true, 'Cờ Đã xuất lưu theo em theo buổi');
select is((select teacher_comment from app.session_student_review r join app.session_attendance sa on sa.id = r.attendance_id where sa.session_id = pg_temp.s('p', 1) and sa.student_id = pg_temp.st(1)), 'Em chú ý nghe giảng', 'Đặt cờ không xoá nhận xét đã ghi');
select lives_ok($$select app.set_review_exported(pg_temp.s('p', 1), pg_temp.st(1), false)$$, 'Cờ đặt lại được, không có lịch sử (R-V2-38)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.set_review_exported(pg_temp.s('p', 1), pg_temp.st(1), true)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không đặt dấu Đã xuất');

-- ================= RLS: ai đọc được điểm nhận xét =================
select is((select count(*)::int from app.session_review_score), 0, 'RLS: giáo viên không được phân công không đọc điểm nhận xét');
select cmp_ok((select count(*)::int from app.review_criterion), '>=', 9, 'Giáo viên đọc được danh sách tiêu chí');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select cmp_ok((select count(*)::int from app.session_review_score), '>', 0, 'RLS: giáo viên được phân công đọc điểm nhận xét của buổi mình');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((select count(*)::int from app.session_review_score), 0, 'RLS: quản lý cơ sở khác không đọc điểm nhận xét');
select is((select count(*)::int from app.exam_score), 0, 'RLS: quản lý cơ sở khác không đọc điểm kiểm tra');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select cmp_ok((select count(*)::int from app.session_review_score), '>', 0, 'RLS: quản lý cơ sở của buổi đọc được điểm nhận xét');
select is(pg_temp.err($$insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select session_id, branch_id, session_criterion_id, attendance_id, 'DA_DANH_GIA', 1 from app.session_review_score limit 1$$), '42501', 'Chặn: không ghi thẳng bảng điểm, chỉ qua hàm nghiệp vụ');

-- ================= Buổi Kiểm tra (R-V2-20) =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_exam_scores(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'total', 8)))$$), 'HMT_KIEM_TRA_CHUA_CAU_HINH', 'Chặn: chấm khi chưa đặt điểm tối đa và cách nhập');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 2), 'Chương 1', 10, 'TONG')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không đặt cấu hình kiểm tra, người xếp lịch đặt (R-V2-18)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 2), 'Chương 1', 10, 'KHAC')$$), 'HMT_CACH_NHAP_DIEM_SAI', 'Chặn: cách nhập điểm phải là Điểm tổng hoặc Theo 3 nhóm');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 2), 'Chương 1', 10, 'NHOM', 3, 4, 2)$$), 'HMT_DIEM_NHOM_KHONG_KHOP', 'Chặn: tổng điểm tối đa ba nhóm khác điểm tối đa của buổi');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 1), 'Chương 1', 10, 'TONG')$$), 'HMT_SAI_LOAI_BUOI', 'Chặn: cấu hình kiểm tra cho buổi không phải Kiểm tra');
select lives_ok($$select app.set_exam_config(pg_temp.s('p', 2), 'Chương 1', null, 'TONG')$$, 'Đúng: đặt cấu hình, điểm tối đa lấy mặc định');
select is((select max_score from app.session_exam where session_id = pg_temp.s('p', 2)), 10.00::numeric, 'Điểm tối đa mặc định 10 từ Cài đặt, chụp lại cho buổi (R-V2-20)');
select is(app.session_pending_reason(pg_temp.s('p', 2)), 'Giáo viên chưa chấm điểm kiểm tra 2 em.', 'Chặn Done: còn em có mặt ở Chưa chấm; em vắng không tự nhận 0 (R-V2-20)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_exam_scores(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'total', 11)))$$), 'HMT_DIEM_VUOT_TOI_DA', 'Chặn: điểm vượt điểm tối đa');
select is(pg_temp.err($$select app.set_exam_scores(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(3), 'total', 5)))$$), 'HMT_EM_KHONG_CO_MAT', 'Chặn: chấm điểm em vắng');
select is(app.set_exam_scores(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'total', 8.5), jsonb_build_object('student_id', pg_temp.st(2), 'total', 10))), 2, 'Đúng: giáo viên nhập điểm tổng');
select is((select count(*)::int from app.exam_score where session_id = pg_temp.s('p', 2)), 2, 'Em vắng không có dòng điểm (không tự nhận 0)');
select is(app.session_pending_reason(pg_temp.s('p', 2)), null, 'Buổi kiểm tra chấm xong khi không còn em có mặt ở Chưa chấm');
select is((app.parent_message_hint(pg_temp.s('p', 2), pg_temp.st(1)) ->> 'level')::int, 3, 'Kiểm tra 85% → mức 3 (R-V2-39: từ 75% đến dưới 90%)');
select is((app.parent_message_hint(pg_temp.s('p', 2), pg_temp.st(2)) ->> 'kind'), 'KIEM_TRA', 'Buổi kiểm tra dùng bộ mẫu câu Kiểm tra');
select pg_temp.sudo($$select app.mark_session_done(pg_temp.s('p', 2))$$);
select is(app.enrollment_hours_balance(pg_temp.e('a')), 7.00::numeric, 'Buổi kiểm tra Done trừ giờ như buổi Chính (R-V2-20, Q-176)');
-- Theo 3 nhóm.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.set_exam_config(pg_temp.s('p', 3), 'Giữa kỳ', 10, 'NHOM', 3, 4, 3);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_exam_scores(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'memory', 4, 'understand', 4, 'apply', 2)))$$), 'HMT_DIEM_VUOT_TOI_DA', 'Chặn: điểm một nhóm vượt tối đa của nhóm');
select is(pg_temp.err($$select app.set_exam_scores(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'memory', 3, 'understand', 4)))$$), 'HMT_DIEM_KHONG_HOP_LE', 'Chặn: thiếu điểm một nhóm có đề');
select app.set_exam_scores(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'memory', 3, 'understand', 3, 'apply', 2)));
select is((select total_score from app.exam_score es join app.session_attendance sa on sa.id = es.attendance_id where sa.session_id = pg_temp.s('p', 3) and sa.student_id = pg_temp.st(1)), 8.00::numeric, 'Điểm tổng tự cộng từ ba nhóm: 3 + 3 + 2 (R-V2-20)');
-- Từ migration 130 (F4) buổi đã có điểm chấm thì không đổi cấu hình; ca này kiểm riêng luật nhóm không có đề nên bỏ cờ Đã chấm của điểm giả trước khi đặt lại (bảng không cho xoá).
select pg_temp.sudo($$update app.exam_score set graded = false where session_id = pg_temp.s('p', 3)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.set_exam_config(pg_temp.s('p', 3), 'Giữa kỳ', 10, 'NHOM', 5, 5, 0);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_exam_scores(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'memory', 4, 'understand', 3)));
select is((select total_score from app.exam_score es join app.session_attendance sa on sa.id = es.attendance_id where sa.session_id = pg_temp.s('p', 3) and sa.student_id = pg_temp.st(1)), 7.00::numeric, 'Nhóm không có đề (tối đa 0) bỏ qua, tổng 4 + 3 = 7');
-- Sửa điểm sau Done (R-V2-20 mục 5).
select is(pg_temp.err($$select app.correct_exam_score_after_done(pg_temp.s('p', 2), pg_temp.st(1), '{"total": 9}', 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không sửa điểm kiểm tra sau Done');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.correct_exam_score_after_done(pg_temp.s('p', 2), pg_temp.st(1), '{"total": 9}', 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: chỉ quản lý đào tạo sửa điểm sau Done');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.correct_exam_score_after_done(pg_temp.s('p', 2), pg_temp.st(1), '{"total": 9}', 'KHONG_CO_LY_DO_NAY')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: sửa điểm sau Done bắt buộc lý do hợp lệ');
select is(pg_temp.err($$select app.correct_exam_score_after_done(pg_temp.s('p', 3), pg_temp.st(1), '{"total": 9}', 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_BUOI_CHUA_DONE', 'Chặn: buổi chưa Done thì giáo viên sửa, không dùng chức năng này');
select lives_ok($$select app.correct_exam_score_after_done(pg_temp.s('p', 2), pg_temp.st(1), '{"total": 9}', 'SUA_SAI_DANH_SACH_DIEM_DANH', 'Chấm lại câu 5')$$, 'Đúng: quản lý sửa điểm sau Done kèm lý do');
select is((select total_score from app.exam_score es join app.session_attendance sa on sa.id = es.attendance_id where sa.session_id = pg_temp.s('p', 2) and sa.student_id = pg_temp.st(1)), 9.00::numeric, 'Điểm đã sửa và lưu lý do (R-V2-20)');
select is((select es.correction_reason_code from app.exam_score es join app.session_attendance sa on sa.id = es.attendance_id where sa.session_id = pg_temp.s('p', 2) and sa.student_id = pg_temp.st(1)), 'SUA_SAI_DANH_SACH_DIEM_DANH', 'Lý do sửa điểm được ghi');

-- ================= Q-198: tham số session_done_requires_review, nhánh Tắt =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.session_pending_reason(pg_temp.s('p', 3)), 'Giáo viên chưa chấm điểm kiểm tra 1 em.', 'Bật: buổi kiểm tra còn em chưa chấm thì chưa Done (Q-198)');
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'session_done_requires_review'$$);
select is(app.session_pending_reason(pg_temp.s('p', 3)), null, 'Tắt: đã điểm danh xong thì Done được dù chưa chấm điểm (Q-198)');
select pg_temp.sudo($$select app.mark_session_done(pg_temp.s('p', 3))$$);
select is((select status_code from app.class_session where id = pg_temp.s('p', 3)), 'DONE', 'Tắt: buổi Done không cần nhận xét hay điểm (Q-198)');
select is(app.enrollment_hours_balance(pg_temp.e('b')), 5.50::numeric, 'Tắt: giờ vẫn trừ như bình thường: 10 − 3 × 1,5 (Q-198, R-GIO-01)');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'session_done_requires_review'$$);
select * from finish();
rollback;
