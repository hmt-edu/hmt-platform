-- C-23-14 (Chat 14:17, anh OK 23/11 14:17; rủi ro CAO: quyền). Chỉ CSKH và Trưởng cơ sở (cơ sở mình) được Thực hiện và Huỷ phiếu nghiệp vụ; Tư vấn, Giáo viên, Trợ giảng chỉ xem.
-- Trước đây hai hàm chỉ kiểm quyền Ticket · Sửa nên Tư vấn (có Sửa) cũng bấm được. Cách làm: thêm hành động «Thực hiện phiếu» (THUC_HIEN) vào danh mục hành động của ma trận quyền, cấp cho
-- CSKH, Trưởng cơ sở (cơ sở mình) và Admin (toàn hệ thống) ở phân hệ Ticket; Ban giám đốc không thêm. Hai hàm app.execute_ticket_task (bản 618) và app.cancel_ticket_task (bản 226)
-- gọi thêm app.assert_can('TICKET', 'THUC_HIEN', cơ sở của phiếu) (mã HMT_KHONG_CO_QUYEN). Ma trận hiện cho Tư vấn: Ticket Xem, Tạo, Sửa (chỉ Thực hiện/Huỷ phiếu bị bỏ, không đổi gì khác).
-- Luật: R-CS-02, R-V2-24, R-TIEN-01. Chỉ mục: không thêm (không bảng, cột mới).
select set_config('hmt.migration', 'on', false);

-- Mục có luật trong code bám vào: đổi tên được, không Ngừng được (is_locked).
insert into app.catalog_item (catalog_code, code, name, sort_order, is_locked)
values ('PERM_ACTION', 'THUC_HIEN', 'Thực hiện phiếu', 8, true)
on conflict (catalog_code, code) do nothing;

insert into app.permission (role_code, module_code, action_code, scope_code)
values ('ADMIN', 'TICKET', 'THUC_HIEN', 'TOAN_HE_THONG'),
       ('BRANCH_MANAGER', 'TICKET', 'THUC_HIEN', 'CO_SO'),
       ('CSKH', 'TICKET', 'THUC_HIEN', 'CO_SO')
on conflict (role_code, module_code, action_code) do update set scope_code = excluded.scope_code, is_active = true;

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
  -- C-23-14 (anh OK 23/11 14:17): chỉ vai trò có quyền «Thực hiện phiếu» (ma trận quyền: CSKH, Trưởng cơ sở, Admin) ở cơ sở của phiếu; Tư vấn, Giáo viên, Trợ giảng chỉ xem.
  perform app.assert_can('TICKET', 'THUC_HIEN', k.branch_id);
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
    -- CS-14: Hoàn tiền = yêu cầu hoàn phí TOÀN BỘ theo R-TIEN-28 (phí xử lý, phiếu chi), người duyệt từng cấp lấy từ nhật ký phiếu như phiếu Hoàn học phí (R-TIEN-01);
    -- Giữ số dư (mặc định, như trước) = giờ còn lại × giá sau chiết khấu thành số dư khách hàng (R-TIEN-33). Giờ tặng còn lại đều bị huỷ.
    if k.payload ->> 'money_mode' = 'HOAN_TIEN' then
      v_new := app.apply_refund_request((k.payload ->> 'enrollment_id')::uuid, 'TOAN_BO', null, k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code,
                                        (select ev.created_by from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq limit 1),
                                        (select ev.created_by from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' order by ev.seq offset 1 limit 1));
      update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('payment_voucher_id', v_new, 'money_mode', 'HOAN_TIEN') where id = k.id;
    else
      v_new := app.apply_enrollment_stop((k.payload ->> 'enrollment_id')::uuid, k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
      update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('stop_id', v_new, 'money_mode', 'GIU_SO_DU') where id = k.id;
    end if;
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
  -- CS-10 (anh chốt 23:17; R-GD-10 mục 9, R-TIEN-33): phiếu Chuyển phí đã qua quản lý cơ sở và kế toán nên áp dụng THẲNG: dừng ghi danh cũ, tiền còn = giờ còn × giá sau chiết khấu chụp lúc mua giữ thành số dư khách hàng (không tự hoàn tiền).
  -- Đơn Nháp cho Sale và việc dùng số dư vào đơn mới làm ở bước sau (cơ chế DUNG_CHO_DON chưa có).
  elsif k.task_type = 'CHUYEN_PHI' then
    if nullif(k.payload ->> 'enrollment_id', '') is null or nullif(btrim(coalesce(k.payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu Chuyển phí cần ghi danh và lý do.');
    end if;
    v_new := app.apply_fee_transfer((k.payload ->> 'enrollment_id')::uuid, nullif(k.payload ->> 'to_parent_id', '')::uuid,
                                    k.payload ->> 'reason_code', nullif(k.payload ->> 'note', ''), t.code);
    update app.ticket_task set status_code = 'DA_THUC_HIEN', executed_at = now(), result = jsonb_build_object('balance_entry_id', v_new) where id = k.id;
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

create or replace function app.cancel_ticket_task(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  perform app.assert_can('TICKET', 'SUA', k.branch_id);
  -- C-23-14 (anh OK 23/11 14:17): chỉ vai trò có quyền «Thực hiện phiếu» (ma trận quyền: CSKH, Trưởng cơ sở, Admin) ở cơ sở của phiếu; Tư vấn, Giáo viên, Trợ giảng chỉ xem.
  perform app.assert_can('TICKET', 'THUC_HIEN', k.branch_id);
  if k.status_code not in ('NHAP', 'CHO_DUYET', 'DA_DUYET') then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu đã xong hoặc đã đóng, không huỷ được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_PHIEU_THIEU_LY_DO', 'Huỷ phiếu cần ghi lý do.');
  end if;
  update app.ticket_task set status_code = 'DA_HUY', cancel_reason = v_reason where id = k.id;
  perform app.ticket_task_log(k, 'HUY', k.status_code, 'DA_HUY', v_reason);
end;
$$;

select set_config('hmt.migration', '', false);
