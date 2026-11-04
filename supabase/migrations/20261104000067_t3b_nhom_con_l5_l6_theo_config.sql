-- T3b: nhóm con L5, L6 theo Config mới 04/11/2026 (anh Trường chốt 04/11, Đ285; R-CRM-13, 15, 34 sửa theo).
--  - L6 đánh lại: L6A "chưa có kết quả test", L6B "có kết quả test, cần phân loại", L6C xuất sắc, L6D tốt, L6E khá, L6F trung bình,
--    thêm L6G học yếu. Mã L6A–L6F ĐỔI NGHĨA (ngoại lệ một lần như migration 017, chỉ vì dữ liệu hiện chỉ là dữ liệu giả).
--  - L5B đổi tên theo Config (giữ nghĩa: có phiếu Nháp hoặc Đang test). L5P và L5Q chuyển Ngừng (không xoá).
--  - Lý do huỷ test "Trung tâm không xếp được lịch test" (danh mục 13) giữ nguyên, nối sang nhóm con L5M.
--  - Hàm đổi: opportunity_l5_substage (bỏ nhánh L5P), submit_student_test (nộp bài: cơ hội từ L5 trở xuống lên L6A),
--    complete_student_test (Hoàn thành: L6B), change_opportunity_stage (không tay đổi về L6A, L6B).
-- Chỉ thêm mới: migration đã gộp không sửa.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Danh mục nhóm con cơ hội
-- ---------------------------------------------------------------------------
-- L5B: tên theo Config (chữ giữ đúng như Config, anh Trường sẽ sửa Config nếu cần).
update app.catalog_item set name = 'Đồng ý tham gia test, đã xếp lớp thành công'
 where catalog_code = 'OPP_SUBSTAGE' and code = 'L5B';

