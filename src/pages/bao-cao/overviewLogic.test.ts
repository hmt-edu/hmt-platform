import { describe, expect, it } from 'vitest';
import { rangeParams } from './overviewLogic';

describe('BC-01 khoảng ngày', () => {
  it('đổi sang yyyy-mm-dd theo ngày Việt Nam', () => {
    // 17:30 UTC ngày 10/11 là 00:30 ngày 11/11 giờ Việt Nam.
    const r = rangeParams({
      from: new Date('2026-11-10T17:30:00Z'),
      to: new Date('2026-11-12T03:00:00Z'),
    });
    expect(r).toEqual({ p_from: '2026-11-11', p_to: '2026-11-12' });
  });
  it('không có khoảng hoặc đến trước từ thì không gọi', () => {
    expect(rangeParams(null)).toBeNull();
    expect(
      rangeParams({ from: new Date('2026-11-12T03:00:00Z'), to: new Date('2026-11-10T03:00:00Z') }),
    ).toBeNull();
  });
});
