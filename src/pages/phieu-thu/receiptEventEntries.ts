// Đổi sự kiện của phiếu thu (get_receipt.events) thành mục dòng thời gian bên phải (Q-52): cùng cột "Ghi chú & hoạt động" như các màn khác.
import type { ChatterEntry } from '../../ui/Chatter';
import { EVENT_TEXT } from './receiptRecord';
import type { ReceiptEvent } from './receiptTypes';

/** Mục dòng thời gian của từng sự kiện phiếu thu; lý do hoặc ghi chú của sự kiện hiện thành một dòng. */
export function receiptEventEntries(events: ReceiptEvent[]): ChatterEntry[] {
  return events.map<ChatterEntry>((e, i) => ({
    kind: 'event',
    id: `receipt-event-${i}`,
    at: e.at,
    author: e.by_name ?? 'Hệ thống',
    title: EVENT_TEXT[e.event_code] ?? e.event_code,
    // Gửi lại mà chưa sửa từ lần bị từ chối: dòng cảnh báo vàng (Q-58), như Trình lại của đơn.
    ...(e.event_code === 'GUI' && e.note
      ? { warning: e.note, lines: [] }
      : { lines: e.note ? [e.note] : [] }),
  }));
}
