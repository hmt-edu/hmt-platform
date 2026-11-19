-- C31 (CS-09 Tiếp tục học, canvas CSN06b_tiep_tuc; Chat 10:00 mục 1; R-GD-09, R-CS-02, R-V2-24): Tiếp tục học (quay lại sớm) là hành động thứ ba của phiếu Bảo lưu, cùng ticket.
-- Luật: giữ nguyên giờ; khi thực hiện, bảo lưu kết thúc (QUAY_LAI_SOM), dòng xếp lớp cũ đóng, ghi danh về hàng chờ xếp lớp (CHO_XEP_LOP) để CSKH xếp lớp như thường; KHÔNG tự xếp lớp.
-- Em quay lại danh sách buổi chỉ sau khi được xếp lớp.
-- Làm gì: (1) hàm nội bộ app.apply_enrollment_resume; (2) create_ticket_task nhận payload {resume: true} cho phiếu BAO_LUU, không đòi số tháng, đòi ghi danh có bảo lưu đang chạy; (3) execute_ticket_task gọi hàm (1) khi resume.
-- Chỉnh theo bản mới nhất: create_ticket_task (migration 262), execute_ticket_task (migration 353); chỉ thêm nhánh resume.
select set_config('hmt.migration', 'on', false);

-- app.apply_enrollment_resume(ghi danh, lý do, ghi chú, mã ticket): NỘI BỘ (chỉ execute_ticket_task gọi). Trả id bản bảo lưu đã kết thúc.
-- Lỗi: HMT_TINH_NANG_TAT (cờ BAO_LUU), HMT_BAO_LUU_KHONG_DANG_MO (không có bảo lưu đang chạy), HMT_KHONG_TIM_THAY.
create or replace function app.apply_enrollment_resume(p_enrollment_id uuid, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  h app.enrollment_hold;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.require_feature('BAO_LUU', e.branch_id);
  select * into h from app.enrollment_hold where enrollment_id = e.id and status_code = 'DANG_BAO_LUU' for update;
  if h.id is null or e.status_code <> 'BAO_LUU' then
    perform app.raise_error('HMT_BAO_LUU_KHONG_DANG_MO', 'Ghi danh này không có bảo lưu đang chạy để tiếp tục học.');
  end if;
  perform app.assert_catalog_code_active('HOLD_REASON', p_reason_code);
  -- Đóng dòng xếp lớp đang mở: ghi danh về hàng chờ xếp lớp, giờ còn lại giữ nguyên (không đụng sổ giờ).
  update app.enrollment_class set end_date = greatest((now() at time zone 'Asia/Ho_Chi_Minh')::date, start_date), end_reason = 'KET_THUC'
   where enrollment_id = e.id and end_date is null;
  update app.enrollment set status_code = 'CHO_XEP_LOP' where id = e.id;
  update app.enrollment_hold set status_code = 'KET_THUC', end_kind = 'QUAY_LAI_SOM', ended_at = now(), ended_by = (select auth.uid()),
         note = coalesce(nullif(btrim(concat_ws(' · ', note, p_note)), ''), note)
   where id = h.id;
  return h.id;
end;
$$;
revoke execute on function app.apply_enrollment_resume(uuid, text, text, text) from public, anon, authenticated;

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
  select r.levels into v_levels from app.ticket_task_rule r where r.task_type = p_type;
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
  elsif p_type in ('BAO_LUU', 'CHUYEN_LOP') then
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
    if p_type = 'BAO_LUU' then
      if p_payload ->> 'resume' = 'true' then
        -- C30/C31 (R-GD-09, R-CS-02): Tiếp tục học (quay lại sớm) là hành động thứ ba của phiếu Bảo lưu; ghi danh phải đang có bảo lưu chạy.
        if not exists (select from app.enrollment_hold h where h.enrollment_id = v_enr.id and h.status_code = 'DANG_BAO_LUU') then
          perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không có bảo lưu đang chạy để tiếp tục học.');
        end if;
      elsif coalesce(nullif(p_payload ->> 'months', '')::integer, 0) < 1 then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Nhập số tháng bảo lưu (từ 1).');
      end if;
    else
      if nullif(p_payload ->> 'to_class_id', '') is null or nullif(p_payload ->> 'start_date', '') is null or nullif(p_payload ->> 'kind_code', '') is null then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn lớp mới, ngày bắt đầu và loại chuyển.');
      end if;
      -- Chuyển cơ sở cần quản lý của cả hai cơ sở duyệt (R-CS-07): chưa làm ở phiếu, chặn ngay lúc tạo.
      if p_payload ->> 'kind_code' = 'CHUYEN_CO_SO' then
        perform app.raise_error('HMT_PHIEU_CHUA_LAM', 'Chuyển cơ sở cần quản lý của cả hai cơ sở duyệt: chưa làm ở bản hiện tại.');
      end if;
    end if;
  end if;
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('PNV', v_branch_code);
  insert into app.ticket_task (code, ticket_id, branch_id, task_type, reason, payload, levels)
  values (v_code, t.id, t.branch_id, p_type, v_reason, coalesce(p_payload, '{}'::jsonb), v_levels) returning id into v_id;
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
