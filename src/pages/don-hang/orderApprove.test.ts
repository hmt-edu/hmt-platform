import { describe, expect, it } from 'vitest';
import {
  capPercentText,
  orderCapText,
  overCapLines,
  percentText,
  roundOne,
  totalPercentText,
} from './orderApprove';
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

describe('orderCapText (khung BH05_chip_*)', () => {
  it('đúng chữ khung, trần lấy từ tham số', () => {
    expect(orderCapText(20)).toBe(
      'Ưu đãi cộng dồn; giờ tặng quy ra % tính vào trần 20%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được.',
    );
    expect(orderCapText(25)).toContain('trần 25%.');
    expect(orderCapText(null)).toContain('trần đã cấu hình.');
  });
});

describe('totalPercentText (Tổng % Đơn Xem, khung BH05_nhap_xem)', () => {
  const line = (d: number, g: number, kind: 'ENROL' | 'GIFT' = 'ENROL') => ({
    line_kind: kind,
    discount_percent: d,
    gift_percent: g,
  });
  it('cộng chiết khấu % với giờ tặng quy ra %: 5% + 8,33% = 13,3%', () => {
    expect(totalPercentText(line(5, 8.33))).toBe('13,3%');
  });
  it('chỉ chiết khấu %, chỉ giờ tặng, không có gì, quà tặng', () => {
    expect(totalPercentText(line(10, 0))).toBe('10%');
    expect(totalPercentText(line(0, 20))).toBe('20%');
    expect(totalPercentText(line(0, 0))).toBe('');
    expect(totalPercentText(line(5, 5, 'GIFT'))).toBe('');
  });
  it('roundOne làm tròn một chữ số', () => {
    expect(roundOne(8.33)).toBe(8.3);
  });
});
