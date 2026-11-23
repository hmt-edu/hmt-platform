-- Code F (23/11/2026), thẻ PH-3 → PR-B, migration 645: hàm DB đọc, ghi cho cổng Phụ huynh (PH-03 Học phí và giờ học, PH-04 Đề nghị và khiếu nại).
-- Dựa trên nền cổng ở migration 637 (app.portal_student_ids, app.portal_require_student). KHÔNG mở RLS cho vai PARENT trên bảng nghiệp vụ: mọi màn đọc qua hàm security definer.
-- Luật: docs/ke-hoach/cong-hoc-tap-phu-huynh.md mục 3, 5; R-GD-13 (ngưỡng giờ còn thấp), R-TIEN (chỉ xem, không thanh toán), AS-02, AS-04, AS-07, AS-13 (Aftersale), R-CS-06, R-CS-09, R-CS-14.
select set_config('hmt.migration', 'on', false);

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note)
values ('TICKET_CHANNEL', 'CONG_PHU_HUYNH', 'Cổng phụ huynh', 91, false)
on conflict (catalog_code, code) do nothing;

-- 1. Các hồ sơ phụ huynh mà người gọi được coi là «mình»: hồ sơ gắn với tài khoản (mã PH) và mọi hồ sơ CÙNG số điện thoại (PH-2: một SĐT nhiều hồ sơ, một tài khoản thấy nhiều con).
-- Ai gọi: các hàm cổng. Tài khoản khoá thì rỗng. Chỉ mục: parent_phone_idx (tra theo SĐT), parent.code unique.
create or replace function app.portal_parent_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p2.id
    from app.user_account a
    join app.parent p on p.code = a.parent_code
    join app.parent p2 on p2.phone = p.phone
   where a.id = (select auth.uid()) and a.parent_code is not null and not a.is_locked;
$$;

-- 2. Học sinh người gọi được thấy: học sinh = chính mình; phụ huynh = con của MỌI hồ sơ cùng SĐT (thay bản ở migration 637).
create or replace function app.portal_student_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
    from app.user_account a
    join app.student s on a.student_code is not null and s.code = a.student_code
   where a.id = (select auth.uid()) and not a.is_locked
  union
  select s.id from app.student s where s.parent_id in (select app.portal_parent_ids());
$$;

-- 2b. Ngưỡng «giờ còn thấp» (R-GD-13) cho cổng: app.get_setting chặn người không phải nhân viên đọc khoá này (migration 470), nên đọc riêng một khoá, giá trị theo cơ sở rồi giá trị chung.
create or replace function app.portal_low_hours_threshold(p_branch_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select sb.value from app.setting_branch sb where sb.setting_key = 'upsale_hours_left_threshold' and sb.branch_id = p_branch_id and sb.is_active),
                  (select d.value from app.setting_def d where d.key = 'upsale_hours_left_threshold'))::numeric;
$$;

