-- Dữ liệu mẫu staging, ĐỢT 2, mảnh báo giá, đơn hàng, phiếu thu (Code B, 24/11/2026; thẻ B-23-41, B-23-42). CAO: đụng hàm kiểm quyền lõi và tiền.
-- Thiết kế: docs/nghiep-vu/du-lieu-mau-dot2-thiet-ke.md (#654); khung: migration 648; mảnh lead/cơ hội: migration 655.
-- Làm gì:
--   (a) thêm cờ is_demo cho báo giá, phiếu thu; mở rộng demo_data_item và app.demo_tag cho hai loại QUOTATION, RECEIPT;
--   (b) thêm app.demo_data_is_allowed() (cùng luật khoá với assert_demo_data_allowed, trả đúng/sai, không báo lỗi);
--   (c) app.assert_can: thêm ĐÚNG MỘT nhánh bỏ qua kiểm quyền, chỉ khi cờ giao dịch hmt.demo_sales = on VÀ khoá dữ liệu mẫu qua (STAGING + công tắc);
--   (d) app.demo_make_sales: từ cơ hội của bộ tạo 6 báo giá, 4 đơn hàng, 2 phiếu thu (đủ và thiếu một phần) bằng các hàm nghiệp vụ THẬT;
--   (e) thêm ĐÚNG MỘT dòng perform vào app.create_demo_data_set.
-- Bốn ràng buộc an toàn (Chat chốt 09:35 24/11):
--   1. Cờ hmt.demo_sales chỉ do app.demo_make_sales đặt (set_config local trong giao dịch) và xoá ngay sau khi gọi xong.
--   2. Nhánh thêm vào assert_can chỉ bỏ qua khi cờ bật VÀ app.demo_data_is_allowed(); mọi trường hợp khác giữ nguyên (cùng mã lỗi, cùng câu).
--   3. pgTAP: thiếu STAGING hoặc công tắc tắt thì cờ bật vẫn bị chặn; người không quyền gọi thẳng hàm vẫn bị chặn; Kế toán, Giáo viên, Trợ giảng tạo bộ được; hết giao dịch cờ không còn.
--   4. Cơ hội nâng lên L8 bằng cập nhật trực tiếp, chỉ cho cơ hội is_demo của chính bộ.
-- Phiếu thu mẫu chỉ ở Nháp, mang cờ is_demo, không duyệt nên không sinh khoản tiền vào và không vào đối chiếu thật.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- (a) Cờ is_demo và loại bản ghi mới của bộ.
-- ---------------------------------------------------------------------------
alter table app.quotation add column is_demo boolean not null default false;
alter table app.receipt add column is_demo boolean not null default false;
-- Chỉ mục từng phần: chỉ chứa dòng mẫu, để bộ lọc «Ẩn dữ liệu mẫu» rẻ (cùng cách với bảng đã có cờ ở migration 648).
create index quotation_demo_idx on app.quotation (id) where is_demo;
create index receipt_demo_idx on app.receipt (id) where is_demo;

alter table app.demo_data_item drop constraint demo_data_item_entity_type_check;
alter table app.demo_data_item add constraint demo_data_item_entity_type_check
  check (entity_type in ('LEAD', 'OPPORTUNITY', 'QUOTATION', 'ORDER', 'RECEIPT', 'STUDENT', 'CLASS', 'SESSION', 'TICKET'));

-- ---------------------------------------------------------------------------
-- (b) Khoá dữ liệu mẫu dạng đúng/sai. assert_demo_data_allowed dùng lại hàm này, một chỗ duy nhất giữ luật khoá.
-- ---------------------------------------------------------------------------
create or replace function app.demo_data_is_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select e.env_code = 'STAGING' from app.deployment_env e), false)
         and app.get_setting_bool('demo_data_enabled');
$$;
revoke all on function app.demo_data_is_allowed() from public, anon, authenticated;

