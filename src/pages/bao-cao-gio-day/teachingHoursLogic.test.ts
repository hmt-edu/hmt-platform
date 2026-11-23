import { describe, expect, it } from 'vitest';
import {
  formatHours,
  mergePerPerson,
  monthEnded,
  monthOptions,
  type HoursRow,
} from './teachingHoursLogic';

const row = (user: string, branch: string, c: number, k: number): HoursRow => ({
  user_id: user,
  code: null,
  name: user,
  role: 'GIAO_VIEN',
  branch_code: branch,
  hours: c + k,
  by_type: { CHINH: c, CUNG_CO: k, HOC_BU: 0, BO_TRO: 0 },
});

describe('giờ dạy giáo viên (BC-09)', () => {
  it('danh sách tháng: tháng hiện tại theo giờ Việt Nam đứng đầu, qua năm đúng', () => {
    const o = monthOptions(new Date('2026-01-31T18:00:00Z')); // 01/02/2026 giờ Việt Nam
    expect(o[0]).toEqual({ value: '2026-02-01', label: 'Tháng 02/2026' });
    expect(o[1]?.value).toBe('2026-01-01');
    expect(o[2]?.value).toBe('2025-12-01');
    expect(o).toHaveLength(12);
  });
  it('gộp một dòng mỗi người khi dạy nhiều cơ sở', () => {
    const merged = mergePerPerson([
      row('a', 'CS1', 3, 1.5),
      row('b', 'CS1', 2, 0),
      row('a', 'CS2', 1.5, 0),
    ]);
    expect(merged).toHaveLength(2);
    expect(merged[0]?.hours).toBe(6);
    expect(merged[0]?.by_type.CHINH).toBe(4.5);
    expect(merged[0]?.branch_code).toBe('CS1, CS2');
  });
  it('không đổi dòng của dữ liệu gốc', () => {
    const src = [row('a', 'CS1', 3, 0), row('a', 'CS2', 1, 0)];
    mergePerPerson(src);
    expect(src[0]?.hours).toBe(3);
  });
  it('định dạng giờ dấu phẩy', () => {
    expect(formatHours(13.5)).toBe('13,5');
    expect(formatHours(0)).toBe('0,0');
  });
});

describe('monthEnded (nút Chốt tháng)', () => {
  it('tháng trước đã kết thúc, tháng hiện tại chưa', () => {
    const now = new Date('2026-11-20T05:00:00Z');
    expect(monthEnded('2026-10-01', now)).toBe(true);
    expect(monthEnded('2026-11-01', now)).toBe(false);
    expect(monthEnded('2025-12-01', now)).toBe(true);
  });
  it('tính theo giờ Việt Nam: 31/10 17:30 UTC đã là 01/11 giờ VN', () => {
    expect(monthEnded('2026-10-01', new Date('2026-10-31T17:30:00Z'))).toBe(true);
  });
});
