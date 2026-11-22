import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildParentAccountFilters } from './parentAccountFilters';

const base: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('bộ lọc Tài khoản phụ huynh (QT-17)', () => {
  it('không lọc gì thì bộ lọc rỗng', () => {
    expect(buildParentAccountFilters(base)).toEqual({});
  });
  it('tìm theo chữ, bỏ khoảng trắng hai đầu', () => {
    expect(buildParentAccountFilters({ ...base, search: '  PH000212 ' })).toEqual({
      q: 'PH000212',
    });
  });
  it('chip Tình trạng chọn một thì lọc, chọn hai thì không lọc', () => {
    expect(buildParentAccountFilters({ ...base, quick: { state: ['locked'] } })).toEqual({
      state: 'BI_KHOA',
    });
    expect(buildParentAccountFilters({ ...base, quick: { state: ['none', 'active'] } })).toEqual(
      {},
    );
  });
  it('điều kiện Cơ sở', () => {
    expect(
      buildParentAccountFilters({
        ...base,
        conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b-1' }],
      }),
    ).toEqual({ branch_id: 'b-1' });
  });
});
