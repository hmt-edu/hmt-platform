import { describe, expect, it } from 'vitest';
import { groupRows, isMismatch, presetRange } from './attendanceLogic';
import type { BoardRow } from './attendanceTypes';

const row = (session_id: string, session_date: string, student_id: string): BoardRow => ({
  session_id,
  session_date,
  student_id,
  student_name: student_id,
  start_time: '18:00',
  end_time: '19:30',
  class_code: 'LOP',
  subject_name: 'Toán',
  room_name: null,
  teacher_name: null,
  locked: false,
  session_total: 1,
  session_marked: 0,
  ops_status_code: null,
  teacher_status_code: null,
  contact_reason_code: null,
  contact_reason_name: null,
  ops_note: null,
});

describe('màn Điểm danh', () => {
  it('khoảng ngày chọn nhanh', () => {
    expect(presetRange('today', '2026-12-01')).toEqual({ from: '2026-12-01', to: '2026-12-01' });
    expect(presetRange('yesterday', '2026-12-01')).toEqual({
      from: '2026-11-30',
      to: '2026-11-30',
    });
    expect(presetRange('week', '2026-12-01')).toEqual({ from: '2026-11-25', to: '2026-12-01' });
  });
  it('gom theo ngày rồi theo buổi, giữ thứ tự máy chủ', () => {
    const days = groupRows([
      row('b2', '2026-11-27', 'a'),
      row('b2', '2026-11-27', 'b'),
      row('b3', '2026-11-27', 'a'),
      row('b1', '2026-11-26', 'a'),
    ]);
    expect(days.map((d) => [d.date, d.sessions.map((s) => s.rows.length)])).toEqual([
      ['2026-11-27', [2, 1]],
      ['2026-11-26', [1]],
    ]);
  });
  it('lệch chỉ khi hai cột đều có và khác nhau', () => {
    const base = row('b', '2026-11-27', 'a');
    expect(isMismatch({ ...base, ops_status_code: 'CO_MAT' })).toBe(false);
    expect(isMismatch({ ...base, ops_status_code: 'CO_MAT', teacher_status_code: 'DI_MUON' })).toBe(
      true,
    );
  });
});
