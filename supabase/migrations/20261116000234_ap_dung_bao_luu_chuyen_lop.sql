-- Migration 234 (Code D, 16/11/2026): hàm «áp dụng» bảo lưu và chuyển lớp cho phiếu nghiệp vụ Aftersale (Code B, migration 226).
-- Vì sao: phiếu nghiệp vụ (ticket_task) đã có cấp duyệt riêng theo loại (R-CS-07). Khi phiếu duyệt đủ cấp, việc THỰC HIỆN không được bắt duyệt lần hai
-- ở bản ghi bảo lưu hay chuyển lớp (R-V2-24: một nơi duyệt). Hai hàm dưới tạo bản ghi ở trạng thái ĐÃ DUYỆT và thực hiện ngay trong một giao dịch,
-- dùng đúng luật của bản tạo thường (R-GD-09, R-GD-10). NỘI BỘ: không cấp cho giao diện; chỉ execute_ticket_task (đã kiểm quyền, cờ AFTERSALE,
-- phiếu Đã duyệt đủ cấp) được gọi. Chưa nối vào execute_ticket_task: chờ Chat và Code B chốt (docs/nghiep-vu/code-d-ham-va-co.md, mục «Chỗ cần chốt»).
-- Cờ BAO_LUU, CHUYEN_LOP vẫn kiểm (tắt cờ thì không áp dụng), như bản tạo thường.

