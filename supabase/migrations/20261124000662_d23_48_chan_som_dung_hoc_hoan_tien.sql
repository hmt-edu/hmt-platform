-- D-23-48 (Chat giao 24/11/2026 13:10; ra soát; rủi ro CAO: tiền). Lỗi: phiếu Dừng học chọn «Hoàn tiền» (money_mode = HOAN_TIEN) chỉ bị chặn «ghi danh đã có yêu cầu hoàn phí chưa xong»
-- (HMT_HOAN_PHI_DANG_MO) ở bước Thực hiện, người duyệt hai cấp mới biết. Sửa giống migration 659 (D-23-46): báo NGAY khi tạo phiếu và khi gửi duyệt; bước Thực hiện vẫn giữ chặn cuối của app.apply_refund_request.
-- Cách làm: thêm MỘT trigger riêng trên app.ticket_task, không thay app.create_ticket_task, app.execute_ticket_task, app.ticket_task_check_scope (nhiều PR cùng sửa các hàm đó) và không đổi trigger của 659.
-- Luật: R-TIEN-28, R-V2-24, R-CS-02. Không đổi luật tiền, không đổi cách tính. Chỉ mục: không thêm (đọc theo ghi danh qua chỉ mục có sẵn của refund_request; ticket_task theo khoá chính và ticket_task_branch_status_idx).
select set_config('hmt.migration', 'on', false);

-- app.ticket_task_check_stop_refund_open: phiếu Dừng học chọn Hoàn tiền không được tạo hoặc gửi duyệt khi ghi danh đã có yêu cầu hoàn phí chưa xong,
-- hoặc đã có một phiếu Hoàn học phí / Dừng học Hoàn tiền khác đang mở. NỘI BỘ (trigger). Lỗi: HMT_HOAN_PHI_DANG_MO.
-- Phiếu đã Thực hiện, Huỷ, Từ chối không chặn; yêu cầu hoàn đã chi, từ chối, huỷ không chặn. Dừng học giữ số dư (GIU_SO_DU, mặc định) không đụng tiền hoàn nên không kiểm.
create or replace function app.ticket_task_check_stop_refund_open()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enr uuid;
begin
  if new.task_type <> 'DUNG_HOC' or app.is_migration() or coalesce(new.payload ->> 'money_mode', '') <> 'HOAN_TIEN' then
    return new;
  end if;
  -- Chỉ kiểm lúc tạo và lúc Nháp sang Chờ duyệt (các bước sau payload đã khoá).
  if tg_op = 'UPDATE' and (new.status_code is not distinct from old.status_code or new.status_code <> 'CHO_DUYET') then
    return new;
  end if;
  begin
    v_enr := nullif(new.payload ->> 'enrollment_id', '')::uuid;
  exception when others then
    v_enr := null;
  end;
  -- Ghi danh sai hoặc thiếu do trigger phạm vi (migration 636) báo.
  if v_enr is null then
    return new;
  end if;
  -- Luật R-TIEN-28: cùng danh sách trạng thái «chưa xong» với hàm tạo yêu cầu hoàn phí (migration 231, 459) và trigger của 659.
  if exists (select from app.refund_request r where r.enrollment_id = v_enr and r.status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET'))
     or exists (select from app.ticket_task k
                 where k.id <> new.id and k.status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')
                   and k.payload ->> 'enrollment_id' = new.payload ->> 'enrollment_id'
                   and (k.task_type = 'HOAN_PHI' or (k.task_type = 'DUNG_HOC' and k.payload ->> 'money_mode' = 'HOAN_TIEN'))) then
    perform app.raise_error('HMT_HOAN_PHI_DANG_MO', 'Ghi danh này đã có một yêu cầu hoàn phí chưa xong.');
  end if;
  return new;
end;
$$;
revoke execute on function app.ticket_task_check_stop_refund_open() from public, anon, authenticated;

-- Tên bắt đầu «ticket_task_kiem_» để chạy SAU trigger phạm vi ticket_task_check_scope (ghi danh của em khác báo lỗi phạm vi trước, không lộ trạng thái hoàn phí).
drop trigger if exists ticket_task_kiem_dung_hoc_hoan_tien on app.ticket_task;
create trigger ticket_task_kiem_dung_hoc_hoan_tien
  before insert or update of status_code on app.ticket_task
  for each row execute function app.ticket_task_check_stop_refund_open();