-- L6: đánh lại A–G theo Config. Xếp chỗ cho L6G ngay sau L6F.
update app.catalog_item set sort_order = sort_order + 1
 where catalog_code = 'OPP_SUBSTAGE'
   and sort_order > (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L6F');

update app.catalog_item i set name = v.name
  from (values
    ('L6A', 'Đã tham gia test, chưa có kết quả test'),
    ('L6B', 'Đã tham gia test, có kết quả test, cần phân loại'),
    ('L6C', 'Đã tham gia test, học xuất sắc'),
    ('L6D', 'Đã tham gia test, học tốt'),
    ('L6E', 'Đã tham gia test, học khá'),
    ('L6F', 'Đã tham gia test, học trung bình')
  ) v(code, name)
 where i.catalog_code = 'OPP_SUBSTAGE' and i.code = v.code;

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'OPP_SUBSTAGE', 'L6G', 'Đã tham gia test, học yếu',
       (select sort_order + 1 from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L6F'),
       (select id from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L6');

-- L6B cũng do hệ thống gắn (khi phiếu Hoàn thành): khoá như L6A.
update app.catalog_item set is_locked = true where catalog_code = 'OPP_SUBSTAGE' and code = 'L6B';

-- L5P, L5Q: Config mới không có. Mở khoá rồi chuyển Ngừng (không xoá).
update app.catalog_item set is_locked = false, is_active = false
 where catalog_code = 'OPP_SUBSTAGE' and code in ('L5P', 'L5Q');

-- Lý do huỷ test "Trung tâm không xếp được lịch test" (mã L5Q) giữ nguyên, nối sang L5M (anh Trường chốt 04/11).
update app.catalog_item set linked_item_id = (select id from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5M')
 where catalog_code = 'TEST_CANCEL_REASON' and code = 'L5Q';

select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- app.opportunity_l5_substage(cơ hội): nhóm con L5 theo các phiếu (R-CRM-15, sửa 04/11).
-- Thứ tự: (1) còn phiếu Nháp hoặc Đang test → L5B; (2) mọi phiếu đều Huỷ → nhóm con nối với lý do của phiếu huỷ gần nhất, bỏ qua
-- "Tạo phiếu sai"; (3) còn lại → L5A. Bỏ nhánh L5P: phiếu Chờ giáo viên chấm đưa cơ hội lên L6A (app.submit_student_test).
-- ---------------------------------------------------------------------------
create or replace function app.opportunity_l5_substage(p_opportunity_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    -- Luật R-CRM-15 (1): còn phiếu Nháp hoặc Đang test.
    when exists (select from app.student_test where opportunity_id = p_opportunity_id
                  and status_code in ('DRAFT', 'TESTING')) then 'L5B'
    -- Luật R-CRM-15 (2): mọi phiếu đều Huỷ (trừ phiếu "Tạo phiếu sai"): nhóm con nối với lý do của phiếu huỷ gần nhất.
    -- Luật R-CRM-15 (3): không có phiếu nào tính được thì L5A.
    else coalesce((
      select i.code
        from app.student_test t
        join app.catalog_item r on r.catalog_code = 'TEST_CANCEL_REASON' and r.code = t.cancel_reason_code
        join app.catalog_item i on i.id = r.linked_item_id
       where t.opportunity_id = p_opportunity_id and t.status_code = 'CANCELLED' and t.cancel_reason_code <> 'TAO_PHIEU_SAI'
         and not exists (select from app.student_test x where x.opportunity_id = p_opportunity_id and x.status_code <> 'CANCELLED')
       order by t.cancelled_at desc, t.id
       limit 1), 'L5A')
  end;
$$;

-- ---------------------------------------------------------------------------
-- app.submit_student_test(phiếu): Nộp bài (Đang test → Chờ giáo viên chấm). Ai gọi: quyền Sửa phiếu.
-- Luật R-CRM-13 (04/11): cơ hội đang ở L5 trở xuống tự lên L6, nhóm con L6A "chưa có kết quả test" (chỉ hệ thống chuyển);
-- cơ hội đã ở L6 trở đi giữ nguyên (R-CRM-02).
-- ---------------------------------------------------------------------------
create or replace function app.submit_student_test(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
  v_opp app.opportunity;
  v_opp_order integer;
  v_l5_order integer;
begin
  if v_test.status_code <> 'TESTING' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ nộp bài được với phiếu ở trạng thái Đang test.');
  end if;
  update app.student_test set status_code = 'TEACHER_REVIEW' where id = p_id;

  -- Luật R-CRM-13: đã làm bài, chờ chấm → cơ hội từ L5 trở xuống lên L6A.
  select * into v_opp from app.opportunity where id = v_test.opportunity_id for update;
  select sort_order into v_opp_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';
  if v_opp_order <= v_l5_order then
    update app.opportunity set stage_code = 'L6', substage_code = 'L6A' where id = v_opp.id;
  else
    perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.complete_student_test(phiếu): Hoàn thành (Chờ giáo viên chấm → Hoàn thành), cần giáo viên chấm, điểm, nhận xét (TS-17).
-- Luật R-CRM-13 (04/11): cơ hội từ L5 trở xuống lên L6, nhóm con L6B "có kết quả test, cần phân loại"; cơ hội đang ở L6A (do nộp bài)
-- chuyển L6B; nhóm con L6 khác (người dùng đã chọn tay) và giai đoạn từ L7 trở đi giữ nguyên (R-CRM-02).
-- ---------------------------------------------------------------------------
create or replace function app.complete_student_test(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
  v_missing text[] := array[]::text[];
  v_opp app.opportunity;
  v_opp_order integer;
  v_l5_order integer;
begin
  if v_test.status_code <> 'TEACHER_REVIEW' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ hoàn thành được phiếu ở trạng thái Chờ giáo viên chấm.');
  end if;
  if v_test.grader_id is null then
    v_missing := array_append(v_missing, 'giáo viên chấm');
  end if;
  if v_test.score is null then
    v_missing := array_append(v_missing, 'điểm');
  end if;
  if btrim(coalesce(v_test.result_note, '')) = '' then
    v_missing := array_append(v_missing, 'nhận xét');
  end if;
  if cardinality(v_missing) > 0 then
    perform app.raise_error('HMT_THIEU_KET_QUA', format('Chưa hoàn thành được: phiếu còn thiếu %s.', array_to_string(v_missing, ', ')));
  end if;
  update app.student_test set status_code = 'COMPLETED', completed_at = now(), completed_by = auth.uid(), status_reason = null
   where id = p_id;

  -- Luật R-CRM-13: có kết quả → L6B (từ L5 trở xuống, hoặc đang L6A do nộp bài).
  select * into v_opp from app.opportunity where id = v_test.opportunity_id for update;
  select sort_order into v_opp_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';
  if v_opp_order <= v_l5_order then
    update app.opportunity set stage_code = 'L6', substage_code = 'L6B' where id = v_opp.id;
  elsif v_opp.stage_code = 'L6' and v_opp.substage_code = 'L6A' then
    update app.opportunity set substage_code = 'L6B' where id = v_opp.id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.change_opportunity_stage: như bản trước (R-CRM-02, 03, 12–17, 35), chỉ đổi luật R-CRM-13: người dùng không tay đổi về
-- L6A, L6B (hệ thống gắn). Người dùng chọn tay L6C–L6G.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.change_opportunity_stage(p_id uuid, p_stage_code text, p_substage_code text DEFAULT NULL::text, p_skip_reason_code text DEFAULT NULL::text, p_skip_note text DEFAULT NULL::text, p_confirm_l8 boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_opp app.opportunity;
  v_old_order integer;
  v_new_order integer;
  v_l5_order integer;
  v_state record;
  v_missing text[] := array[]::text[];
  v_first app.prospect_student_v;
  v_skip_code text;
  v_skip_note text;
  v_substage text := p_substage_code;
begin
  select * into v_opp from app.opportunity where id = p_id for update;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('OPPORTUNITY', 'SUA', v_opp.branch_id);
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, chỉ xem được.');
  end if;
  perform app.assert_catalog_code_active('OPP_STAGE', p_stage_code);
  if p_substage_code is not null then
    perform app.assert_catalog_code_active('OPP_SUBSTAGE', p_substage_code);
  end if;

  select sort_order into v_old_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_new_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = p_stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';

  -- Luật R-CRM-02: giai đoạn chỉ đi tới.
  if v_new_order < v_old_order then
    perform app.raise_error('HMT_CO_HOI_KHONG_LUI', 'Giai đoạn cơ hội chỉ đi tới, không lùi lại.');
  end if;

  -- ===== Cùng giai đoạn: chỉ đổi nhóm con =====
  if p_stage_code = v_opp.stage_code then
    if p_substage_code is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn nhóm con mới của giai đoạn này.');
    end if;
    if p_substage_code is not distinct from v_opp.substage_code then
      perform app.raise_error('HMT_KHONG_THAY_DOI', 'Cơ hội đã ở nhóm con này.');
    end if;
    -- Luật R-CRM-17: đã L8C thì không rời nhóm con L8C.
    if v_opp.substage_code = 'L8C' then
      perform app.raise_error('HMT_L8C_GIU_NGUYEN', 'Cơ hội đã ở nhóm con L8C (đã đóng đủ học phí), không đổi sang nhóm con khác.');
    end if;
    -- Luật R-CRM-15: nhóm con L5 do hệ thống gắn theo các phiếu kiểm tra, không đổi tay.
    if p_stage_code = 'L5' then
      perform app.raise_error('HMT_NHOM_CON_L5_HE_THONG', 'Nhóm con của L5 do hệ thống tự gắn theo phiếu kiểm tra, không đổi tay.');
    end if;
    -- Luật R-CRM-13 (04/11): không tay đổi về L6A, L6B (hệ thống gắn: L6A khi đã làm bài chờ chấm, L6B khi phiếu Hoàn thành).
    if p_substage_code in ('L6A', 'L6B') then
      perform app.raise_error('HMT_L6A_HE_THONG', 'Nhóm con L6A, L6B do hệ thống tự gắn theo phiếu kiểm tra, không đổi tay.');
    end if;
    update app.opportunity set substage_code = p_substage_code where id = p_id;
    return;
  end if;

  -- ===== Sang giai đoạn phía trước =====
  -- Luật R-CRM-13: L6 chỉ do hệ thống chuyển (khi phiếu kiểm tra Hoàn thành), người dùng không bấm tay.
  if p_stage_code = 'L6' then
    perform app.raise_error('HMT_L6_HE_THONG', 'Giai đoạn L6 do hệ thống tự chuyển khi phiếu kiểm tra hoàn thành, không bấm tay.');
  end if;
  -- Luật R-CRM-15: vào L5 thì nhóm con do hệ thống gắn; người dùng không chọn.
  if p_stage_code = 'L5' then
    if p_substage_code is not null then
      perform app.raise_error('HMT_NHOM_CON_L5_HE_THONG', 'Nhóm con của L5 do hệ thống tự gắn theo phiếu kiểm tra, không chọn tay.');
    end if;
    v_substage := app.opportunity_l5_substage(p_id);
  end if;

  -- Luật R-CRM-03: từ L5 trở lên bắt buộc tên và năm sinh học sinh, kể cả khi bấm thẳng L7, L8.
  if v_new_order >= v_l5_order then
    -- Em đầu của danh sách em (hành vi cũ; "ít nhất một em đủ tên và năm sinh" làm ở DB-2).
    select * into v_first from app.prospect_student_v where opportunity_id = p_id order by position limit 1;
    if v_first.full_name is null then
      v_missing := array_append(v_missing, 'tên học sinh');
    end if;
    if v_first.birth_year is null then
      v_missing := array_append(v_missing, 'năm sinh học sinh');
    end if;
    if cardinality(v_missing) > 0 then
      perform app.raise_error('HMT_THIEU_HOC_SINH',
        format('Chưa chuyển được: cơ hội còn thiếu %s.', array_to_string(v_missing, ' và ')));
    end if;
  end if;

  if p_stage_code in ('L7', 'L8') then
    select * into v_state from app.opportunity_test_state(p_id);
    -- Luật R-CRM-12: còn phiếu dang dở thì không sang L7, L8; nêu rõ mã phiếu.
    if v_state.in_progress > 0 then
      perform app.raise_error('HMT_PHIEU_DANG_DO',
        format('Cơ hội còn phiếu kiểm tra đang dở: %s. Hoàn thành hoặc huỷ phiếu trước.',
               array_to_string(v_state.in_progress_codes, ', ')));
    end if;
    -- Luật R-CRM-14: không có phiếu Hoàn thành (không có phiếu, hoặc mọi phiếu đều Huỷ) thì bắt lý do bỏ qua test.
    if v_state.completed = 0 then
      v_skip_code := coalesce(p_skip_reason_code, v_opp.skip_reason_code);
      v_skip_note := case when p_skip_reason_code is not null then nullif(btrim(coalesce(p_skip_note, '')), '')
                          else v_opp.skip_note end;
      if v_skip_code is null then
        perform app.raise_error('HMT_THIEU_LY_DO', 'Cơ hội chưa có phiếu kiểm tra hoàn thành: chọn lý do bỏ qua test.');
      end if;
      perform app.assert_catalog_code_active('TEST_SKIP_REASON', v_skip_code);
      if (select requires_note from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and code = v_skip_code)
         and v_skip_note is null then
        perform app.raise_error('HMT_THIEU_GHI_CHU', 'Chọn "Khác" thì phải ghi chú lý do bỏ qua test.');
      end if;
    end if;
  end if;

  -- Luật R-CRM-16: sang L8 bắt chọn L8A, L8B hoặc L8C và xác nhận (không có Hoàn tác).
  if p_stage_code = 'L8' then
    if p_substage_code is null or p_substage_code not in ('L8A', 'L8B', 'L8C') then
      perform app.raise_error('HMT_L8_CAN_NHOM_CON', 'Chuyển L8 phải chọn nhóm con L8A, L8B hoặc L8C.');
    end if;
    if not coalesce(p_confirm_l8, false) then
      perform app.raise_error('HMT_L8_CAN_XAC_NHAN', 'Chuyển sang L8 không hoàn tác được: xác nhận để tiếp tục.');
    end if;
  end if;

  update app.opportunity
     set stage_code = p_stage_code, substage_code = v_substage,
         skip_reason_code = v_skip_code, skip_note = v_skip_note
   where id = p_id;
end;
$function$;
