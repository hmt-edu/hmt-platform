-- KH-08 chặn «Lên khối đầu năm» lần hai trong cùng năm học (Code F, 23/11/2026; thẻ F-23-26, F-23-27; anh Trường chốt (a) 17:56, Chat chốt cách định nghĩa 18:25).
-- Luật: em đã được lên khối (hoặc tốt nghiệp) trong NĂM HỌC NÀY thì các lần chạy sau bỏ qua em đó (theo cơ sở hay mọi cơ sở đều vậy).
-- «Năm học này» = từ ngày 1 của tháng school_year_start_month (mặc định 6, Admin chỉnh ở Cài đặt, ghi đè theo cơ sở được) gần nhất tính đến hôm nay (giờ Việt Nam).
-- «Đã lên khối» = có dòng đợt chưa hoàn tác của một đợt DA_CHAY tạo từ ngày đó. Hoàn tác đợt (7 ngày) thì em chạy lại được.
-- Đây là định nghĩa «năm học» tạm theo tham số; anh Trường đổi tháng ở Cài đặt khi cần.
-- Làm gì: tham số school_year_start_month; hàm app.school_year_start, app.grade_promotion_done_this_year; viết lại app.grade_promotion_candidates,
-- app.preview_grade_promotion (thêm skipped.da_len_khoi_nam_nay, last_run_at), app.run_grade_promotion (lỗi HMT_DA_LEN_KHOI_NAM_NAY).
select set_config('hmt.migration', 'on', false);

insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('school_year_start_month', 'Tháng bắt đầu năm học (cho việc lên khối)', 'INT', 'tháng', 1, 12, '6', true, 'ADMIN', null,
        'Năm học tính từ ngày 1 của tháng này. Em đã được «Lên khối đầu năm» trong năm học hiện tại thì các lần chạy sau bỏ qua em đó (KH-08).');

-- Ngày đầu của năm học hiện tại theo cơ sở (giờ Việt Nam): ngày 1 của tháng bắt đầu gần nhất, không sau hôm nay.
create or replace function app.school_year_start(p_branch uuid default null)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select case when make_date(extract(year from t.today)::int, m.month, 1) > t.today
              then make_date(extract(year from t.today)::int - 1, m.month, 1)
              else make_date(extract(year from t.today)::int, m.month, 1) end
    from (select (now() at time zone 'Asia/Ho_Chi_Minh')::date as today) t,
         (select app.get_setting_int('school_year_start_month', p_branch)::int as month) m;
$$;
revoke execute on function app.school_year_start(uuid) from public, anon, authenticated;

