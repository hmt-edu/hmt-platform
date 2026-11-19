-- Dữ liệu GIẢ cho bản THỬ NGHIỆM (staging) để anh Trường kiểm tay các màn: Lead, Cơ hội, Đơn, Phiếu thu, Khoản tiền vào, Công nợ, Lớp, Buổi, Ghi danh, Tái tục, Ticket, Phiếu nghiệp vụ.
-- Tạo bằng HÀM NGHIỆP VỤ với claims giả của tài khoản seed-users (đi đúng luật, cấp mã, nhật ký), trải CS1 và CS5. Tên ghép giả, SĐT 0996xxxxxx giả. KHÔNG DỮ LIỆU THẬT.
-- Cần: DB đã dựng (db:reset hoặc migration) VÀ tài khoản giả (npm run db:seed-users). KHÔNG chạy ở bản chạy thật.
-- Chạy lại KHÔNG nhân đôi: đã có phụ huynh SĐT 0996000001 thì thoát ngay. Chạy local: npm run db:seed-staging. Cuối file có câu đếm số dòng mỗi bảng.
\set ON_ERROR_STOP on
select exists (select from app.parent where phone = '0996000001') as seeded \gset
\if :seeded
\echo 'seed-staging: đã có dữ liệu (SĐT 0996000001), bỏ qua.'
\quit
\endif

begin;
do $$ begin
  if (select count(*) from app.user_account where login_name like '%@thu.hoamatoan.invalid') < 10 then
    raise exception 'Chưa có tài khoản giả: chạy npm run db:seed-users trước.';
  end if;
end $$;

-- Đặt claims giả của một tài khoản seed (aal2 cho Admin, Kế toán vì cần hai bước).
create function pg_temp.claims(p_login text, p_aal text default 'aal1') returns void language plpgsql security definer as $$
declare v_id uuid; v_result jsonb;
begin
  select id into v_id from app.user_account where login_name = p_login || '@thu.hoamatoan.invalid';
  if v_id is null then raise exception 'Không có tài khoản giả %: chạy npm run db:seed-users trước.', p_login; end if;
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', v_id, 'claims', jsonb_build_object('sub', v_id, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
grant execute on function pg_temp.claims(text, text) to public;

-- Cờ phân hệ bật cho CS1 và CS5 (bản thử nghiệm kiểm đủ màn).
insert into app.feature_flag (module_code, branch_id, enabled)
select m, b.id, true from app.branch b, unnest(array['BAN_HANG', 'VAN_HANH_LOP', 'AFTERSALE', 'BAO_CAO', 'HOAN_PHI', 'SAP_HET_GIO', 'DIEM_DANH_TRONG_NGAY']) m
 where b.code in ('CS1', 'CS5')
on conflict (module_code, branch_id) do update set enabled = true;

-- ===== 1. Lead, cơ hội, đơn hàng (Sale lập; quản lý duyệt). 30 phụ huynh mỗi cơ sở. =====
create temp table sd_opp (n int, branch text, opp_id uuid, ps_id uuid, order_id uuid);
grant all on sd_opp to public;
create temp table sd_names as
select * from (values (1, 'Nguyễn Minh Anh'), (2, 'Trần Gia Bảo'), (3, 'Lê Thu Cúc'), (4, 'Phạm Quốc Dũng'), (5, 'Hoàng Mai Linh'), (6, 'Vũ Đức Hải'),
  (7, 'Đặng Khánh Vy'), (8, 'Bùi Thanh Tùng'), (9, 'Đỗ Bảo Châu'), (10, 'Hồ Anh Khoa'), (11, 'Ngô Thu Trang'), (12, 'Dương Hải Yến')) t(n, nm);
grant select on sd_names to public;

do $$
declare
  v_branch text; v_sale text; v_n int; v_phone text; v_lead uuid; v_opp jsonb; v_pkg uuid; v_ps uuid; v_ord jsonb; v_idx int := 0; v_nm text;
