-- TS-15 Tạo phiếu kiểm tra: CHỌN EM trong danh sách em của cơ hội (canvas 9933: TS15_hop, TS15_chon_em, TS15_hai_phieu; R-CRM-23, R-CRM-27, R-CRM-03).
-- Trước đây phiếu luôn lấy em đầu. Nay p_data nhận thêm khoá prospect_student_id (id dòng em của chính cơ hội); không có khoá thì lấy em đầu như cũ.
-- Em không thuộc cơ hội: HMT_EM_KHONG_THUOC_CO_HOI. Cơ hội chưa có em nào: HMT_CO_HOI_CHUA_CO_EM (trước đây lỗi khó hiểu khi tạo hồ sơ học sinh không tên).
-- Các luật khác của hàm giữ nguyên (L5 trở đi, ngày giờ tương lai, môn khối hình thức cấp độ, người phụ trách, R-CRM-27 tìm hoặc tạo hồ sơ học sinh).
-- Chữ ký không đổi (không mất quyền thực thi đã cấp); không thêm chỉ mục.

CREATE OR REPLACE FUNCTION app.create_student_test(p_opportunity_id uuid, p_data jsonb, p_reminder_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_reminder_activity text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_opp app.opportunity;
  v_stage_order integer;
  v_l5_order integer;
  v_scheduled timestamptz := nullif(p_data ->> 'scheduled_at', '')::timestamptz;
  v_subject text := nullif(p_data ->> 'subject_code', '');
  v_grade text := nullif(p_data ->> 'grade_code', '');
  v_mode text := nullif(p_data ->> 'mode_code', '');
  v_level text := nullif(p_data ->> 'level_code', '');
  v_owner uuid;
  v_test_branch uuid;
  v_room uuid := nullif(p_data ->> 'room_id', '')::uuid;
  v_grader uuid := nullif(p_data ->> 'grader_id', '')::uuid;
  v_student_id uuid;
  v_line app.prospect_student_v;
  v_student_code text;
  v_id uuid;
  v_code text;
begin
  select * into v_opp from app.opportunity where id = p_opportunity_id for update;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('STUDENT_TEST', 'TAO', v_opp.branch_id);
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo phiếu được.');
  end if;

  -- Luật R-CRM-05: chỉ tạo khi cơ hội đang ở L5 trở đi (chặn trong hàm; nút mờ ở giao diện chỉ là gợi ý).
  select sort_order into v_stage_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';
  if v_stage_order < v_l5_order then
    perform app.raise_error('HMT_CO_HOI_CHUA_DEN_L5', 'Chỉ tạo phiếu kiểm tra khi cơ hội đang ở L5 trở đi. Chuyển cơ hội sang L5 trước.');
  end if;

  -- Luật R-CRM-05: ngày giờ test bắt buộc và ở tương lai (anh chốt 18/10).
  if v_scheduled is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày và giờ test.');
  end if;
  if v_scheduled <= now() then
    perform app.raise_error('HMT_GIO_TEST_QUA_KHU', 'Giờ test phải ở tương lai.');
  end if;
  -- Luật: môn, khối, hình thức, cấp độ đề bắt buộc, lấy từ danh mục đang dùng (R-CRM-10).
  if v_subject is null or v_grade is null or v_mode is null or v_level is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn đủ môn, khối, hình thức test và cấp độ đề.');
  end if;
  perform app.assert_catalog_code_active('SUBJECT', v_subject);
  perform app.assert_catalog_code_active('GRADE', v_grade);
  perform app.assert_catalog_code_active('TEST_MODE', v_mode);
  perform app.assert_catalog_code_active('TEST_LEVEL', v_level);

  -- Luật: người phụ trách mặc định là người tạo; giao cho người khác cần quyền Giao việc.
  v_owner := coalesce(nullif(p_data ->> 'owner_id', '')::uuid, auth.uid());
  if v_owner <> auth.uid() then
    perform app.assert_can('STUDENT_TEST', 'GIAO_VIEC', v_opp.branch_id);
    perform app.assert_staff_in_branch(v_owner, v_opp.branch_id);
  end if;
  v_test_branch := coalesce(nullif(p_data ->> 'test_branch_id', '')::uuid, app.current_branch_id(), v_opp.branch_id);
  if v_grader is not null then
    perform app.assert_grader(v_grader);
  end if;

  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh (phụ huynh + tên chuẩn hoá + năm sinh), gắn vào cơ hội.
  -- Danh sách em (R-CRM-23, TS-15): p_data.prospect_student_id chọn em trong danh sách của cơ hội; không có khoá này thì lấy em đầu (hành vi cũ).
  if nullif(p_data ->> 'prospect_student_id', '') is not null then
    select * into v_line from app.prospect_student_v
     where id = (p_data ->> 'prospect_student_id')::uuid and opportunity_id = v_opp.id;
    if v_line.id is null then
      perform app.raise_error('HMT_EM_KHONG_THUOC_CO_HOI', 'Em được chọn không thuộc cơ hội này.');
    end if;
  else
    select * into v_line from app.prospect_student_v where opportunity_id = v_opp.id order by position limit 1;
  end if;
  -- Luật R-CRM-23: phiếu kiểm tra cần một em trong danh sách của cơ hội (không tạo em mới ở đây).
  if v_line.id is null then
    perform app.raise_error('HMT_CO_HOI_CHUA_CO_EM', 'Cơ hội chưa có em. Thêm em ở hồ sơ cơ hội trước khi tạo phiếu kiểm tra.');
  end if;
  v_student_id := v_line.student_id;
  if v_student_id is null then
    v_student_id := app.find_or_create_student(v_opp.parent_id, v_line.full_name, v_line.birth_year,
                                               v_line.birth_date, v_line.school, v_line.self_rating, v_line.goal,
                                               v_opp.branch_id);
    -- Dòng em gắn hồ sơ học sinh vừa tìm hoặc tạo; từ đây đọc thẳng từ hồ sơ (Đ86).
    update app.prospect_student set student_id = v_student_id, full_name = null, birth_date = null, birth_year = null,
           school = null, self_rating = null, goal = null where id = v_line.id;
  end if;
  select code into v_student_code from app.student where id = v_student_id;

  v_code := app.issue_crm_code('PKT');
  insert into app.student_test (
    code, opportunity_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code, grade_code, mode_code,
    level_code, exam_name, scheduled_at, room_id, grader_id, owner_id, prospect_student_id)
  values (
    v_code, v_opp.id, v_student_id, v_opp.branch_id, v_test_branch, coalesce(app.current_branch_id(), v_opp.branch_id),
    v_subject, v_grade, v_mode, v_level, nullif(btrim(coalesce(p_data ->> 'exam_name', '')), ''), v_scheduled, v_room,
    v_grader, v_owner, v_line.id)
  returning id into v_id;

  -- Luật R-CRM-05: tự sinh lịch hẹn nhắc cùng phiếu.
  perform app.ensure_test_reminder(v_id, p_reminder_at, p_reminder_activity);
  -- Luật R-CRM-15: cơ hội đang ở L5 thì nhóm con tính lại (có phiếu Nháp → L5B).
  perform app.refresh_opportunity_l5_substage(v_opp.id);

  return jsonb_build_object('id', v_id, 'code', v_code, 'student_id', v_student_id, 'student_code', v_student_code);
end;
$function$;
