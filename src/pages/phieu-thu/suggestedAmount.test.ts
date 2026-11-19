import { describe, expect, it } from 'vitest';
import { suggestedReceiptAmount } from './suggestedAmount';

const THREE = [
  { seq: 1, amount: 1000 },
  { seq: 2, amount: 600 },
  { seq: 3, amount: 600 },
];

describe('Số tiền gợi ý của phiếu thu (T2-04)', () => {
  it('chưa thu gì: gợi ý đợt đầu (cọc), không phải cả đơn', () => {
    expect(suggestedReceiptAmount(THREE, 0, 2200)).toBe(1000);
  });
  it('đã thu đủ đợt đầu: gợi ý đợt kế', () => {
    expect(suggestedReceiptAmount(THREE, 1000, 1200)).toBe(600);
  });
  it('đã thu dở một đợt: gợi ý phần còn lại của đợt đó', () => {
    expect(suggestedReceiptAmount(THREE, 1200, 1000)).toBe(400);
  });
  it('không vượt phần còn thu được (phiếu đang chờ duyệt đã chiếm)', () => {
    expect(suggestedReceiptAmount(THREE, 0, 700)).toBe(700);
  });
  it('đơn trả một lần hoặc không có đợt: gợi ý phần còn thu', () => {
    expect(suggestedReceiptAmount([], 0, 2200)).toBe(2200);
    expect(suggestedReceiptAmount([{ seq: 1, amount: 2200 }], 0, 2200)).toBe(2200);
  });
  it('hết đợt hoặc không còn gì để thu: không gợi ý', () => {
    expect(suggestedReceiptAmount(THREE, 2200, 0)).toBeNull();
    expect(suggestedReceiptAmount(THREE, 0, null)).toBeNull();
  });
});
