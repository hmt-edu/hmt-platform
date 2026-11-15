// Đổi dòng nhật ký ticket (app.get_ticket) thành mục dòng thời gian của khuôn Chatter (CSN-03).
import type { ChatterEntry } from '../../ui/Chatter';
import type { TicketEvent } from './ticketTypes';

export function ticketTimeline(
  events: TicketEvent[],
  statusName: (code: string | null) => string,
): ChatterEntry[] {
  // Mới nhất lên đầu, như các bản ghi khác.
  return [...events].reverse().map((e): ChatterEntry => {
    const author = e.created_by_name ?? 'Hệ thống';
    if (e.event_type === 'GHI_CHU') {
      return {
        kind: 'note',
        id: e.id,
        at: e.created_at,
        author,
        body: e.note ?? '',
        mentions: [],
      };
    }
    const text =
      e.event_type === 'TAO'
        ? 'Tạo ticket.'
        : e.event_type === 'GIAO'
          ? 'Giao ticket.'
          : e.event_type === 'DOI_TRANG_THAI'
            ? `Đổi trạng thái: ${statusName(e.from_status)} → ${statusName(e.to_status)}.`
            : e.event_type === 'DOI_NHOM_CON'
              ? 'Đổi nhóm con.'
              : 'Đổi mức độ.';
    return {
      kind: 'system',
      id: e.id,
      at: e.created_at,
      author,
      text: e.note ? `${text} ${e.note}` : text,
    };
  });
}
