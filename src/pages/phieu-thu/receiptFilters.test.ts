import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import {
  RECEIPT_GROUP_FIELD_OF,
  buildReceiptFilters,
  nextReceiptSort,
  receiptGroupFilter,
  receiptSortParam,
} from './receiptFilters';

const EMPTY: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'created',
  datePreset: '',
};

describe('bộ lọc danh sách phiếu thu (TC-01, TC-04)', () => {
  it('không lọc gì thì bộ lọc rỗng', () => {
    expect(buildReceiptFilters(EMPTY)).toEqual({});
  });

  it('tìm, lọc nhanh Tôi lập, Chờ tôi duyệt và tình trạng', () => {
    const state: ListState = {
      ...EMPTY,
      search: ' An ',
      quick: { mine: ['mine', 'waiting_manager'], status: ['DA_GUI', 'KHONG_CO'] },
    };
    expect(buildReceiptFilters(state)).toEqual({
      q: 'An',
      mine: true,
      waiting_manager: true,
      status: ['DA_GUI'],
    });
  });

  it('«Hình thức» (TC-01, TC-04): nhiều hình thức gửi thành mảng payment_method', () => {
    expect(
      buildReceiptFilters({ ...EMPTY, quick: { method: ['CHUYEN_KHOAN', 'TIEN_MAT'] } }),
    ).toEqual({ payment_method: ['CHUYEN_KHOAN', 'TIEN_MAT'] });
    expect(buildReceiptFilters({ ...EMPTY, quick: { method: [] } })).toEqual({});
  });

  it('«Sao kê» của TC-04: chọn một bên thì lọc, chọn cả hai hoặc giá trị lạ thì không', () => {
    expect(buildReceiptFilters({ ...EMPTY, quick: { bank: ['KHOP'] } })).toEqual({
      bank_matched: 'KHOP',
    });
    expect(buildReceiptFilters({ ...EMPTY, quick: { bank: ['CHUA'] } })).toEqual({
      bank_matched: 'CHUA',
    });
    expect(buildReceiptFilters({ ...EMPTY, quick: { bank: ['KHOP', 'CHUA'] } })).toEqual({});
    expect(buildReceiptFilters({ ...EMPTY, quick: { bank: ['LA'] } })).toEqual({});
  });

  it('bộ lọc cố định của TC-04 luôn được giữ', () => {
    expect(buildReceiptFilters({ ...EMPTY, search: 'x' }, { waiting_accounting: true })).toEqual({
      q: 'x',
      waiting_accounting: true,
    });
  });

  it('trường lọc nâng cao: tình trạng, cơ sở, ngày tạo từ đến (giờ Việt Nam)', () => {
    const state: ListState = {
      ...EMPTY,
      conditions: [
        { id: '1', field: 'status', op: 'in', value: ['CHO_KE_TOAN'] },
        { id: '2', field: 'branch', op: 'eq', value: 'b1' },
        { id: '3', field: 'created', op: 'from', value: '2026-11-01' },
        { id: '4', field: 'created', op: 'to', value: '2026-11-05' },
      ],
    };
    const f = buildReceiptFilters(state);
    expect(f.status).toEqual(['CHO_KE_TOAN']);
    expect(f.branch_id).toBe('b1');
    expect(f.created_from).toBe('2026-10-31T17:00:00.000Z');
    expect(f.created_to).toBe('2026-11-05T17:00:00.000Z');
  });

  it('sắp xếp: chỉ các kiểu máy chủ hỗ trợ', () => {
    expect(receiptSortParam({ key: 'created', direction: 'asc' })).toBe('created_asc');
    expect(receiptSortParam({ key: 'amount', direction: 'desc' })).toBe('amount_desc');
    expect(receiptSortParam({ key: 'amount', direction: 'asc' })).toBeUndefined();
    expect(nextReceiptSort({ key: 'amount', direction: 'asc' })).toBeNull();
  });

  it('Group By «Sao kê» (TC-04): trường nhóm bank, mở nhóm lọc bank_matched', () => {
    expect(RECEIPT_GROUP_FIELD_OF.bank).toBe('bank');
    expect(receiptGroupFilter('bank', 'KHOP')).toEqual({ bank_matched: 'KHOP' });
    expect(receiptGroupFilter('bank', 'CHUA')).toEqual({ bank_matched: 'CHUA' });
    expect(receiptGroupFilter('bank', '')).toEqual({});
  });

  it('Chip nhiều «Cơ sở»: gửi mảng branch_ids, không chọn thì không lọc', () => {
    expect(buildReceiptFilters({ ...EMPTY, quick: { branches: ['cs1-id', 'cs2-id'] } })).toEqual({
      branch_ids: ['cs1-id', 'cs2-id'],
    });
    expect(buildReceiptFilters({ ...EMPTY, quick: { branches: [] } })).toEqual({});
  });
});
