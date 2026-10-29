// Hàm thuần của bản ghi Đơn hàng (BH-05): các bước trên thanh tình trạng, đơn bị từ chối (lấy từ lịch sử), chữ người duyệt dự kiến. Có kiểm thử.
// Không tính tiền (R-TIEN-13).
import type { OrderEvent, OrderRecord } from './orderTypes';

/** Các bước hiện trên thanh tình trạng: Nháp, Đã trình, Đã duyệt; đơn Huỷ thay bước cuối bằng Huỷ (nhánh khác). */
export function orderSteps(record: Pick<OrderRecord, 'status_code'>): string[] {
  return record.status_code === 'HUY' ? ['NHAP', 'HUY'] : ['NHAP', 'DA_TRINH', 'DA_DUYET'];
}

/**
 * Đơn bị từ chối (R-TIEN-06): bị từ chối thì về Nháp, nên "bị từ chối" là sự kiện TU_CHOI gần nhất khi đơn đang Nháp và chưa trình lại.
 * Lý do và người từ chối lấy từ lịch sử đơn; đơn Nháp chưa từng bị từ chối, hoặc đã trình lại, thì không có.
 */
export function lastRejection(
  record: Pick<OrderRecord, 'status_code' | 'events'>,
): OrderEvent | null {
  if (record.status_code !== 'NHAP') return null;
  const last = [...record.events].sort((a, b) => b.seq - a.seq).find((e) => e.event_code !== 'TAO');
  return last?.event_code === 'TU_CHOI' ? last : null;
}

/** Dòng "Người duyệt" cạnh nút Trình của đơn Nháp, theo đường duyệt dự kiến (R-HT-06). */
export function expectedApproverText(
  record: Pick<
    OrderRecord,
    'status_code' | 'expected_route' | 'expected_approver_name' | 'created_by_name'
  >,
): string | null {
  if (record.status_code !== 'NHAP' || record.expected_route === null) return null;
  if (record.expected_route === 'THIEU')
    return 'Người duyệt: chưa có · người lập chưa có quản lý trực tiếp';
  const name = record.expected_approver_name ?? '';
  return record.expected_route === 'TU_DUYET'
    ? `Người duyệt: ${name} · Trưởng cơ sở tự duyệt`
    : `Người duyệt: ${name} · quản lý trực tiếp của ${record.created_by_name ?? ''}`;
}

/** Cảnh báo trước khi trình (Đ205, R-HT-06); rỗng khi không có gì cần báo. Câu cùng chữ với lỗi máy chủ. */
export function approverWarning(
  record: Pick<
    OrderRecord,
    'status_code' | 'expected_route' | 'expected_approver_can_approve' | 'expected_approver_name'
  >,
): string | null {
  if (record.status_code !== 'NHAP') return null;
  if (record.expected_route === 'THIEU')
    return 'Chưa có quản lý trực tiếp để duyệt. Nhờ Admin đặt Quản lý trực tiếp cho người lập rồi trình lại.';
  if (record.expected_approver_can_approve === false)
    return `${record.expected_approver_name ?? 'Người duyệt'} chưa có quyền Duyệt đơn hàng ở cơ sở này nên chưa trình được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.`;
  return null;
}

/** Nút Trình: đơn Nháp, người xem có quyền Đơn hàng · Sửa và Bán hàng đang bật (Đ173); điện thoại chỉ đọc (Đ248). Máy chủ kiểm lại. */
export function canSubmitOrder(
  record: Pick<OrderRecord, 'status_code'>,
  can: { edit: boolean; featureOn: boolean; phone: boolean },
): boolean {
  return record.status_code === 'NHAP' && can.edit && can.featureOn && !can.phone;
}

/**
 * Mục Huỷ đơn (R-TIEN-38): người có quyền Đơn hàng · Huỷ và Bán hàng đang bật; đơn Nháp chỉ NGƯỜI LẬP huỷ; đơn Đã trình, Đã duyệt do người
 * duyệt đã chốt lúc trình huỷ, hoặc người duyệt thay (quyền Quản trị, như Admin). Đơn Huỷ rồi thì không. Điện thoại chỉ đọc (Đ248).
 * "Chỉ khi chưa có phiếu thu" do máy chủ kiểm (order_has_receipt): khi bấm mà bị chặn thì hộp hiện câu máy chủ.
 */
export function canCancelOrder(
  record: Pick<OrderRecord, 'status_code' | 'created_by' | 'assigned_approver_id'>,
  me: {
    userId: string;
    canCancel: boolean;
    featureOn: boolean;
    approvesInstead: boolean;
    phone: boolean;
  },
): boolean {
  if (!me.canCancel || !me.featureOn || me.phone || record.status_code === 'HUY') return false;
  if (record.status_code === 'NHAP') return record.created_by === me.userId;
  return record.assigned_approver_id === me.userId || me.approvesInstead;
}

/** Số dòng đơn được nêu trong câu lỗi của máy chủ ("Dòng 3: …; Dòng 5: …"), để chỉ đúng dòng. */
export function errorLineNumbers(message: string): number[] {
  const found = [...message.matchAll(/Dòng (\d+)/g)].map((m) => Number(m[1]));
  return [...new Set(found)];
}
