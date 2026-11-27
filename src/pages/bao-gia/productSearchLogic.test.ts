import { describe, expect, it } from 'vitest';
import { NO_FILTERS, filterValues, productGroups, productRows } from './productSearchLogic';
import type { SellablePackage, SellablePackages } from './useQuoteData';

const pkg = (code: string, name: string, subject: string, grade: string): SellablePackage => ({
  id: code,
  code,
  name,
  package_type_code: 'LC',
  subject_code: subject,
  grade_from_code: grade,
  grade_to_code: null,
  unit_code: 'GIO',
  prices: { ONL: 120000, OFF: 220000 },
});
const data: SellablePackages = {
  types: [{ code: 'LC', name: 'Lớp nhóm' }],
  popular: ['LC-ANH-K07'],
  suggested: ['LC-TOAN-K06', 'LC-ANH-K07'],
  total: 2,
  packages: [pkg('LC-TOAN-K06', 'Toán 6', 'TOAN', 'K06'), pkg('LC-ANH-K07', 'Anh 7', 'ANH', 'K07')],
};
const names: Record<string, string> = { TOAN: 'Toán', ANH: 'Tiếng Anh', K06: '6', K07: '7' };
const rows = productRows(data, (_c, code) => names[code]);
const codes = (q: string, f = NO_FILTERS) =>
  productGroups(rows, data, q, f).flatMap((g) => g.rows.map((r) => r.pkg.code));

describe('Ô tìm sản phẩm', () => {
  it('chưa gõ: Hay dùng và Gợi ý theo cơ hội, không lặp sản phẩm', () => {
    expect(productGroups(rows, data, '', NO_FILTERS).map((g) => g.title)).toEqual([
      'Hay dùng',
      'Gợi ý theo cơ hội',
    ]);
    expect(codes('')).toEqual(['LC-ANH-K07', 'LC-TOAN-K06']);
  });
  it('gõ không dấu, nhiều từ, cả mã', () => {
    expect(codes('toan 6')).toEqual(['LC-TOAN-K06']);
    expect(codes('tieng anh')).toEqual(['LC-ANH-K07']);
    expect(codes('anh-k07')).toEqual(['LC-ANH-K07']);
    expect(codes('khong co')).toEqual([]);
  });
  it('lọc theo môn, khối; giá ghi theo hình thức và đơn vị', () => {
    expect(codes('', { ...NO_FILTERS, subject: 'Toán' })).toEqual(['LC-TOAN-K06']);
    expect(codes('', { ...NO_FILTERS, grade: '7' })).toEqual(['LC-ANH-K07']);
    expect(filterValues(rows, 'grade')).toEqual(['6', '7']);
    expect(rows[0]?.price).toBe('OFF 220.000 · ONL 120.000 đ/giờ');
  });
  it('không có Hay dùng, Gợi ý thì liệt kê tất cả', () => {
    expect(
      productGroups(rows, { popular: [], suggested: [] }, '', NO_FILTERS)[0]?.rows,
    ).toHaveLength(2);
  });
});
