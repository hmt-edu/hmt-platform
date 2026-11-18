// Hàm thuần cho các hộp chọn lớp (BH-08, GD-03): nhãn thứ, nhãn buổi sắp tới, ngày vào lớp mặc định, lý do mờ. Luật (đúng thứ, đúng buổi, trùng giờ)
// do máy chủ quyết (app.assert_enrol_start_date, app.assert_no_time_clash); giao diện chỉ gợi ý và hiện lý do báo trước.
import type { MatchingClass } from './enrollTypes';

export function weekdayLabel(isodow: number): string {
  return isodow === 7 ? 'Chủ nhật' : `Thứ ${isodow + 1}`;
}

/** "03/11 · Thứ 3, buổi 8" cho một buổi sắp tới (date dạng yyyy-mm-dd). */
export function upcomingLabel(date: string, sessionNo: number | null): string {
  const [y, m, d] = date.split('-').map(Number);
  const isodow = y && m && d ? ((new Date(Date.UTC(y, m - 1, d, 12)).getUTCDay() + 6) % 7) + 1 : 1;
  const dm = `${date.slice(8, 10)}/${date.slice(5, 7)}`;
  return `${dm} · ${weekdayLabel(isodow)}${sessionNo ? `, buổi ${sessionNo}` : ''}`;
}

/** Ngày vào lớp gợi ý: buổi sắp tới đầu tiên; lớp chưa có buổi thì trống (người dùng chọn đúng thứ có lịch). */
export function defaultStart(cls: MatchingClass): string {
  return cls.upcoming[0]?.date ?? '';
}

/** Lý do báo trước vì sao lớp mờ (không chọn được), hoặc null. R-GD-15: lớp luân phiên không báo trùng (máy chủ đã tính). */
export function disabledReason(cls: MatchingClass): string | null {
  if (cls.clash_sessions > 0) {
    return `Trùng ${cls.clash_sessions} buổi với lớp em đang học`;
  }
  return null;
}

/** "Còn 4 chỗ" / "Không giới hạn sĩ số". */
export function seatsText(cls: MatchingClass): string {
  return cls.seats_left === null ? 'Không giới hạn sĩ số' : `Còn ${cls.seats_left} chỗ`;
}

/** Gợi ý chọn ngày cho lớp chưa có buổi: "Ngày đúng Thứ 3, Thứ 5, không trước 06/10/2026". */
export function startHint(cls: MatchingClass): string {
  const days = [...cls.weekdays]
    .sort((a, b) => a - b)
    .map(weekdayLabel)
    .join(', ');
  const [y, m, d] = cls.class_start_date.split('-');
  return `Lớp chưa có buổi: chọn ngày đúng ${days || 'thứ có lịch'}, không trước ${d}/${m}/${y}.`;
}

/** Chuyển Date (giờ máy) sang yyyy-mm-dd. */
export function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: hai chữ số
}
export function keyToDate(key: string): Date | null {
  const [y, m, d] = key.split('-').map(Number);
  return y && m && d ? new Date(y, m - 1, d) : null;
}
