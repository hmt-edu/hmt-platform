import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildQuoteFilters, nextQuoteSort, quoteSortParam } from './quoteFilters';

const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

describe('bộ lọc danh sách Báo giá', () => {
  it('trạng thái rỗng thì không có bộ lọc', () => {
    expect(buildQuoteFilters(EMPTY)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng', () => {
    expect(buildQuoteFilters({ ...EMPTY, search: '  BG-CS1  ' })).toEqual({ q: 'BG-CS1' });
  });
  it('lọc nhanh: tình trạng nhiều lựa chọn, của tôi, quá hạn', () => {
    const f = buildQuoteFilters({
      ...EMPTY,
      quick: { status: ['NHAP', 'DA_GUI'], mine: ['mine'], valid: ['expired'] },
    });
    expect(f).toEqual({ status: ['NHAP', 'DA_GUI'], mine: true, expired: true });
  });
  it('trạng thái lạ bị bỏ, không gửi lên máy chủ', () => {
    expect(buildQuoteFilters({ ...EMPTY, quick: { status: ['KHONG_CO', 'HUY'] } })).toEqual({
      status: ['HUY'],
    });
  });
  it('Đã chuyển đơn là một tình trạng hiển thị, gửi trong danh sách status (Đ243)', () => {
    expect(buildQuoteFilters({ ...EMPTY, quick: { status: ['DA_CHUYEN_DON'] } })).toEqual({
      status: ['DA_CHUYEN_DON'],
    });
  });
  it('Đã chuyển đơn kèm Nháp và Đã gửi: gửi cả ba, máy chủ nối bằng HOẶC', () => {
    expect(
      buildQuoteFilters({ ...EMPTY, quick: { status: ['DA_CHUYEN_DON', 'DA_GUI', 'NHAP'] } }),
    ).toEqual({ status: ['DA_CHUYEN_DON', 'DA_GUI', 'NHAP'] });
  });
  it('Đã chuyển đơn chọn trong điều kiện lọc nâng cao cũng gửi trong status', () => {
    expect(
      buildQuoteFilters({
        ...EMPTY,
        conditions: [{ id: '1', field: 'status', op: 'in', value: ['DA_CHUYEN_DON'] }],
      }),
    ).toEqual({ status: ['DA_CHUYEN_DON'] });
  });
  it('điều kiện lọc nâng cao: tình trạng gộp với lọc nhanh, cơ sở, ngày tạo', () => {
    const f = buildQuoteFilters({
      ...EMPTY,
      quick: { status: ['NHAP'] },
      conditions: [
        { id: '1', field: 'status', op: 'in', value: ['DA_GUI', 'NHAP'] },
        { id: '2', field: 'branch', op: 'eq', value: 'b1' },
        { id: '3', field: 'created', op: 'from', value: '2026-10-01' },
      ],
    });
    expect(f.status).toEqual(['NHAP', 'DA_GUI']);
    expect(f.branch_id).toBe('b1');
    expect(typeof f.created_from).toBe('string');
  });
  it('sắp xếp chỉ các kiểu máy chủ hỗ trợ', () => {
    expect(quoteSortParam({ key: 'created', direction: 'asc' })).toBe('created_asc');
    expect(quoteSortParam({ key: 'total', direction: 'desc' })).toBe('total_desc');
    expect(quoteSortParam({ key: 'total', direction: 'asc' })).toBeUndefined();
    expect(nextQuoteSort({ key: 'total', direction: 'asc' })).toBeNull();
    expect(nextQuoteSort({ key: 'valid', direction: 'asc' })).toEqual({
      key: 'valid',
      direction: 'asc',
    });
  });
});
