import { DISPLAY_TIME_ZONE } from './datetime';

const PART_FORMAT = new Intl.DateTimeFormat('en-US', {
  timeZone: DISPLAY_TIME_ZONE,
  hourCycle: 'h23',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

type Parts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
};

function partsOf(date: Date): Parts {
  const out: Record<string, number> = {};
  for (const p of PART_FORMAT.formatToParts(date))
    if (p.type !== 'literal') out[p.type] = Number(p.value);
  return out as Parts;
}

/** Chênh lệch (ms) giữa giờ Việt Nam và UTC tại một thời điểm; đọc từ múi giờ, không viết cứng số giờ. */
function offsetMs(date: Date): number {
  const p = partsOf(date);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return asUtc - Math.floor(date.getTime() / 1000) * 1000; // allow-number: đổi giây sang mili giây
}

/** Thời điểm UTC của 00:00 theo giờ Việt Nam của ngày (năm, tháng, ngày) cho trước. */
function startOfVnDate(year: number, month: number, day: number): Date {
  const guess = Date.UTC(year, month - 1, day);
  // Việt Nam không đổi giờ mùa hè; vẫn trừ chênh lệch tại chính thời điểm đó cho đúng nếu múi giờ đổi sau này.
  return new Date(guess - offsetMs(new Date(guess)));
}

/**
 * Ranh giới "hôm nay" theo giờ Việt Nam (Asia/Ho_Chi_Minh), không theo múi giờ của trình duyệt:
 * `start` là 00:00 hôm nay, `end` là 00:00 ngày mai (khoảng nửa mở [start, end)).
 */
export function vnDayBounds(now: Date = new Date()): { start: Date; end: Date; dateKey: string } {
  const p = partsOf(now);
  const pad = (n: number) => String(n).padStart(2, '0'); // allow-number: độ rộng hai chữ số của ngày, tháng
  return {
    start: startOfVnDate(p.year, p.month, p.day),
    end: startOfVnDate(p.year, p.month, p.day + 1),
    dateKey: `${p.year}-${pad(p.month)}-${pad(p.day)}`,
  };
}

/** "Thứ Tư, 14/10/2026" theo giờ Việt Nam. */
export function formatVnDayLong(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: DISPLAY_TIME_ZONE,
    weekday: 'long',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(now);
}

/** Giờ:phút theo giờ Việt Nam, ví dụ "09:00". */
export function formatVnTime(value: string | Date): string {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: DISPLAY_TIME_ZONE,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(typeof value === 'string' ? new Date(value) : value);
}

/** 00:00 theo giờ Việt Nam của một ngày dạng "yyyy-mm-dd" (ô chọn ngày); chuỗi sai thì null. */
export function vnDayStartOf(isoDate: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(isoDate);
  if (!match) return null;
  return startOfVnDate(Number(match[1]), Number(match[2]), Number(match[3]));
}
