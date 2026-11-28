-- Dữ liệu GIẢ cho cổng Giáo viên CHỈ trên hmt-staging (E-27-16): tài khoản tập gvtap1.cs5 có lớp, buổi, học sinh để thử điểm danh, nhận xét, Done.
-- Tạo: 2 lớp CS5 do gvtap1.cs5 dạy (lớp Toán có trợ giảng tg.cs5), mỗi lớp 4 em, buổi MỖI NGÀY từ hôm qua trong 30 ngày;
--   buổi hôm qua đã Done (đủ điểm danh, nội dung, nhận xét), buổi hôm nay Đã chốt danh sách, chưa điểm danh; các ngày sau còn Nháp.
-- Đi bằng HÀM NGHIỆP VỤ với claims giả của đúng vai (đúng luật, cấp mã, nhật ký). Tên và SĐT giả (dải 0995 3xxxxx). KHÔNG DỮ LIỆU THẬT.
-- Chạy lại được: còn lớp của bộ này có buổi từ ngày mai trở đi thì bỏ qua; hết buổi thì tạo bộ mới.
-- Chỉ deploy-staging.yml chạy (sau seed-users và seed-staging). KHÔNG phải migration nên bản chạy thật không bao giờ có; thêm khoá: DB phải có dòng STAGING.
\set ON_ERROR_STOP on
select not exists (select from app.deployment_env where env_code = 'STAGING') as not_staging \gset
\if :not_staging
\echo 'seed-staging-gv: DB không có khoá môi trường STAGING, bỏ qua.'
\quit
\endif
select (select count(*) from app.user_account
         where login_name in ('gvtap1.cs5@thu.hoamatoan.invalid', 'tg.cs5@thu.hoamatoan.invalid',
                              'truongcs.cs5@thu.hoamatoan.invalid', 'cskh.cs5@thu.hoamatoan.invalid')) < 4 as no_users \gset
\if :no_users
\echo 'seed-staging-gv: thiếu tài khoản giả (gvtap1.cs5 cần SEED_PRACTICE_PASSWORD), bỏ qua.'
\quit
\endif
select exists (
  select from app.class c join app.class_session s on s.class_id = c.id
   where c.legacy_ref like 'SEED-GV-%' and c.status_code = 'DA_DUYET' and s.status_code in ('NHAP', 'DA_CHOT')
     and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date) as seeded \gset
\if :seeded
\echo 'seed-staging-gv: đã có lớp còn buổi sắp tới, bỏ qua.'
\quit
\endif

begin;
create function pg_temp.claims(p_login text) returns void language plpgsql security definer as $$
declare v_id uuid; v_result jsonb;
begin
  select id into v_id from app.user_account where login_name = p_login || '@thu.hoamatoan.invalid';
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', v_id, 'claims', jsonb_build_object('sub', v_id, 'role', 'authenticated', 'aal', 'aal1')));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.uid(p_login text) returns uuid language sql stable security definer as $$
  select id from app.user_account where login_name = p_login || '@thu.hoamatoan.invalid' $$;
grant execute on all functions in schema pg_temp to public;

insert into app.feature_flag (module_code, branch_id, enabled)
select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
on conflict (module_code, branch_id) do update set enabled = true;

do $$
declare
  r record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_first date := (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1;
  v_tag text := to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'YYMMDDHH24MI');
  v_branch uuid := (select id from app.branch where code = 'CS5');
  v_teacher uuid := pg_temp.uid('gvtap1.cs5');
  v_slots jsonb; v_class uuid; v_parent uuid; v_student uuid; v_enrollment uuid; v_i int; v_seq int := 0;
  v_phone_base int := (select count(*) from app.parent where code like 'PHGV%');
  v_past uuid; v_now uuid; v_students uuid[]; v_att jsonb; v_scores jsonb; v_notes jsonb;
