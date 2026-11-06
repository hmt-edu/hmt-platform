import { describe, expect, it } from 'vitest';
import { buildPriceItems, hasNoOnline, priceUnit, toDateKey } from './priceLogic';

describe('priceLogic', () => {
  it('ngày yyyy-mm-dd theo giờ địa phương', () => {
    expect(toDateKey(new Date(2026, 10, 6))).toBe('2026-11-06');
    expect(toDateKey(new Date(2027, 0, 1))).toBe('2027-01-01');
  });
  it('đơn vị giá theo loại gói', () => {
    expect(priceUnit('LC')).toBe('giờ');
    expect(priceUnit('DV')).toBe('tháng');
    expect(priceUnit('TL')).toBe('bộ');
    expect(hasNoOnline('DV')).toBe(true);
    expect(hasNoOnline('VIP')).toBe(false);
  });
  const sel = [
    { id: 'a', type: 'LC' },
    { id: 'b', type: 'VIP' },
    { id: 'c', type: 'DV' },
  ];
  it('giá chung áp cho mọi gói đã chọn, bỏ online của dịch vụ, tài liệu', () => {
    const items = buildPriceItems(sel, { off: 180000, onl: 120000 }, {});
    expect(items).toHaveLength(5);
    expect(items.filter((i) => i.package_id === 'c')).toEqual([
      { package_id: 'c', mode: 'OFF', unit_price: 180000 },
    ]);
  });
  it('giá riêng của gói thắng giá chung; none = không bán; null = bỏ qua', () => {
    const items = buildPriceItems(sel, { off: 100, onl: null }, { b: { off: 200, onl: 'none' } });
    expect(items).toEqual([
      { package_id: 'a', mode: 'OFF', unit_price: 100 },
      { package_id: 'b', mode: 'OFF', unit_price: 200 },
      { package_id: 'b', mode: 'ONL', unit_price: null },
      { package_id: 'c', mode: 'OFF', unit_price: 100 },
    ]);
  });
  it('không nhập gì thì không có dòng nào', () => {
    expect(buildPriceItems(sel, { off: null, onl: null }, {})).toEqual([]);
  });
});
