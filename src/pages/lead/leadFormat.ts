// Hiển thị riêng của màn Lead (hàm thuần, có kiểm thử).
import { DISPLAY_TIME_ZONE } from '../../lib/datetime';
import { vnDayBounds } from '../../lib/vnDay';

// Ghép từ các phần của Intl (không phụ thuộc cách vi-VN ngăn ngày, tháng trên từng trình duyệt): "15/10", "09:00".
const PARTS = new Intl.DateTimeFormat('en-GB', {
  timeZone: DISPLAY_TIME_ZONE,
  day: '2-digit',
  month: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

function parts(date: Date): { dayMonth: string; time: string } {
  const get = (type: string) => PARTS.formatToParts(date).find((p) => p.type === type)?.value ?? '';
  return { dayMonth: `${get('day')}/${get('month')}`, time: `${get('hour')}:${get('minute')}` };
}

export type AppointmentTag = { label: string; tone: 'neutral' | 'danger' | 'warning' | 'success' };

/**
 * Thẻ "Lịch hẹn kế tiếp" (theo giờ Việt Nam): "Quá hạn 11/10" (trước đầu ngày hôm nay), "Hôm nay 14:00",
 * "15/10 09:00" (từ ngày mai), "Chưa có lịch".
 */
export function appointmentTag(at: string | null, now: Date = new Date()): AppointmentTag {
  if (!at) return { label: 'Chưa có lịch', tone: 'neutral' };
  const date = new Date(at);
  if (Number.isNaN(date.getTime())) return { label: 'Chưa có lịch', tone: 'neutral' };
  const { start, end } = vnDayBounds(now);
  if (date < start) return { label: `Quá hạn ${parts(date).dayMonth}`, tone: 'danger' };
  if (date < end) return { label: `Hôm nay ${parts(date).time}`, tone: 'warning' };
  return { label: `${parts(date).dayMonth} ${parts(date).time}`, tone: 'success' };
}

/** "0912000121" → "0912 000 121" (SĐT Việt Nam 10 số); số khác dạng giữ nguyên. */
export function formatPhone(phone: string): string {
  const match = /^(\d{4})(\d{3})(\d{3})$/.exec(phone);
  return match ? `${match[1]} ${match[2]} ${match[3]}` : phone;
}

/** "Chị Lê Thu Hằng · Lê Gia Huy" cho thẻ Kanban: tên phụ huynh, kèm tên học sinh nếu có. */
export function leadTitle(row: { parent_name: string; student_name: string | null }): string {
  return row.student_name ? `${row.parent_name} · ${row.student_name}` : row.parent_name;
}

/** "C4 Khách hàng tiềm năng": mã giai đoạn kèm tên danh mục. */
export function codeAndName(code: string, name: string | undefined): string {
  return name ? `${code} ${name}` : code;
}
