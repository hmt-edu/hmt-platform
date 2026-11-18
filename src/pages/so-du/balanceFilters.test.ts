import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildBalanceFilters } from './balanceFilters';

const base: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('buildBalanceFilters', () => {
  it('trạng thái trống cho bộ lọc trống', () => {
    expect(buildBalanceFilters(base)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildBalanceFilters({ ...base, search: ' PH0001 ' })).toEqual({ q: 'PH0001' });
  });
  it('lọc nhanh còn tiền dư', () => {
    expect(buildBalanceFilters({ ...base, quick: { balance: ['positive'] } })).toEqual({
      only_positive: true,
    });
  });
  it('điều kiện cơ sở vào bộ lọc', () => {
    expect(
      buildBalanceFilters({
        ...base,
        conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b1' }],
      }),
    ).toEqual({ branch_id: 'b1' });
  });
});