begin
  select id into v_pkg from app.sales_package where code = 'LC-TOAN-K09';
  if v_pkg is null then raise exception 'Không có gói LC-TOAN-K09 (seed.sql).'; end if;
  foreach v_branch in array array['CS1', 'CS5'] loop
    v_sale := 'sale.' || lower(v_branch);
    perform pg_temp.claims(v_sale);
    set local role authenticated;
    for v_n in 1..30 loop
      v_idx := v_idx + 1;
      v_phone := '0996' || lpad((case when v_branch = 'CS1' then v_n else 100 + v_n end)::text, 6, '0');
      select nm into v_nm from sd_names where n = 1 + (v_n - 1) % 12;
      v_lead := (app.create_lead(jsonb_build_object('parent_name', 'Chị ' || v_nm || ' (giả)', 'parent_phone', v_phone,
                 'student_name', 'Em ' || split_part(v_nm, ' ', 3) || ' ' || v_n, 'student_birth_year', 2010 + (v_n % 5),
                 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS', 'channel_code', 'FACEBOOK_ADS_LEAD_FORM')) ->> 'id')::uuid;
      -- 20 lead đầu mỗi cơ sở lên C4C và có cơ hội; 10 lead còn lại để ở C1 (danh sách lead đủ trạng thái).
      if v_n <= 20 then
        perform app.change_lead_stage(v_lead, 'C4', 'C4C');
        v_opp := app.create_opportunity(v_lead);
        select id into v_ps from app.prospect_student where opportunity_id = (v_opp ->> 'id')::uuid and position = 1;
        insert into sd_opp (n, branch, opp_id, ps_id) values (v_n, v_branch, (v_opp ->> 'id')::uuid, v_ps);
      end if;
    end loop;
    reset role;
  end loop;
end $$;

-- ===== 2. Đơn hàng: 12 cơ hội đầu mỗi cơ sở lên L8 có đơn; đơn 1-8 Đã duyệt, 9-11 Đã trình, 12 Nháp (cơ hội tới L8 là bước bán hàng, đặt thẳng vì chưa có luồng tự động). =====
reset role;
update app.opportunity o set stage_code = 'L8', substage_code = 'L8A' from sd_opp s where s.opp_id = o.id and s.n <= 12;

do $$
declare
  r record; v_ord jsonb; v_term uuid; v_hours int;
begin
  select id into v_term from app.payment_term where code = 'CHIA_3_DOT' and version = 1;
  for r in select * from sd_opp where n <= 12 order by branch, n loop
    perform pg_temp.claims('sale.' || lower(r.branch));
    set local role authenticated;
    v_hours := 6 + r.n * 2;
    v_ord := app.create_order_from_opportunity(r.opp_id,
      jsonb_build_array(jsonb_build_object('kind', 'ENROL', 'prospect_student_id', r.ps_id,
        'package_id', (select id from app.sales_package where code = 'LC-TOAN-K09'), 'delivery_mode_code', 'OFF', 'quantity', v_hours, 'discounts', '[]'::jsonb)),
      null, true);
    update sd_opp set order_id = (v_ord ->> 'id')::uuid where opp_id = r.opp_id;
    perform app.save_order((v_ord ->> 'id')::uuid, null, v_term);
    if r.n <= 11 then perform app.submit_order((v_ord ->> 'id')::uuid, false); end if;
    reset role;
  end loop;
  -- Trưởng cơ sở duyệt các đơn 1-4.
  for r in select * from sd_opp where n <= 8 order by branch, n loop
    perform pg_temp.claims('truongcs.' || lower(r.branch));
    set local role authenticated;
    perform app.approve_order(r.order_id, false);
    reset role;
  end loop;
end $$;
select count(*) as sd_orders, count(*) filter (where status_code = 'DA_DUYET') as duyet, count(*) filter (where status_code = 'DA_TRINH') as trinh from app.sales_order where id in (select order_id from sd_opp);

-- ===== 2b. Báo giá: cơ hội 13-20 mỗi cơ sở có báo giá (13-16 Nháp, 17-20 Đã gửi). =====
do $$
declare
  r record; v_q jsonb;
begin
  for r in select * from sd_opp where n between 13 and 20 order by branch, n loop
    perform pg_temp.claims('sale.' || lower(r.branch));
    set local role authenticated;
    v_q := app.save_quotation(null, r.opp_id, jsonb_build_array(jsonb_build_object('kind', 'ENROL', 'prospect_student_id', r.ps_id,
      'package_id', (select id from app.sales_package where code = 'LC-TOAN-K09'), 'delivery_mode_code', 'OFF', 'quantity', 8 + r.n, 'discounts', '[]'::jsonb)));
    if r.n >= 17 then perform app.send_quotation((v_q ->> 'id')::uuid); end if;
    reset role;
  end loop;
end $$;
select count(*) as sd_baogia from app.quotation where opportunity_id in (select opp_id from sd_opp);

-- ===== 3. Phiếu thu: đơn 1-8 mỗi cơ sở thu tiền, qua hai bước duyệt (quản lý, kế toán) thành Khoản tiền vào + Ghi danh (Chờ xếp lớp);
-- đơn 4 có phiếu thu Nháp, đơn 3 CS5 có phiếu thu chờ quản lý (đủ trạng thái cho màn Phiếu thu, Chờ kế toán duyệt). =====
create temp table sd_rc (order_id uuid, branch text, n int, receipt_id uuid);
grant all on sd_rc to public;
do $$
declare
  r record; v_rc jsonb; v_amount bigint;
begin
  for r in select * from sd_opp where n <= 8 order by branch, n loop
    perform pg_temp.claims('sale.' || lower(r.branch));
    set local role authenticated;
    select least(total_amount, 2000000) into v_amount from app.sales_order where id = r.order_id; -- allow-number: số tiền thu mẫu của dữ liệu giả (đủ cọc tối thiểu)
    v_rc := app.create_receipt(r.order_id, jsonb_build_object('amount', v_amount, 'payment_method_code', 'CHUYEN_KHOAN',
              'paid_on', current_date, 'txn_ref', 'GD-GIA-' || r.branch || '-' || r.n));
    insert into sd_rc values (r.order_id, r.branch, r.n, (v_rc ->> 'id')::uuid);
    if r.n <= 7 then perform app.submit_receipt((v_rc ->> 'id')::uuid); end if;
    reset role;
  end loop;
  for r in select * from sd_rc where n <= 7 order by branch, n loop
    perform pg_temp.claims('truongcs.' || lower(r.branch));
    set local role authenticated;
    perform app.approve_receipt_manager(r.receipt_id);
    reset role;
  end loop;
  for r in select * from sd_rc where n <= 6 order by branch, n loop
    perform pg_temp.claims(case when r.branch = 'CS1' then 'ketoan' else 'ketoan.cs5' end, 'aal2');
    set local role authenticated;
    perform app.approve_receipt_accounting(r.receipt_id);
    reset role;
  end loop;
end $$;
select r.status_code, count(*) from app.receipt r where r.id in (select receipt_id from sd_rc) group by 1 order by 1;
select (select count(*) from app.enrollment) as enroll_all, (select count(*) from app.money_in) as money_in, (select count(*) from app.hour_ledger) as ledger;

-- ===== 4. Lớp, buổi, ghi danh, học sinh đang học. CS5: 3 lớp (có buổi hôm nay cho gv.cs5); CS1: 2 lớp. Trưởng cơ sở tạo và duyệt; tám học sinh đang học mỗi cơ sở (ghi danh có giờ đầu kỳ). =====
create temp table sd_cl (code text, branch text, id uuid);
grant all on sd_cl to public;
do $$
declare
  r record; v_id uuid; v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date; v_teacher uuid;
begin
  for r in select * from (values
      ('CS5', 'TOAN', 'K08', 0, 'gv.cs5'), ('CS5', 'TOAN', 'K09', 1, 'gv2.cs5'), ('CS5', 'ANH', 'K07', 2, 'gv.cs5'),
      ('CS1', 'TOAN', 'K08', 0, null), ('CS1', 'ANH', 'K09', 1, null)) v(branch, subject, grade, plus_days, teacher) loop
    perform pg_temp.claims('truongcs.' || lower(r.branch));
    set local role authenticated;
    select id into v_teacher from app.user_account where login_name = r.teacher || '@thu.hoamatoan.invalid';
    v_id := (app.create_class(jsonb_build_object(
      'branch_id', (select id from app.branch where code = r.branch), 'year_code', '2627', 'subject_code', r.subject, 'grade_code', r.grade,
      'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', v_today + r.plus_days, 'total_sessions', 8,
      'slots', jsonb_build_array(jsonb_build_object('weekday', extract(isodow from (v_today + r.plus_days))::int, 'start_time', '18:00', 'end_time', '19:30',
        'repeat_weeks', 1, 'first_date', v_today + r.plus_days, 'teacher_id', v_teacher)))) ->> 'id')::uuid;
    perform app.transition_class(v_id, 'DA_TRINH');
    perform app.transition_class(v_id, 'DA_XAC_NHAN');
    perform app.transition_class(v_id, 'DA_DUYET');
    insert into sd_cl select code, r.branch, id from app.class where id = v_id;
    reset role;
  end loop;
end $$;

-- Tám học sinh đang học mỗi cơ sở: phụ huynh, học sinh, ghi danh có 20 giờ đầu kỳ (lùi ngày tạo để vào danh sách buổi, R-GIO-02), xếp vào lớp đầu của cơ sở.
create temp table sd_en (id uuid, branch text);
grant all on sd_en to public;
do $$
declare
  b text; v_i int; v_p uuid; v_s uuid; v_e uuid; v_nm text; v_br uuid;
begin
  foreach b in array array['CS1', 'CS5'] loop
    select id into v_br from app.branch where code = b;
    for v_i in 1..8 loop
      select sn.nm into v_nm from sd_names sn where sn.n = v_i;
      insert into app.parent (code, full_name, phone, branch_id)
      values ('PHST' || b || v_i, 'Phụ huynh ' || v_nm || ' (giả)', '0995' || lpad((case when b = 'CS1' then v_i else 100 + v_i end)::text, 6, '0'), v_br) returning id into v_p;
      insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade)
      values ('HSST' || b || v_i, v_p, 'Em ' || split_part(v_nm, ' ', 3) || ' ' || v_i, 2010 + (v_i % 5), v_br, 8) returning id into v_s;
      insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
      values ('GDST' || b || v_i, v_s, v_p, v_br, 'TOAN') returning id into v_e;
      alter table app.enrollment disable trigger enrollment_fill_standard;
      update app.enrollment set created_at = now() - interval '60 days' where id = v_e;
      alter table app.enrollment enable trigger enrollment_fill_standard;
      perform app.add_opening_hours(v_e, 20, 'DOT-ST');
      insert into sd_en values (v_e, b);
    end loop;
  end loop;
end $$;
do $$
declare
  r record; v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date; v_cls uuid;
begin
  for r in select * from sd_en loop
    perform pg_temp.claims('cskh.' || lower(r.branch));
    set local role authenticated;
    select id into v_cls from sd_cl where branch = r.branch order by code limit 1;
    perform app.assign_enrollment_class(r.id, v_cls, (select min(session_date) from app.class_session where class_id = v_cls and status_code not in ('HUY_KHONG_PHI', 'DA_THAY')));
    reset role;
  end loop;
  -- Chốt danh sách buổi đầu của các lớp (có buổi hôm nay cho gv.cs5).
  for r in select * from sd_cl loop
    perform pg_temp.claims('cskh.' || lower(r.branch));
    set local role authenticated;
    perform app.close_session((select s.id from app.class_session s where s.class_id = r.id and s.session_no = 1 and s.status_code not in ('HUY_KHONG_PHI', 'DA_THAY')));
    reset role;
  end loop;
end $$;
select (select count(*) from app.class where id in (select id from sd_cl)) as lop, (select count(*) from app.class_session s where s.class_id in (select id from sd_cl)) as buoi,
       (select count(*) from app.enrollment where code like 'GDST%' and status_code <> 'CHO_XEP_LOP') as ghi_danh_da_xep;

-- ===== 5. Ticket (đề nghị DN, khiếu nại KN) mỗi cơ sở; phiếu nghiệp vụ (cập nhật hồ sơ) nháp và đã trình; phiếu tái tục từ ghi danh. =====
create temp table sd_tk (id uuid, branch text, n int);
grant all on sd_tk to public;
do $$
declare
  b text; v_i int; v_t jsonb; v_cat text; v_type text; v_tk jsonb;
begin
  foreach b in array array['CS1', 'CS5'] loop
    perform pg_temp.claims('cskh.' || lower(b));
    set local role authenticated;
    for v_i in 1..8 loop
      v_type := case when v_i % 4 = 0 then 'KN' else 'DN' end;
      v_cat := case when v_type = 'KN' then 'KN_01_01' else (array['DN_01_01', 'DN_01_02', 'DN_02_01', 'DN_04_01'])[1 + v_i % 4] end;
      v_t := app.create_ticket(jsonb_build_object('ticket_type', v_type, 'branch_id', (select id from app.branch where code = b),
               'title', 'Ticket giả ' || b || ' số ' || v_i, 'description', 'Mô tả giả của dữ liệu thử nghiệm', 'channel_code', (array['GOI_DIEN', 'ZALO', 'TRUC_TIEP', 'EMAIL'])[1 + v_i % 4],
               'category_code', v_cat, 'priority_code', (array['THUONG', 'CAO', 'KHAN', 'THAP'])[1 + v_i % 4],
               'parent_id', (select id from app.parent where code = 'PHST' || b || v_i), 'student_id', (select id from app.student where code = 'HSST' || b || v_i)));
      insert into sd_tk values ((v_t ->> 'id')::uuid, b, v_i);
    end loop;
    reset role;
  end loop;
  -- Phiếu nghiệp vụ «Cập nhật hồ sơ»: ticket số 3 (nhóm con DN_04_01): nháp; số 7: đã trình (chờ duyệt).
  for b in select unnest(array['CS1', 'CS5']) loop
    perform pg_temp.claims('cskh.' || lower(b));
    set local role authenticated;
    v_tk := app.create_ticket_task((select id from sd_tk where branch = b and n = 3), 'CAP_NHAT_HO_SO', 'Phụ huynh báo đổi trường', '{"entity":"STUDENT","changes":{"school":"Trường giả A"}}'::jsonb);
    v_tk := app.create_ticket_task((select id from sd_tk where branch = b and n = 7), 'CAP_NHAT_HO_SO', 'Phụ huynh báo đổi trường', '{"entity":"STUDENT","changes":{"school":"Trường giả B"}}'::jsonb);
    perform app.submit_ticket_task((v_tk ->> 'id')::uuid);
    reset role;
  end loop;
  -- Phiếu tái tục từ ghi danh (hai em mỗi cơ sở).
  for b in select unnest(array['CS1', 'CS5']) loop
    perform pg_temp.claims('cskh.' || lower(b));
    set local role authenticated;
    for v_i in 1..2 loop
      perform app.create_upsale_ticket_from_enrollment('GDST' || b || v_i, 'Tạo thủ công cho dữ liệu thử nghiệm');
    end loop;
    reset role;
  end loop;
end $$;

-- Đếm số dòng mỗi bảng (do dữ liệu giả sinh ra).
select 'lead' as bang, count(*) from app.lead where parent_phone like '0996%' or parent_phone like '0995%'
union all select 'opportunity', count(*) from app.opportunity where lead_id in (select id from app.lead where parent_phone like '0996%')
union all select 'sales_order', count(*) from app.sales_order where id in (select order_id from sd_opp)
union all select 'receipt', count(*) from app.receipt where id in (select receipt_id from sd_rc)
union all select 'money_in', count(*) from app.money_in
union all select 'class', count(*) from app.class where id in (select id from sd_cl)
union all select 'class_session', count(*) from app.class_session where class_id in (select id from sd_cl)
union all select 'enrollment', count(*) from app.enrollment where parent_id in (select id from app.parent where phone like '099%')
union all select 'ticket', count(*) from app.ticket where title like 'Ticket giả%'
union all select 'ticket_task', count(*) from app.ticket_task
union all select 'upsale_ticket', count(*) from app.upsale_ticket;
commit;
