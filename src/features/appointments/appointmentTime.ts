// Ngày giờ của hộp Tạo và Dời lịch hẹn (TS-13): chọn nhanh ngày, giờ; ghép ngày và giờ theo giờ Việt Nam. Hàm thuần.
import { toIsoDate } from '../../lib/dateText';
import { vnDayBounds, vnDayStartOf } from '../../lib/vnDay';

/** Giờ chọn nhanh trong hộp (theo bản vẽ TS-13): các giờ hẹn hay dùng, không phải số nghiệp vụ. */
export const QUICK_HOURS = [
  '08:00',
  '09:00',
  '10:00',
  '14:00',
  '15:30',
  '17:00',
  '18:30',
  '19:30',
  '20:00',
]; // allow-number: giờ chọn nhanh của giao diện

const WEEKDAY = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
const WEEK = 7; // allow-number: số ngày trong tuần
const AFTER_TOMORROW = 2; // allow-number: "Ngày kia" là hai ngày sau hôm nay
const MINUTES_PER_HOUR = 60; // allow-number: đổi giờ ra phút
const MS_PER_MINUTE = 60_000; // allow-number: đổi phút ra mili giây

export type QuickDay = { label: string; date: Date };

/** Ngày lịch Việt Nam của `now` dưới dạng Date địa phương 00:00 (để ô ngày dd/mm/yyyy hiện đúng). */
export function vnToday(now: Date = new Date()): Date {
  const [y, m, d] = vnDayBounds(now).dateKey.split('-').map(Number);
  // dateKey luôn có đủ ba phần; giá trị dự phòng chỉ để thoả kiểu.
  return new Date(y ?? 0, (m ?? 1) - 1, d ?? 1);
}

const addDays = (date: Date, days: number) =>
  new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
const dayMonth = (date: Date) =>
  `${String(date.getDate()).padStart(2, '0')}/${String(date.getMonth() + 1).padStart(2, '0')}`; // allow-number: độ rộng hai chữ số

/**
 * Chọn nhanh ngày: Hôm nay, Ngày mai, Ngày kia, rồi thứ Bảy, Chủ nhật, thứ Hai kế tiếp (nếu chưa nằm trong ba ngày đầu)
 * và Tuần sau (bảy ngày nữa). Theo ngày lịch Việt Nam.
 */
export function quickDays(now: Date = new Date()): QuickDay[] {
  const today = vnToday(now);
  const days: QuickDay[] = [
    { label: 'Hôm nay', date: today },
    { label: 'Ngày mai', date: addDays(today, 1) },
    { label: 'Ngày kia', date: addDays(today, AFTER_TOMORROW) },
  ];
  const next = (weekday: number) => {
    let offset = AFTER_TOMORROW + 1;
    while (addDays(today, offset).getDay() !== weekday) offset += 1;
    return addDays(today, offset);
  };
  for (const weekday of [6, 0, 1]) {
    const date = next(weekday);
    days.push({ label: `${WEEKDAY[weekday] ?? ''} ${dayMonth(date)}`, date });
  }
  days.push({ label: 'Tuần sau', date: addDays(today, WEEK) });
  return days.sort((a, b) => a.date.getTime() - b.date.getTime());
}

/** "08:30" → số phút từ 00:00; sai dạng thì null. */
export function parseTime(time: string): number | null {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(time);
  return match ? Number(match[1]) * MINUTES_PER_HOUR + Number(match[2]) : null;
}

/** Ghép ngày (Date địa phương) và giờ "HH:mm" thành thời điểm theo giờ Việt Nam; thiếu hoặc sai thì null. */
export function combineVn(date: Date | null, time: string): Date | null {
  const minutes = parseTime(time);
  if (!date || minutes === null) return null;
  const start = vnDayStartOf(toIsoDate(date));
  return start ? new Date(start.getTime() + minutes * MS_PER_MINUTE) : null;
}
