-- D-23-30 (Chat giao 23/11/2026 20:10; ra soát N0 #17; migration 636; rủi ro CAO: bảo mật + tiền). Lỗi: phiếu Hoàn học phí, Dừng học nhận ghi danh của EM KHÁC hoặc CƠ SỞ KHÁC qua rpc;
-- phiếu Chuyển phí nhận phụ huynh nhận số dư BẤT KỲ (kể cả cơ sở khác).
-- Cách sửa: một TRIGGER trên app.ticket_task kiểm payload mọi đường ghi (tạo phiếu, sửa payload, trình duyệt), không thay các hàm create_ticket_task, execute_ticket_task
-- (nhiều PR cùng sửa hai hàm này; trigger không bị bản hàm sau ghi đè). Payload phiếu bị khoá sau khi tạo cho ba loại này nên số đã kiểm lúc tạo là số được thực hiện.
-- Luật: R-V2-24, R-CS-02, R-TIEN-28, R-TIEN-33, R-GD-16 (ghi danh phải thuộc học sinh của ticket, cùng cơ sở, còn hiệu lực).
-- Chỉ mục: không thêm (không bảng, cột mới; đọc theo khoá chính).
select set_config('hmt.migration', 'on', false);

-- app.ticket_task_check_scope: kiểm phạm vi dữ liệu của phiếu HOAN_PHI, DUNG_HOC, CHUYEN_PHI. NỘI BỘ (trigger, không gọi từ giao diện).
-- Lỗi: HMT_PHIEU_DU_LIEU_SAI (ghi danh không thuộc học sinh hoặc cơ sở của ticket, không còn hiệu lực, phụ huynh nhận ngoài cơ sở, đổi payload sau khi tạo), cùng các lỗi tính hoàn phí của app.compute_refund.
create or replace function app.ticket_task_check_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  e app.enrollment;
  v_enr uuid;
  v_to uuid;
  v_status_check boolean;
begin
  if new.task_type not in ('HOAN_PHI', 'DUNG_HOC', 'CHUYEN_PHI') then
    return new;
  end if;
  -- Di chuyển dữ liệu (migration, cờ hmt.migration) không đi qua luật phạm vi: người dùng không bật được cờ này.
  if app.is_migration() then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    -- Luật: payload của ba loại phiếu này không đổi sau khi tạo (người duyệt thấy gì thì thực hiện đúng cái đó).
    if new.payload is distinct from old.payload then
      perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Không sửa nội dung phiếu sau khi đã tạo. Huỷ phiếu và tạo phiếu mới.');
    end if;
    -- Chỉ kiểm lại lúc trình duyệt (Nháp sang Chờ duyệt: ghi danh phải còn hiệu lực lúc người duyệt nhận phiếu). Payload đã khoá nên các bước sau không cần kiểm lại.
    if new.status_code is not distinct from old.status_code or new.status_code <> 'CHO_DUYET' then
      return new;
    end if;
  end if;
  select * into t from app.ticket where id = new.ticket_id;
  begin
    v_enr := nullif(new.payload ->> 'enrollment_id', '')::uuid;
  exception when others then
    v_enr := null;
  end;
  select * into e from app.enrollment where id = v_enr;
  -- Luật phạm vi: ghi danh phải của đúng học sinh gắn với ticket và đúng cơ sở của ticket (chặn em khác, cơ sở khác).
  if e.id is null or t.student_id is null or e.student_id is distinct from t.student_id or e.branch_id is distinct from t.branch_id or e.branch_id is distinct from new.branch_id then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn ghi danh của học sinh gắn với ticket (cùng cơ sở).');
  end if;
  -- Luật trạng thái: ghi danh còn hiệu lực lúc tạo và lúc trình duyệt (sau khi thực hiện, ghi danh đổi trạng thái nên không kiểm lại).
  v_status_check := tg_op = 'INSERT' or new.status_code = 'CHO_DUYET';
  if v_status_check and e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Ghi danh này không còn hiệu lực.');
  end if;
  if tg_op = 'INSERT' then
    -- Luật R-TIEN-28 (Hoàn học phí): kiểm sớm loại hoàn và giờ hoàn bằng đúng hàm tính hoàn phí; lỗi trả mã của hàm đó.
    if new.task_type = 'HOAN_PHI' then
      if coalesce(nullif(new.payload ->> 'kind', ''), '') not in ('TOAN_BO', 'MOT_PHAN') then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chọn loại hoàn: toàn bộ hoặc một phần.');
      end if;
      perform app.compute_refund(e.id, new.payload ->> 'kind', nullif(new.payload ->> 'hours', '')::numeric);
    end if;
    -- Luật R-TIEN-33 (Chuyển phí): phụ huynh nhận số dư (tuỳ chọn) phải tồn tại và thuộc cùng cơ sở của ticket.
    if new.task_type = 'CHUYEN_PHI' and nullif(new.payload ->> 'to_parent_id', '') is not null then
      begin
        v_to := (new.payload ->> 'to_parent_id')::uuid;
      exception when others then
        v_to := null;
      end;
      if v_to is null or not exists (select from app.parent pa where pa.id = v_to and pa.branch_id = t.branch_id) then
        perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phụ huynh nhận số dư phải thuộc cùng cơ sở với ticket.');
      end if;
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function app.ticket_task_check_scope() from public, anon, authenticated;

drop trigger if exists ticket_task_check_scope on app.ticket_task;
create trigger ticket_task_check_scope
  before insert or update of payload, status_code on app.ticket_task
  for each row execute function app.ticket_task_check_scope();
