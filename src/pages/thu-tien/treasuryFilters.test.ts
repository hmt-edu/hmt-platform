import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import {
  buildMoneyInFilters,
  buildReceivableFilters,
  moneyInSortParam,
  nextReceivableSort,
  receivableSortParam,
} from './treasuryFilters';

const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

describe('bộ lọc Khoản tiền vào (TC-08)', () => {
  it('không lọc gì thì rỗng', () => {
    expect(buildMoneyInFilters(EMPTY)).toEqual({});
  });
  it('tìm, loại khoản (một lựa chọn) và cơ sở', () => {
    const state: ListState = {
      ...EMPTY,
      search: ' Hà ',
      quick: { kind: ['DAO'] },
      conditions: [{ id: '1', field: 'branch', op: 'eq', value: 'b1' }],
    };
    expect(buildMoneyInFilters(state)).toEqual({ q: 'Hà', kind: 'DAO', branch_id: 'b1' });
  });
  it('chọn cả hai loại khoản thì không lọc loại', () => {
    expect(buildMoneyInFilters({ ...EMPTY, quick: { kind: ['THU', 'DAO'] } })).toEqual({});
  });
  it('sắp xếp: ngày và số tiền hai chiều, cột khác dùng mặc định', () => {
    expect(moneyInSortParam({ key: 'date', direction: 'asc' })).toBe('date_asc');
    expect(moneyInSortParam({ key: 'amount', direction: 'desc' })).toBe('amount_desc');
    expect(moneyInSortParam({ key: 'amount', direction: 'asc' })).toBe('amount_asc');
    expect(moneyInSortParam({ key: 'code', direction: 'asc' })).toBeUndefined();
    expect(moneyInSortParam(null)).toBeUndefined();
  });
});

describe('bộ lọc Công nợ (TC-13)', () => {
  const DUE: ListState = { ...EMPTY, dateField: 'due' };
  it('lọc nhanh tình trạng chỉ nhận mã hợp lệ', () => {
    expect(buildReceivableFilters({ ...DUE, quick: { status: ['QUA_HAN', 'KHONG_CO'] } })).toEqual({
      status: ['QUA_HAN'],
    });
  });
  it('hạn đóng từ/đến thành ngày yyyy-mm-dd; cơ sở', () => {
    const state: ListState = {
      ...DUE,
      conditions: [
        { id: '1', field: 'due', op: 'from', value: '2026-11-01' },
        { id: '2', field: 'due', op: 'to', value: '2026-11-15' },
        { id: '3', field: 'branch', op: 'eq', value: 'b5' },
      ],
    };
    expect(buildReceivableFilters(state)).toEqual({
      due_from: '2026-11-01',
      due_to: '2026-11-15',
      branch_id: 'b5',
    });
  });
  it('sắp xếp: hạn hai chiều, còn nợ chỉ giảm dần (tăng dần bỏ sắp xếp)', () => {
    expect(receivableSortParam({ key: 'due', direction: 'desc' })).toBe('due_desc');
    expect(receivableSortParam({ key: 'owed', direction: 'desc' })).toBe('owed_desc');
    expect(nextReceivableSort({ key: 'owed', direction: 'asc' })).toBeNull();
    expect(nextReceivableSort({ key: 'due', direction: 'asc' })).toEqual({
      key: 'due',
      direction: 'asc',
    });
  });
});