begin
  for r in select * from (values
      (1, 'TOAN', 'K08', '18:00', '19:30', pg_temp.uid('tg.cs5')),
      (2, 'ANH', 'K07', '19:45', '21:15', null::uuid)) v(n, subject, grade, starts, ends, assistant) loop
    -- Lịch bảy khung, mỗi thứ một khung, để ngày nào cũng có buổi.
    select jsonb_agg(jsonb_build_object('weekday', extract(isodow from v_first + d)::int, 'start_time', r.starts, 'end_time', r.ends,
             'repeat_weeks', 1, 'first_date', v_first + d, 'teacher_id', v_teacher, 'assistant_id', r.assistant) order by d)
      into v_slots from generate_series(0, 6) d;
    perform pg_temp.claims('truongcs.cs5');
    set local role authenticated;
    v_class := (app.create_class(jsonb_build_object('branch_id', v_branch, 'year_code', '2627', 'subject_code', r.subject, 'grade_code', r.grade,
      'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', v_first, 'total_sessions', 30,
      'legacy_ref', 'SEED-GV-' || v_tag || '-' || r.n, 'slots', v_slots)) ->> 'id')::uuid;
    perform app.transition_class(v_class, 'DA_TRINH');
    perform app.transition_class(v_class, 'DA_XAC_NHAN');
    perform app.transition_class(v_class, 'DA_DUYET');
    reset role;

    -- Bốn em mỗi lớp, ghi danh có 40 giờ đầu kỳ (lùi ngày tạo để vào danh sách buổi, R-GIO-02).
    v_students := '{}';
    for v_i in 1..4 loop
      v_seq := v_seq + 1;
      insert into app.parent (code, full_name, phone, branch_id)
      values ('PHGV' || v_tag || v_seq, 'Phụ huynh cổng GV ' || v_seq || ' (giả)',
              '09953' || lpad((v_phone_base + v_seq)::text, 5, '0'), v_branch)
      returning id into v_parent;
      insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade)
      values ('HSGV' || v_tag || v_seq, v_parent, 'Em Thử Lớp ' || r.n || ' số ' || v_i || ' (giả)', 2013, v_branch, substring(r.grade from 2)::int)
      returning id into v_student;
      insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
      values ('GDGV' || v_tag || v_seq, v_student, v_parent, v_branch, r.subject) returning id into v_enrollment;
      alter table app.enrollment disable trigger enrollment_fill_standard;
      update app.enrollment set created_at = now() - interval '60 days' where id = v_enrollment;
      alter table app.enrollment enable trigger enrollment_fill_standard;
      perform app.add_opening_hours(v_enrollment, 40, 'DOT-GV');
      perform pg_temp.claims('cskh.cs5');
      set local role authenticated;
      perform app.assign_enrollment_class(v_enrollment, v_class, v_first);
      reset role;
      v_students := v_students || v_student;
    end loop;

    select id into v_past from app.class_session where class_id = v_class and session_date = v_first and status_code in ('NHAP', 'DA_CHOT');
    select id into v_now from app.class_session where class_id = v_class and session_date = v_today and status_code in ('NHAP', 'DA_CHOT');
    -- Chốt danh sách buổi hôm qua và hôm nay (ngày nghỉ lễ thì không có buổi).
    perform pg_temp.claims('cskh.cs5');
    set local role authenticated;
    if v_past is not null then perform app.close_session(v_past); end if;
    if v_now is not null then perform app.close_session(v_now); end if;
    reset role;

    -- Buổi hôm qua: giáo viên điểm danh, chấm 9 tiêu chí và nhận xét, ghi nội dung, bài tập; đủ điều kiện thì Done.
    if v_past is not null then
      select jsonb_agg(jsonb_build_object('student_id', s, 'status_code', 'CO_MAT')) into v_att from unnest(v_students) s;
      perform pg_temp.claims('gvtap1.cs5');
      set local role authenticated;
      perform app.save_attendance_teacher(v_past, v_att);
      perform app.open_session_review(v_past);
      reset role;
      select jsonb_agg(jsonb_build_object('student_id', s, 'criterion_id', c.criterion_id, 'state', 'DA_DANH_GIA', 'score', 4)) into v_scores
        from unnest(v_students) s cross join app.session_review_criterion c where c.session_id = v_past and c.enabled;
      select jsonb_agg(jsonb_build_object('student_id', s, 'comment', 'Tập trung nghe giảng, làm bài tốt.', 'improvement', 'Làm bài tập về nhà đều.'))
        into v_notes from unnest(v_students) s;
      perform pg_temp.claims('gvtap1.cs5');
      set local role authenticated;
      perform app.save_review_grading(v_past, '[]'::jsonb, v_scores, v_notes);
      -- Nội dung buổi ghi SAU CÙNG: đủ điều kiện là buổi tự Done ngay, khi đó không chấm thêm được.
      perform app.save_session_content(v_past, array['Ôn bài cũ', 'Bài mới và luyện tập'], 'Làm bài 1 đến 5 trong phiếu bài tập.');
      reset role;
    end if;
  end loop;
end $$;

-- Kết quả (không in dữ liệu cá nhân): mỗi lớp, trạng thái buổi hôm qua, hôm nay, ngày mai, và còn thiếu gì nếu buổi hôm qua chưa Done.
select c.code as lop, s.session_date - (now() at time zone 'Asia/Ho_Chi_Minh')::date as lech_ngay, s.status_code, s.assistant_id is not null as co_tro_giang,
       (select count(*) from app.session_attendance a where a.session_id = s.id and a.is_active) as so_em,
       case when s.status_code <> 'DONE' and s.session_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date
            then app.session_pending_reason(s.id) end as con_thieu
  from app.class c join app.class_session s on s.class_id = c.id
 where c.legacy_ref like 'SEED-GV-' || to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'YYMMDDHH24MI') || '-%'
   and s.status_code <> 'DA_THAY' and s.session_date <= (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1
 order by c.code, s.session_date;
commit;
