-- D-23-07 (anh duyệt 23/11/2026; Chat chốt 02:32; migration 618; rủi ro CAO: tiền). CS-14 Thực hiện dừng học theo canvas CSN06e_dung_hoc.
-- Làm gì: (1) tham số stop_date_max_days_ahead (số ngày tối đa «Ngày dừng» được sau hôm nay, mặc định 0); (2) create_ticket_task (bản 571) kiểm sớm payload Dừng học: money_mode, stop_date;
-- (3) execute_ticket_task (bản 567, giữ nguyên mọi nhánh khác) nhánh DUNG_HOC: money_mode HOAN_TIEN gọi apply_refund_request toàn bộ (R-TIEN-28), GIU_SO_DU (mặc định) như cũ.
-- Ngày dừng chỉ ghi nhận trong payload, KHÔNG đổi cách tính giờ. Chỉ mục: không thêm (không bảng, cột mới). Luật: R-GD-16, R-TIEN-28, R-TIEN-33, R-V2-24.
select set_config('hmt.migration', 'on', false);

insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('stop_date_max_days_ahead', 'Ngày dừng học được sau hôm nay tối đa', 'INT', 'ngày', 0, 30, '0', false, 'VAN_HANH_LOP', 'R-GD-16',
        'Phiếu Dừng học: «Ngày dừng» chỉ ghi nhận, không được sau hôm nay quá số ngày này (0 = không được sau hôm nay).')
on conflict (key) do nothing;