create or replace function app.assert_demo_data_allowed()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.demo_data_is_allowed() then
    perform app.raise_error('HMT_DEMO_TAT', 'Dữ liệu mẫu đang tắt. Chức năng này chỉ dùng ở môi trường thử nghiệm.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Đánh dấu bản ghi thuộc bộ mẫu: thêm QUOTATION và RECEIPT vào app.demo_tag (giữ nguyên các loại cũ).
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
    when 'STUDENT' then update app.student set is_demo = true where id = p_entity_id;
    when 'CLASS' then update app.class set is_demo = true where id = p_entity_id;
    when 'SESSION' then update app.class_session set is_demo = true where id = p_entity_id;
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
-- (c) Kiểm quyền lõi: giữ nguyên luật cũ, thêm đúng một nhánh cho dữ liệu mẫu (ràng buộc 1 và 2).
-- Nhánh chỉ mở khi: cờ giao dịch hmt.demo_sales = on (chỉ app.demo_make_sales đặt) VÀ khoá dữ liệu mẫu qua (STAGING + công tắc bật).
-- ---------------------------------------------------------------------------
create or replace function app.assert_can(p_module text, p_action text, p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.can_see_branch(p_module, p_action, p_branch_id) then
    -- Ngoại lệ duy nhất: đang đổ dữ liệu mẫu trong môi trường thử nghiệm đã bật công tắc.
    if coalesce(current_setting('hmt.demo_sales', true), '') = 'on' and app.demo_data_is_allowed() then
      return;
    end if;
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này ở cơ sở này.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- (d) Tạo báo giá, đơn hàng, phiếu thu mẫu cho bộ.
-- Ai gọi: chỉ app.create_demo_data_set (người gọi phải là chủ bộ). Đầu vào: bộ, cơ sở. Kết quả: không.
-- Dùng hàm thật: save_quotation, send_quotation, create_order_from_quotation, order_approve_core, create_receipt (mã, giá, luật giống bản thật).
-- Từ cơ hội của bộ (F tạo ở migration 655), theo thứ tự tạo: mỗi cơ hội một báo giá Đã gửi rồi một đơn hàng;
--   cơ hội 1 có thêm báo giá Đã gửi chưa lên đơn, cơ hội 2 có thêm báo giá Nháp (cộng lại 6 báo giá, 4 đơn khi bộ có đủ 4 cơ hội).
--   Đơn của cơ hội 1 và 2 được duyệt (qua lõi duyệt, không cần người duyệt thật) để có phiếu thu Nháp: phiếu đủ và phiếu thiếu một phần.
-- Gói bán và giá lấy từ cấu hình đang có hiệu lực (không viết cứng mã gói); điều khoản thanh toán và hình thức thanh toán lấy mục đang dùng đầu tiên.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_sales(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_opps uuid[];
  v_pkgs uuid[];
  v_modes text[];
  v_term uuid;
  v_method text;
  v_opp uuid;
  v_ps uuid;
  v_n integer;
  v_k integer;
  v_pi integer;
  v_q jsonb;
  v_qid uuid;
  v_order jsonb;
  v_oid uuid;
  v_orders uuid[] := '{}';
  v_due bigint;
  v_rid uuid;
  v_student uuid;
begin
  -- Luật khoá: chạy thật hoặc công tắc tắt thì từ chối.
  perform app.assert_demo_data_allowed();
  -- Luật: chỉ gọi từ hàm tạo bộ: bộ phải của chính người gọi, còn dùng, và chưa đổ báo giá.
  if not exists (select 1 from app.demo_data_set where id = p_set_id and created_by = v_user
                    and status_code = 'DANG_DUNG' and branch_id = p_branch_id)
     or exists (select 1 from app.demo_data_item where set_id = p_set_id and entity_type = 'QUOTATION') then
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Không tạo được báo giá mẫu cho bộ này.');
  end if;

  -- Cơ hội của bộ theo thứ tự tạo; chưa có cơ hội thì không có gì để làm (không báo lỗi).
  select array_agg(i.entity_id order by o.created_at, o.code) into v_opps
    from app.demo_data_item i join app.opportunity o on o.id = i.entity_id
   where i.set_id = p_set_id and i.entity_type = 'OPPORTUNITY' and o.is_demo;
  if coalesce(array_length(v_opps, 1), 0) = 0 then
    return;
  end if;

  -- Gói khoá học đang bán (có khối lớp) kèm hình thức có giá hiệu lực hôm nay, theo mã gói.
  select array_agg(x.package_id order by x.code, x.mode), array_agg(x.mode order by x.code, x.mode) into v_pkgs, v_modes
    from (select distinct on (p.id, pp.delivery_mode_code) p.id as package_id, p.code, pp.delivery_mode_code as mode, pp.unit_price
            from app.sales_package p
            join app.package_price pp on pp.package_id = p.id and pp.effective_from <= v_on
           where p.is_active and p.grade_from_code is not null
           order by p.id, pp.delivery_mode_code, pp.effective_from desc) x
   where x.unit_price is not null;
  if coalesce(array_length(v_pkgs, 1), 0) = 0 then
    perform app.raise_error('HMT_DEMO_THIEU_DANH_MUC', 'Chưa có gói bán nào đang dùng kèm giá để tạo báo giá mẫu.');
  end if;
  select t.id into v_term from app.payment_term t where t.valid_from <= v_on order by t.code, t.version desc limit 1;
  select c.code into v_method from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.is_active order by c.sort_order, c.code limit 1;

  -- Ràng buộc 1: cờ giao dịch chỉ bật trong hàm này; mọi đường ra đều xoá lại ở cuối.
  perform set_config('hmt.demo_sales', 'on', true);

  for v_n in 1 .. array_length(v_opps, 1) loop
    v_opp := v_opps[v_n];
    -- Em đầu tiên của cơ hội (F tạo một em cho mỗi cơ hội).
    select id into v_ps from app.prospect_student where opportunity_id = v_opp order by position limit 1;
    -- Số báo giá của cơ hội: cơ hội 1, 2 có hai, còn lại một.
    for v_k in 1 .. case when v_n <= 2 then 2 else 1 end loop  -- allow-number: kế hoạch dữ liệu mẫu (2 báo giá cho hai cơ hội đầu)
      v_pi := 1 + (v_n + v_k - 2) % array_length(v_pkgs, 1);  -- allow-number: chỉ số xoay vòng chọn gói (1 = phần tử đầu mảng, 2 = bù hai chỉ số bắt đầu từ 1), không phải số nghiệp vụ
      v_q := app.save_quotation(null, v_opp, jsonb_build_array(jsonb_build_object(
               'kind', 'ENROL', 'prospect_student_id', v_ps, 'package_id', v_pkgs[v_pi],
               'delivery_mode_code', v_modes[v_pi], 'quantity', 10, 'discounts', '[]'::jsonb)));  -- allow-number: số lượng mẫu
      v_qid := (v_q ->> 'id')::uuid;
      perform app.demo_tag(p_set_id, 'QUOTATION', v_qid);
      -- Báo giá thứ hai của cơ hội 2 giữ Nháp; các báo giá còn lại Đã gửi.
      if not (v_n = 2 and v_k = 2) then  -- allow-number: kế hoạch dữ liệu mẫu
        perform app.send_quotation(v_qid);
      end if;
      -- Báo giá đầu của mỗi cơ hội lên đơn hàng Nháp. Ràng buộc 4: nâng cơ hội lên L8 bằng cập nhật trực tiếp, chỉ cơ hội mẫu của bộ.
      if v_k = 1 then
        update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = v_opp and is_demo;
        v_order := app.create_order_from_quotation(v_qid, null, v_term);
        v_oid := (v_order ->> 'id')::uuid;
        perform app.demo_tag(p_set_id, 'ORDER', v_oid);
        v_orders := v_orders || v_oid;
      end if;
    end loop;
  end loop;

  -- Hai đơn đầu: duyệt qua lõi duyệt (đặt Đã trình rồi duyệt) để có phiếu thu; phiếu đủ cho đơn một, thiếu một phần cho đơn hai.
  for v_n in 1 .. least(2, coalesce(array_length(v_orders, 1), 0)) loop  -- allow-number: kế hoạch dữ liệu mẫu (hai đơn có phiếu thu)
    v_oid := v_orders[v_n];
    update app.sales_order set status_code = 'DA_TRINH', submitted_at = now(), submitted_by = v_user where id = v_oid and is_demo;
    perform app.order_approve_core(v_oid, false, false, 'Dữ liệu mẫu');
    -- Hồ sơ học sinh do duyệt đơn tạo ra cũng thuộc bộ (ẩn khi xoá bộ).
    for v_student in select distinct student_id from app.sales_order_line where order_id = v_oid and student_id is not null loop
      perform app.demo_tag(p_set_id, 'STUDENT', v_student);
    end loop;
    v_due := app.order_receivable(v_oid);
    if v_method is not null and v_due > 0 then
      v_rid := (app.create_receipt(v_oid, jsonb_build_object(
                  'amount', case when v_n = 1 then v_due else greatest(v_due / 2, 1) end,  -- allow-number: một nửa số còn thu cho phiếu thiếu một phần
                  'payment_method_code', v_method, 'collect_branch_id', p_branch_id, 'receiver_id', v_user,
                  'txn_ref', '[MẪU] giao dịch giả', 'note', '[MẪU] Phiếu thu mẫu, không phải tiền thật')) ->> 'id')::uuid;
      perform app.demo_tag(p_set_id, 'RECEIPT', v_rid);
    end if;
  end loop;

  perform set_config('hmt.demo_sales', '', true);
exception when others then
  -- Mọi lỗi đều xoá cờ trước khi báo tiếp (giao dịch sẽ lùi, nhưng không để cờ sống sót trong lúc xử lý lỗi).
  perform set_config('hmt.demo_sales', '', true);
  raise;
end;
$$;
revoke all on function app.demo_make_sales(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (e) Hàm tạo bộ: giữ nguyên bản 655, thêm đúng một dòng perform app.demo_make_sales (sau lead và cơ hội).
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
  return v_id;
end;
$$;

select set_config('hmt.migration', '', false);
