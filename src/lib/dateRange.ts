// Mốc nhanh của khoảng ngày (Hôm nay, Tuần này, Tháng này, Tháng trước). Tuần bắt đầu từ thứ Hai.
import { vnDayBounds } from './vnDay';

/**
 * Khoảng ngày của một mốc nhanh. Tuần bắt đầu từ thứ Hai. `to` tính hết ngày.
 * "Hôm nay" là ngày lịch Việt Nam (Asia/Ho_Chi_Minh), không theo múi giờ của trình duyệt: máy ở múi giờ khác
 * (hoặc máy chạy kiểm thử ở UTC) lúc 00:00–07:00 giờ Việt Nam vẫn ra đúng ngày, đúng tuần như hộp Tạo lịch hẹn.
 */
export function datePresetRange(preset: string, today: Date): { from: Date; to: Date } | null {
  const [y, m, d] = vnDayBounds(today).dateKey.split('-').map(Number);
  // dateKey luôn có đủ ba phần; giá trị dự phòng chỉ để thoả kiểu.
  const day = new Date(y ?? 0, (m ?? 1) - 1, d ?? 1);
  const DAY = 86_400_000; // allow-number: số mili giây trong một ngày
  const WEEK = 7; // allow-number: số ngày trong tuần
  const endOf = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime() - 1;
  switch (preset) {
    case 'today':
      return { from: day, to: new Date(endOf(day)) };
    case 'week': {
      const monday = new Date(day.getTime() - ((day.getDay() + WEEK - 1) % WEEK) * DAY);
      return { from: monday, to: new Date(endOf(new Date(monday.getTime() + (WEEK - 1) * DAY))) };
    }
    case 'month':
      return {
        from: new Date(day.getFullYear(), day.getMonth(), 1),
        to: new Date(endOf(new Date(day.getFullYear(), day.getMonth() + 1, 0))),
      };
    case 'last-month':
      return {
        from: new Date(day.getFullYear(), day.getMonth() - 1, 1),
        to: new Date(endOf(new Date(day.getFullYear(), day.getMonth(), 0))),
      };
    default:
      return null;
  }
}
