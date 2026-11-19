import { describe, expect, it } from 'vitest';
import { maxApplicable } from './useBalance';

describe('TC-16 số tiền dùng số dư', () => {
  it('tối đa là số nhỏ hơn của số dư và phần còn thu', () => {
    expect(maxApplicable(3_000_000, 2_000_000)).toBe(2_000_000);
    expect(maxApplicable(500_000, 2_000_000)).toBe(500_000);
  });
  it('không âm khi số dư hay phần còn thu bằng 0', () => {
    expect(maxApplicable(0, 2_000_000)).toBe(0);
    expect(maxApplicable(1_000_000, 0)).toBe(0);
  });
});
