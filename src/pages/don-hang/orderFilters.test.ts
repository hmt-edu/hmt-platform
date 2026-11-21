import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import {
  ORDER_GROUP_FIELD_OF,
  buildOrderFilters,
  nextOrderSort,
  orderGroupFilter,
  orderSortParam,
} from './orderFilters';

const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

describe('bộ lọc danh sách Đơn hàng', () => {
  it('trạng thái rỗng thì không có bộ lọc', () => {
    expect(buildOrderFilters(EMPTY)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildOrderFilters({ ...EMPTY, search: '  DH-CS1  ' })).toEqual({ q: 'DH-CS1' });
  });
  it('lọc nhanh: tình trạng nhiều lựa chọn và của tôi', () => {
    expect(
      buildOrderFilters({
        ...EMPTY,
        quick: { status: ['NHAP', 'DA_TRINH'], mine: ['mine'] },
      }),
    ).toEqual({ status: ['NHAP', 'DA_TRINH'], mine: true });
  });
  it('trạng thái lạ (Từ chối không lưu, R-TIEN-06) bị bỏ, không gửi lên máy chủ', () => {
    expect(buildOrderFilters({ ...EMPTY, quick: { status: ['TU_CHOI', 'HUY'] } })).toEqual({
      status: ['HUY'],
    });
  });
  it('điều kiện lọc nâng cao: tình trạng gộp với lọc nhanh, cơ sở, ngày tạo', () => {
    const f = buildOrderFilters({
      ...EMPTY,
      quick: { status: ['NHAP'] },
      conditions: [
        { id: '1', field: 'status', op: 'in', value: ['DA_DUYET', 'NHAP'] },
        { id: '2', field: 'branch', op: 'eq', value: 'b1' },
        { id: '3', field: 'created', op: 'from', value: '2026-10-01' },
      ],
    });
    expect(f.status).toEqual(['NHAP', 'DA_DUYET']);
    expect(f.branch_id).toBe('b1');
    expect(typeof f.created_from).toBe('string');
  });
  it('sắp xếp: chỉ các kiểu máy chủ hỗ trợ', () => {
    expect(orderSortParam(null)).toBeUndefined();
    expect(orderSortParam({ key: 'total', direction: 'desc' })).toBe('total_desc');
    expect(orderSortParam({ key: 'total', direction: 'asc' })).toBeUndefined();
    expect(orderSortParam({ key: 'created', direction: 'asc' })).toBe('created_asc');
  });
  it('bấm lần hai ở cột chỉ một chiều thì bỏ sắp xếp', () => {
    expect(nextOrderSort({ key: 'total', direction: 'asc' })).toBeNull();
    expect(nextOrderSort({ key: 'total', direction: 'desc' })).toEqual({
      key: 'total',
      direction: 'desc',
    });
  });

  it('Group By «Sale» (BH-06): trường nhóm sale, mở nhóm lọc creator_id', () => {
    expect(ORDER_GROUP_FIELD_OF.sale).toBe('sale');
    expect(orderGroupFilter('sale', 'u-1')).toEqual({ creator_id: 'u-1' });
    expect(orderGroupFilter('sale', '')).toEqual({});
  });
});
