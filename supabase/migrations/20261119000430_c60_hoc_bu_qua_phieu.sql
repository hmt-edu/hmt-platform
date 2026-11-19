-- C60 CS-11 phần Học bù (Chat 16:44 mục 1, R-BUOI-03 thắng canvas CSN06e): phiếu Đổi lịch hành động HOC_BU sinh buổi Học bù MỚI cho em của ticket (không chọn buổi có sẵn), không trừ giờ.
-- Xây trên execute_ticket_task của migration 429 (CS-11 dời buổi, đổi ca; PR #297): gộp 429 trước.
select set_config('hmt.migration', 'on', false);

-- app.apply_makeup_session(lớp, em, ngày, giờ bắt đầu, giờ kết thúc, phòng, lý do, cơ sở của phiếu): NỘI BỘ cho phiếu Đổi lịch hành động HOC_BU đã duyệt (C60 CS-11, R-BUOI-03, R-BUOI-01).
-- Làm cùng việc app.save_makeup_request + app.approve_session_request (migration 141, 305) nhưng KHÔNG đòi quyền Buổi học · Tạo/Duyệt của người bấm Thực hiện: quyền đã ở phiếu (TICKET · Sửa, duyệt quản lý cơ sở).
-- Luật: lớp cùng cơ sở phiếu và đã duyệt; em đang học trong lớp; ngày không ở quá khứ; giờ kết thúc sau giờ bắt đầu; phòng thuộc cơ sở lớp; cờ YEU_CAU_BUOI bật; sinh yêu cầu ở trạng thái Đã duyệt (có mã YB) và buổi loại Học bù do lớp (giáo viên lấy khung giờ lớp), danh sách chỉ em được chọn, không trừ giờ.
-- Kết quả: id buổi mới. Lỗi: HMT_KHONG_TIM_THAY, HMT_PHIEU_DU_LIEU_SAI, HMT_LOP_CHUA_DUYET, HMT_EM_KHONG_TRONG_LOP, HMT_NGAY_BUOI_QUA_KHU, HMT_BUOI_GIO_SAI, HMT_PHONG_KHONG_CO, HMT_THIEU_LY_DO, HMT_TINH_NANG_TAT.
create or replace function app.apply_makeup_session(p_class_id uuid, p_student_id uuid, p_date date, p_start time, p_end time, p_room_id uuid, p_reason text, p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_code text;
  v_branch_code text;
  v_req uuid;
  v_session uuid;
  v_teacher uuid;
begin
  select * into c from app.class where id = p_class_id;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  if c.branch_id is distinct from p_branch_id then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Lớp phải cùng cơ sở với phiếu.');
  end if;
  perform app.require_feature('YEU_CAU_BUOI', c.branch_id);
  if c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_LOP_CHUA_DUYET', 'Chỉ lớp đã duyệt mới có buổi học bù.');
  end if;
  -- Luật R-BUOI-03: lý do bắt buộc.
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Nhập lý do học bù.');
  end if;
  if p_student_id is null or not exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                          where ec.class_id = c.id and e.student_id = p_student_id and ec.end_date is null) then
    perform app.raise_error('HMT_EM_KHONG_TRONG_LOP', 'Em của ticket không đang học trong lớp này.');
  end if;
  if p_date is null or p_start is null or p_end is null or p_end <= p_start then
    perform app.raise_error('HMT_BUOI_GIO_SAI', 'Cần ngày, giờ bắt đầu và giờ kết thúc sau giờ bắt đầu.');
  end if;
  if p_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    perform app.raise_error('HMT_NGAY_BUOI_QUA_KHU', 'Ngày buổi học bù đã qua.');
  end if;
  if p_room_id is not null and not exists (select from app.room where id = p_room_id and branch_id = c.branch_id and is_active) then
    perform app.raise_error('HMT_PHONG_KHONG_CO', 'Phòng không có hoặc đã Ngừng ở cơ sở của lớp.');
  end if;
  select code into v_branch_code from app.branch where id = c.branch_id;
  v_code := app.issue_document_number('YB', v_branch_code);
  v_teacher := (select sl.teacher_id from app.class_slot sl where sl.class_id = c.id and sl.is_active order by sl.weekday, sl.start_time limit 1);
  insert into app.session_request (code, branch_id, kind, class_id, session_date, start_time, end_time, room_id, note, teacher_id, reason, status_code, decided_at, decided_by)
  values (v_code, c.branch_id, 'HOC_BU', c.id, p_date, p_start, p_end, p_room_id, null, v_teacher, btrim(p_reason), 'DA_DUYET', now(), (select auth.uid()))
  returning id into v_req;
  insert into app.session_request_student (request_id, student_id) values (v_req, p_student_id);
  insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id, type_code, status_code, is_manual, no_charge)
  values (c.id, c.branch_id, p_date, p_start, p_end, v_teacher, null, p_room_id, 'HOC_BU', 'NHAP', true, false)
  returning id into v_session;
  perform app.renumber_class_sessions(c.id);
  update app.session_request set created_session_id = v_session where id = v_req;
  return v_session;
