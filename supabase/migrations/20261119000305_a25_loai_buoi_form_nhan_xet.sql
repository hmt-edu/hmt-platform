-- A25 PR1 (Chat duyệt 19/11/2026, Q-176, R-V2-18, R-V2-20): LOẠI BUỔI quyết định FORM NHẬN XÉT, sửa được ở Danh mục; thêm Kiểm tra giữa kỳ, Kiểm tra cuối kỳ.
-- Trước đây mã 'KIEM_TRA' viết cứng ở nhiều hàm để chọn «form điểm» thay cho «9 tiêu chí». Bản này:
--   1. Thêm hai loại buổi KT_GIUA_KY, KT_CUOI_KY (mã KIEM_TRA giữ, buổi cũ không đổi). Cả ba trừ giờ như buổi Chính (Q-176).
--   2. Bảng app.session_type_form (loại buổi -> form: TIEU_CHI hoặc DIEM), sửa bằng app.set_session_type_form (chỉ Admin cấu hình). Đổi form CHỈ áp dụng cho buổi tạo SAU.
--   3. Cột class_session.review_form: chụp lại form lúc tạo buổi (trigger), buổi cũ KIEM_TRA = DIEM, còn lại TIEU_CHI. app.session_is_exam(buổi) thay cho so sánh mã.
--   4. Yêu cầu buổi (migration 303) chọn được cả ba loại kiểm tra (app.set_request_exam thêm tham số p_type_code), duyệt sinh buổi đúng loại.
-- Các hàm dưới đây giữ nguyên bản mới nhất của chúng, chỉ đổi so sánh mã loại buổi thành app.session_is_exam.
select set_config('hmt.migration', 'on', false);

insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('SESSION_TYPE', 'KT_GIUA_KY', 'Kiểm tra giữa kỳ', 6),
  ('SESSION_TYPE', 'KT_CUOI_KY', 'Kiểm tra cuối kỳ', 7);

-- Loại buổi nào dùng form nhận xét nào. Đổi form chỉ áp dụng cho buổi tạo sau (buổi đã tạo giữ form lúc tạo).
create table app.session_type_form (
  type_catalog text not null default 'SESSION_TYPE' check (type_catalog = 'SESSION_TYPE'),
  type_code text primary key,
  form_code text not null check (form_code in ('TIEU_CHI', 'DIEM')),
  id uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (type_catalog, type_code) references app.catalog_item (catalog_code, code)
);
comment on table app.session_type_form is 'Form nhận xét của từng loại buổi: TIEU_CHI (9 tiêu chí) hoặc DIEM (form điểm). Đổi chỉ áp dụng cho buổi tạo sau (A25, Q-176).';
select app.apply_standard('app.session_type_form');
alter table app.session_type_form enable row level security;
grant select on app.session_type_form to authenticated;
create policy session_type_form_read on app.session_type_form for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);
insert into app.session_type_form (type_code, form_code) values
  ('CHINH', 'TIEU_CHI'), ('CUNG_CO', 'TIEU_CHI'), ('HOC_BU', 'TIEU_CHI'), ('BO_TRO', 'TIEU_CHI'),
  ('KIEM_TRA', 'DIEM'), ('KT_GIUA_KY', 'DIEM'), ('KT_CUOI_KY', 'DIEM');

-- Cột chụp form lúc tạo buổi. Chỉ mục không cần: chỉ đọc theo từng buổi.
alter table app.class_session add column review_form text not null default 'TIEU_CHI' check (review_form in ('TIEU_CHI', 'DIEM'));
comment on column app.class_session.review_form is 'Form nhận xét chụp lúc tạo buổi từ app.session_type_form (A25). TIEU_CHI hoặc DIEM; buổi cũ KIEM_TRA = DIEM.';
update app.class_session set review_form = 'DIEM' where type_code = 'KIEM_TRA';

create or replace function app.class_session_set_review_form()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Luật: buổi mới chụp form của loại buổi lúc tạo (đổi form sau không đổi buổi đã tạo).
  if tg_op = 'UPDATE' and new.type_code is not distinct from old.type_code then
    return new;
  end if;
  select f.form_code into new.review_form from app.session_type_form f where f.type_code = new.type_code;
  new.review_form := coalesce(new.review_form, 'TIEU_CHI');
  return new;