create or replace function app.create_ticket_task(p_ticket_id uuid, p_type text, p_reason text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_biz text;
  v_levels text[];
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_entity text;
  v_key text;
  v_enr app.enrollment;
  v_enr_id uuid;
  v_dest uuid;
begin
  select * into t from app.ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không tạo phiếu được.');
  end if;
  if v_reason is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập lý do của phiếu.');
  end if;
  -- QT-15: cấp duyệt theo phiên bản có hiệu lực tại ngày lập phiếu (app.ticket_task_levels); phiếu chụp lại cấp duyệt lúc tạo (ticket_task.levels).
  v_levels := app.ticket_task_levels(p_type, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  if v_levels is null then
    perform app.raise_error('HMT_PHIEU_LOAI_SAI', 'Loại phiếu nghiệp vụ không có.');
  end if;
  -- Luật R-V2-24: nhóm con của ticket phải có phiếu nghiệp vụ đúng loại.
  select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
  if v_biz is distinct from p_type then
    perform app.raise_error('HMT_PHIEU_KHAC_NHOM', 'Nhóm con của ticket này không dùng loại phiếu đã chọn.');
  end if;
  -- Luật AS-10: mỗi ticket một phiếu đang mở.
  if exists (select from app.ticket_task k where k.ticket_id = t.id and k.status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO', 'Ticket này đã có một phiếu đang mở. Xong hoặc huỷ phiếu đó trước.');
  end if;
  -- CS-14 (anh chốt 23/11/2026, thẻ D-23-07): phiếu Dừng học chọn «Xử lý tiền còn lại» (HOAN_TIEN hoặc GIU_SO_DU, trống = GIU_SO_DU như trước) và «Ngày dừng»
  -- (chỉ ghi nhận, không đổi cách tính giờ; không sau hôm nay quá tham số stop_date_max_days_ahead). Luật R-GD-16, R-TIEN-28, R-TIEN-33.
  if p_type = 'DUNG_HOC' then
    if nullif(p_payload ->> 'money_mode', '') is not null and p_payload ->> 'money_mode' not in ('HOAN_TIEN', 'GIU_SO_DU') then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Xử lý tiền còn lại chỉ chọn Hoàn tiền hoặc Giữ số dư.');
    end if;
    if nullif(p_payload ->> 'stop_date', '') is not null then
      begin
        if (p_payload ->> 'stop_date')::date > (now() at time zone 'Asia/Ho_Chi_Minh')::date + app.get_setting_int('stop_date_max_days_ahead', t.branch_id)::integer then
          perform app.raise_error('HMT_DUNG_HOC_NGAY_SAI', 'Ngày dừng không được sau hôm nay quá số ngày cho phép.');
        end if;
      exception when invalid_datetime_format or datetime_field_overflow then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ngày dừng không hợp lệ.');
      end;
    end if;
  end if;
  -- Kiểm sớm dữ liệu phiếu Cập nhật hồ sơ.
  if p_type = 'CAP_NHAT_HO_SO' then
    v_entity := p_payload ->> 'entity';
    if v_entity is null or v_entity not in ('PARENT', 'STUDENT') or jsonb_typeof(p_payload -> 'changes') is distinct from 'object' or (p_payload -> 'changes') = '{}'::jsonb then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn hồ sơ (phụ huynh hoặc học sinh) và ít nhất một trường cần sửa.');
    end if;
    if v_entity = 'STUDENT' and t.student_id is null then
      perform app.raise_error('HMT_TICKET_THIEU_HOC_SINH', 'Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.');
    end if;
    for v_key in select jsonb_object_keys(p_payload -> 'changes') loop
      if not exists (select from app.ticket_task_field f where f.entity = v_entity and f.field_code = v_key and f.is_active) then
        perform app.raise_error('HMT_PHIEU_TRUONG_SAI', 'Trường này không được sửa bằng phiếu Cập nhật hồ sơ.');
      end if;
    end loop;
  -- Luật R-V2-24, R-CS-02: phiếu Bảo lưu, Chuyển lớp mang dữ liệu để thực hiện bằng hàm của cụm Ghi danh (migration 234); kiểm sớm để báo lỗi ngay lúc tạo.
  elsif p_type in ('BAO_LUU', 'CHUYEN_LOP', 'CHUYEN_PHI') then
    begin
      v_enr_id := nullif(p_payload ->> 'enrollment_id', '')::uuid;
    exception when others then
      v_enr_id := null;
    end;
    select * into v_enr from app.enrollment where id = v_enr_id;
    if v_enr.id is null or t.student_id is null or v_enr.student_id is distinct from t.student_id or v_enr.branch_id <> t.branch_id then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn ghi danh của học sinh gắn với ticket (cùng cơ sở).');
    end if;
    if nullif(btrim(coalesce(p_payload ->> 'reason_code', '')), '') is null then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lý do.');
    end if;
    if p_type = 'CHUYEN_PHI' then
      -- CS-10 (anh chốt 23:17, R-GD-10 mục 9): ghi danh cũ phải còn hiệu lực; phụ huynh nhận số dư tuỳ chọn (anh chị em), trống thì giữ ở phụ huynh của ghi danh.
      if v_enr.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không còn hiệu lực để chuyển phí.');
      end if;
      if nullif(p_payload ->> 'to_parent_id', '') is not null
         and not exists (select from app.parent pa where pa.id = nullif(p_payload ->> 'to_parent_id', '')::uuid) then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phụ huynh nhận số dư không tồn tại.');
      end if;
    elsif p_type = 'BAO_LUU' then
      if p_payload ->> 'resume' = 'true' then
        -- C30/C31 (R-GD-09, R-CS-02): Tiếp tục học (quay lại sớm) là hành động thứ ba của phiếu Bảo lưu; ghi danh phải đang có bảo lưu chạy.
        if not exists (select from app.enrollment_hold h where h.enrollment_id = v_enr.id and h.status_code = 'DANG_BAO_LUU') then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không có bảo lưu đang chạy để tiếp tục học.');
        end if;
      elsif coalesce(nullif(p_payload ->> 'months', '')::integer, 0) < 1 then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Nhập số tháng bảo lưu (từ 1).');
      end if;
    else
      -- CS-07 (anh chốt 23:17, R-GD-10, R-CS-07): Chuyển cơ sở đi hai cấp duyệt tuần tự (quản lý cơ sở ĐI rồi quản lý cơ sở ĐẾN); lớp mới và ngày bắt đầu do quản lý cơ sở ĐẾN chọn ở cấp của họ, nên lúc tạo chỉ cần cơ sở đích.
      if p_payload ->> 'kind_code' = 'CHUYEN_CO_SO' then
        begin
          v_dest := nullif(p_payload ->> 'dest_branch_id', '')::uuid;
        exception when others then
          v_dest := null;
        end;
        if v_dest is null or v_dest = t.branch_id
           or not exists (select from app.branch b where b.id = v_dest and b.is_active and not b.is_office) then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn cơ sở đích: cơ sở dạy học đang hoạt động, khác cơ sở của ticket.');
        end if;
        v_levels := array['QUAN_LY_CO_SO', 'QUAN_LY_CO_SO_DICH'];
      elsif nullif(p_payload ->> 'to_class_id', '') is null or nullif(p_payload ->> 'start_date', '') is null or nullif(p_payload ->> 'kind_code', '') is null then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp mới, ngày bắt đầu và loại chuyển.');
      end if;
    end if;
  end if;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('PNV', v_branch_code);
  insert into app.ticket_task (code, ticket_id, branch_id, task_type, reason, payload, levels, dest_branch_id)
  values (v_code, t.id, t.branch_id, p_type, v_reason, coalesce(p_payload, '{}'::jsonb), v_levels, v_dest) returning id into v_id;
  perform app.ticket_task_log((select k from app.ticket_task k where k.id = v_id), 'TAO', null, 'NHAP', null);
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

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

select set_config('hmt.migration', '', false);
