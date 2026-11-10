import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildParentFilters, buildStudentFilters, custSortParam } from './custFilters';

const empty: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('Bộ lọc Khách hàng (KH-01, KH-04)', () => {
  it('không lọc gì thì rỗng', () => {
    expect(buildParentFilters(empty)).toEqual({});
    expect(buildStudentFilters(empty)).toEqual({});
  });

  it('phụ huynh: tìm, tình trạng, cơ sở tiếp nhận', () => {
    expect(
      buildParentFilters({
        ...empty,
        search: ' 0912 ',
        quick: { status: ['DANG_HOC'] },
        conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b1' }],
      }),
    ).toEqual({ search: '0912', status: ['DANG_HOC'], branch_id: 'b1' });
  });

  it('học sinh: tìm, tình trạng, cơ sở, khối; bỏ phép khác máy chủ chưa hiểu', () => {
    expect(
      buildStudentFilters({
        ...empty,
        quick: { status: ['DANG_HOC', 'BAO_LUU'] },
        conditions: [
          { id: '1', field: 'grade', op: 'eq', value: '9' },
          { id: '2', field: 'branch', op: 'ne', value: 'b1' },
        ],
      }),
    ).toEqual({ status: ['DANG_HOC', 'BAO_LUU'], grade: '9' });
  });

  it('sắp xếp', () => {
    expect(custSortParam(null, null)).toBe('code_asc');
    expect(custSortParam('name', 'asc')).toBe('name_asc');
    expect(custSortParam('code', 'desc')).toBe('code_desc');
  });
});