end;
$$;
-- Đổi loại buổi (hiếm, chỉ qua cấu hình lịch) cũng chụp lại form của loại mới.
create trigger class_session_review_form before insert or update of type_code on app.class_session
  for each row execute function app.class_session_set_review_form();

-- app.session_is_exam(buổi): buổi chấm bằng form điểm (Kiểm tra). Thay cho so sánh mã 'KIEM_TRA'.
create or replace function app.session_is_exam(p_session app.class_session)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_session.review_form = 'DIEM';
$$;
revoke execute on function app.session_is_exam(app.class_session) from public, anon, authenticated;

-- app.set_session_type_form(loại buổi, form): Danh mục · Loại buổi, sửa form nhận xét. Ai gọi: Admin cấu hình. Mã loại buổi không đổi. Chỉ áp dụng cho buổi tạo sau.
create or replace function app.set_session_type_form(p_type_code text, p_form_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  if p_form_code is null or p_form_code not in ('TIEU_CHI', 'DIEM') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Form nhận xét phải là 9 tiêu chí hoặc form điểm.');
  end if;
  if not exists (select from app.session_type_form where type_code = p_type_code) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy loại buổi.');
  end if;
  update app.session_type_form set form_code = p_form_code where type_code = p_type_code;
end;
$$;
revoke execute on function app.set_session_type_form(text, text) from public, anon, authenticated;
grant execute on function app.set_session_type_form(text, text) to authenticated;

-- app.session_type_deducts_hours: thêm hai loại kiểm tra, trừ giờ như buổi Chính (Q-176).
create or replace function app.session_type_deducts_hours(p_session_type text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  -- Luật: buổi chính, củng cố, kiểm tra các loại trừ giờ (R-V2-20, Q-176).
  if p_session_type in ('CHINH', 'CUNG_CO', 'KIEM_TRA', 'KT_GIUA_KY', 'KT_CUOI_KY') then
    return true;
  end if;
  -- Luật: học bù, học bổ trợ không trừ giờ.
  if p_session_type in ('HOC_BU', 'BO_TRO') then
    return false;
  end if;
  perform app.raise_error('HMT_LOAI_BUOI_SAI', format('Không có loại buổi "%s".', p_session_type));
  return null;
end;
$$;


-- session_pending_reason: bản mới nhất ở 20261111000121_gv08_cham_btvn.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.session_pending_reason(p_session_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_missing integer;
  v_hw jsonb;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.status_code <> 'DA_CHOT' then
    return 'Buổi chưa chốt danh sách.';
  end if;
  if app.session_ends_at(p_session_id) > now() then
    return 'Buổi chưa kết thúc.';
  end if;
  select count(*) into v_missing from app.session_attendance where session_id = p_session_id and is_active and teacher_status_code is null;
  if v_missing > 0 then
    return format('Giáo viên chưa điểm danh %s em.', v_missing);
  end if;
  -- Luật Q-231, R-V2-35: buổi thường cần ít nhất một dòng nội dung buổi (BTVN không bắt buộc), cả khi tham số Bật lẫn Tắt.
  -- Buổi Kiểm tra: khung GV-06 kiểm tra để phạm vi kiến thức và BTVN tuỳ giáo viên nên không đòi dòng nội dung; vẫn cần cấu hình điểm (R-V2-20).
  if not app.session_is_exam(s) and not app.session_has_content(p_session_id) then
    return 'Giáo viên chưa nhập nội dung buổi.';
  end if;
  -- Luật Q-198: tham số tắt thì bỏ điều kiện nhận xét, điểm; điểm danh và nội dung buổi vẫn bắt buộc (kiểm ở trên).
  if not app.get_setting_bool('session_done_requires_review', s.branch_id) then
    return null;
  end if;
  -- Luật Q-272, R-GIO-06, R-GV-11: bước chấm BTVN buổi trước chặn Done khi tham số Bật (chỉ khi buổi trước có giao BTVN); Tắt thì không chặn (đã return ở trên).
  v_hw := app.homework_progress(p_session_id);
  if (v_hw ->> 'state') = 'CAN_CHAM' and (v_hw ->> 'done')::integer < (v_hw ->> 'present')::integer then
    return format('Giáo viên chưa chấm BTVN buổi trước cho %s em.', (v_hw ->> 'present')::integer - (v_hw ->> 'done')::integer);
  end if;
  if app.session_is_exam(s) then
    -- Luật R-V2-20: buổi kiểm tra chấm xong khi không còn em có mặt ở Chưa chấm.
    if not exists (select from app.session_exam where session_id = p_session_id) then
      return 'Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.';
    end if;
    select count(*) into v_missing from app.session_attendance sa
     where sa.session_id = p_session_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
       and not exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded);
    if v_missing > 0 then
      return format('Giáo viên chưa chấm điểm kiểm tra %s em.', v_missing);
    end if;
  else
    -- Luật R-V2-19, R-GV-04 (sửa 04/11): chấm xong khi mọi em có mặt không còn ô Chưa đánh giá ở tiêu chí đang bật.
    if not exists (select from app.session_review_criterion where session_id = p_session_id and enabled) then
      return 'Giáo viên chưa mở phần nhận xét của buổi.';
    end if;
    select count(*) into v_missing
      from app.session_attendance sa
      join app.session_review_criterion rc on rc.session_id = sa.session_id and rc.enabled
     where sa.session_id = p_session_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
       and not exists (select from app.session_review_score sc
                        where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA');
    if v_missing > 0 then
      return format('Còn %s ô nhận xét chưa đánh giá.', v_missing);
    end if;
  end if;
  return null;
end;
$$;

-- parent_message_hint: bản mới nhất ở 20261111000103_d2_nhan_xet_kiem_tra.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.parent_message_hint(p_session_id uuid, p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  sa app.session_attendance;
  ex app.session_exam;
  v_kind text;
  v_value numeric;
  v_l4 numeric;
  v_l3 numeric;
  v_l2 numeric;
  v_level smallint;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into sa from app.session_attendance where session_id = p_session_id and student_id = p_student_id and is_active;
  if sa.id is null then
    perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Em không nằm trong danh sách buổi này.');
  end if;
  if app.session_is_exam(s) then
    v_kind := 'KIEM_TRA';
    select * into ex from app.session_exam where session_id = p_session_id;
    select es.total_score / ex.max_score * 100 into v_value from app.exam_score es where es.attendance_id = sa.id and es.graded; -- allow-number: đổi điểm thành phần trăm
    v_l4 := app.get_setting_numeric('parent_hint_exam_level4', s.branch_id);
    v_l3 := app.get_setting_numeric('parent_hint_exam_level3', s.branch_id);
    v_l2 := app.get_setting_numeric('parent_hint_exam_level2', s.branch_id);
  else
    v_kind := 'THUONG';
    v_value := app.review_average(sa.id);
    v_l4 := app.get_setting_numeric('parent_hint_regular_level4', s.branch_id);
    v_l3 := app.get_setting_numeric('parent_hint_regular_level3', s.branch_id);
    v_l2 := app.get_setting_numeric('parent_hint_regular_level2', s.branch_id);
  end if;
  if v_value is null then
    return jsonb_build_object('kind', v_kind, 'level', null, 'phrases', '[]'::jsonb);
  end if;
  v_level := case when v_value >= v_l4 then 4 when v_value >= v_l3 then 3 when v_value >= v_l2 then 2 else 1 end; -- allow-number: số mức gợi ý cố định 1 đến 4 (R-V2-39)
  return jsonb_build_object('kind', v_kind, 'level', v_level,
    'phrases', coalesce((select jsonb_agg(pp.phrase order by pp.seq) from app.parent_phrase pp where pp.kind = v_kind and pp.level = v_level), '[]'::jsonb));
end;
$$;

-- assert_review_writable: bản mới nhất ở 20261111000103_d2_nhan_xet_kiem_tra.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.assert_review_writable(p_session_id uuid, p_exam boolean)
returns app.class_session
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nhận xét, điểm. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa chấm được.');
  end if;
  if app.session_is_exam(s) is distinct from p_exam then
    perform app.raise_error('HMT_SAI_LOAI_BUOI', case when p_exam then 'Buổi này không phải buổi kiểm tra.' else 'Buổi kiểm tra chấm bằng điểm, không dùng 9 tiêu chí.' end);
  end if;
  return s;
end;
$$;

-- set_exam_config: bản mới nhất ở 20261115000130_sua_diem_kiem_tra_f3_f4.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.set_exam_config(p_session_id uuid, p_scope text, p_max_score numeric, p_mode text,
                                               p_max_memory numeric default 0, p_max_understand numeric default 0, p_max_apply numeric default 0)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_max numeric;
  v_old app.session_exam;
  v_scope text := nullif(btrim(p_scope), '');
  v_m numeric;
  v_u numeric;
  v_a numeric;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if not app.session_is_exam(s) then
    perform app.raise_error('HMT_SAI_LOAI_BUOI', 'Buổi này không phải buổi kiểm tra.');
  end if;
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA_DUOC', 'Chỉ đặt cấu hình kiểm tra cho buổi chưa Done và chưa huỷ.');
  end if;
  if p_mode not in ('TONG', 'NHOM') then
    perform app.raise_error('HMT_CACH_NHAP_DIEM_SAI', 'Cách nhập điểm là Điểm tổng hoặc Theo 3 nhóm.');
  end if;
  v_max := coalesce(p_max_score, app.get_setting_int('exam_default_max_score', s.branch_id));
  if v_max <= 0 then
    perform app.raise_error('HMT_DIEM_TOI_DA_SAI', 'Điểm tối đa phải lớn hơn 0.');
  end if;
  -- Luật R-V2-20: theo 3 nhóm thì tổng tối đa 3 nhóm bằng điểm tối đa của buổi.
  if p_mode = 'NHOM' and coalesce(p_max_memory, 0) + coalesce(p_max_understand, 0) + coalesce(p_max_apply, 0) <> v_max then
    perform app.raise_error('HMT_DIEM_NHOM_KHONG_KHOP', 'Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi.');
  end if;
  v_m := case when p_mode = 'NHOM' then coalesce(p_max_memory, 0) else 0 end;
  v_u := case when p_mode = 'NHOM' then coalesce(p_max_understand, 0) else 0 end;
  v_a := case when p_mode = 'NHOM' then coalesce(p_max_apply, 0) else 0 end;
  -- F4: đã có điểm chấm thì chặn mọi thay đổi cấu hình.
  select * into v_old from app.session_exam where session_id = p_session_id;
  if exists (select 1 from app.exam_score where session_id = p_session_id and graded)
     and (v_old.session_id is null
          or v_old.scope_text is distinct from v_scope or v_old.max_score is distinct from v_max or v_old.entry_mode is distinct from p_mode
          or v_old.max_memory is distinct from v_m or v_old.max_understand is distinct from v_u or v_old.max_apply is distinct from v_a) then
    perform app.raise_error('HMT_KIEM_TRA_DA_CO_DIEM', 'Buổi kiểm tra đã có điểm chấm, không đổi được cấu hình.');
  end if;
  insert into app.session_exam (session_id, branch_id, scope_text, max_score, entry_mode, max_memory, max_understand, max_apply)
  values (p_session_id, s.branch_id, v_scope, v_max, p_mode, v_m, v_u, v_a)
  on conflict (session_id) do update set scope_text = excluded.scope_text, max_score = excluded.max_score, entry_mode = excluded.entry_mode,
         max_memory = excluded.max_memory, max_understand = excluded.max_understand, max_apply = excluded.max_apply;
end;
$$;

-- correct_exam_score_after_done: bản mới nhất ở 20261111000103_d2_nhan_xet_kiem_tra.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.correct_exam_score_after_done(p_session_id uuid, p_student_id uuid, p_entry jsonb, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  ex app.session_exam;
  v_att uuid;
  v_r numeric[];
  v_requires_note boolean;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  perform app.assert_can('ATTENDANCE', 'DUYET', s.branch_id);
  if s.status_code <> 'DONE' or not app.session_is_exam(s) then
    perform app.raise_error('HMT_BUOI_CHUA_DONE', 'Chỉ sửa điểm sau Done cho buổi kiểm tra đã Done. Buổi chưa Done thì giáo viên sửa.');
  end if;
  perform app.assert_catalog_code_active('HOURS_ADJUST_REASON', p_reason_code);
  select requires_note into v_requires_note from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' and code = p_reason_code;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  select * into ex from app.session_exam where session_id = p_session_id;
  select id into v_att from app.session_attendance
   where session_id = p_session_id and student_id = p_student_id and is_active and teacher_status_code in ('CO_MAT', 'DI_MUON');
  if v_att is null then
    perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ sửa điểm của em có mặt trong buổi.');
  end if;
  v_r := app.exam_resolve_scores(ex, p_entry);
  insert into app.exam_score (attendance_id, session_id, branch_id, total_score, memory_score, understand_score, apply_score, graded,
                              correction_reason_code, correction_note)
  values (v_att, p_session_id, s.branch_id, v_r[1], v_r[2], v_r[3], v_r[4], true, p_reason_code, nullif(btrim(p_note), '')) -- allow-number: số mức gợi ý cố định 1 đến 4 (R-V2-39)
  on conflict (attendance_id) do update set total_score = excluded.total_score, memory_score = excluded.memory_score,
         understand_score = excluded.understand_score, apply_score = excluded.apply_score, graded = true,
         correction_reason_code = excluded.correction_reason_code, correction_note = excluded.correction_note;
end;
$$;

-- session_overview: bản mới nhất ở 20261115000135_dau_dung_han_tre_han.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.session_overview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_total integer;
  v_marked integer;
  v_homework text;
  v_lines jsonb;
  v_scored integer;
  v_exam jsonb;
  v_present integer;
  v_graded integer;
  v_missing jsonb;
  v_hw jsonb;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  select count(*), count(teacher_status_code) into v_total, v_marked
    from app.session_attendance where session_id = s.id and is_active;
  select coalesce(jsonb_agg(l.line_text order by l.sort_order), '[]'::jsonb) into v_lines
    from app.session_content_line l where l.session_id = s.id and l.is_active;
  select homework_text into v_homework from app.session_content where session_id = s.id;
  -- Buổi Kiểm tra: phạm vi kiến thức, điểm tối đa, cách nhập điểm do vận hành đặt (set_exam_config); giáo viên chỉ xem. Chưa đặt thì null.
  select jsonb_build_object('scope_text', e.scope_text, 'max_score', e.max_score, 'entry_mode', e.entry_mode,
                            'max_memory', e.max_memory, 'max_understand', e.max_understand, 'max_apply', e.max_apply)
    into v_exam from app.session_exam e where e.session_id = s.id;
  -- Số ô nhận xét đã chấm: màn GV-06 báo "sửa nội dung sau khi đã chấm" (điểm 9 tiêu chí không đổi khi sửa dòng nội dung, Q-245).
  select count(*) into v_scored from app.session_review_score where session_id = s.id and state <> 'CHUA_DANH_GIA';
  -- Bước chấm của GV-04 (R-GV-04, R-V2-20): em có mặt (Có mặt, Đi muộn) đã chấm đủ. Buổi thường: mọi tiêu chí đang bật đều có điểm hoặc trạng thái khác "Chưa đánh giá".
  -- Buổi Kiểm tra: đã chấm điểm. Kèm tên tối đa 10 em còn thiếu (giáo viên được thấy tên em trong lớp mình, R-GV-13).
  with present as (
    select sa.id, st.full_name,
           case when app.session_is_exam(s) then exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded)
                else exists (select from app.session_review_criterion rc where rc.session_id = sa.session_id and rc.enabled)
                     and not exists (select from app.session_review_criterion rc
                                      where rc.session_id = sa.session_id and rc.enabled
                                        and not exists (select from app.session_review_score sc
                                                         where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA')) end as complete
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  )
  select count(*), count(*) filter (where complete),
         coalesce((select jsonb_agg(m.full_name) from (select full_name from present where not complete order by full_name limit 10) m), '[]'::jsonb) -- allow-number: tối đa 10 tên em còn thiếu hiện trên màn
    into v_present, v_graded, v_missing from present;
  -- Bước chấm BTVN buổi trước (GV-04, GV-08, R-V2-35, R-GV-11): tiến độ do app.homework_progress tính (DAU_LOP, KHONG_GIAO: bỏ qua, không chặn).
  v_hw := app.homework_progress(s.id);
  return jsonb_build_object(
    'session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code,
    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = s.type_code),
    'class_code', c.code,
    'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'session_no', s.session_no, 'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time,
    'attendance_total', v_total, 'attendance_marked', v_marked,
    'content_lines', jsonb_array_length(v_lines), 'has_content', jsonb_array_length(v_lines) > 0,
    'lines', v_lines, 'homework_text', v_homework, 'review_scored', v_scored, 'exam', v_exam,
    'grading_present', v_present, 'grading_done', v_graded, 'grading_missing', v_missing, 'prev_homework_state', v_hw ->> 'state', 'homework_present', (v_hw ->> 'present')::integer, 'homework_done', (v_hw ->> 'done')::integer,
    'homework_missing', v_hw -> 'missing', 'prev_session_no', (v_hw ->> 'prev_session_no')::integer,
    -- Số phiên bản để chặn ghi đè (Q-243): giao diện gửi lại giá trị này khi lưu; 0 = chưa có nội dung nào.
    'content_version', coalesce((select sc.version from app.session_content sc where sc.session_id = s.id), 0),
    'deadline_at', app.session_ends_at(s.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer),
    'pending_reason', case when s.status_code = 'DONE' then null else app.session_pending_reason(s.id) end,
    -- Dấu Đúng hạn/Trễ hạn do hệ thống đóng lúc Done (R-GV-05); buổi chưa Done hoặc Done trước khi có cột thì null.
    'completion', case when s.completion_stamped_at is null then null
                       else jsonb_build_object('late', s.completion_late, 'late_hours', s.completion_late_hours, 'stamped_at', s.completion_stamped_at) end);
end;
$$;

-- save_session_content: bản mới nhất ở 20261111000109_gv06_chi_tiet_buoi.sql, đổi so sánh mã loại buổi thành app.session_is_exam.
create or replace function app.save_session_content(p_session_id uuid, p_lines text[], p_homework text default null,
                                                    p_expected_version integer default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_lines text[];
  v_homework text := nullif(btrim(coalesce(p_homework, '')), '');
  v_current integer;
  v_has_row boolean;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  -- Luật R-GV-08: buổi Done, huỷ hoặc đã bị thay thì không sửa nội dung (sửa qua ticket cho vận hành).
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nội dung buổi. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA', 'Buổi đã huỷ hoặc đã được thay bằng lịch mới nên không lưu nội dung.');
  end if;
  -- Luật R-V2-35: buổi thường cần ít nhất một dòng nội dung (bỏ dòng trống).
  -- Q-252: buổi Kiểm tra không đòi dòng nội dung (khung GV-06 kiểm tra: phạm vi kiến thức và BTVN tuỳ giáo viên); BTVN luôn tuỳ giáo viên.
  select coalesce(array_agg(btrim(t) order by o), '{}') into v_lines
    from unnest(coalesce(p_lines, '{}')) with ordinality as x (t, o) where btrim(coalesce(t, '')) <> '';
  if cardinality(v_lines) = 0 and not app.session_is_exam(s) then
    perform app.raise_error('HMT_THIEU_NOI_DUNG', 'Cần ít nhất một dòng nội dung buổi.');
  end if;
  -- Luật Q-243: khoá dòng nội dung của buổi rồi so phiên bản; hai người lưu cùng lúc thì người sau bị từ chối.
  select version into v_current from app.session_content where session_id = s.id for update;
  v_has_row := found;
  if p_expected_version is not null
     and ((v_has_row and p_expected_version is distinct from v_current) or (not v_has_row and p_expected_version <> 0)) then
    perform app.raise_error('HMT_XUNG_DOT', 'Ô này vừa được người khác sửa, tải lại để xem.');
  end if;
  insert into app.session_content (session_id, branch_id, homework_text) values (s.id, s.branch_id, v_homework)
  on conflict (session_id) do update set homework_text = excluded.homework_text, version = app.session_content.version + 1, updated_at = now(), updated_by = auth.uid();
  -- Không xoá cứng: tắt cả bộ dòng cũ rồi ghi đè theo số thứ tự (dòng nào còn thì bật lại).
  update app.session_content_line set is_active = false where session_id = s.id and is_active;
  insert into app.session_content_line (session_id, branch_id, sort_order, line_text)
  select s.id, s.branch_id, o::integer, t from unnest(v_lines) with ordinality as x (t, o)
  on conflict (session_id, sort_order) do update set line_text = excluded.line_text, is_active = true, updated_at = now(), updated_by = auth.uid();
  return cardinality(v_lines);
end;
$$;

-- approve_session_request: bản ở 20261119000303_a25_loai_kiem_tra_yeu_cau_buoi.sql; yêu cầu có loại kiểm tra (một trong ba mã) thì sinh buổi đúng loại đó.
create or replace function app.approve_session_request(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
  c app.class;
  v_session uuid;
  v_teacher uuid;
  v_assistant uuid;
begin
  select * into r from app.session_request where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'DUYET', r.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', r.branch_id);
  if r.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được yêu cầu buổi ở tình trạng Chờ duyệt.');
  end if;
  select * into c from app.class where id = r.class_id;
  if c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_LOP_CHUA_DUYET', 'Lớp không còn ở tình trạng đã duyệt nên không chèn thêm buổi được.');
  end if;
  if r.session_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    perform app.raise_error('HMT_NGAY_BUOI_QUA_KHU', 'Ngày buổi củng cố đã qua, không chèn được. Từ chối yêu cầu và tạo yêu cầu mới.');
  end if;
  if r.kind in ('BO_TRO', 'HOC_BU') then
    -- Luật R-BUOI-05, R-BUOI-03: học bổ trợ và học bù không trừ giờ học sinh; giáo viên là người được chọn (học bù không chọn thì lấy giáo viên khung giờ của lớp), vẫn tính giờ dạy; danh sách chỉ các em được chọn (build_session_roster).
    v_teacher := coalesce(r.teacher_id, (select sl.teacher_id from app.class_slot sl where sl.class_id = c.id and sl.is_active order by sl.weekday, sl.start_time limit 1));
    v_assistant := null;
  else
    select sl.teacher_id, sl.assistant_id into v_teacher, v_assistant
      from app.class_slot sl
     where sl.class_id = c.id and sl.is_active
     order by (sl.weekday = extract(isodow from r.session_date)::integer) desc, sl.weekday, sl.start_time
     limit 1;
  end if;
  insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id, type_code, status_code, is_manual, no_charge)
  values (c.id, c.branch_id, r.session_date, r.start_time, r.end_time, v_teacher, v_assistant, r.room_id,
          case when r.session_type_code is not null then r.session_type_code else case r.kind when 'BO_TRO' then 'BO_TRO' when 'HOC_BU' then 'HOC_BU' else 'CUNG_CO' end end, 'NHAP', true,
          -- Luật (Chat 19/11, R-BUOI-03, R-V2-20): kiểm tra BÙ (từ yêu cầu học bù, bổ trợ) KHÔNG trừ giờ; kiểm tra từ yêu cầu củng cố trừ giờ như buổi Chính (R-V2-18).
          (r.session_type_code is not null) and r.kind in ('BO_TRO', 'HOC_BU'))
  returning id into v_session;
  -- Loại Kiểm tra (A25): đặt cấu hình điểm đã nhập ở yêu cầu (cùng luật app.set_exam_config; người duyệt có quyền Sửa buổi ở cơ sở).
  if r.session_type_code is not null then
    perform app.set_exam_config(v_session, r.exam_scope, r.exam_max_score, r.exam_mode, r.exam_max_memory, r.exam_max_understand, r.exam_max_apply);
  end if;
  perform app.renumber_class_sessions(c.id);
  update app.session_request set status_code = 'DA_DUYET', decided_at = now(), decided_by = auth.uid(), created_session_id = v_session where id = r.id;
  return jsonb_build_object('session_id', v_session, 'warnings', app.class_clash_warnings(c.id));
end;
$$;

-- list_session_requests: bản ở 20261119000303_a25_loai_kiem_tra_yeu_cau_buoi.sql.
create or replace function app.list_session_requests(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SESSION', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array'
                          then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_can_approve text := app.permission_scope('SESSION', 'DUYET');
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null or v_scope = 'DUOC_PHAN_CONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem yêu cầu buổi.');
  end if;
  with f as (
    select r.* from app.session_request r
     where (v_scope = 'TOAN_HE_THONG' or r.branch_id = app.current_branch_id())
       and (v_status is null or r.status_code = any (v_status))
       and (v_class is null or r.class_id = v_class)
  ), page as (
    select * from f order by created_at desc, code desc limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id, 'code', p.code, 'kind', p.kind, 'status_code', p.status_code,
           'class_id', p.class_id, 'class_code', c.code,
           'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
           'student_count', case when p.kind in ('BO_TRO', 'HOC_BU') then (select count(*) from app.session_request_student rs where rs.request_id = p.id and rs.is_active)
                                 else (select count(distinct e.student_id) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                        where ec.class_id = c.id and ec.end_date is null) end,
           'student_names', case when p.kind in ('BO_TRO', 'HOC_BU') then (select coalesce(jsonb_agg(st.full_name order by st.full_name), '[]'::jsonb)
                                                               from app.session_request_student rs join app.student st on st.id = rs.student_id
                                                              where rs.request_id = p.id and rs.is_active) else '[]'::jsonb end,
           'teacher_name', app.staff_display_name(p.teacher_id),
           'session_date', p.session_date, 'start_time', p.start_time, 'end_time', p.end_time,
           'room_name', (select rm.name from app.room rm where rm.id = p.room_id),
           'note', p.note, 'reason', p.reason, 'session_type_code', p.session_type_code,
           'exam', case when p.session_type_code is not null then jsonb_build_object('scope', p.exam_scope, 'max_score', p.exam_max_score, 'mode', p.exam_mode,
                         'max_memory', p.exam_max_memory, 'max_understand', p.exam_max_understand, 'max_apply', p.exam_max_apply) end, 'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
           'reject_reason_code', p.reject_reason_code, 'reject_note', p.reject_note, 'created_session_id', p.created_session_id,
           'can_approve', p.status_code = 'CHO_DUYET' and (v_can_approve = 'TOAN_HE_THONG' or (v_can_approve = 'CO_SO' and p.branch_id = app.current_branch_id())))
           order by p.created_at desc, p.code desc), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- Yêu cầu buổi: bỏ ràng buộc cứng chỉ cho KIEM_TRA, kiểm theo app.session_type_form trong app.set_request_exam. Thêm tham số loại kiểm tra.
alter table app.session_request drop constraint session_request_session_type_code_check;
drop function app.set_request_exam(uuid, boolean, text, numeric, text, numeric, numeric, numeric);
create or replace function app.set_request_exam(p_request_id uuid, p_enabled boolean, p_scope text default null, p_max_score numeric default null, p_mode text default null,
                                                p_max_memory numeric default 0, p_max_understand numeric default 0, p_max_apply numeric default 0,
                                                p_type_code text default 'KIEM_TRA')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.session_request;
  v_max numeric;
begin
  select * into r from app.session_request where id = p_request_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy yêu cầu buổi.');
  end if;
  perform app.assert_can('SESSION', 'TAO', r.branch_id);
  perform app.require_feature('YEU_CAU_BUOI', r.branch_id);
  -- Luật: chỉ sửa khi yêu cầu còn Nháp.
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ đặt loại buổi cho yêu cầu đang ở tình trạng Nháp.');
  end if;
  if not coalesce(p_enabled, false) then
    update app.session_request set session_type_code = null, exam_scope = null, exam_max_score = null, exam_mode = null,
           exam_max_memory = 0, exam_max_understand = 0, exam_max_apply = 0 where id = r.id;
    return;
  end if;
  -- Luật A25: loại buổi của yêu cầu phải là loại dùng form điểm (Kiểm tra, giữa kỳ, cuối kỳ), tra ở app.session_type_form.
  if not exists (select from app.session_type_form f where f.type_code = p_type_code and f.form_code = 'DIEM') then
    perform app.raise_error('HMT_LOAI_BUOI_SAI', 'Loại buổi này không phải loại kiểm tra.');
  end if;
  if p_mode is null or p_mode not in ('TONG', 'NHOM') then
    perform app.raise_error('HMT_CACH_NHAP_DIEM_SAI', 'Cách nhập điểm là Điểm tổng hoặc Theo 3 nhóm.');
  end if;
  v_max := coalesce(p_max_score, app.get_setting_int('exam_default_max_score', r.branch_id));
  if v_max <= 0 then
    perform app.raise_error('HMT_DIEM_TOI_DA_SAI', 'Điểm tối đa phải lớn hơn 0.');
  end if;
  -- Luật R-V2-20: theo 3 nhóm thì tổng tối đa 3 nhóm bằng điểm tối đa của buổi.
  if p_mode = 'NHOM' and coalesce(p_max_memory, 0) + coalesce(p_max_understand, 0) + coalesce(p_max_apply, 0) <> v_max then
    perform app.raise_error('HMT_DIEM_NHOM_KHONG_KHOP', 'Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi.');
  end if;
  update app.session_request set session_type_code = p_type_code, exam_scope = nullif(btrim(coalesce(p_scope, '')), ''), exam_max_score = v_max, exam_mode = p_mode,
         exam_max_memory = case when p_mode = 'NHOM' then coalesce(p_max_memory, 0) else 0 end,
         exam_max_understand = case when p_mode = 'NHOM' then coalesce(p_max_understand, 0) else 0 end,
         exam_max_apply = case when p_mode = 'NHOM' then coalesce(p_max_apply, 0) else 0 end
   where id = r.id;
end;
$$;
revoke execute on function app.set_request_exam(uuid, boolean, text, numeric, text, numeric, numeric, numeric, text) from public, anon, authenticated;
grant execute on function app.set_request_exam(uuid, boolean, text, numeric, text, numeric, numeric, numeric, text) to authenticated;
