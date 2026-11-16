// Đổi nhật ký phiếu (app.get_ticket_task) thành mục dòng thời gian của khuôn Chatter (CSN-06). Mới nhất lên đầu.
import type { ChatterEntry } from '../../ui/Chatter';
import { TASK_STATUS_LABEL, type TaskEvent } from './phieuTypes';

const TEXT: Record<TaskEvent['event_type'], string> = {
  TAO: 'Tạo phiếu.',
  TRINH: 'Trình duyệt.',
  DUYET: 'Duyệt.',
  TU_CHOI: 'Từ chối.',
  THUC_HIEN: 'Thực hiện phiếu.',
  HUY: 'Huỷ phiếu.',
};

export function taskTimeline(events: TaskEvent[]): ChatterEntry[] {
  return [...events].reverse().map((e): ChatterEntry => ({
    kind: 'system',
    id: e.id,
    at: e.created_at,
    author: e.created_by_name ?? 'Hệ thống',
    text: [
      TEXT[e.event_type],
      e.from_status && e.to_status && e.from_status !== e.to_status
        ? `${TASK_STATUS_LABEL[e.from_status] ?? e.from_status} → ${TASK_STATUS_LABEL[e.to_status] ?? e.to_status}.`
        : '',
      e.note ?? '',
    ]
      .filter((s) => s !== '')
      .join(' '),
  }));
}
