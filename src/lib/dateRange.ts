// Mốc nhanh của khoảng ngày (Hôm nay, Tuần này, Tuần trước, Tháng này, Tháng trước) và khoảng tự chọn. Tuần bắt đầu từ thứ Hai.
import { startOfVnDate, vnDayBounds } from './vnDay';

// Khoảng tự chọn nằm ngay trong chuỗi mốc ("range:2026-11-01:2026-11-15") nên mọi bộ lọc và bộ lọc đã lưu dùng chung một đường (L1).
const CUSTOM_RANGE = /^range:(\d{4})-(\d{2})-(\d{2}):(\d{4})-(\d{2})-(\d{2})$/;

const dayKey = (d: Date) => {
  const pad = (n: number) => String(n).padStart(2, '0'); // allow-number: độ rộng hai chữ số của ngày, tháng
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

export function customRangePreset(from: Date, to: Date): string {
  return `range:${dayKey(from)}:${dayKey(to)}`;
}

/** Ngày đầu, ngày cuối của khoảng tự chọn; null nếu `preset` không phải khoảng tự chọn. */
export function customRangeDays(preset: string): { from: Date; to: Date } | null {
  const match = CUSTOM_RANGE.exec(preset);
  if (!match) return null;
  const [y1 = 0, m1 = 1, d1 = 1, y2 = 0, m2 = 1, d2 = 1] = match.slice(1).map(Number);
  return { from: new Date(y1, m1 - 1, d1), to: new Date(y2, m2 - 1, d2) };
}

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
    case 'last-week': {
      const monday = new Date(
        day.getFullYear(),
        day.getMonth(),
        day.getDate() - ((day.getDay() + WEEK - 1) % WEEK) - WEEK,
      );
      const sunday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + WEEK - 1);
      return { from: monday, to: new Date(endOf(sunday)) };
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
    default: {
      const custom = customRangeDays(preset);
      return custom && { from: custom.from, to: new Date(endOf(custom.to)) };
    }
  }
}

/**
 * Cùng mốc nhanh với `datePresetRange` nhưng trả về THỜI ĐIỂM thật: `from` là 00:00 giờ Việt Nam của ngày đầu, `to` là mili giây cuối cùng của ngày cuối
 * (23:59:59.999 giờ Việt Nam). Dùng để lọc theo thời điểm (so với dữ liệu, gửi lên máy chủ). `datePresetRange` giữ cho ô chọn ngày (ngày lịch, theo múi giờ máy).
 * R-HT-07 (Q-171): kết quả không phụ thuộc múi giờ của máy.
 */
export function datePresetInstants(preset: string, today: Date): { from: Date; to: Date } | null {
  const days = datePresetRange(preset, today);
  if (!days) return null;
  return {
    from: startOfVnDate(days.from.getFullYear(), days.from.getMonth() + 1, days.from.getDate()),
    to: new Date(
      startOfVnDate(
        days.to.getFullYear(),
        days.to.getMonth() + 1,
        days.to.getDate() + 1,
      ).getTime() - 1,
    ),
  };
}

/** Cùng mốc nhanh dạng ngày lịch yyyy-mm-dd (đầu, cuối khoảng) để lọc theo cột kiểu ngày (hạn thu). Không phụ thuộc múi giờ của máy. */
export function datePresetDateKeys(
  preset: string,
  today: Date,
): { from: string; to: string } | null {
  const days = datePresetRange(preset, today);
  if (!days) return null;
  return { from: dayKey(days.from), to: dayKey(days.to) };
}