-- 3. app.ph_hours_orders(học sinh): PH-03 màn chính. Chỉ xem.
-- Kết quả: {hours_left, projected_end, is_low, orders: [{id, code, name, hours, status, total, paid, remaining}], receipts: [{code, paid_on, amount}]}.
-- Luật: giờ còn = tổng sổ giờ các ghi danh còn hiệu lực của em (kể cả giờ tặng); ngày hết dự kiến = hôm nay + giờ còn / giờ học mỗi tuần theo lịch lớp đang học (cùng công thức GD-07), null nếu chưa có lịch;
-- giờ còn thấp khi giờ còn <= upsale_hours_left_threshold (R-GD-13); đơn Nháp, Huỷ không hiện; không lộ phiếu thu chưa duyệt; tối đa 5 phiếu thu gần nhất.
create or replace function app.ph_hours_orders(p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := app.portal_require_student(p_student_id);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_left numeric;
  v_weekly numeric;
  v_end date;
  v_orders jsonb;
  v_receipts jsonb;
begin
  -- Giờ còn và giờ học mỗi tuần.
  select coalesce(sum(h.hours), 0) into v_left
    from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
   where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC');
  select coalesce(sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks), 0) into v_weekly -- allow-number: 3600 giây một giờ
    from app.class_slot s
   where s.is_active and s.class_id in (select ec.class_id from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                                         where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC'));
  if v_left > 0 and v_weekly > 0 then
    v_end := v_today + ceil(v_left / v_weekly * 7)::integer; -- allow-number: 7 ngày một tuần
  end if;
  -- Đơn của phụ huynh có dòng dành cho em (Đã duyệt).
  select coalesce(jsonb_agg(x.j order by x.created_at desc), '[]'::jsonb) into v_orders
    from (select o.created_at, jsonb_build_object(
            'id', o.id, 'code', o.code,
            'name', (select string_agg(l.package_name, ', ' order by l.line_no) from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id),
            'hours', (select sum(l.quantity + l.gifted_quantity) from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id and l.unit_code = 'GIO'),
            'total', o.total_amount, 'paid', app.order_paid_amount(o.id), 'remaining', greatest(o.total_amount - app.order_paid_amount(o.id), 0)) as j
            from app.sales_order o
           where o.status_code = 'DA_DUYET' and o.parent_id in (select app.portal_parent_ids())
             and exists (select 1 from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id)
           order by o.created_at desc limit 20) x; -- allow-number: trần số đơn hiện trên màn
  select coalesce(jsonb_agg(r.j order by r.paid_on desc), '[]'::jsonb) into v_receipts
    from (select rc.paid_on, jsonb_build_object('code', rc.code, 'paid_on', rc.paid_on, 'amount', rc.amount, 'order_code', o.code) as j
            from app.receipt rc join app.sales_order o on o.id = rc.order_id
           where rc.status_code = 'DA_DUYET' and rc.parent_id in (select app.portal_parent_ids())
             and exists (select 1 from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id)
           order by rc.paid_on desc limit 5) r; -- allow-number: năm phiếu thu gần nhất theo khung PH03
  return jsonb_build_object('hours_left', v_left, 'projected_end', v_end,
                            'is_low', v_left <= app.portal_low_hours_threshold(v_branch),
                            'orders', v_orders, 'receipts', v_receipts);
end;
$$;

-- 4. app.ph_order(đơn): PH-03 chi tiết đơn. Đơn phải của phụ huynh người gọi (các hồ sơ cùng SĐT), đã duyệt, và có dòng cho con của họ.
-- Kết quả: {code, name, hours, total, paid, remaining, status, receipts: [{code, paid_on, amount}]}; status: DA_THU_DU hoặc CON_THIEU.
create or replace function app.ph_order(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_paid bigint;
begin
  select * into o from app.sales_order where id = p_order_id and parent_id in (select app.portal_parent_ids()) and status_code = 'DA_DUYET';
  -- Luật quyền riêng: đơn người khác báo như không có.
  if o.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  perform app.require_feature('HOC_TAP', o.branch_id);
  v_paid := app.order_paid_amount(o.id);
  return jsonb_build_object(
    'code', o.code,
    'name', (select string_agg(l.package_name, ', ' order by l.line_no) from app.sales_order_line l where l.order_id = o.id),
    'hours', (select sum(l.quantity + l.gifted_quantity) from app.sales_order_line l where l.order_id = o.id and l.unit_code = 'GIO'),
    'total', o.total_amount, 'paid', v_paid, 'remaining', greatest(o.total_amount - v_paid, 0),
    'status', case when v_paid >= o.total_amount then 'DA_THU_DU' else 'CON_THIEU' end,
    'receipts', (select coalesce(jsonb_agg(jsonb_build_object('code', rc.code, 'paid_on', rc.paid_on, 'amount', rc.amount) order by rc.paid_on desc), '[]'::jsonb)
                   from app.receipt rc where rc.order_id = o.id and rc.status_code = 'DA_DUYET'));
end;
$$;

-- 5. app.ph_request_categories(loại): danh sách nhóm con cho ô «Nhóm» khi gửi mới (PH04_gui). Loại DN hoặc KN; chỉ nhóm con đang dùng, không đòi chọn lớp.
create or replace function app.ph_request_categories(p_type text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select count(*) from app.portal_parent_ids()) = 0 then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  if p_type not in ('DN', 'KN') then
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Loại phải là Đề nghị hoặc Khiếu nại.');
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name, 'group_name', g.name) order by g.sort_order, c.sort_order)
                     from app.ticket_category c join app.ticket_category g on g.code = c.parent_code
                    where c.kind = 'SUBGROUP' and c.is_active and g.is_active and c.ticket_type = p_type and not c.requires_class), '[]'::jsonb);
end;
$$;

-- 6. app.ph_list_tickets(học sinh hoặc null, số dòng, vị trí): PH-04 danh sách «Đề nghị của tôi». Chỉ ticket loại Đề nghị, Khiếu nại của phụ huynh người gọi.
-- Kết quả: {total, rows: [{id, code, title, ticket_type, student_name, created_at, status}]}; status cho phụ huynh: DANG_XU_LY, CHO_XAC_NHAN (Đã xử lý), DA_XONG (Đã đóng), DA_HUY.
-- Phân trang ở máy chủ, tối đa list_page_size_max (quy ước hiệu năng); chỉ mục ticket_parent_idx.
create or replace function app.ph_list_tickets(p_student_id uuid default null, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), app.get_setting_int('list_page_size_max')::integer); -- allow-number: mặc định 50 dòng theo quy ước hiệu năng
  v_total bigint;
  v_rows jsonb;
