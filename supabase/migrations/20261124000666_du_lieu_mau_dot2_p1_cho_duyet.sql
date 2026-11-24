-- Dữ liệu mẫu staging, ĐỢT 2 phần P1: dữ liệu «chờ xử lý» để tập luồng P1 (Code E, 24/11/2026; thẻ E-23-39 phần 2, E-23-43). CAO: đụng dữ liệu đào tạo và tiền (chỉ ở staging).
-- Làm gì: app.demo_make_p1 thêm vào mỗi bộ mẫu: (1) một phiếu kiểm tra đầu vào Nháp cho cơ hội đã ở L8; (2) phiếu thu thiếu một phần được GỬI (chờ duyệt);
--   (3) hai ghi danh Chờ xếp lớp thêm (không lớp); (4) một yêu cầu bảo lưu Chờ duyệt; (5) một yêu cầu hoàn phí Chờ quản lý; (6) một nhận xét buổi Done chưa gửi phụ huynh.
--   Cơ hội L8, đơn, phiếu thu Nháp, ghi danh chờ xếp lớp từ duyệt đơn đã có từ migration 656. Mục 7: nâng hạn mức mặc định 3 bộ/người, 10 bộ/cơ sở để tập theo cặp (tham số, không viết cứng).
-- Cách làm: hàm thật cho phiếu kiểm tra (create_student_test), phiếu thu (submit_receipt), bảo lưu (create_enrollment_hold, submit_enrollment_hold); dùng lại nhánh bỏ qua kiểm quyền của 656
--   (cờ hmt.demo_sales + app.demo_data_is_allowed()). Hoàn phí chèn trực tiếp (compute_refund đòi tiền đã phân bổ từ phiếu thu được Kế toán duyệt, bộ mẫu không có), số liệu minh hoạ ghi «[MẪU]».
--   Nhận xét chờ gửi: bỏ dấu «đã gửi phụ huynh» của MỘT nhận xét ở buổi Done.
-- Mỗi mục chạy trong khối riêng: mục nào lỗi (ví dụ công tắc phân hệ tắt, quản lý trực tiếp của người bấm thiếu quyền duyệt phiếu thu) thì bỏ qua, ghi vào demo_data_set.notice, các mục khác vẫn làm.
-- Luật an toàn: khoá STAGING + công tắc (app.assert_demo_data_allowed); chỉ gọi từ hàm tạo bộ (app.demo_assert_caller_set); không nhận dữ liệu từ người gọi; hàm con không cấp cho giao diện.
select set_config('hmt.migration', 'on', false);

-- (a) Cờ is_demo cho ba bảng mới (chỉ mục từng phần: chỉ chứa dòng mẫu, để bộ lọc «Ẩn dữ liệu mẫu» rẻ) và loại bản ghi mới.
alter table app.student_test add column is_demo boolean not null default false;
alter table app.enrollment_hold add column is_demo boolean not null default false;
alter table app.refund_request add column is_demo boolean not null default false;
create index student_test_demo_idx on app.student_test (id) where is_demo;
create index enrollment_hold_demo_idx on app.enrollment_hold (id) where is_demo;
create index refund_request_demo_idx on app.refund_request (id) where is_demo;

alter table app.demo_data_item drop constraint demo_data_item_entity_type_check;
alter table app.demo_data_item add constraint demo_data_item_entity_type_check
  check (entity_type in ('LEAD', 'OPPORTUNITY', 'QUOTATION', 'ORDER', 'RECEIPT', 'PARENT', 'STUDENT', 'CLASS', 'SESSION', 'ENROLLMENT', 'HOUR_LEDGER', 'TICKET',
                         'STUDENT_TEST', 'ENROLLMENT_HOLD', 'REFUND_REQUEST'));

