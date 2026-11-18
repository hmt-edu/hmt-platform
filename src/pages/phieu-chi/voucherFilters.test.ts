import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildVoucherFilters } from './voucherFilters';

const base: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

describe('buildVoucherFilters', () => {
  it('trạng thái trống cho bộ lọc trống', () => {
    expect(buildVoucherFilters(base)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildVoucherFilters({ ...base, search: '  DN-CS1 ' })).toEqual({ q: 'DN-CS1' });
  });
  it('lọc nhanh tình trạng chỉ nhận mã hợp lệ', () => {
    expect(buildVoucherFilters({ ...base, quick: { status: ['CHO_CHI', 'LA'] } })).toEqual({
      status: ['CHO_CHI'],
    });
  });
  it('điều kiện cơ sở và tình trạng gộp vào bộ lọc', () => {
    const state: ListState = {
      ...base,
      conditions: [
        { id: '1', field: 'branch', op: 'eq', value: 'b1' },
        { id: '2', field: 'status', op: 'in', value: ['DA_CHI'] },
      ],
    };
    expect(buildVoucherFilters(state)).toEqual({ branch_id: 'b1', status: ['DA_CHI'] });
  });
});
