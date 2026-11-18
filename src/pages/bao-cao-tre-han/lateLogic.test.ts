import { describe, expect, it } from 'vitest';
import { formatHours, mergePerPerson, monthOptions, type LateRow } from './lateLogic';

const row = (user: string, branch: string, n: number, h: number): LateRow => ({
  user_id: user,
  code: null,
  name: user,
  role: 'GIAO_VIEN',
  branch_code: branch,
  late_sessions: n,
  late_hours: h,
  done_sessions: n + 1,
});

describe('giáo viên trễ hạn (BC-08)', () => {
  it('danh sách tháng theo giờ Việt Nam, qua năm đúng', () => {
    const o = monthOptions(new Date('2026-01-31T18:00:00Z'));
    expect(o[0]).toEqual({ value: '2026-02-01', label: 'Tháng 02/2026' });
    expect(o[2]?.value).toBe('2025-12-01');
    expect(o).toHaveLength(12);
  });
  it('gộp một dòng mỗi người, cộng buổi trễ và giờ trễ, ghép cơ sở', () => {
    const m = mergePerPerson([
      row('a', 'CS1', 2, 3),
      row('b', 'CS1', 1, 0.5),
      row('a', 'CS2', 1, 1.5),
    ]);
    expect(m).toHaveLength(2);
    expect(m[0]).toMatchObject({ late_sessions: 3, late_hours: 4.5, branch_code: 'CS1, CS2' });
  });
  it('không đổi dữ liệu gốc; định dạng giờ dấu phẩy', () => {
    const src = [row('a', 'CS1', 2, 3), row('a', 'CS2', 1, 1)];
    mergePerPerson(src);
    expect(src[0]?.late_sessions).toBe(2);
    expect(formatHours(20.5)).toBe('20,5');
  });
});
