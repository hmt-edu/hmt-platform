import { describe, expect, it } from 'vitest';
import {
  currentPrices,
  parsePriceInput,
  priceStateLabel,
  priceText,
  type PriceRow,
} from './packageRecordLogic';

const row = (mode: string, price: number | null, from: string): PriceRow => ({
  id: `${mode}${from}`,
  delivery_mode_code: mode,
  unit_price: price,
  effective_from: from,
});

describe('gói bán, bản ghi (CH-02)', () => {
  const rows = [
    row('OFF', 100, '2026-01-01'),
    row('OFF', 120, '2026-06-01'),
    row('OFF', 150, '2027-01-01'),
    row('ONL', null, '2026-03-01'),
  ];
  it('giá đang hiệu lực: dòng mới nhất không sau hôm nay; tương lai chưa tính', () => {
    const c = currentPrices(rows, '2026-11-19');
    expect(c.OFF?.unit_price).toBe(120);
    expect(c.ONL?.unit_price).toBeNull();
    expect(c.ONL?.id).toBe('ONL2026-03-01');
  });
  it('hình thức chưa có giá nào trước hôm nay thì null', () => {
    expect(currentPrices([row('OFF', 100, '2027-01-01')], '2026-11-19').OFF).toBeNull();
  });
  it('nhãn dòng lịch sử và chữ giá', () => {
    expect(priceStateLabel(row('OFF', 1, '2027-01-01'), '2026-11-19')).toBe(
      'Chưa tới ngày hiệu lực',
    );
    expect(priceStateLabel(row('OFF', 1, '2026-01-01'), '2026-11-19')).toBe('Đã hiệu lực');
    expect(priceText(null, (n) => `${n}`)).toBe('Ngừng bán');
    expect(priceText(5, (n) => `${n} đ`)).toBe('5 đ');
  });
  it('ô nhập giá', () => {
    expect(parsePriceInput('')).toBeNull();
    expect(parsePriceInput('1.200.000')).toBe(1200000);
    expect(parsePriceInput('0')).toBeUndefined();
    expect(parsePriceInput('abc')).toBeUndefined();
  });
});
