import { describe, expect, it } from 'vitest';
import { defaultColumnKeys, DEFAULT_MAX_COLUMNS } from '../list/state';
import { buildOrderConfig } from './don-hang/orderConfig';
import { buildQuoteConfig } from './bao-gia/quoteConfig';
import { buildReceiptConfig } from './phieu-thu/receiptConfig';
import { buildClassConfig } from './lop/classConfig';
import { buildEnrollConfig } from './ghi-danh/enrollConfig';
import { buildLeadConfig } from './lead/leadConfig';

// Khai báo giả tối thiểu: chỉ để dựng cấu hình cột, không gọi DB.
const catalogs = new Proxy({}, { get: () => () => [] }) as never;
const access = new Proxy(
  {},
  { get: (_t, k) => (k === 'teachingBranches' || k === 'branches' ? [] : () => true) },
) as never;
const classOpts = { branches: [], subjects: [], grades: [], types: [], statuses: [] };

describe('K03 cột mặc định theo việc hằng ngày (F-23-24)', () => {
  const cases: [string, string[], string[]][] = [
    ['Đơn hàng', defaultColumnKeys(buildOrderConfig(catalogs, access)), ['status']],
    ['Báo giá', defaultColumnKeys(buildQuoteConfig(catalogs, access)), ['status']],
    ['Phiếu thu', defaultColumnKeys(buildReceiptConfig(catalogs, access)), ['status']],
    ['Lớp', defaultColumnKeys(buildClassConfig(classOpts)), ['status']],
    ['Ghi danh', defaultColumnKeys(buildEnrollConfig(catalogs, access)), ['status']],
    ['Lead', defaultColumnKeys(buildLeadConfig(catalogs, access)), ['owner', 'next']],
  ];
  it.each(cases)('%s: không quá số cột tối đa và giữ cột bắt buộc', (_n, keys, must) => {
    expect(keys.length).toBeLessThanOrEqual(DEFAULT_MAX_COLUMNS);
    for (const k of must) expect(keys).toContain(k);
  });
});
