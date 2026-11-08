-- R-V2-12 (anh chốt 04/11, Q-114, Q-115, Q-117, Q-118, Q-120 ngày 08/11): người lập đơn hoặc phiếu thu CHƯA có quản lý trực tiếp vẫn
-- Trình được: đi tới TRƯỞNG CƠ SỞ của cơ sở chứng từ (phiếu thu rồi tới Kế toán). Thay luật cũ R-HT-06 "không trình được".
--  (1) approval_route nhận thêm cơ sở và loại chứng từ; không có quản lý và không phải Trưởng cơ sở thì trả route TRUONG_CS, người chốt để TRỐNG
--      (Q-117: cơ sở có nhiều Trưởng cơ sở thì không chốt một người). Cơ sở chưa có Trưởng cơ sở nào đang hoạt động thì vẫn chặn, mã
--      HMT_KHONG_CO_QUAN_LY, câu nói rõ lý do.
--  (2) can_approve_as_manager hiểu route TRUONG_CS: mọi Trưởng cơ sở của cơ sở đó duyệt được (Admin duyệt thay đơn như cũ, phiếu thu thì không).
--      Ai duyệt trước thì có hiệu lực: chứng từ rời trạng thái chờ ngay trong giao dịch duyệt, người sau gặp lỗi sai trạng thái.
--  (3) Hàng chờ "chờ tôi duyệt" (list_orders waiting_me, export_orders, list_receipts waiting_manager) tính cả chứng từ route TRUONG_CS thuộc
--      cơ sở của Trưởng cơ sở đang đăng nhập.
--  (4) submit_order, submit_receipt, get_order, get_receipt, approve_order, reject_order, cancel_order, approve_receipt_manager, reject_receipt
--      truyền route và cơ sở cho can_approve_as_manager; "duyệt thay" không tính cho Trưởng cơ sở duyệt chứng từ TRUONG_CS.
-- Báo giá KHÔNG dùng approval_route (không có bước quản lý duyệt) nên không đổi. Ca cơ sở mất hết Trưởng cơ sở sau khi chứng từ đã trình
-- (Q-120, chọn B): không xử trong migration này; Admin đặt lại Trưởng cơ sở thì chứng từ route TRUONG_CS tự có người duyệt.

alter table app.sales_order drop constraint sales_order_approval_route_check;
alter table app.sales_order add constraint sales_order_approval_route_check
  check (approval_route in ('QUAN_LY', 'TU_DUYET', 'TRUONG_CS'));
alter table app.receipt drop constraint receipt_approval_route_check;
alter table app.receipt add constraint receipt_approval_route_check
  check (approval_route in ('QUAN_LY', 'TU_DUYET', 'TRUONG_CS'));

-- Chỉ mục cho hàng chờ TRUONG_CS: lọc theo cơ sở trong lúc chứng từ còn chờ (ít dòng); không có chỉ mục này thì lọc "chờ tôi duyệt" của
-- Trưởng cơ sở quét cả bảng (chỉ mục sẵn có theo assigned_approver_id không khớp vì người chốt để trống).
create index sales_order_truong_cs_idx on app.sales_order (branch_id) where approval_route = 'TRUONG_CS' and status_code = 'DA_TRINH';
create index receipt_truong_cs_idx on app.receipt (branch_id) where approval_route = 'TRUONG_CS' and status_code = 'DA_GUI';

-- ---------------------------------------------------------------------------
-- Người này có phải Trưởng cơ sở đang hoạt động, có quyền Duyệt ở cơ sở đó không (dùng chung cho đơn và phiếu thu).
-- Đầu vào: người cần kiểm, mô-đun quyền ('SALES_ORDER' hoặc 'RECEIPT'), cơ sở chứng từ. Kết quả: true hoặc false. Ai gọi: hàm nghiệp vụ.
-- Luật R-V2-12: người duyệt route TRUONG_CS là Trưởng cơ sở của đúng cơ sở chứng từ (không bị khoá, có quyền Duyệt ở cơ sở).
-- ---------------------------------------------------------------------------
create or replace function app.is_branch_manager_at(p_user_id uuid, p_module text, p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_role ur
                  where ur.user_id = p_user_id and ur.role_code = 'BRANCH_MANAGER' and ur.is_active)
         and app.user_can_at_branch(p_user_id, p_module, 'DUYET', p_branch_id);
$$;

