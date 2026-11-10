// Logic thuần của LOP-08 Lịch tuần cơ sở: khoảng ngày của tuần (thứ Hai đến Chủ nhật), nhóm buổi theo ngày và theo phòng hoặc giáo viên,
// màu viền theo nhóm lớp (hai lớp cùng nhóm cùng màu, R-LOP-14). Luật R-LOP-08: trùng phòng, trùng giáo viên chỉ cảnh báo, không chặn.
import type { WeekSession } from './classTypes';

const DAY_MS = 86_400_000; // allow-number: số mili giây một ngày

const iso = (d: Date) => d.toISOString().slice(0, 10); // allow-number: cắt yyyy-mm-dd từ chuỗi ISO
const fromIso = (s: string) => new Date(`${s}T00:00:00Z`);

/** Thứ Hai của tuần chứa ngày (yyyy-mm-dd). */
export function weekStart(day: string): string {
  const d = fromIso(day);
  const offset = (d.getUTCDay() + 6) % 7; // allow-number: đổi Chủ nhật = 0 thành cuối tuần
  return iso(new Date(d.getTime() - offset * DAY_MS));
}

export function addDays(day: string, n: number): string {
  return iso(new Date(fromIso(day).getTime() + n * DAY_MS));
}

/** Bảy ngày của tuần bắt đầu từ thứ Hai. */
export function weekDays(start: string): string[] {
  return Array.from({ length: 7 }, (_, i) => addDays(start, i)); // allow-number: bảy ngày một tuần
}

export type GroupBy = 'ROOM' | 'TEACHER';

/** Nhãn nhóm của một buổi (phòng hoặc giáo viên); trống thì "Chưa có phòng" / "Chưa có giáo viên". */
export function groupLabel(s: WeekSession, by: GroupBy): string {
  return by === 'ROOM' ? (s.room_name ?? 'Chưa có phòng') : (s.teacher_name ?? 'Chưa có giáo viên');
}

/** Dòng của lịch: mỗi phòng hoặc giáo viên là một dòng, mỗi ngày là một ô chứa các buổi theo giờ. */
export function buildRows(sessions: WeekSession[], days: string[], by: GroupBy) {
  const rows = new Map<string, Map<string, WeekSession[]>>();
  for (const s of sessions) {
    const label = groupLabel(s, by);
    const byDay = rows.get(label) ?? new Map<string, WeekSession[]>();
    byDay.set(s.session_date, [...(byDay.get(s.session_date) ?? []), s]);
    rows.set(label, byDay);
  }
  return [...rows.entries()]
    .sort(([a], [b]) => a.localeCompare(b, 'vi'))
    .map(([label, byDay]) => ({
      label,
      cells: days.map((d) =>
        (byDay.get(d) ?? []).sort((x, y) => x.start_time.localeCompare(y.start_time)),
      ),
    }));
}

const PALETTE = ['#EF6925', '#2563EB', '#059669', '#9333EA', '#DB2777', '#CA8A04'];

/** Màu viền theo nhóm lớp: cùng nhóm cùng màu; lớp không thuộc nhóm nào dùng màu trung tính. */
export function groupColor(groupId: string | null): string {
  if (!groupId) return '#9CA3AF';
  let h = 0;
  for (const ch of groupId) h = (h * 31 + ch.charCodeAt(0)) >>> 0; // allow-number: băm chuỗi ra chỉ số màu
  return PALETTE[h % PALETTE.length] ?? '#9CA3AF';
}

export const clashCount = (sessions: WeekSession[]) =>
  sessions.filter((s) => s.room_clash || s.teacher_clash).length;
