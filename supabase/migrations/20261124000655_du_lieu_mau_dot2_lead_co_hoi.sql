-- Dữ liệu mẫu staging, ĐỢT 2, mảnh 1 (Code F, 24/11/2026; thẻ F-23-39): 10 lead và 6 cơ hội mẫu cho cơ sở của người tạo bộ.
-- Thiết kế: docs/nghiep-vu/du-lieu-mau-dot2-thiet-ke.md (#654); khung: migration 648.
-- Làm gì: thêm app.demo_tag (đặt is_demo + ghi demo_data_item, một chỗ duy nhất cho mọi mảnh đợt 2), app.demo_make_leads (hàm con),
--   và thêm ĐÚNG MỘT dòng perform vào app.create_demo_data_set.
-- Luật an toàn: hàm con là security definer nhưng chỉ chạy khi gọi từ hàm tạo bộ (kiểm bộ của chính người gọi, còn DANG_DUNG, chưa có lead mẫu)
--   và kiểm lại khoá môi trường. Không tham số nội dung. Người tạo bộ không cần quyền tạo lead/cơ hội (quyết định 5 của thiết kế),
--   nên chèn trực tiếp và cấp mã bằng app.issue_crm_code để mã giống bản thật; không tự duyệt, không gửi tin.
-- SĐT dải 0999 000 001-999 (bộ đếm DEMO_PHONE, không nhảy, không trùng giữa các bộ); email không dùng (@example.invalid nếu cần).
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Đánh dấu một bản ghi thuộc bộ mẫu: đặt is_demo = true và ghi demo_data_item. Chỉ gọi từ hàm mẫu (không cấp cho giao diện).
-- Đầu vào: bộ, loại (LEAD, OPPORTUNITY, ORDER, STUDENT, CLASS, SESSION, TICKET), id bản ghi.
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
    when 'ORDER' then update app.sales_order set is_demo = true where id = p_entity_id;
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
-- Tạo 10 lead mẫu và 6 cơ hội mẫu cho bộ.
-- Ai gọi: chỉ app.create_demo_data_set (người gọi phải là chủ bộ). Đầu vào: bộ, cơ sở. Kết quả: không.
-- Luật: kiểm khoá môi trường; người phụ trách = người tạo bộ; nguồn lấy từ danh mục đang dùng (không viết cứng mã);
--   giai đoạn trải nhiều bước: lead C1, C2A, C3A, C4A, C4B, C4C, và 6 lead C4D mỗi lead một cơ hội ở L1, L1, L2A, L4A, L4B, L4C.
-- ---------------------------------------------------------------------------
create or replace function app.demo_make_leads(p_set_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  -- Mỗi dòng: giai đoạn, nhóm con lead; giai đoạn, nhóm con cơ hội (null = chỉ có lead).
  v_plan constant text[][] := array[
    ['C1', null, null, null], ['C2', 'C2A', null, null], ['C3', 'C3A', null, null], ['C4', 'C4A', null, null],
    ['C4', 'C4B', null, null], ['C4', 'C4C', null, null],
    ['C4', 'C4D', 'L1', null], ['C4', 'C4D', 'L1', null], ['C4', 'C4D', 'L2', 'L2A'],
    ['C4', 'C4D', 'L4', 'L4A']];
  v_names constant text[] := array['An', 'Bình', 'Chi', 'Dũng', 'Hà', 'Khoa', 'Lan', 'Minh', 'Nga', 'Phúc'];
  v_types text[];
  v_sources text[];
  v_type text;
  v_source text;
  v_channel text;
  v_n integer;
  v_seq bigint;
  v_phone text;
  v_lead_id uuid;
  v_parent_id uuid;
  v_opp_id uuid;
  v_code text;
begin
  -- Luật khoá: chạy thật hoặc công tắc tắt thì từ chối.
  perform app.assert_demo_data_allowed();
  -- Luật: chỉ gọi từ hàm tạo bộ: bộ phải của chính người gọi, còn dùng, và chưa đổ lead.
  if not exists (select 1 from app.demo_data_set where id = p_set_id and created_by = v_user
                    and status_code = 'DANG_DUNG' and branch_id = p_branch_id)
     or exists (select 1 from app.demo_data_item where set_id = p_set_id and entity_type = 'LEAD') then
    perform app.raise_error('HMT_DEMO_KHONG_DU_QUYEN', 'Không tạo được lead mẫu cho bộ này.');
  end if;

  -- Nguồn: các nguồn đang dùng trong danh mục, theo thứ tự (xoay vòng cho các lead khác nhau).
  select array_agg(s.code order by t.sort_order, s.sort_order, s.code), array_agg(t.code order by t.sort_order, s.sort_order, s.code)
    into v_sources, v_types
    from app.catalog_item s
    join app.catalog_item t on t.id = s.parent_id and t.catalog_code = 'SOURCE_TYPE' and t.is_active
   where s.catalog_code = 'SOURCE' and s.is_active;
  if coalesce(array_length(v_sources, 1), 0) = 0 then
    perform app.raise_error('HMT_DEMO_THIEU_DANH_MUC', 'Danh mục nguồn khách chưa có mục nào đang dùng.');
  end if;

  for v_n in 1 .. array_length(v_plan, 1) loop
    v_type := v_types[1 + (v_n - 1) % array_length(v_sources, 1)];
    v_source := v_sources[1 + (v_n - 1) % array_length(v_sources, 1)];
    -- Kênh: bắt buộc khi nguồn có kênh con; lấy kênh đầu tiên đang dùng.
    select c.code into v_channel from app.catalog_item c
      join app.catalog_item s on s.id = c.parent_id and s.catalog_code = 'SOURCE' and s.code = v_source
     where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active
     order by c.sort_order, c.code limit 1;
    -- Luật: SĐT dải 0999 000 001-999 từ bộ đếm, hết dải thì dừng.
    v_seq := app.next_counter_value('DEMO_PHONE', 1);
    if v_seq > 999 then  -- allow-number: hết dải số điện thoại mẫu 0999 000 001-999 (dải cố định của thiết kế)
      perform app.raise_error('HMT_DEMO_HET_SO_DIEN_THOAI', 'Đã dùng hết dải số điện thoại mẫu. Báo quản trị.');
    end if;
    v_phone := '0999000' || lpad(v_seq::text, 3, '0');  -- allow-number: độ rộng 3 chữ số của dải số mẫu

    insert into app.lead (
      code, parent_name, parent_phone, need,
      branch_id, owner_id, source_type_code, source_code, channel_code, stage_code, substage_code, created_by, updated_by, is_demo)
    values (
      app.issue_crm_code('LD'), '[MẪU] Phụ huynh ' || v_names[v_n], v_phone, '[MẪU] Cần tư vấn lớp học thêm',
      p_branch_id, v_user, v_type, v_source, v_channel, v_plan[v_n][1], v_plan[v_n][2], v_user, v_user, true)  -- allow-number: chỉ số cột trong bảng kế hoạch mẫu
    returning id into v_lead_id;
    perform app.demo_tag(p_set_id, 'LEAD', v_lead_id);
    -- Em của lead (danh sách em nằm ở bảng riêng từ TS-06).
    insert into app.prospect_student (lead_id, branch_id, position, full_name, birth_year, school, created_by, updated_by)
    values (v_lead_id, p_branch_id, 1, '[MẪU] Học sinh ' || v_names[v_n], 2010 + (v_n % 6), '[MẪU] Trường thử nghiệm', v_user, v_user);  -- allow-number: năm sinh giả để thử

    -- Cơ hội: chỉ lead có giai đoạn cơ hội. Phụ huynh tìm/tạo theo SĐT giả (tên đã có nhãn [MẪU]).
    if v_plan[v_n][3] is not null then  -- allow-number: chỉ số cột trong bảng kế hoạch mẫu
      v_parent_id := app.find_or_create_parent(v_phone, '[MẪU] Phụ huynh ' || v_names[v_n], null, null, null, p_branch_id);
      v_code := app.issue_crm_code('CO');
      insert into app.opportunity (
        code, lead_id, parent_id, branch_id, owner_id, need,
        source_type_code, source_code, channel_code, stage_code, substage_code, created_by, updated_by, is_demo)
      values (
        v_code, v_lead_id, v_parent_id, p_branch_id, v_user, '[MẪU] Cần tư vấn lớp học thêm',
        v_type, v_source, v_channel, v_plan[v_n][3], v_plan[v_n][4], v_user, v_user, true)  -- allow-number: chỉ số cột trong bảng kế hoạch mẫu
      returning id into v_opp_id;
      perform app.demo_tag(p_set_id, 'OPPORTUNITY', v_opp_id);
      insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year, school, created_by, updated_by)
      values (v_opp_id, p_branch_id, 1, '[MẪU] Học sinh ' || v_names[v_n], 2010 + (v_n % 6), '[MẪU] Trường thử nghiệm', v_user, v_user);  -- allow-number: năm sinh giả để thử
    end if;
  end loop;
end;
$$;
revoke all on function app.demo_make_leads(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hàm tạo bộ: giữ nguyên đợt 1, thêm đúng một dòng perform app.demo_make_leads.
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
  return v_id;
end;
$$;

select set_config('hmt.migration', '', false);