begin
  if p_student_id is not null then
    perform app.portal_require_student(p_student_id);
  elsif (select count(*) from app.portal_parent_ids()) = 0 then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  select count(*) into v_total from app.ticket t
   where t.parent_id in (select app.portal_parent_ids()) and t.ticket_type in ('DN', 'KN') and (p_student_id is null or t.student_id = p_student_id);
  select coalesce(jsonb_agg(x.j order by x.created_at desc), '[]'::jsonb) into v_rows
    from (select t.created_at, jsonb_build_object(
            'id', t.id, 'code', t.code, 'title', t.title, 'ticket_type', t.ticket_type, 'student_name', s.full_name, 'created_at', t.created_at,
            'status', case t.status_code when 'DA_XU_LY' then 'CHO_XAC_NHAN' when 'DA_DONG' then 'DA_XONG' when 'DA_HUY' then 'DA_HUY' else 'DANG_XU_LY' end) as j
            from app.ticket t left join app.student s on s.id = t.student_id
           where t.parent_id in (select app.portal_parent_ids()) and t.ticket_type in ('DN', 'KN') and (p_student_id is null or t.student_id = p_student_id)
           order by t.created_at desc limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- 7. app.ph_get_ticket(ticket): PH-04 chi tiết «theo dõi 4 bước». Không lộ ghi chú nội bộ, người xử lý, hạn xử lý.
-- Kết quả: {id, code, title, ticket_type, student_name, created_at, status, step, proposal, satisfaction, steps_at: {received, processing, proposal, done}}.
-- step: 1 Đã nhận, 2 Đang xử lý, 3 Phương án (Đã xử lý: chờ phụ huynh xác nhận), 4 Hoàn tất (Đã đóng). proposal = kết quả xử lý, chỉ hiện từ bước 3.
create or replace function app.ph_get_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_step integer;
begin
  select * into t from app.ticket where id = p_ticket_id and parent_id in (select app.portal_parent_ids()) and ticket_type in ('DN', 'KN');
  if t.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  v_step := case t.status_code when 'DA_XU_LY' then 3 when 'DA_DONG' then 4 when 'MOI' then 1 else 2 end; -- allow-number: bốn bước theo dõi theo khung PH04
  return jsonb_build_object(
    'id', t.id, 'code', t.code, 'title', t.title, 'ticket_type', t.ticket_type, 'created_at', t.created_at,
    'student_name', (select s.full_name from app.student s where s.id = t.student_id),
    'status', case t.status_code when 'DA_XU_LY' then 'CHO_XAC_NHAN' when 'DA_DONG' then 'DA_XONG' when 'DA_HUY' then 'DA_HUY' else 'DANG_XU_LY' end,
    'step', v_step,
    'proposal', case when v_step >= 3 then t.resolution end, -- allow-number: từ bước 3 (Phương án) mới hiện nội dung
    'satisfaction', t.satisfaction,
    'steps_at', jsonb_build_object('received', t.created_at, 'processing', t.first_response_at, 'proposal', t.resolved_at, 'done', t.closed_at));
end;
$$;

-- 8. app.ph_create_request(học sinh, loại, nhóm con, nội dung): PH-04 gửi mới (PH04_gui).
-- Ai gọi: phụ huynh có con là học sinh này. Luật: công tắc AFTERSALE (AS-13); nội dung bắt buộc; nhóm con thuộc loại, đang dùng, không đòi chọn lớp; mã AS-01; hạn chụp lúc tạo (AS-07);
-- nguồn «Cổng phụ huynh»; đội mặc định theo nhóm con hoặc CSKH. Kết quả: {id, code}.
create or replace function app.ph_create_request(p_student_id uuid, p_type text, p_category_code text, p_content text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
  v_content text := nullif(btrim(coalesce(p_content, '')), '');
  v_parent uuid;
  v_cat app.ticket_category;
  v_priority text;
  v_resp integer;
  v_res integer;
  v_code text;
  v_id uuid;
  v_now timestamptz := now();
begin
  v_branch := app.portal_require_student(p_student_id);
  perform app.require_feature('AFTERSALE', v_branch);
  if p_type not in ('DN', 'KN') then
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Loại phải là Đề nghị hoặc Khiếu nại.');
  end if;
  if v_content is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Quý phụ huynh vui lòng nhập nội dung.');
  end if;
  select * into v_cat from app.ticket_category where code = p_category_code and kind = 'SUBGROUP' and is_active and ticket_type = p_type and not requires_class;
  if v_cat.id is null then
    perform app.raise_error('HMT_TICKET_NHOM_SAI', 'Nhóm không có, đã Ngừng hoặc không thuộc loại này.');
  end if;
  -- Người gửi là hồ sơ phụ huynh của em (hồ sơ nằm trong nhóm cùng SĐT với người gọi, đã được portal_require_student bảo đảm).
  select s.parent_id into v_parent from app.student s where s.id = p_student_id;
  v_priority := v_cat.default_priority;
  select r.response_hours into v_resp from app.ticket_sla_rule r where r.ticket_type = p_type and r.priority_code = v_priority;
  v_res := app.ticket_resolve_hours(p_type, v_priority, v_cat.code);
  v_code := app.issue_document_number(p_type, (select b.code from app.branch b where b.id = v_branch));
  insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, team_code, parent_id, student_id,
                          response_due_at, resolve_due_at)
  values (v_code, p_type, v_branch, v_cat.name, v_content, 'CONG_PHU_HUYNH', v_cat.code, v_priority, coalesce(v_cat.default_team, 'CSKH'), v_parent, p_student_id,
          v_now + make_interval(hours => v_resp), v_now + make_interval(hours => v_res))
  returning id into v_id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, to_status) values (v_id, v_branch, 'TAO', 'MOI');
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- 9. app.ph_confirm_option(ticket): PH-04 «Đồng ý phương án». Chỉ ghi xác nhận vào nhật ký ticket (ticket đang Đã xử lý); CSKH đóng ticket theo luồng thường (AS-04).
create or replace function app.ph_confirm_option(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_ticket_id and parent_id in (select app.portal_parent_ids()) and ticket_type in ('DN', 'KN') for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  if t.status_code <> 'DA_XU_LY' then
    perform app.raise_error('HMT_PH_KHONG_CO_PHUONG_AN', 'Đề nghị này chưa có phương án chờ xác nhận.');
  end if;
  insert into app.ticket_event (ticket_id, branch_id, event_type, from_status, to_status, note)
  values (t.id, t.branch_id, 'DOI_TRANG_THAI', t.status_code, t.status_code, 'Phụ huynh đồng ý phương án.');
end;
$$;

-- 10. app.ph_rate_ticket(ticket, mức 1 đến 5): PH-04 chấm hài lòng (PH04_hai_long). Chỉ ticket Đã xử lý hoặc Đã đóng của mình, chấm một lần.
-- Luật AS-04, R-CS-14: mức 1 đến 5. Khiếu nại đang Đã xử lý thì chấm xong chuyển Đã đóng (đóng khiếu nại cần mức hài lòng).
create or replace function app.ph_rate_ticket(p_ticket_id uuid, p_score integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_ticket_id and parent_id in (select app.portal_parent_ids()) and ticket_type in ('DN', 'KN') for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  if p_score is null or p_score not between 1 and 5 then -- allow-number: thang hài lòng 1 đến 5 (AS-04)
    perform app.raise_error('HMT_TICKET_THIEU_HAI_LONG', 'Mức hài lòng từ 1 đến 5.');
  end if;
  if t.status_code not in ('DA_XU_LY', 'DA_DONG') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Chỉ chấm được khi ticket đã xử lý xong.');
  end if;
  if t.satisfaction is not null then
    perform app.raise_error('HMT_TICKET_DA_CHAM', 'Đề nghị này đã được đánh giá.');
  end if;
  update app.ticket set satisfaction = p_score where id = t.id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, from_status, to_status, note)
  values (t.id, t.branch_id, 'DOI_TRANG_THAI', t.status_code, t.status_code, 'Phụ huynh chấm hài lòng ' || p_score || '/5.');
end;
$$;

revoke execute on function app.portal_parent_ids(), app.portal_low_hours_threshold(uuid), app.portal_student_ids(), app.ph_hours_orders(uuid), app.ph_order(uuid), app.ph_request_categories(text),
  app.ph_list_tickets(uuid, integer, integer), app.ph_get_ticket(uuid), app.ph_create_request(uuid, text, text, text), app.ph_confirm_option(uuid),
  app.ph_rate_ticket(uuid, integer) from public, anon;
grant execute on function app.portal_parent_ids(), app.portal_low_hours_threshold(uuid), app.portal_student_ids(), app.ph_hours_orders(uuid), app.ph_order(uuid), app.ph_request_categories(text),
  app.ph_list_tickets(uuid, integer, integer), app.ph_get_ticket(uuid), app.ph_create_request(uuid, text, text, text), app.ph_confirm_option(uuid),
  app.ph_rate_ticket(uuid, integer) to authenticated;

select set_config('hmt.migration', '', false);
