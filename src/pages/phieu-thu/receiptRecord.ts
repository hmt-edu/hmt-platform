// Phần thuần của trang Phiếu thu (TC-02): chữ lý do, dữ liệu nháp để sửa, kiểm ô trước khi gửi. Luật tiền, quyền, trạng thái do hàm DB kiểm.
import type { ReceiptEvent, ReceiptInput, ReceiptRecord, ReceiptStatus } from './receiptTypes';

/** Bước của thanh tình trạng (chỉ đọc): Nháp, Đã gửi, Chờ kế toán, Đã duyệt; Huỷ thì thêm bước Huỷ. */
export function receiptSteps(status: ReceiptStatus): ReceiptStatus[] {
  return status === 'HUY'
    ? ['NHAP', 'DA_GUI', 'CHO_KE_TOAN', 'HUY']
    : ['NHAP', 'DA_GUI', 'CHO_KE_TOAN', 'DA_DUYET'];
}

/** Nháp để sửa, lấy từ bản ghi (số tiền là số đồng). */
export type ReceiptDraft = {
  amount: number | null;
  paymentMethod: string;
  paidOn: string;
  txnRef: string;
  receiverId: string;
  receiverName: string;
  collectBranchId: string;
  targetLineId: string;
  note: string;
};

export function draftOf(r: ReceiptRecord): ReceiptDraft {
  return {
    amount: r.amount,
    paymentMethod: r.payment_method_code,
    paidOn: r.paid_on,
    txnRef: r.txn_ref ?? '',
    receiverId: r.receiver_id ?? '',
    receiverName: r.receiver_name ?? '',
    collectBranchId: r.collect_branch_id,
    targetLineId: r.target_line_id ?? '',
    note: r.note ?? '',
  };
}

export function inputOf(d: ReceiptDraft): ReceiptInput {
  return {
    amount: d.amount ?? 0,
    payment_method_code: d.paymentMethod,
    txn_ref: d.txnRef.trim() === '' ? null : d.txnRef.trim(),
    paid_on: d.paidOn,
    collect_branch_id: d.collectBranchId,
    receiver_id: d.receiverId === '' ? null : d.receiverId,
    target_line_id: d.targetLineId === '' ? null : d.targetLineId,
    note: d.note.trim() === '' ? null : d.note.trim(),
  };
}

/** Lý do gửi hàm từ chối, huỷ: tên lý do, kèm ghi chú nếu có ("Sai chứng từ: ghi chú"). */
export function reasonText(reasonName: string, note: string): string {
  const extra = note.trim();
  return extra === '' ? reasonName : `${reasonName}: ${extra}`;
}

export const EVENT_TEXT: Record<string, string> = {
  TAO: 'Tạo phiếu thu',
  SUA: 'Sửa phiếu',
  GUI: 'Trình quản lý duyệt',
  DUYET_QL: 'Quản lý duyệt',
  TU_DUYET_QL: 'Trưởng cơ sở tự duyệt',
  DUYET_KT: 'Kế toán duyệt',
  TU_CHOI: 'Từ chối',
  HUY: 'Huỷ phiếu thu',
};

/** Nhãn đóng khung theo tình trạng: chỉ phiếu đã duyệt in sạch. */
export function receiptStamp(status: ReceiptStatus): string | null {
  if (status === 'NHAP') return 'BẢN NHÁP';
  if (status === 'DA_GUI' || status === 'CHO_KE_TOAN') return 'CHỜ DUYỆT';
  if (status === 'HUY') return 'ĐÃ HUỶ';
  return null;
}

/** Lần từ chối gần nhất của phiếu đang Nháp (sự kiện TU_CHOI), kèm vị trí trong lịch sử; phiếu không phải Nháp hoặc chưa từng bị từ chối thì null. */
export function lastRejection(
  record: Pick<ReceiptRecord, 'status_code' | 'events'>,
): { event: ReceiptEvent; index: number } | null {
  if (record.status_code !== 'NHAP') return null;
  for (let i = record.events.length - 1; i >= 0; i--) {
    const e = record.events[i];
    if (e && e.event_code === 'TU_CHOI') return { event: e, index: i };
  }
  return null;
}

/** Phiếu bị từ chối rồi đã có lần sửa (sự kiện SUA) sau lần từ chối cuối (R-TIEN-06, Q-58). Chưa từng bị từ chối thì sai. */
export function editedSinceRejection(
  record: Pick<ReceiptRecord, 'status_code' | 'events'>,
): boolean {
  const rejection = lastRejection(record);
  return (
    rejection !== null &&
    record.events.some((e, i) => i > rejection.index && e.event_code === 'SUA')
  );
}

/** Lần từ chối cuối do Kế toán (phiếu đang Chờ kế toán lúc bị từ chối): hộp xác nhận nhắc "Trình lại sẽ đi từ bước quản lý duyệt". */
export function rejectedByAccountant(
  record: Pick<ReceiptRecord, 'status_code' | 'events'>,
): boolean {
  return lastRejection(record)?.event.from_status === 'CHO_KE_TOAN';
}
