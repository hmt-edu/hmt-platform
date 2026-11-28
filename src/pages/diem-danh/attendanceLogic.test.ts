import { describe, expect, it } from 'vitest';
import { boardGroups, isMismatch, presetRange } from './attendanceLogic';
import type { BoardRow } from './attendanceTypes';

const row = (student_id: string, k1: string, k2: string | null = null): BoardRow => ({
  session_id: 'b',
  session_date: '2026-11-27',
  student_id,
  student_code: student_id,
  student_name: student_id,
  start_time: '18:00',
  end_time: '19:30',
  class_id: 'c',
  class_code: 'LOP',
  subject_name: 'Toán',
  grade_code: null,
  parent_name: 'Phụ huynh giả',
  parent_phone: null,
  teacher_name: null,
  cskh_name: null,
  locked: false,
  ops_status_code: null,
  teacher_status_code: null,
  teacher_marked_at: null,
  contact_reason_code: null,
  contact_reason_name: null,
  ops_note: null,
  k1,
  k2,
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
  it('nhóm hai cấp giữ thứ tự máy chủ, số đếm lấy của cả bộ lọc', () => {
    const tree = boardGroups(
      [row('a', 'd2', 'L1'), row('b', 'd2', 'L2'), row('c', 'd1', 'L1')],
      [
        { k1: 'd1', k2: 'L1', count: 4 },
        { k1: 'd2', k2: 'L1', count: 2 },
        { k1: 'd2', k2: 'L2', count: 3 },
      ],
      ['date', 'class'],
      (_, key) => key,
    );
    expect(
      tree.map((g) => [g.label, g.count, g.children.map((c) => [c.label, c.count, c.rows.length])]),
    ).toEqual([
      [
        'd2',
        5,
        [
          ['L1', 2, 1],
          ['L2', 3, 1],
        ],
      ],
      ['d1', 4, [['L1', 4, 1]]],
    ]);
  });
  it('một cấp: dòng nằm ngay trong nhóm; không nhóm thì không có cây', () => {
    const rows = [row('a', 'x'), row('b', 'x')];
    expect(
      boardGroups(rows, [{ k1: 'x', k2: null, count: 2 }], ['class'], (_, k) => k)[0]?.rows,
    ).toHaveLength(2);
    expect(boardGroups(rows, [], [], (_, k) => k)).toEqual([]);
  });
  it('lệch chỉ khi hai cột đều có và khác nhau', () => {
    const base = row('a', 'x');
    expect(isMismatch({ ...base, ops_status_code: 'CO_MAT' })).toBe(false);
    expect(isMismatch({ ...base, ops_status_code: 'CO_MAT', teacher_status_code: 'DI_MUON' })).toBe(
      true,
    );
  });
});
