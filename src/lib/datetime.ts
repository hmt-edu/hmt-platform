export const DISPLAY_TIME_ZONE = 'Asia/Ho_Chi_Minh';

const dateTimeFormatter = new Intl.DateTimeFormat('vi-VN', {
  timeZone: DISPLAY_TIME_ZONE,
  dateStyle: 'short',
  timeStyle: 'medium',
});

/** Hiển thị thời điểm (UTC trong DB) theo giờ Việt Nam. */
export function formatDateTime(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return Number.isNaN(date.getTime()) ? String(value) : dateTimeFormatter.format(date);
}
