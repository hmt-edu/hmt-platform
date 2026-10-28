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
