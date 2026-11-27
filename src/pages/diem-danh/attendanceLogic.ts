// Hàm thuần của màn «Điểm danh»: khoảng ngày chọn nhanh, nhóm dòng theo ngày rồi theo buổi, khoá chọn một dòng.
import { addDays } from '../lop/weekLogic';
import type { BoardRow } from './attendanceTypes';

export type RangePreset = 'today' | 'yesterday' | 'week';

export const PRESETS: { key: RangePreset; label: string }[] = [
  { key: 'today', label: 'Hôm nay' },
  { key: 'yesterday', label: 'Hôm qua' },
  { key: 'week', label: '7 ngày qua' },
];

export function presetRange(preset: RangePreset, today: string): { from: string; to: string } {
  if (preset === 'today') return { from: today, to: today };
  if (preset === 'yesterday') {
    const day = addDays(today, -1);
    return { from: day, to: day };
  }
  return { from: addDays(today, -6), to: today }; // allow-number: «7 ngày qua» gồm cả hôm nay
}

export const rowKey = (r: { session_id: string; student_id: string }) =>
  `${r.session_id}:${r.student_id}`;

export type SessionGroup = { sessionId: string; head: BoardRow; rows: BoardRow[] };
export type DayGroup = { date: string; sessions: SessionGroup[] };

/** Máy chủ đã xếp theo ngày, giờ, lớp, tên: chỉ gom các dòng liền nhau. */
export function groupRows(rows: BoardRow[]): DayGroup[] {
  const days: DayGroup[] = [];
  for (const row of rows) {
    let day = days.at(-1);
    if (!day || day.date !== row.session_date) {
      day = { date: row.session_date, sessions: [] };
      days.push(day);
    }
    let session = day.sessions.at(-1);
    if (!session || session.sessionId !== row.session_id) {
      session = { sessionId: row.session_id, head: row, rows: [] };
      day.sessions.push(session);
    }
    session.rows.push(row);
  }
  return days;
}

export const isMismatch = (r: BoardRow) =>
  r.ops_status_code !== null &&
  r.teacher_status_code !== null &&
  r.ops_status_code !== r.teacher_status_code;