-- Đánh dấu: giữ mọi loại cũ (bản 657), thêm STUDENT_TEST, ENROLLMENT_HOLD, REFUND_REQUEST.
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
    when 'STUDENT_TEST' then update app.student_test set is_demo = true where id = p_entity_id;
    when 'ENROLLMENT_HOLD' then update app.enrollment_hold set is_demo = true where id = p_entity_id;
    when 'REFUND_REQUEST' then update app.refund_request set is_demo = true where id = p_entity_id;
    else perform app.raise_error('HMT_DEMO_LOAI_SAI', 'Loại bản ghi mẫu không hợp lệ.');
  end case;
  insert into app.demo_data_item (set_id, entity_type, entity_id, created_by, updated_by)
  values (p_set_id, p_entity_type, p_entity_id, auth.uid(), auth.uid())
  on conflict (set_id, entity_type, entity_id) do nothing;
end;
$$;
revoke all on function app.demo_tag(uuid, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (b) Ghi danh Chờ xếp lớp thêm cho học sinh của bộ chưa có ghi danh (giờ mẫu ở sổ giờ is_demo, KHÔNG xếp lớp).
-- Ai gọi: chỉ app.demo_make_p1. Kết quả: số ghi danh tạo. Luật: giống app.demo_make_enrollments của 657 nhưng không gọi assign_enrollment_class.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_waiting_enrollments(p_set_id uuid, p_branch_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_hours constant numeric := 20;  -- allow-number: số giờ mẫu mỗi ghi danh (dữ liệu mẫu, không phải cấu hình nghiệp vụ)
  v_want constant integer := 2;  -- allow-number: kế hoạch dữ liệu mẫu (2 ghi danh chờ xếp lớp thêm)
  v_class app.class;
  v_student app.student;
  v_enrol uuid;
  v_ledger uuid;
  v_n integer := 0;
begin
  select c.* into v_class from app.class c
   where c.is_demo and c.status_code = 'DA_DUYET'
     and c.id in (select entity_id from app.demo_data_item where set_id = p_set_id and entity_type = 'CLASS')
   order by c.created_at limit 1;
  if v_class.id is null then
    return 0;
  end if;
  for v_student in
    select s.* from app.student s
     where s.is_demo and s.id in (select entity_id from app.demo_data_item where set_id = p_set_id and entity_type = 'STUDENT')
       and not exists (select 1 from app.enrollment e where e.student_id = s.id)
     order by s.created_at, s.code limit v_want
  loop
    insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, purchased_hours, created_by, updated_by, is_demo)
    values (app.issue_enrollment_code(), v_student.id, v_student.parent_id, p_branch_id, v_class.subject_code, v_class.delivery_mode_code, v_hours, v_user, v_user, true)
    returning id into v_enrol;
    perform app.demo_tag(p_set_id, 'ENROLLMENT', v_enrol);
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref, note, created_by, updated_by, is_demo)
    values (v_enrol, p_branch_id, 'CAP_MUA', v_hours, 'DU_LIEU_MAU', '[MẪU] Giờ mẫu, không phải giờ mua thật', v_user, v_user, true)
    returning id into v_ledger;
    perform app.demo_tag(p_set_id, 'HOUR_LEDGER', v_ledger);
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke all on function app.demo_make_waiting_enrollments(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (c) Phiếu kiểm tra đầu vào Nháp cho cơ hội đầu của bộ (cơ hội đã ở L8, qua mốc L5 của R-CRM-05). Hàm thật: create_student_test.
-- Môn, khối, hình thức, cấp độ lấy mục đang dùng đầu tiên của danh mục; giờ test = 3 ngày sau (phải ở tương lai).
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_student_test(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_opp uuid;
  v_subject text;
  v_grade text;
  v_mode text;
  v_level text;
  v_res jsonb;
begin
  select i.entity_id into v_opp
    from app.demo_data_item i join app.opportunity o on o.id = i.entity_id
   where i.set_id = p_set_id and i.entity_type = 'OPPORTUNITY' and o.is_demo
   order by o.created_at, o.code limit 1;
  if v_opp is null then
    return;
  end if;
  select c.code into v_subject from app.catalog_item c where c.catalog_code = 'SUBJECT' and c.is_active order by c.sort_order, c.code limit 1;
  select c.code into v_grade from app.catalog_item c where c.catalog_code = 'GRADE' and c.is_active order by c.sort_order, c.code limit 1;
  select c.code into v_mode from app.catalog_item c where c.catalog_code = 'TEST_MODE' and c.is_active order by c.sort_order, c.code limit 1;
  select c.code into v_level from app.catalog_item c where c.catalog_code = 'TEST_LEVEL' and c.is_active order by c.sort_order, c.code limit 1;
  v_res := app.create_student_test(v_opp, jsonb_build_object(
    'scheduled_at', (now() + interval '3 days')::text, 'subject_code', v_subject, 'grade_code', v_grade,  -- allow-number: giờ test mẫu 3 ngày sau
    'mode_code', v_mode, 'level_code', v_level, 'exam_name', '[MẪU] Đề kiểm tra đầu vào'));
  perform app.demo_tag(p_set_id, 'STUDENT_TEST', (v_res ->> 'id')::uuid);
end;
$$;
revoke all on function app.demo_make_student_test(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (d) Phiếu thu chờ duyệt: gửi (submit_receipt) phiếu thu thiếu một phần của bộ (phiếu thứ hai theo thứ tự tạo). Phiếu đủ giữ Nháp.
-- Hàm thật kiểm quản lý trực tiếp của người bấm có quyền Duyệt phiếu thu; không đủ thì khối bị bỏ qua ở app.demo_make_p1.
-- ---------------------------------------------------------------------------
create or replace function app.demo_submit_receipt(p_set_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rid uuid;
begin
  select r.id into v_rid
    from app.demo_data_item i join app.receipt r on r.id = i.entity_id
   where i.set_id = p_set_id and i.entity_type = 'RECEIPT' and r.is_demo and r.status_code = 'NHAP'
   order by r.created_at desc, r.id limit 1;
  if v_rid is not null then
    perform app.submit_receipt(v_rid);
  end if;
end;
$$;
revoke all on function app.demo_submit_receipt(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (e) Bảo lưu Chờ duyệt (hàm thật create + submit) và hoàn phí Chờ quản lý (chèn trực tiếp) cho hai ghi danh đã xếp lớp của bộ.
-- Hoàn phí: số liệu minh hoạ chụp theo cấu trúc app.compute_refund (phí xử lý lấy từ tham số refund_processing_fee_percent).
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_hold_and_refund(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_enrols uuid[];
  v_reason text;
  v_hold uuid;
  v_ref uuid;
  v_pct numeric;
  v_base constant bigint := 1000000;  -- allow-number: số tiền gốc minh hoạ của phiếu hoàn phí mẫu (không phải tiền thật)
  v_fee bigint;
begin
  select array_agg(e.id order by e.created_at, e.code) into v_enrols
    from app.enrollment e
   where e.is_demo and e.status_code = 'DA_XEP_LOP'
     and e.id in (select entity_id from app.demo_data_item where set_id = p_set_id and entity_type = 'ENROLLMENT');
  if coalesce(array_length(v_enrols, 1), 0) < 3 then  -- allow-number: kế hoạch dữ liệu mẫu (cần ghi danh thứ 2 và 3 đã xếp lớp)
    return;
  end if;
  -- Bảo lưu cho ghi danh thứ hai: tạo rồi trình, dừng ở Chờ duyệt.
  select c.code into v_reason from app.catalog_item c where c.catalog_code = 'HOLD_REASON' and c.is_active order by c.sort_order, c.code limit 1;
  v_hold := app.create_enrollment_hold(v_enrols[2], 1, v_reason, '[MẪU] Yêu cầu bảo lưu mẫu', null);  -- allow-number: chỉ số ghi danh và số tháng bảo lưu mẫu
  perform app.submit_enrollment_hold(v_hold);
  perform app.demo_tag(p_set_id, 'ENROLLMENT_HOLD', v_hold);
  -- Hoàn phí cho ghi danh thứ ba: Chờ quản lý duyệt.
  select c.code into v_reason from app.catalog_item c where c.catalog_code = 'REFUND_REASON' and c.is_active order by c.sort_order, c.code limit 1;
  v_pct := app.get_setting('refund_processing_fee_percent', p_branch_id)::numeric;
  v_fee := round(v_base * v_pct / 100);  -- allow-number: đổi phần trăm sang tỉ lệ
  insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, note, hours_refund, paid_amount, hours_used,
                                  unit_price_base, unit_price_net, base_amount, fee_percent, fee_amount, refund_amount, status_code, created_by, updated_by)
  select e.id, e.student_id, e.branch_id, 'MOT_PHAN', v_reason, '[MẪU] Yêu cầu hoàn phí mẫu, số liệu minh hoạ', 5, v_base * 2, 0, v_base / 5, v_base / 5,  -- allow-number: số liệu minh hoạ
         v_base, v_pct, v_fee, v_base - v_fee, 'CHO_QL', v_user, v_user
    from app.enrollment e where e.id = v_enrols[3]  -- allow-number: chỉ số ghi danh thứ ba
  returning id into v_ref;
  perform app.demo_tag(p_set_id, 'REFUND_REQUEST', v_ref);
end;
$$;
revoke all on function app.demo_make_hold_and_refund(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (f) Nhận xét chờ gửi phụ huynh: bỏ dấu «đã gửi» của MỘT nhận xét ở buổi Done của lớp mẫu (R-GV-04, R-CS-13: CSKH gửi).
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_pending_review(p_set_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app.session_student_review set parent_sent_at = null, parent_sent_by = null
   where id = (select r.id from app.session_student_review r
                 join app.class_session s on s.id = r.session_id
                where s.is_demo and s.status_code = 'DONE' and r.parent_sent_at is not null
                  and s.class_id in (select entity_id from app.demo_data_item where set_id = p_set_id and entity_type = 'CLASS')
                order by r.created_at, r.id limit 1);
end;
$$;
revoke all on function app.demo_make_pending_review(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (g) Hàm gom: đặt cờ giao dịch, chạy từng mục trong khối riêng (lỗi thì bỏ qua mục đó và ghi notice), xoá cờ ở mọi đường ra.
-- Ai gọi: chỉ app.create_demo_data_set (bộ của chính người gọi, còn dùng).
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_p1(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_skipped text[] := '{}';
begin
  perform app.demo_assert_caller_set(p_set_id, p_branch_id, null);
  perform set_config('hmt.demo_sales', 'on', true);
  begin
    perform app.demo_make_student_test(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'phiếu kiểm tra'::text);
  end;
  begin
    perform app.demo_submit_receipt(p_set_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'phiếu thu chờ duyệt'::text);
  end;
  begin
    perform app.demo_make_waiting_enrollments(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'ghi danh chờ xếp lớp'::text);
  end;
  begin
    perform app.demo_make_hold_and_refund(p_set_id, p_branch_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'bảo lưu và hoàn phí chờ duyệt'::text);
  end;
  begin
    perform app.demo_make_pending_review(p_set_id);
  exception when others then
    v_skipped := array_append(v_skipped, 'nhận xét chờ gửi'::text);
  end;
  if array_length(v_skipped, 1) is not null then
    update app.demo_data_set set notice = concat_ws(' ', notice, 'Đã bỏ qua: ' || array_to_string(v_skipped, ', ') || ' (thiếu danh mục, quyền hoặc công tắc).')
     where id = p_set_id;
  end if;
  perform set_config('hmt.demo_sales', '', true);
exception when others then
  perform set_config('hmt.demo_sales', '', true);
  raise;
end;
$$;
revoke all on function app.demo_make_p1(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (h) Hàm tạo bộ: giữ nguyên bản 660, thêm đúng một dòng perform app.demo_make_p1 (sau buổi học).
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
  perform app.demo_make_sessions(v_id, v_branch);
  perform app.demo_make_p1(v_id, v_branch);
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- (i) Nâng hạn mức mặc định để tập theo cặp (tham số có min/max, đổi được ở màn Cài đặt): 3 → 6 bộ/người, 10 → 30 bộ/cơ sở.
-- ---------------------------------------------------------------------------
update app.setting_def set value = '6' where key = 'demo_data_max_per_user' and value = '3';
update app.setting_def set value = '30' where key = 'demo_data_max_per_branch' and value = '10';

select set_config('hmt.migration', '', false);
