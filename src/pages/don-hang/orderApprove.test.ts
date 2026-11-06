import { describe, expect, it } from 'vitest';
import { capPercentText, overCapLines, percentText } from './orderApprove';
import type { OrderLine } from './orderTypes';

const line = (over: Partial<OrderLine>): OrderLine =>
  ({
    line_no: 1,
    student_name: 'Em A',
    over_cap: false,
    discount_percent: 0,
    gift_percent: 0,
    ...over,
  }) as OrderLine;

describe('orderApprove', () => {
  it('chỉ lấy dòng máy chủ đánh dấu vượt trần, kèm tổng % cộng dồn', () => {
    const rows = overCapLines([
      line({ line_no: 1 }),
      line({ line_no: 3, over_cap: true, discount_percent: 15, gift_percent: 8.3 }),
    ]);
    expect(rows).toEqual([{ line_no: 3, student_name: 'Em A', total_percent_text: '23,3' }]);
  });
  it('% bỏ số 0 thừa', () => {
    expect(percentText(10)).toBe('10');
    expect(percentText(8.25)).toBe('8,3');
  });
  it('chữ trần lấy từ tham số, chưa tải thì chữ chung', () => {
    expect(capPercentText(20)).toBe('20%');
    expect(capPercentText(null)).toBe('đã cấu hình');
  });
});
