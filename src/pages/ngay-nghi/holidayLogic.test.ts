// QT-14: đổi ngày ↔ chuỗi theo giờ địa phương (không lệch múi giờ), nhãn phạm vi, khoảng ngày của năm.
import { describe, expect, it } from 'vitest';
import { fromIso, scopeLabel, toIso, yearRange, type Holiday } from './holidayLogic';

const h = (branch: string | null): Holiday => ({
  id: '1',
  holiday_date: '2026-11-20',
  name: 'Ngày Nhà giáo',
  branch_id: branch,
  is_active: true,
});

describe('QT-14 ngày nghỉ lễ', () => {
  it('đổi ngày qua lại không lệch ngày (đầu và cuối năm)', () => {
    for (const iso of ['2026-01-01', '2026-11-20', '2026-12-31']) {
      expect(toIso(fromIso(iso))).toBe(iso);
    }
  });
  it('nhãn phạm vi: rỗng là Mọi cơ sở, có cơ sở thì mã cơ sở', () => {
    expect(scopeLabel(h(null), () => 'CS5')).toBe('Mọi cơ sở');
    expect(scopeLabel(h('b5'), () => 'CS5')).toBe('CS5');
  });
  it('khoảng ngày của năm', () => {
    expect(yearRange(2026)).toEqual({ from: '2026-01-01', to: '2026-12-31' });
  });
});