end;
$$;
revoke execute on function app.apply_makeup_session(uuid, uuid, date, time, time, uuid, text, uuid) from public, anon, authenticated;

create or replace function app.execute_ticket_task(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  v_entity text;
  v_ch jsonb;
  v_target uuid;
  v_before jsonb;
  v_grade smallint;
  v_new uuid;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  perform app.assert_can('TICKET', 'SUA', k.branch_id);
  if k.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ thực hiện phiếu đã duyệt.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  -- Luật R-V2-24: phiếu đã có cấp duyệt riêng nên áp dụng THẲNG bảo lưu, chuyển lớp (bản ghi đã duyệt, thực hiện ngay trong giao dịch này), không duyệt lần hai.
  -- Hàm áp dụng kiểm cờ BAO_LUU, CHUYEN_LOP và mọi luật như bản tạo thường (R-GD-09, R-GD-10). Mã ticket gắn vào bản ghi để truy ngược (R-CS-02).
  if k.task_type = 'BAO_LUU' then
    -- C31: Tiếp tục học (quay lại sớm): kết thúc bảo lưu, ghi danh về hàng chờ xếp lớp, giữ nguyên giờ (R-GD-09); không tự xếp lớp.
    if k.payload ->> 'resume' = 'true' then
      v_new := app.apply_enrollment_resume((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    else
      v_new := app.apply_enrollment_hold((k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'months')::integer, k.payload ->> 'reason_code',
                                         nullif(k.payload ->> 'note', ''), t.code, nullif(k.payload ->> 'extends_hold_id', '')::uuid);
    end if;
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('hold_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  elsif k.task_type = 'CHUYEN_LOP' then
    v_new := app.apply_class_transfer((k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'to_class_id')::uuid, (k.payload ->> 'start_date')::date,
                                      k.payload ->> 'kind_code', k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('transfer_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  -- Luật R-V2-24, R-TIEN-34, R-CS-02: phiếu Hoàn học phí đã qua cấp quản lý cơ sở và kế toán nên áp dụng THẲNG (tạo yêu cầu đã qua quản lý, tính tiền, ghi sổ giờ ngược dấu, lập phiếu chi), không duyệt lần hai. Cờ HOAN_PHI do hàm áp dụng kiểm (migration 235).
  -- Người duyệt từng cấp lấy từ nhật ký phiếu (cấp 1 quản lý cơ sở, cấp 2 kế toán) và ghi đúng vào yêu cầu hoàn phí, để luật hai người duyệt khác nhau còn hiệu lực (R-TIEN-01).
  elsif k.task_type = 'HOAN_PHI' then
    if nullif(k.payload ->> 'enrollment_id', '') is null or k.payload ->> 'kind' is null or k.payload ->> 'kind' not in ('TOAN_BO', 'MOT_PHAN')
       or nullif(btrim(coalesce(k.payload ->> 'reason_code', '')), '') is null
       or (k.payload ->> 'kind' = 'MOT_PHAN' and coalesce(nullif(k.payload ->> 'hours', '')::numeric, 0) <= 0) then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Hoàn học phí cần ghi danh, lý do, hình thức hoàn (toàn bộ hoặc một phần, một phần cần số giờ hoàn).');
    end if;
    v_new := app.apply_refund_request((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'kind', nullif(k.payload ->> 'hours', '')::numeric,
                                      k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code,
                                      (select ev.created_by from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq limit 1),
                                      (select ev.created_by from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq offset 1 limit 1));
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('payment_voucher_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  -- C60 CS-14 (R-GD-16, R-TIEN-33, R-V2-24, R-CS-02): phiếu Dừng học đã qua quản lý cơ sở và kế toán nên áp dụng THẲNG: huỷ giờ tặng, ghi sổ giờ ngược dấu, ghi danh sang Dừng, giờ còn lại giữ thành số dư khách hàng. Cờ DUNG_HOC kiểm trong hàm áp dụng.
  elsif k.task_type = 'DUNG_HOC' then
    if nullif(k.payload ->> 'enrollment_id', '') is null or nullif(btrim(coalesce(k.payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Dừng học cần ghi danh và lý do.');
    end if;
    v_new := app.apply_enrollment_stop((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('stop_id', v_new) where id = k.id;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  -- C60 CS-11 (R-CS-03, R-BUOI-03 thắng canvas CSN06e, R-LOP-10, R-V2-24): phiếu Đổi lịch học đã qua quản lý cơ sở nên áp dụng THẲNG, không duyệt lần hai. Ba hành động:
  --   DOI_BUOI: dời MỘT buổi (ngày, giờ, phòng) bằng app.apply_session_move; DOI_CA: đổi ca cố định = sửa Time Table ở màn Sửa lớp (R-LOP-10), phiếu chỉ ghi nhận làm tay;
  --   HOC_BU: yêu cầu học bù (R-BUOI-03: quản lý duyệt SINH buổi mới, không chọn buổi có sẵn): làm ở PR sau, hiện báo chưa làm.
  elsif k.task_type = 'DOI_LICH' then
    if k.payload ->> 'action' = 'DOI_BUOI' then
      begin
        v_new := app.apply_session_move((k.payload ->> 'session_id')::uuid, (k.payload ->> 'date')::date, (k.payload ->> 'start')::time, (k.payload ->> 'end')::time,
                                        nullif(k.payload ->> 'room_id', '')::uuid, t.branch_id);
      exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Đổi lịch cần buổi, ngày, giờ bắt đầu và giờ kết thúc hợp lệ.');
      end;
      update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('session_id', v_new) where id = k.id;
    elsif k.payload ->> 'action' = 'DOI_CA' then
      update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(),
             result = jsonb_build_object('note', 'Đổi ca cố định làm ở màn Sửa lớp (Time Table, R-LOP-10); phiếu ghi nhận.') where id = k.id;
    elsif k.payload ->> 'action' = 'HOC_BU' then
      -- R-BUOI-03: quản lý duyệt (ở phiếu) thì SINH buổi Học bù mới cho em của ticket, không chọn buổi có sẵn; không trừ giờ.
      begin
        v_new := app.apply_makeup_session((k.payload ->> 'class_id')::uuid, t.student_id, (k.payload ->> 'date')::date, (k.payload ->> 'start')::time,
                                          (k.payload ->> 'end')::time, nullif(k.payload ->> 'room_id', '')::uuid, nullif(k.payload ->> 'note', ''), t.branch_id);
      exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Học bù cần lớp, ngày, giờ bắt đầu và giờ kết thúc hợp lệ.');
      end;
      update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('session_id', v_new) where id = k.id;
    else
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Đổi lịch cần chọn hành động: dời một buổi hoặc đổi ca cố định.');
    end if;
    perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
    perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
    return;
  elsif k.task_type <> 'CAP_NHAT_HO_SO' then
    perform app.raise_error('HMT_PHIEU_CHUA_LAM', 'Loại phiếu này chưa thực hiện được ở bản hiện tại.');
  end if;
  v_entity := k.payload ->> 'entity';
  v_ch := k.payload -> 'changes';
  if v_entity = 'STUDENT' then
    v_target := t.student_id;
    if v_target is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh.');
    end if;
    select jsonb_build_object('school', s.school, 'school_type', s.school_type, 'grade', s.grade, 'goal', s.goal, 'gender', s.gender) into v_before from app.student s where s.id = v_target;
    if v_ch ? 'grade' then
      v_grade := nullif(v_ch ->> 'grade', '')::smallint;
    end if;
    -- Luật: chỉ cập nhật khoá có trong phiếu; các trường khác giữ nguyên (không dùng SQL động).
    update app.student s set
      school = case when v_ch ? 'school' then nullif(btrim(v_ch ->> 'school'), '') else s.school end,
      school_type = case when v_ch ? 'school_type' then nullif(btrim(v_ch ->> 'school_type'), '') else s.school_type end,
      grade = case when v_ch ? 'grade' then v_grade else s.grade end,
      goal = case when v_ch ? 'goal' then nullif(btrim(v_ch ->> 'goal'), '') else s.goal end,
      gender = case when v_ch ? 'gender' then nullif(btrim(v_ch ->> 'gender'), '') else s.gender end
     where s.id = v_target;
  else
    -- PARENT: phụ huynh của ticket, hoặc phụ huynh của học sinh gắn ticket.
    v_target := coalesce(t.parent_id, (select s.parent_id from app.student s where s.id = t.student_id));
    if v_target is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không xác định được phụ huynh để cập nhật.');
    end if;
    select jsonb_build_object('full_name', p.full_name, 'address', p.address, 'relative_name', p.relative_name) into v_before from app.parent p where p.id = v_target;
    update app.parent p set
      full_name = case when v_ch ? 'full_name' then coalesce(nullif(btrim(v_ch ->> 'full_name'), ''), p.full_name) else p.full_name end,
      address = case when v_ch ? 'address' then nullif(btrim(v_ch ->> 'address'), '') else p.address end,
      relative_name = case when v_ch ? 'relative_name' then nullif(btrim(v_ch ->> 'relative_name'), '') else p.relative_name end
     where p.id = v_target;
  end if;
  update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(),
         result = jsonb_build_object('entity', v_entity, 'record_id', v_target, 'before', v_before, 'changes', v_ch)
   where id = k.id;
  perform app.ticket_task_log(k, 'THUC_HIEN', 'DA_DUYET', 'DA_THUC_HIEN', null);
  perform app.ticket_task_finish_ticket(k.ticket_id, 'Phiếu ' || k.code || ' đã thực hiện.');
end;
$$;
select set_config('hmt.migration', '', false);