-- ---------------------------------------------------------------------------
-- Đường duyệt của một người lập (R-HT-06, R-V2-12). Gọi LÚC TRÌNH.
-- Đầu vào: người lập, cơ sở chứng từ (không có thì chỉ xét quản lý trực tiếp như trước), loại chứng từ ('DON' hoặc 'PHIEU_THU').
-- Kết quả: route 'TU_DUYET' (người lập là Trưởng cơ sở; approver_id = chính họ), 'QUAN_LY' (approver_id = quản lý trực tiếp lúc trình),
-- hoặc 'TRUONG_CS' (không có quản lý; approver_id trống, mọi Trưởng cơ sở của cơ sở duyệt được). Lỗi HMT_KHONG_CO_QUAN_LY: không có quản lý
-- và cơ sở chưa có Trưởng cơ sở nào đang hoạt động (hoặc không biết cơ sở).
-- ---------------------------------------------------------------------------
drop function app.approval_route(uuid);
create or replace function app.approval_route(p_creator_id uuid, p_branch_id uuid default null, p_kind text default 'DON')
returns table (route text, approver_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_manager uuid;
  v_module text := case when p_kind = 'PHIEU_THU' then 'RECEIPT' else 'SALES_ORDER' end;
begin
  if not exists (select from app.user_account where id = p_creator_id and student_code is null) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy nhân viên lập.');
  end if;
  -- Luật R-HT-06: Trưởng cơ sở tự duyệt.
  if exists (select from app.user_role ur
              where ur.user_id = p_creator_id and ur.role_code = 'BRANCH_MANAGER' and ur.is_active) then
    return query select 'TU_DUYET'::text, p_creator_id;
    return;
  end if;
  select manager_id into v_manager from app.user_account where id = p_creator_id;
  -- Luật R-HT-06: có quản lý trực tiếp thì quản lý duyệt (người duyệt chốt lúc trình).
  if v_manager is not null then
    return query select 'QUAN_LY'::text, v_manager;
    return;
  end if;
  -- Luật R-V2-12 (Q-117): không có quản lý thì Trưởng cơ sở của cơ sở duyệt, không chốt một người.
  if p_branch_id is not null and exists (
       select from app.user_role ur
        where ur.role_code = 'BRANCH_MANAGER' and ur.is_active
          and app.is_branch_manager_at(ur.user_id, v_module, p_branch_id)) then
    return query select 'TRUONG_CS'::text, null::uuid;
    return;
  end if;
  perform app.raise_error('HMT_KHONG_CO_QUAN_LY',
    'Người lập chưa có Quản lý trực tiếp và cơ sở này chưa có Trưởng cơ sở nào đang hoạt động để duyệt. Nhờ Admin đặt Quản lý trực tiếp hoặc Trưởng cơ sở rồi trình lại.');
end;
$$;

-- ---------------------------------------------------------------------------
-- Người đang đăng nhập có duyệt được ở bước quản lý không (dùng chung cho đơn và phiếu thu). Thêm route và cơ sở của chứng từ (R-V2-12).
-- Duyệt được khi: (1) route TRUONG_CS và là Trưởng cơ sở của cơ sở chứng từ; hoặc (2) là người duyệt đã chốt (quản lý trực tiếp lúc trình,
-- hoặc chính Trưởng cơ sở lập khi tự duyệt); hoặc (3) CHỈ với đơn: là Admin đã xác thực hai bước, duyệt thay khi vắng (R-HT-01).
-- Phiếu thu: bước quản lý Admin KHÔNG duyệt thay (R-HT-01: việc tiền).
-- ---------------------------------------------------------------------------
drop function app.can_approve_as_manager(uuid, text, uuid);
create or replace function app.can_approve_as_manager(
  p_creator_id uuid, p_kind text default 'DON', p_assigned_approver uuid default null,
  p_route text default null, p_branch_id uuid default null)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_approver uuid := p_assigned_approver;
begin
  if p_kind not in ('DON', 'PHIEU_THU') then
    perform app.raise_error('HMT_LOAI_CHUNG_TU_SAI', 'Chỉ có đơn hàng và phiếu thu có bước quản lý duyệt.');
  end if;
  if not app.current_user_ready() then
    return false;
  end if;
  -- Luật R-V2-12: route TRUONG_CS thì mọi Trưởng cơ sở của cơ sở chứng từ duyệt được (người chốt để trống).
  if p_route = 'TRUONG_CS' then
    if app.is_branch_manager_at(auth.uid(), case when p_kind = 'PHIEU_THU' then 'RECEIPT' else 'SALES_ORDER' end, p_branch_id) then
      return true;
    end if;
  elsif v_approver is null then
    -- Chưa chốt lúc trình: lấy theo hiện tại (Trưởng cơ sở là chính mình, còn lại là quản lý trực tiếp); không lỗi nếu chưa có.
    select case when exists (select from app.user_role ur
                              where ur.user_id = p_creator_id and ur.role_code = 'BRANCH_MANAGER' and ur.is_active)
                then p_creator_id else a.manager_id end
      into v_approver from app.user_account a where a.id = p_creator_id;
  end if;
  if v_approver = auth.uid() then
    return true;
  end if;
  -- Đơn hàng: Admin duyệt thay (R-HT-01). Phiếu thu: không.
  return p_kind = 'DON' and app.mfa_satisfied()
         and exists (select from app.user_role ur
                      where ur.user_id = auth.uid() and ur.role_code = 'ADMIN' and ur.is_active);
end;
$$;

revoke execute on function app.is_branch_manager_at(uuid, text, uuid), app.approval_route(uuid, uuid, text),
  app.can_approve_as_manager(uuid, text, uuid, text, uuid) from public, anon;
grant execute on function app.is_branch_manager_at(uuid, text, uuid), app.approval_route(uuid, uuid, text),
  app.can_approve_as_manager(uuid, text, uuid, text, uuid) to authenticated;

-- submit_order: route theo cơ sở (R-V2-12); route TRUONG_CS không có người chốt nên bỏ kiểm khoá và thiếu quyền của người chốt (đã kiểm trong approval_route).
create or replace function app.submit_order(p_id uuid, p_acknowledged boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_route text;
  v_approver uuid;
  l app.sales_order_line;
  v_auto boolean;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'SUA', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ trình được đơn Nháp.');
  end if;
  if not exists (select from app.sales_order_line where order_id = p_id) then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn chưa có dòng nào, chưa trình được.');
  end if;
  -- Luật R-TIEN-35: em đủ họ tên và năm sinh.
  perform app.assert_order_students_complete(p_id);
  -- Luật R-TIEN-07: phải chọn điều khoản thanh toán; lịch đóng tiền tính lại để báo sớm nếu điều khoản không hợp tổng đơn.
  if v_o.payment_term_id is null then
    perform app.raise_error('HMT_THIEU_DIEU_KHOAN', 'Chọn điều khoản thanh toán trước khi trình đơn.');
  end if;
  perform app.order_refresh_totals(p_id);
  -- Luật R-GD-06, R-GD-08: lớp trên dòng kiểm lại lúc trình.
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Luật R-HT-06: chốt người duyệt lúc trình theo NGƯỜI LẬP.
  select r.route, r.approver_id into v_route, v_approver from app.approval_route(v_o.created_by, v_o.branch_id, 'DON') r;
  -- Luật Q-63 (anh chốt 07/11): người duyệt đã chốt đang bị KHOÁ thì nói rõ, KHÁC với người duyệt thiếu quyền (câu bên dưới giữ nguyên).
  if v_approver is not null and exists (select from app.user_account a where a.id = v_approver and a.is_locked) then
    perform app.raise_error('HMT_NGUOI_DUYET_BI_KHOA',
      'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.');
  end if;
  -- Luật Đ205: người duyệt đã chốt phải có quyền Duyệt đơn ở cơ sở này.
  if v_route <> 'TRUONG_CS' and not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', v_o.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt đơn hàng ở cơ sở này nên chưa trình được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.sales_order set status_code = 'DA_TRINH', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  -- Luật Q-29 (anh chốt 06/11): trình lại mà chưa sửa gì từ lần bị từ chối thì nhật ký ghi rõ (không chặn, hộp xác nhận ở giao diện).
  perform app.order_add_event(p_id, 'TRINH', 'NHAP', 'DA_TRINH', null, null,
                              case when app.order_resubmitted_unedited(p_id) then 'Trình lại, chưa sửa từ lần bị từ chối' end);
  -- Luật Q-P6 (Đ283): Trưởng cơ sở lập và chính họ trình thì tự duyệt ngay, trong cùng giao dịch. Mọi điều kiện của approve_order áp lại; lỗi thì
  -- cả giao dịch lùi (đơn vẫn Nháp). Người khác trình đơn của Trưởng cơ sở thì dừng ở Đã trình, Trưởng cơ sở duyệt sau.
  v_auto := v_route = 'TU_DUYET' and v_o.created_by is not distinct from auth.uid();
  if v_auto then
    perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
    if not app.can_approve_as_manager(v_o.created_by, 'DON', v_approver) then
      perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình duyệt (Admin duyệt thay khi vắng).');
    end if;
    perform app.order_approve_core(p_id, p_acknowledged, false, 'Tự duyệt');
  end if;
  return jsonb_build_object('id', p_id, 'approver_id', v_approver, 'route', v_route,
                            'status', case when v_auto then 'DA_DUYET' else 'DA_TRINH' end, 'auto_approved', v_auto);
end;
$$;

-- submit_receipt: như submit_order (R-V2-12).
create or replace function app.submit_receipt(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_route text;
  v_approver uuid;
  v_auto boolean;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if r.created_by is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới gửi được phiếu thu của mình.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi được phiếu thu Nháp.');
  end if;
  select * into v_o from app.sales_order where id = r.order_id;
  if v_o.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_DON_CHUA_DUYET', 'Đơn hàng không còn ở trạng thái đã duyệt.');
  end if;
  -- Kiểm lại số tiền với phần còn thu được (các phiếu khác có thể đã gửi từ lúc lập).
  perform app.receipt_normalize(v_o, jsonb_build_object('amount', r.amount, 'payment_method_code', r.payment_method_code,
            'paid_on', r.paid_on, 'collect_branch_id', r.collect_branch_id, 'receiver_id', r.receiver_id, 'target_line_id', r.target_line_id), r.id);
  select x.route, x.approver_id into v_route, v_approver from app.approval_route(r.created_by, r.branch_id, 'PHIEU_THU') x;
  -- Luật Q-63 (anh chốt 07/11): người duyệt đã chốt đang bị KHOÁ thì nói rõ, KHÁC với người duyệt thiếu quyền (câu bên dưới giữ nguyên).
  if v_approver is not null and exists (select from app.user_account a where a.id = v_approver and a.is_locked) then
    perform app.raise_error('HMT_NGUOI_DUYET_BI_KHOA',
      'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.');
  end if;
  if v_route <> 'TRUONG_CS' and not app.user_can_at_branch(v_approver, 'RECEIPT', 'DUYET', r.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt phiếu thu ở cơ sở này nên chưa gửi được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.receipt set status_code = 'DA_GUI', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  -- Luật Q-58 (anh chốt 07/11, giống đơn Q-29): gửi lại mà chưa sửa gì từ lần bị từ chối thì sự kiện Gửi ghi rõ (không chặn, hộp xác nhận ở giao diện).
  perform app.receipt_add_event(p_id, 'GUI', 'NHAP', 'DA_GUI',
                                case when app.receipt_resubmitted_unedited(p_id) then 'Gửi lại, chưa sửa từ lần bị từ chối' end);
  -- Trưởng cơ sở lập và chính họ gửi: tự duyệt bước quản lý ngay, trong cùng giao dịch.
  v_auto := v_route = 'TU_DUYET' and r.created_by is not distinct from auth.uid();
  if v_auto then
    perform app.receipt_manager_step_done(p_id, 'TU_DUYET_QL');
  end if;
  return jsonb_build_object('id', p_id, 'approver_id', v_approver, 'route', v_route,
                            'status', case when v_auto then 'CHO_KE_TOAN' else 'DA_GUI' end, 'auto_approved', v_auto);
end;
$$;

-- get_order: người duyệt dự kiến theo cơ sở; cờ duyệt, từ chối, huỷ biết route TRUONG_CS (R-V2-12).
create or replace function app.get_order(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_route text;
  v_approver uuid;
  v_hint text;
  v_feature boolean;
  v_can_approve boolean;
  v_can_cancel boolean;
begin
  select * into o from app.sales_order where id = p_id;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'XEM', o.branch_id);
  -- Người duyệt dự kiến của đơn Nháp: ĐÚNG đầu vào và hàm mà submit_order dùng để chốt assigned_approver_id (R-HT-06): người LẬP đơn
  -- (created_by) qua app.approval_route. Chưa có quản lý trực tiếp thì KHÔNG báo lỗi: đường duyệt THIEU, người duyệt rỗng, để giao diện
  -- hiện khung "chưa có quản lý trực tiếp". Đơn đã trình trở đi thì không trả (đã có assigned_approver_id).
  if o.status_code = 'NHAP' then
    begin
      select r.route, r.approver_id into v_route, v_approver from app.approval_route(o.created_by, o.branch_id, 'DON') r;
    -- Chủ ý bắt mọi lỗi: tra người duyệt dự kiến chỉ để hiển thị, KHÔNG được chặn việc mở màn đơn. Chưa có quản lý thì THIEU; lỗi khác thì để
    -- trống (route null); luật chặn thật vẫn nằm ở submit_order lúc Trình.
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      if v_hint = 'HMT_KHONG_CO_QUAN_LY' then
        v_route := 'THIEU';
        v_approver := null;
      else
        v_route := null;
        v_approver := null;
      end if;
    end;
  end if;
  -- Bốn cờ cho giao diện (Đ283): tính bằng ĐÚNG các hàm không báo lỗi mà hàm ghi dùng (can_see_branch của assert_can, feature_enabled của
  -- require_feature, can_approve_as_manager, order_has_receipt), nên giao diện không tự đoán quyền. Cờ chỉ xét QUYỀN và TRẠNG THÁI, không xét
  -- dữ liệu: thiếu điều khoản, em thiếu năm sinh, chưa có quản lý trực tiếp... vẫn do hàm ghi báo lúc bấm (cờ đúng, lỗi cấu hình khi Trình).
  v_feature := app.feature_enabled('BAN_HANG', o.branch_id);
  -- Duyệt và Từ chối (approve_order, reject_order kiểm y hệt): đơn Đã trình, quyền Duyệt, đúng người duyệt đã chốt (Admin thay khi vắng).
  v_can_approve := coalesce(o.status_code = 'DA_TRINH' and v_feature
                            and app.can_see_branch('SALES_ORDER', 'DUYET', o.branch_id)
                            and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id), false);
  -- Huỷ (cancel_order, R-TIEN-38): đơn Nháp chỉ người lập; đơn Đã trình, Đã duyệt do người duyệt đã chốt; chỉ khi chưa có phiếu thu.
  v_can_cancel := coalesce(o.status_code <> 'HUY' and v_feature
                  and app.can_see_branch('SALES_ORDER', 'HUY', o.branch_id)
                  and case when o.status_code = 'NHAP' then o.created_by is not distinct from auth.uid()
                           else app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id) end
                  and not app.order_has_receipt(o.id), false);
  return (to_jsonb(o) - 'search_text') || jsonb_build_object(
    -- Trình (submit_order): đơn Nháp, quyền Sửa ở cơ sở, Bán hàng bật.
    'can_submit', coalesce(o.status_code = 'NHAP' and v_feature and app.can_see_branch('SALES_ORDER', 'SUA', o.branch_id), false),
    'can_cancel', v_can_cancel,
    'can_approve', v_can_approve,
    'can_reject', v_can_approve,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = o.status_code),
    'branch_code', (select b.code from app.branch b where b.id = o.branch_id),
    'opportunity_code', (select x.code from app.opportunity x where x.id = o.opportunity_id),
    'quotation_code', (select q.code from app.quotation q where q.id = o.quotation_id),
    'parent_code', (select p.code from app.parent p where p.id = o.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = o.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = o.parent_id),
    'payment_term_name', (select t.name from app.payment_term t where t.id = o.payment_term_id),
    -- Tổng niêm yết và tổng chiết khấu: DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.sales_order_line l3
                     where l3.order_id = o.id and l3.line_kind = 'ENROL'),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.sales_order_line l3
                        where l3.order_id = o.id and l3.line_kind = 'ENROL'),
    -- Chỉ khi đơn Nháp: QUAN_LY, TU_DUYET hoặc THIEU; người duyệt dự kiến; và người đó có quyền Duyệt đơn ở cơ sở này không (Đ205).
    'expected_route', v_route,
    'expected_approver_id', v_approver,
    'expected_approver_name', app.staff_display_name(v_approver),
    'expected_approver_can_approve', case when v_approver is null then null
                                          else app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) end,
    -- Q-63, Q-62: MỘT lý do chặn phía người duyệt cho giao diện (dải thông báo cạnh nút trình dùng lại, không đổi DB nữa); chỉ khi đơn Nháp.
    -- KHONG_CO_QUAN_LY, NGUOI_DUYET_BI_KHOA (người duyệt dự kiến đang bị khoá), NGUOI_DUYET_THIEU_QUYEN (không bị khoá nhưng thiếu quyền Duyệt
    -- ở cơ sở), null (không chặn). Trùng mã lỗi của submit_order.
    'expected_block', case when o.status_code <> 'NHAP' then null
                           when v_route = 'THIEU' then 'KHONG_CO_QUAN_LY'
                           when v_approver is null then null
                           when exists (select from app.user_account a where a.id = v_approver and a.is_locked) then 'NGUOI_DUYET_BI_KHOA'
                           when not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) then 'NGUOI_DUYET_THIEU_QUYEN'
                           else null end,
    'created_by_name', app.staff_display_name(o.created_by),
    'submitted_by_name', app.staff_display_name(o.submitted_by),
    'approver_name', app.staff_display_name(o.assigned_approver_id),
    'approved_by_name', app.staff_display_name(o.approved_by),
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_CANCEL_REASON' and c.code = o.cancel_reason_code),
    'has_incomplete_students', exists (
      select from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id
         and (coalesce(s.full_name, v.full_name) is null or coalesce(s.birth_year, v.birth_year) is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'order_id' || jsonb_build_object(
               'student_name', coalesce(s.full_name, v.full_name), 'student_birth_year', coalesce(s.birth_year, v.birth_year),
               'student_code', coalesce(s.code, v.student_code),
               'student_complete', (coalesce(s.full_name, v.full_name) is not null and coalesce(s.birth_year, v.birth_year) is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.sales_order_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id), '[]'::jsonb),
    'installments', coalesce((
      select jsonb_agg(jsonb_build_object('seq', i.seq, 'due_days', i.due_days, 'amount', i.amount, 'due_date', i.due_date) order by i.seq)
        from app.sales_order_installment i where i.order_id = o.id), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
               'seq', e.seq, 'event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
               'reason_code', e.reason_code, 'note', e.note, 'on_behalf', e.on_behalf, 'created_at', e.created_at, 'total_amount', e.total_amount,
               'actor_name', app.staff_display_name(e.created_by)) order by e.seq)
        from app.sales_order_event e where e.order_id = o.id), '[]'::jsonb));
