import { describe, expect, it } from 'vitest';
import { depositWarning } from './depositWarning';

const inst = (seq: number, amount: number) => ({ seq, due_days: 0, amount, due_date: null });

describe('cảnh báo đợt 1 nhỏ hơn cọc tối thiểu (B-23-14)', () => {
  it('đợt 1 nhỏ hơn cọc thì cảnh báo, kèm hai số', () => {
    expect(depositWarning('NHAP', [inst(2, 9), inst(1, 3)], 5)).toEqual({
      firstAmount: 3,
      depositMin: 5,
    });
  });
  it('đợt 1 bằng hoặc lớn hơn cọc thì không cảnh báo', () => {
    expect(depositWarning('NHAP', [inst(1, 5)], 5)).toBeNull();
    expect(depositWarning('DA_TRINH', [inst(1, 6)], 5)).toBeNull();
  });
  it('chưa có lịch, chưa đọc được tham số, đơn đã duyệt: không cảnh báo', () => {
    expect(depositWarning('NHAP', [], 5)).toBeNull();
    expect(depositWarning('NHAP', [inst(1, 1)], null)).toBeNull();
    expect(depositWarning('DA_DUYET', [inst(1, 1)], 5)).toBeNull();
  });
});
