// Đổi sự kiện của phiếu tái tục (get_upsale_ticket.events) thành mục dòng thời gian bên phải (khung chung «Ghi chú & hoạt động»). Hàm thuần, có kiểm thử.
import type { ChatterEntry } from '../../ui/Chatter';
import type { UpsaleEvent } from './upsaleTypes';

export function upsaleEventTitle(
  e: Pick<UpsaleEvent, 'event_type' | 'from_stage' | 'to_stage'>,
): string {
  switch (e.event_type) {
    case 'TAO':
      return 'Tạo phiếu tái tục';
    case 'GIAO':
      return 'Giao người phụ trách';
    case 'DOI_GIAI_DOAN':
      return e.from_stage && e.to_stage
        ? `Chuyển giai đoạn ${e.from_stage} → ${e.to_stage}`
        : 'Cập nhật phiếu';
    case 'SUA_GHI_CHU':
      return 'Sửa ghi chú phiếu';
  }
}

export function upsaleEventEntries(events: UpsaleEvent[]): ChatterEntry[] {
  return events.map<ChatterEntry>((e) => ({
    kind: 'event',
    id: `upsale-event-${e.id}`,
    at: e.created_at,
    author: e.created_by_name ?? 'Hệ thống',
    title: upsaleEventTitle(e),
    lines: e.note ? [e.note] : [],
  }));
}
