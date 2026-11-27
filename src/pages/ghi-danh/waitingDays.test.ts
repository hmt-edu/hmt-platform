import { describe, expect, it } from 'vitest';
import { waitingDaysLabel } from './waitingDays';

describe('số ngày chờ xếp lớp', () => {
  const now = new Date('2026-11-27T10:00:00+07:00');
  it('cùng ngày Việt Nam là Hôm nay', () => {
    expect(waitingDaysLabel('2026-11-27T00:30:00+07:00', now)).toBe('Hôm nay');
  });
  it('đếm theo ngày lịch, không theo đủ 24 giờ', () => {
    expect(waitingDaysLabel('2026-11-26T23:30:00+07:00', now)).toBe('1 ngày');
    expect(waitingDaysLabel('2026-11-24', now)).toBe('3 ngày');
  });
});
