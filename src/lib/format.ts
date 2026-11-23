// Định dạng hiển thị dùng chung: tiền "9.504.000 đ", ngày dd/mm/yyyy, giờ 24h, múi giờ Việt Nam.
const TIME_ZONE = 'Asia/Ho_Chi_Minh';

const DATE = new Intl.DateTimeFormat('vi-VN', {
  timeZone: TIME_ZONE,
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
});
const TIME = new Intl.DateTimeFormat('vi-VN', {
  timeZone: TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});
const NUMBER = new Intl.NumberFormat('vi-VN');

function toDate(value: string | Date): Date | null {
  const date = typeof value === 'string' ? new Date(value) : value;
  return Number.isNaN(date.getTime()) ? null : date;
}

/** 11/10/2026 */
export function formatDate(value: string | Date | null | undefined): string {
  const date = value ? toDate(value) : null;
  return date ? DATE.format(date) : '';
}

/** 05/2026 */
export function formatMonth(value: string | Date | null | undefined): string {
  const date = value ? toDate(value) : null;
  return date ? DATE.format(date).slice(3) : '';
}

/** 09:42 */
export function formatTime(value: string | Date | null | undefined): string {
  const date = value ? toDate(value) : null;
  return date ? TIME.format(date) : '';
}

/** 11/10/2026 09:42 */
export function formatDateTime(value: string | Date | null | undefined): string {
  const date = value ? toDate(value) : null;
  return date ? `${DATE.format(date)} ${TIME.format(date)}` : '';
}

/** "09:42 hôm nay" nếu trong ngày (giờ Việt Nam), còn lại "11/10/2026 09:42". */
export function formatWhen(value: string | Date, now: Date = new Date()): string {
  const date = toDate(value);
  if (!date) return '';
  return DATE.format(date) === DATE.format(now)
    ? `${TIME.format(date)} hôm nay`
    : formatDateTime(date);
}

/** 9.504.000 */
export function formatNumber(value: number): string {
  return NUMBER.format(value);
}

/** 9.504.000 đ (tiền là số nguyên đồng). */
export function formatMoney(value: number | null | undefined): string {
  return value === null || value === undefined ? '' : `${NUMBER.format(value)} đ`;
}

/** Đọc số tiền người dùng gõ ("9.504.000", "9504000 đ") thành số nguyên đồng; rỗng thì null. */
export function parseMoney(text: string): number | null {
  const digits = text.replace(/\D/g, '');
  return digits === '' ? null : Number(digits);
}

/** Gấp chữ để tìm không dấu, khớp với app.fold_text trong cơ sở dữ liệu. */
export function foldText(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}
