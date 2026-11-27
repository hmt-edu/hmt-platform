// Hàm thuần của Lịch tuần (canvas 1bcc, VC06): màu ô theo tình trạng và chữ trên ô. Có kiểm thử.
import type { CalendarKind } from '../../list/Calendar';
import type { CalendarEvent } from '../../list/calendarLogic';
import type { AppointmentRow } from '../lich-hen/appointmentTypes';

export type WeekState = 'open' | 'overdue' | 'done';

export const WEEK_KINDS: (CalendarKind & { key: WeekState })[] = [
  { key: 'done', label: 'Đã hoàn thành', icon: 'done', tone: 'success' },
  { key: 'overdue', label: 'Quá hạn', icon: 'alert', tone: 'danger' },
  { key: 'open', label: 'Chưa làm', icon: 'clock', tone: 'warning' },
];

export function weekState(
  row: Pick<AppointmentRow, 'status' | 'scheduled_at'>,
  now: Date,
): WeekState {
  if (row.status === 'HOAN_THANH') return 'done';
  return new Date(row.scheduled_at).getTime() < now.getTime() ? 'overdue' : 'open';
}

export function weekEvent(
  row: AppointmentRow,
  activity: string,
  now: Date,
  minutes: number,
): CalendarEvent {
  const start = new Date(row.scheduled_at);
  // Lịch gắn phiếu kiểm tra ghi «Test» thay cho loại hoạt động.
  const what = row.student_test_id ? 'Test' : activity;
  return {
    id: row.id,
    title: `${what} · ${row.record_label ?? row.title}`,
    start,
    end: new Date(start.getTime() + minutes * 60_000), // allow-number: số mili giây trong một phút
    kind: weekState(row, now),
    // Để «open» cho mọi ô: màu và biểu tượng đã theo tình trạng, không tô xám hay gạch chữ ô đã hoàn thành.
    status: 'open',
    subtitle: row.record_code ?? undefined,
  };
}
