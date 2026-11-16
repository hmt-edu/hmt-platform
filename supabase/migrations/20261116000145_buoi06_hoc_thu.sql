-- BUOI-06 Thêm học sinh học thử vào buổi (canvas BUOI06, R-GD-11, R-GD-17, R-CRM-03, R-CRM-27). Làm theo tiền lệ phiếu kiểm tra (R-CRM-27, tìm hoặc tạo hồ sơ học sinh gắn vào cơ hội);
-- Chat 11:55: câu hỏi chưa chốt thì chọn phương án an toàn nhất, ghi rõ để Chat xác nhận hoặc đổi:
--  * cơ hội phải từ L5 trở lên (có em đủ họ tên, năm sinh, R-CRM-03); em chưa có hồ sơ học sinh thì dùng app.find_or_create_student như phiếu kiểm tra, KHÔNG tạo luồng mới;
--  * chỉ buổi Đã chốt (Nháp chưa có danh sách; Done đã khoá); học thử miễn phí, không trừ giờ (is_trial, không ghi danh); tối đa trial_sessions_max_per_opportunity buổi mỗi cơ hội;
--  * không tính vào sĩ số lớp; vượt sĩ số tối đa chỉ cảnh báo; chưa cảnh báo khác khối (cơ hội không có cột khối).
-- Cờ: phân hệ HOC_THU, MẶC ĐỊNH TẮT (chạm danh sách điểm danh); kiểm cả ở giao diện và trong hàm.
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'HOC_THU', 'Học thử vào buổi (BUOI-06)', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('trial_sessions_max_per_opportunity', 'Học thử: số buổi tối đa mỗi cơ hội', 'INT', 'buổi', 1, 20, '2', true, 'VAN_HANH_LOP', 'R-GD-17',
   'Mỗi cơ hội được thêm học thử vào tối đa bấy nhiêu buổi; vượt thì chặn.')
on conflict (key) do nothing;
select set_config('hmt.migration', '', false);

-- Dòng điểm danh học thử nhớ cơ hội đã đưa em vào (để đếm hạn mức R-GD-17).
alter table app.session_attendance add column trial_opportunity_id uuid references app.opportunity (id);
-- Chỉ mục (lý do): đếm số buổi học thử đã dùng của một cơ hội; khoá ngoại.
create index session_attendance_trial_opp_idx on app.session_attendance (trial_opportunity_id) where trial_opportunity_id is not null;

-- app.add_trial_student(buổi, dòng em của cơ hội) -> {attendance_id, student_id, warnings}
-- Thêm một em của cơ hội vào danh sách của buổi Đã chốt làm học thử (R-GD-11: miễn phí, không trừ giờ, không ghi danh; R-GD-17: tối đa trial_sessions_max_per_opportunity buổi mỗi cơ hội,
-- không tính vào sĩ số lớp). Ai gọi: Buổi học · Sửa ở cơ sở của buổi (CSKH, Trưởng cơ sở, Admin). Cần phân hệ HOC_THU bật.
create or replace function app.add_trial_student(p_session_id uuid, p_prospect_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  ps app.prospect_student_v;
  opp app.opportunity;
  c app.class;
  v_student uuid;
  v_max integer;
  v_used integer;
  v_attendance uuid;
  v_active integer;
  v_trials integer;
  v_warnings text[] := '{}';
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  perform app.assert_can('SESSION', 'SUA', s.branch_id);
  -- Luật (BUOI-06: CSKH, Sale, Admin; Trưởng cơ sở): chỉ phạm vi cơ sở hoặc toàn hệ thống; giáo viên theo phân công không thêm học thử.
  if app.permission_scope('SESSION', 'SUA') not in ('CO_SO', 'TOAN_HE_THONG') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thêm học thử vào buổi.');
  end if;
  perform app.require_feature('HOC_THU', s.branch_id);
  -- Luật: chỉ buổi Đã chốt (Nháp chưa có danh sách, Done và buổi huỷ đã khoá).
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_KHONG_THEM_HOC_THU', 'Chỉ thêm học thử vào buổi đang ở Đã chốt.');
  end if;
  select * into ps from app.prospect_student_v where id = p_prospect_student_id;
  if ps.id is null or ps.opportunity_id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy em của cơ hội.');
  end if;
  select * into opp from app.opportunity where id = ps.opportunity_id;
  if opp.branch_id <> s.branch_id then
    perform app.raise_error('HMT_HOC_THU_KHAC_CO_SO', 'Cơ hội thuộc cơ sở khác với buổi học.');
  end if;
  -- Luật R-CRM-03 và tiền lệ phiếu kiểm tra (R-CRM-05): cơ hội từ L5 trở lên mới có em đủ họ tên, năm sinh.
  if (select sort_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = opp.stage_code)
     < (select sort_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5') then
    perform app.raise_error('HMT_CO_HOI_CHUA_DEN_L5', 'Chỉ thêm học thử khi cơ hội đang ở L5 trở đi. Chuyển cơ hội sang L5 trước.');
  end if;
  -- Luật R-GD-17: tối đa trial_sessions_max_per_opportunity buổi mỗi cơ hội, vượt thì chặn.
  v_max := app.get_setting_int('trial_sessions_max_per_opportunity', s.branch_id);
  select count(distinct a.session_id) into v_used
    from app.session_attendance a where a.trial_opportunity_id = opp.id and a.is_trial and a.is_active;
  if v_used >= v_max then
    perform app.raise_error('HMT_HOC_THU_VUOT_HAN_MUC', 'Cơ hội này đã dùng hết số buổi học thử cho phép (' || v_max || ' buổi).');
  end if;
  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh rồi gắn vào dòng em của cơ hội (như phiếu kiểm tra).
  v_student := ps.student_id;
  if v_student is null then
    v_student := app.find_or_create_student(opp.parent_id, ps.full_name, ps.birth_year, ps.birth_date, ps.school, ps.self_rating, ps.goal, opp.branch_id);
    update app.prospect_student set student_id = v_student, full_name = null, birth_date = null, birth_year = null,
           school = null, self_rating = null, goal = null where id = ps.id;
  end if;
  if exists (select from app.session_attendance a where a.session_id = s.id and a.student_id = v_student) then
    perform app.raise_error('HMT_EM_DA_CO_TRONG_BUOI', 'Em này đã có trong danh sách của buổi.');
  end if;
  -- Luật R-GD-11: học thử không ghi danh nên không trừ giờ (enrollment_id để trống).
  insert into app.session_attendance (session_id, class_id, branch_id, student_id, is_active, is_trial, trial_opportunity_id)
  values (s.id, s.class_id, s.branch_id, v_student, true, true, opp.id)
  returning id into v_attendance;
  -- Luật R-GD-17: vượt sĩ số tối đa của lớp chỉ cảnh báo (học thử không tính vào sĩ số lớp, nhưng có tính vào số em của buổi).
  select * into c from app.class where id = s.class_id;
  select count(*) filter (where not a.is_trial), count(*) filter (where a.is_trial) into v_active, v_trials
    from app.session_attendance a where a.session_id = s.id and a.is_active;
  if c.max_students > 0 and v_active + v_trials > c.max_students then
    v_warnings := v_warnings || 'Buổi vượt sĩ số tối đa của lớp (chỉ cảnh báo).';
  end if;
  return jsonb_build_object('attendance_id', v_attendance, 'student_id', v_student, 'warnings', to_jsonb(v_warnings));
end;
$$;

revoke execute on function app.add_trial_student(uuid, uuid) from public, anon, authenticated;
grant execute on function app.add_trial_student(uuid, uuid) to authenticated;