-- app.apply_enrollment_hold: bảo lưu (mới hoặc gia hạn) đã duyệt, bắt đầu ngay. Kết quả: id bản ghi.
-- Luật: R-GD-09 (một lần không quá reservation_max_months; giữ nguyên giờ), R-CS-03 (gia hạn nối từ ngày hết hạn bản đang chạy).
create or replace function app.apply_enrollment_hold(
  p_enrollment_id uuid, p_months integer, p_reason_code text, p_note text default null, p_ticket_ref text default null,
  p_extends_hold_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  prev app.enrollment_hold;
  v_max integer;
  v_start date;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.require_feature('BAO_LUU', e.branch_id);
  -- Luật R-GD-09: thời gian một lần không quá tham số của cơ sở.
  v_max := app.get_setting_int('reservation_max_months', e.branch_id);
  if p_months is null or p_months < 1 or p_months > v_max then
    perform app.raise_error('HMT_BAO_LUU_QUA_THOI_GIAN', format('Bảo lưu mỗi lần từ 1 đến %s tháng.', v_max));
  end if;
  perform app.assert_catalog_code_active('HOLD_REASON', p_reason_code);
  if exists (select from app.enrollment_hold where enrollment_id = e.id and status_code in ('NHAP', 'CHO_DUYET')) then
    perform app.raise_error('HMT_BAO_LUU_DANG_MO', 'Ghi danh này đã có một yêu cầu bảo lưu chưa xong.');
  end if;
  if p_extends_hold_id is null then
    if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC') then
      perform app.raise_error('HMT_BAO_LUU_GHI_DANH_SAI', 'Chỉ ghi danh Đã xếp lớp hoặc Đang học mới bảo lưu được.');
    end if;
    v_start := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
    update app.enrollment set status_code = 'BAO_LUU' where id = e.id;
  else
    select * into prev from app.enrollment_hold where id = p_extends_hold_id for update;
    if prev.id is null or prev.enrollment_id <> e.id or prev.status_code <> 'DANG_BAO_LUU' then
      perform app.raise_error('HMT_BAO_LUU_GIA_HAN_SAI', 'Chỉ gia hạn được bảo lưu đang chạy của chính ghi danh này.');
    end if;
    v_start := prev.end_date;
    update app.enrollment_hold set status_code = 'KET_THUC', end_kind = 'GIA_HAN', ended_at = now(), ended_by = (select auth.uid()) where id = prev.id;
  end if;
  insert into app.enrollment_hold (enrollment_id, student_id, branch_id, kind_code, months, extends_hold_id, reason_code, note, ticket_ref,
                                   return_status_code, status_code, start_date, end_date, approved_by, approved_at)
  values (e.id, e.student_id, e.branch_id, case when p_extends_hold_id is null then 'MOI' else 'GIA_HAN' end, p_months, p_extends_hold_id,
          p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          case when p_extends_hold_id is null then e.status_code else prev.return_status_code end,
          'DANG_BAO_LUU', v_start, (v_start + make_interval(months => p_months))::date, (select auth.uid()), now())
  returning id into v_id;
  return v_id;
end;
$$;

-- app.apply_class_transfer: chuyển lớp, chuyển cơ sở đã duyệt, thực hiện ngay. Kết quả: id bản ghi.
-- Luật: R-GD-10 (cùng môn; đóng dòng xếp lớp cũ, mở dòng mới, giờ đi theo ghi danh), R-CS-03 (khác môn là chuyển phí, chặn), R-GD-06, 08, 15.
create or replace function app.apply_class_transfer(
  p_enrollment_id uuid, p_to_class_id uuid, p_start_date date, p_kind_code text, p_reason_code text,
  p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v_from app.class;
  v_to app.class;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.require_feature('CHUYEN_LOP', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_GHI_DANH_KHONG_CHUYEN_DUOC', 'Ghi danh này không còn hiệu lực để chuyển lớp.');
  end if;
  select c.* into v_from from app.enrollment_class ec join app.class c on c.id = ec.class_id where ec.enrollment_id = e.id and ec.end_date is null;
  if v_from.id is null then
    perform app.raise_error('HMT_GHI_DANH_CHUA_CO_LOP', 'Ghi danh chưa có lớp đang học nên chưa chuyển lớp được. Hãy xếp lớp.');
  end if;
  select * into v_to from app.class where id = p_to_class_id;
  if v_to.id is null then
    perform app.raise_error('HMT_LOP_KHONG_TIM_THAY', 'Chuyển lớp: không tìm thấy lớp.');
  end if;
  if v_to.id = v_from.id then
    perform app.raise_error('HMT_CHUYEN_LOP_TRUNG_LOP', 'Lớp mới trùng lớp đang học.');
  end if;
  if p_kind_code not in ('DOI_GIO', 'DOI_TRINH_DO', 'DOI_GIAO_VIEN', 'CHUYEN_CO_SO')
     or (p_kind_code = 'CHUYEN_CO_SO') <> (v_to.branch_id <> v_from.branch_id) then
    perform app.raise_error('HMT_CHUYEN_LOP_LOAI_SAI', 'Loại chuyển không hợp lệ hoặc không khớp cơ sở của lớp mới.');
  end if;
  if v_to.subject_code is distinct from v_from.subject_code then
    perform app.raise_error('HMT_CHUYEN_LOP_KHAC_MON', 'Chuyển sang lớp khác môn là chuyển phí, chưa làm ở chức năng này.');
  end if;
  perform app.assert_catalog_code_active('TRANSFER_REASON', p_reason_code);
  if exists (select from app.class_transfer where enrollment_id = e.id and status_code in ('NHAP', 'CHO_DUYET', 'DA_DUYET')) then
    perform app.raise_error('HMT_CHUYEN_LOP_DANG_MO', 'Ghi danh này đã có một yêu cầu chuyển lớp chưa xong.');
  end if;
  insert into app.class_transfer (enrollment_id, student_id, from_class_id, to_class_id, from_branch_id, to_branch_id, start_date, kind_code,
                                  reason_code, note, ticket_ref, hours_snapshot, status_code,
                                  approved_from_by, approved_from_at, approved_to_by, approved_to_at)
  values (e.id, e.student_id, v_from.id, v_to.id, v_from.branch_id, v_to.branch_id, p_start_date, p_kind_code,
          p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''), coalesce(app.enrollment_hours_balance(e.id), 0), 'DA_CHUYEN',
          (select auth.uid()), now(), case when p_kind_code = 'CHUYEN_CO_SO' then (select auth.uid()) end,
          case when p_kind_code = 'CHUYEN_CO_SO' then now() end)
  returning id into v_id;
  -- move_enrollment_class kiểm hiệu lực ghi danh, môn, khối, chỗ, ngày vào, trùng giờ (R-GD-06, 08, 15) và thực hiện.
  perform app.move_enrollment_class(e.id, v_to.id, p_start_date, coalesce(nullif(btrim(p_ticket_ref), ''), v_id::text));
  return v_id;
end;
$$;

-- NỘI BỘ: không cấp cho giao diện.
revoke execute on function app.apply_enrollment_hold(uuid, integer, text, text, text, uuid) from public, anon, authenticated;
revoke execute on function app.apply_class_transfer(uuid, uuid, date, text, text, text, text) from public, anon, authenticated;