-- Các em đã lên khối (hoặc tốt nghiệp) trong năm học này, kèm lúc đợt chạy gần nhất. Dùng chung xem trước và chạy.
create or replace function app.grade_promotion_done_this_year(p_branch uuid)
returns table (student_id uuid, ran_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  with y as materialized (select b.id as branch_id, app.school_year_start(b.id) as start_on from app.branch b)
  select i.student_id, max(bt.created_at)
    from app.grade_promotion_item i
    join app.grade_promotion_batch bt on bt.id = i.batch_id
    join app.student s on s.id = i.student_id
    join y on y.branch_id = s.branch_id
   where bt.status_code = 'DA_CHAY' and not i.undone
     and (bt.created_at at time zone 'Asia/Ho_Chi_Minh')::date >= y.start_on
     and (p_branch is null or s.branch_id = p_branch)
   group by i.student_id;
$$;
revoke execute on function app.grade_promotion_done_this_year(uuid) from public, anon, authenticated;

-- Các em đủ điều kiện (luật 2) và CHƯA lên khối trong năm học này (luật chặn lần hai).
create or replace function app.grade_promotion_candidates(p_branch uuid)
returns table (student_id uuid, old_grade smallint, new_grade smallint)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.grade,
         case when s.grade >= 12 then null else (s.grade + 1)::smallint end -- allow-number: khối cuối cấp là lớp 12 (R-V2-31); lớp 12 tốt nghiệp
    from app.student s
   where s.grade is not null
     and s.graduated_on is null
     and (p_branch is null or s.branch_id = p_branch)
     and exists (select from app.enrollment e where e.student_id = s.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC'))
     -- Chặn lần hai: em đã lên khối trong năm học này thì bỏ qua.
     and not exists (select from app.grade_promotion_done_this_year(p_branch) d where d.student_id = s.id);
$$;
revoke execute on function app.grade_promotion_candidates(uuid) from public, anon, authenticated;

-- Xem trước: như bản 566, thêm skipped.da_len_khoi_nam_nay (em đủ điều kiện nhưng đã lên khối năm học này) và last_run_at (lần chạy gần nhất của những em đó).
create or replace function app.preview_grade_promotion(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_result jsonb;
begin
  perform app.assert_account_admin(); -- Luật 1: chỉ Admin.
  with c as materialized (select * from app.grade_promotion_candidates(v_branch)),
  d as materialized (select * from app.grade_promotion_done_this_year(v_branch)),
  scoped as (select s.id, s.grade, s.graduated_on, (c.student_id is not null) as eligible, (d.student_id is not null) as done_year,
                    exists (select from app.enrollment e where e.student_id = s.id) as has_enrollment,
                    exists (select from app.enrollment e where e.student_id = s.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')) as studying
               from app.student s left join c on c.student_id = s.id left join d on d.student_id = s.id
              where v_branch is null or s.branch_id = v_branch),
  page as (
    select s.id, s.code, s.full_name, s.branch_id, c.old_grade, c.new_grade
      from c join app.student s on s.id = c.student_id
     where v_q is null or s.search_text like '%' || v_q || '%'
     order by s.code, s.id limit v_limit offset v_offset)
  select jsonb_build_object(
           'eligible', (select count(*) from c),
           'graduating', (select count(*) from c where c.new_grade is null),
           'skipped', jsonb_build_object(
             'da_tot_nghiep', (select count(*) from scoped where graduated_on is not null and not done_year),
             'chua_co_khoi', (select count(*) from scoped where grade is null and graduated_on is null),
             'khong_dang_hoc', (select count(*) from scoped where grade is not null and graduated_on is null and not eligible and has_enrollment and not studying),
             'tiem_nang', (select count(*) from scoped where grade is not null and graduated_on is null and not eligible and not has_enrollment),
             'da_len_khoi_nam_nay', (select count(*) from scoped where done_year)),
           'last_run_at', (select max(ran_at) from d),
           'total', (select count(*) from c join app.student s on s.id = c.student_id where v_q is null or s.search_text like '%' || v_q || '%'),
           'rows', coalesce((select jsonb_agg(jsonb_build_object('student_id', p.id, 'code', p.code, 'full_name', p.full_name, 'branch_code', b.code,
                                                              'old_grade', p.old_grade, 'new_grade', p.new_grade) order by p.code, p.id)
                               from page p join app.branch b on b.id = p.branch_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- Chạy đợt: như bản 566. Khi không còn em nào mà có em đã lên khối năm học này thì báo HMT_DA_LEN_KHOI_NAM_NAY kèm ngày chạy lần trước.
create or replace function app.run_grade_promotion(p_filters jsonb default '{}'::jsonb, p_excluded uuid[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_excluded uuid[] := coalesce(p_excluded, '{}');
  v_batch uuid;
  v_promoted integer;
  v_graduated integer;
  v_excluded_n integer;
  v_done integer;
  v_last timestamptz;
begin
  perform app.assert_account_admin(); -- Luật 1: chỉ Admin.
  select count(*) into v_excluded_n from app.grade_promotion_candidates(v_branch) c where c.student_id = any (v_excluded);
  select count(*) filter (where c.new_grade is not null), count(*) filter (where c.new_grade is null) into v_promoted, v_graduated
    from app.grade_promotion_candidates(v_branch) c where not (c.student_id = any (v_excluded));
  if v_promoted + v_graduated = 0 then
    -- Chặn lần hai trong năm học: nêu rõ lý do và ngày chạy lần trước (R-KH-08).
    select count(*), max(d.ran_at) into v_done, v_last from app.grade_promotion_done_this_year(v_branch) d;
    if v_done > 0 then
      perform app.raise_error('HMT_DA_LEN_KHOI_NAM_NAY',
        format('Các em đã được lên khối trong năm học này (lần chạy gần nhất %s), không lên thêm. Muốn chạy lại phải hoàn tác đợt trước.',
               to_char(v_last at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY')));
    end if;
    perform app.raise_error('HMT_KHONG_CO_EM_LEN_KHOI', 'Không có em nào đủ điều kiện lên khối (đang học, đã có khối, chưa tốt nghiệp).');
  end if;

  insert into app.grade_promotion_batch (branch_id, promoted_count, graduated_count, excluded_count)
  values (v_branch, v_promoted, v_graduated, v_excluded_n) returning id into v_batch;
  insert into app.grade_promotion_item (batch_id, student_id, old_grade, new_grade)
  select v_batch, c.student_id, c.old_grade, c.new_grade from app.grade_promotion_candidates(v_branch) c where not (c.student_id = any (v_excluded));
  -- Luật 3: tăng một khối; lớp 12 ghi ngày tốt nghiệp (theo giờ Việt Nam), giữ khối.
  update app.student s set grade = coalesce(i.new_grade, s.grade),
                           graduated_on = case when i.new_grade is null then (now() at time zone 'Asia/Ho_Chi_Minh')::date else s.graduated_on end
    from app.grade_promotion_item i where i.batch_id = v_batch and s.id = i.student_id;
  return jsonb_build_object('batch_id', v_batch, 'promoted', v_promoted, 'graduated', v_graduated, 'excluded', v_excluded_n);
end;
$$;

revoke execute on function app.preview_grade_promotion(jsonb, integer, integer), app.run_grade_promotion(jsonb, uuid[]) from public, anon;
grant execute on function app.preview_grade_promotion(jsonb, integer, integer), app.run_grade_promotion(jsonb, uuid[]) to authenticated;
