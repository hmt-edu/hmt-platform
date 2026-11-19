import { describe, expect, it } from 'vitest';
import { campaignFilters, periodText, toIsoDate } from './campaignLogic';

const fmt = (iso: string) => iso.split('-').reverse().join('/');

describe('chiến dịch marketing (CH-08)', () => {
  it('bộ lọc bỏ ô trống và giá trị lạ', () => {
    expect(campaignFilters('  ', '')).toEqual({});
    expect(campaignFilters(' khai giảng ', 'NGUNG')).toEqual({ q: 'khai giảng', status: 'NGUNG' });
    expect(campaignFilters('', 'LA')).toEqual({});
  });
  it('thời gian chạy: đủ, một đầu, chưa đặt', () => {
    expect(periodText('2026-12-01', '2026-12-31', fmt)).toBe('01/12/2026 – 31/12/2026');
    expect(periodText('2026-12-01', null, fmt)).toBe('Từ 01/12/2026');
    expect(periodText(null, '2026-12-31', fmt)).toBe('Đến 31/12/2026');
    expect(periodText(null, null, fmt)).toBe('Chưa đặt thời gian');
  });
  it('đổi ngày sang YYYY-MM-DD theo ngày địa phương', () => {
    expect(toIsoDate(new Date(2026, 0, 5))).toBe('2026-01-05');
  });
});