end;
$$;

-- approve_order: route và cơ sở cho kiểm người duyệt; Trưởng cơ sở duyệt chứng từ TRUONG_CS không bị tính là duyệt thay (R-V2-12).
create or replace function app.approve_order(p_id uuid, p_acknowledged boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_on_behalf boolean;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'DA_TRINH' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được đơn Đã trình.');
  end if;
  if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id, v_o.approval_route, v_o.branch_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình duyệt (Admin duyệt thay khi vắng).');
  end if;
  v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid()
                  and not (v_o.approval_route = 'TRUONG_CS' and app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', v_o.branch_id));
  perform app.order_approve_core(p_id, p_acknowledged, v_on_behalf,
                                 case when v_on_behalf then 'Admin duyệt thay'
                                      when v_o.approval_route = 'TU_DUYET' then 'Tự duyệt' end);
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'on_behalf', v_on_behalf);
end;
$$;

-- reject_order: route và cơ sở cho kiểm người duyệt; Trưởng cơ sở duyệt chứng từ TRUONG_CS không bị tính là duyệt thay (R-V2-12).
create or replace function app.reject_order(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_item app.catalog_item;
  v_on_behalf boolean;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'DA_TRINH' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ từ chối được đơn Đã trình.');
  end if;
  if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id, v_o.approval_route, v_o.branch_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình xử lý (Admin thay khi vắng).');
  end if;
  select * into v_item from app.catalog_item
   where catalog_code = 'REJECT_REASON' and code = p_reason_code and is_active
     and (cardinality(applies_to) = 0 or 'DON' = any (applies_to));
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do từ chối dành cho đơn hàng.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid()
                  and not (v_o.approval_route = 'TRUONG_CS' and app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', v_o.branch_id));
  update app.sales_order set status_code = 'NHAP', approval_route = null, assigned_approver_id = null,
         submitted_at = null, submitted_by = null where id = p_id;
  perform app.order_add_event(p_id, 'TU_CHOI', 'DA_TRINH', 'NHAP', 'REJECT_REASON', p_reason_code, p_note, v_on_behalf);
end;
$$;

-- cancel_order: route và cơ sở cho kiểm người duyệt; Trưởng cơ sở duyệt chứng từ TRUONG_CS không bị tính là duyệt thay (R-V2-12).
create or replace function app.cancel_order(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_item app.catalog_item;
  v_on_behalf boolean := false;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'HUY', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code = 'HUY' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Đơn này đã huỷ.');
  end if;
  if v_o.status_code = 'NHAP' then
    -- Luật R-TIEN-38: đơn Nháp chỉ người lập huỷ.
    if v_o.created_by is distinct from auth.uid() then
      perform app.raise_error('HMT_KHONG_DUOC_HUY_DON', 'Đơn Nháp chỉ người lập huỷ được.');
    end if;
  else
    -- Luật R-TIEN-38: đơn Đã trình, Đã duyệt do người duyệt đã chốt huỷ (Admin thay khi vắng).
    if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id, v_o.approval_route, v_o.branch_id) then
      perform app.raise_error('HMT_KHONG_DUOC_HUY_DON', 'Đơn đã trình hoặc đã duyệt chỉ người duyệt đã chốt lúc trình huỷ được (Admin huỷ thay khi vắng).');
    end if;
    v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid()
                  and not (v_o.approval_route = 'TRUONG_CS' and app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', v_o.branch_id));
  end if;
  -- Luật R-TIEN-38: chỉ huỷ khi đơn chưa có phiếu thu.
  if app.order_has_receipt(p_id) then
    perform app.raise_error('HMT_DON_DA_CO_PHIEU_THU', 'Đơn đã có phiếu thu, không huỷ được.');
  end if;
  select * into v_item from app.catalog_item
   where catalog_code = 'ORDER_CANCEL_REASON' and code = p_reason_code and is_active;
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do huỷ đơn.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  update app.sales_order set status_code = 'HUY', cancel_reason_code = p_reason_code,
         cancel_note = nullif(btrim(coalesce(p_note, '')), ''), cancelled_at = now(), cancelled_by = auth.uid() where id = p_id;
  -- Trả dòng về báo giá: tắt cờ đang sống (trigger khoá cho phép riêng việc này).
  perform set_config('hmt.order_cancel', 'on', true);
  update app.sales_order_line set is_live = false where order_id = p_id;
  perform set_config('hmt.order_cancel', '', true);
  perform app.order_add_event(p_id, 'HUY', v_o.status_code, 'HUY', 'ORDER_CANCEL_REASON', p_reason_code, p_note, v_on_behalf);
end;
$$;

-- list_orders: hàng chờ 'chờ tôi duyệt' tính thêm đơn route TRUONG_CS của cơ sở mình làm Trưởng cơ sở (R-V2-12).
create or replace function app.list_orders(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_quo uuid := nullif(p_filters ->> 'quotation_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_waiting boolean := coalesce((p_filters ->> 'waiting_me')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách đơn hàng.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang).
  with f as not materialized (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'total_desc' then f.total_amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = p.status_code),
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'opportunity_id', p.opportunity_id, 'opportunity_code', op.code,
             'quotation_id', p.quotation_id, 'quotation_code', q.code,
             'student_name', (select coalesce(s.full_name, v.full_name) from app.sales_order_line l
                                left join app.prospect_student_v v on v.id = l.prospect_student_id
                                left join app.student s on s.id = l.student_id
                               where l.order_id = p.id order by l.line_no limit 1),
             -- Tên các em theo thứ tự dòng, không trùng; chỉ gom cho các đơn của trang đang hiện (p là trang, không quét cả bảng).
             'student_names', (select coalesce(jsonb_agg(x.nm order by x.first_line), '[]'::jsonb)
                                 from (select coalesce(s.full_name, v.full_name) as nm, min(l.line_no) as first_line
                                         from app.sales_order_line l
                                         left join app.prospect_student_v v on v.id = l.prospect_student_id
                                         left join app.student s on s.id = l.student_id
                                        where l.order_id = p.id and coalesce(s.full_name, v.full_name) is not null
                                        group by coalesce(s.full_name, v.full_name)) x),
             'line_count', (select count(*) from app.sales_order_line l where l.order_id = p.id),
             'total_amount', p.total_amount, 'needs_acknowledgement', p.needs_acknowledgement,
             'submitted_at', p.submitted_at, 'approved_at', p.approved_at, 'created_at', p.created_at, 'branch_code', b.code,
             'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id))
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'total_desc' then p.total_amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.opportunity op on op.id = p.opportunity_id
    left join app.quotation q on q.id = p.quotation_id;
  return v_result;
end;
$$;

-- export_orders: hàng chờ 'chờ tôi duyệt' tính thêm đơn route TRUONG_CS của cơ sở mình làm Trưởng cơ sở (R-V2-12).
create or replace function app.export_orders(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XUAT');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_quo uuid := nullif(p_filters ->> 'quotation_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_waiting boolean := coalesce((p_filters ->> 'waiting_me')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất, không phải Xem.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách đơn hàng.');
  end if;
  select count(*) into v_total
    from app.sales_order o
   where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
     and (v_q is null or o.search_text like '%' || v_q || '%')
     and (cardinality(v_status) = 0 or o.status_code = any (v_status))
     and (v_branch is null or o.branch_id = v_branch)
     and (v_opp is null or o.opportunity_id = v_opp)
     and (v_quo is null or o.quotation_id = v_quo)
     and (v_parent is null or o.parent_id = v_parent)
     and (not v_mine or o.created_by = auth.uid())
     and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
     and (v_from is null or o.created_at >= v_from)
     and (v_to is null or o.created_at < v_to);
  with f as (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
     order by o.created_at desc, o.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code,
           'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = f.status_code),
           'parent_name', par.full_name, 'parent_phone', par.phone, 'opportunity', op.code, 'quotation', q.code,
           'students', (select string_agg(distinct coalesce(s.full_name, v.full_name), '; ') from app.sales_order_line l
                          left join app.prospect_student_v v on v.id = l.prospect_student_id
                          left join app.student s on s.id = l.student_id where l.order_id = f.id),
           'total_amount', f.total_amount, 'submitted_at', f.submitted_at, 'approved_at', f.approved_at,
           'branch', b.code, 'created_by', app.staff_display_name(f.created_by), 'created_at', f.created_at)
           order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    left join app.opportunity op on op.id = f.opportunity_id
    left join app.quotation q on q.id = f.quotation_id;
  perform app.log_export('SALES_ORDER', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

-- list_receipts: như list_orders (R-V2-12).
create or replace function app.list_receipts(p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null,
                                             p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_order uuid := nullif(p_filters ->> 'order_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_wait_mgr boolean := coalesce((p_filters ->> 'waiting_manager')::boolean, false);
  v_wait_acc boolean := coalesce((p_filters ->> 'waiting_accounting')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu thu.');
  end if;
  with f as not materialized (
    select r.*
      from app.receipt r
     where (v_scope = 'TOAN_HE_THONG' or r.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or r.status_code = any (v_status))
       and (v_branch is null or r.branch_id = v_branch)
       and (v_order is null or r.order_id = v_order)
       and (v_parent is null or r.parent_id = v_parent)
       and (not v_mine or r.created_by = auth.uid())
       and (not v_wait_mgr or (r.status_code = 'DA_GUI' and (r.assigned_approver_id = auth.uid() or r.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'RECEIPT', r.branch_id)))))
       and (not v_wait_acc or r.status_code = 'CHO_KE_TOAN')
       and (v_from is null or r.created_at >= v_from)
       and (v_to is null or r.created_at < v_to)
       and (v_q is null or r.search_text like '%' || v_q || '%')
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = p.status_code),
             'order_id', p.order_id, 'order_code', o.code, 'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name,
             'amount', p.amount, 'payment_method_code', p.payment_method_code,
             'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = p.payment_method_code),
             'paid_on', p.paid_on, 'branch_code', b.code, 'collect_branch_code', cb.code,
             'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id), 'submitted_at', p.submitted_at)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.branch cb on cb.id = p.collect_branch_id
    join app.parent par on par.id = p.parent_id
    join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;

-- approve_receipt_manager: route và cơ sở cho kiểm người duyệt (R-V2-12).
create or replace function app.approve_receipt_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'DUYET', r.branch_id);
  if r.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt bước quản lý được phiếu thu Đã gửi.');
  end if;
  if not app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Phiếu thu này do người duyệt đã chốt lúc gửi duyệt (Admin không duyệt thay bước quản lý).');
  end if;
  perform app.receipt_manager_step_done(p_id, 'DUYET_QL');
end;
$$;

-- reject_receipt: route và cơ sở cho kiểm người duyệt (R-V2-12).
create or replace function app.reject_receipt(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Nhập lý do từ chối.');
  end if;
  if r.status_code = 'DA_GUI' then
    perform app.assert_can('RECEIPT', 'DUYET', r.branch_id);
    if not app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
      perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Phiếu thu này do người duyệt đã chốt lúc gửi duyệt.');
    end if;
  elsif r.status_code = 'CHO_KE_TOAN' then
    perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  else
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ từ chối được phiếu thu Đã gửi hoặc Chờ kế toán.');
  end if;
  update app.receipt set status_code = 'NHAP', approval_route = null, assigned_approver_id = null, submitted_at = null, submitted_by = null,
         manager_approved_at = null, manager_approved_by = null where id = p_id;
  perform app.receipt_add_event(p_id, 'TU_CHOI', r.status_code, 'NHAP', p_reason);
end;
$$;

-- get_receipt: route và cơ sở cho kiểm người duyệt (R-V2-12).
create or replace function app.get_receipt(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_actions text[] := array[]::text[];
  v_me uuid := auth.uid();
begin
  select * into r from app.receipt where id = p_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'XEM', r.branch_id);
  select * into v_o from app.sales_order where id = r.order_id;
  if r.status_code = 'NHAP' and r.created_by is not distinct from v_me and app.can_see_branch('RECEIPT', 'TAO', r.branch_id) then
    v_actions := v_actions || array['sua', 'gui'];
  end if;
  if r.status_code = 'DA_GUI' and app.can_see_branch('RECEIPT', 'DUYET', r.branch_id)
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
    v_actions := v_actions || array['duyet_quan_ly', 'tu_choi'];
  end if;
  if r.status_code = 'CHO_KE_TOAN' and app.can_see_branch('ACCOUNTING', 'DUYET', r.branch_id) then
    v_actions := v_actions || array['duyet_ke_toan', 'tu_choi'];
  end if;
  if r.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
     and (r.created_by is not distinct from v_me and app.can_see_branch('RECEIPT', 'TAO', r.branch_id) or app.can_see_branch('RECEIPT', 'HUY', r.branch_id)) then
    v_actions := v_actions || array['huy'];
  end if;
  return jsonb_build_object(
    'id', r.id, 'code', r.code, 'status_code', r.status_code,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = r.status_code),
    'order', jsonb_build_object('id', v_o.id, 'code', v_o.code, 'total_amount', v_o.total_amount, 'status_code', v_o.status_code),
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone) from app.parent p where p.id = r.parent_id),
    'amount', r.amount, 'payment_method_code', r.payment_method_code,
    'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = r.payment_method_code),
    'txn_ref', r.txn_ref, 'paid_on', r.paid_on, 'note', r.note, 'target_line_id', r.target_line_id,
    'branch_code', (select code from app.branch where id = r.branch_id), 'collect_branch_id', r.collect_branch_id,
    'collect_branch_code', (select code from app.branch where id = r.collect_branch_id),
    'receiver_id', r.receiver_id, 'receiver_name', app.staff_display_name(r.receiver_id),
    'created_at', r.created_at, 'created_by', r.created_by, 'created_by_name', app.staff_display_name(r.created_by),
    'approver_name', app.staff_display_name(r.assigned_approver_id), 'approval_route', r.approval_route,
    'submitted_at', r.submitted_at, 'manager_approved_at', r.manager_approved_at, 'accountant_approved_at', r.accountant_approved_at,
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_CANCEL_REASON' and c.code = r.cancel_reason_code),
    'cancel_note', r.cancel_note, 'cancelled_at', r.cancelled_at,
    'payment', app.order_payment_summary(r.order_id),
    'actions', to_jsonb(v_actions),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
                                                            'note', e.note, 'at', e.created_at, 'by_name', app.staff_display_name(e.created_by))
                                         order by e.seq) from app.receipt_event e where e.receipt_id = r.id), '[]'::jsonb),
    'money_in', (select jsonb_build_object('code', m.code, 'amount', m.amount,
                   'allocations', (select coalesce(jsonb_agg(jsonb_build_object('line_no', l.line_no, 'package_name', l.package_name, 'amount', a.amount)
                                                             order by l.line_no), '[]'::jsonb)
                                     from app.money_in_allocation a join app.sales_order_line l on l.id = a.order_line_id where a.money_in_id = m.id))
                   from app.money_in m where m.receipt_id = r.id));
end;
$$;
