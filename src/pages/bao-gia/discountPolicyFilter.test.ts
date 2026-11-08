import { describe, expect, it } from 'vitest';
import { withoutFlexible } from './discountPolicyFilter';

describe('Ưu đãi linh hoạt: tạm ẩn khỏi ô chọn chiết khấu chờ khung chip (Q-141)', () => {
  it('bỏ chính sách có cờ is_flexible, giữ chính sách thường và thứ tự', () => {
    const list = [
      { code: 'A', is_flexible: false },
      { code: 'UU_DAI_LINH_HOAT', is_flexible: true },
      { code: 'B' },
    ];
    expect(withoutFlexible(list).map((p) => p.code)).toEqual(['A', 'B']);
  });
  it('danh sách rỗng giữ rỗng', () => {
    expect(withoutFlexible([])).toEqual([]);
  });
});
