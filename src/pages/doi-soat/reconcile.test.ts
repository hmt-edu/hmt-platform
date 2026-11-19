import { describe, expect, it } from 'vitest';
import {
  NO_ACCOUNT,
  buildReconcileFilters,
  emptyReconcileState,
  reconcileSortParam,
} from './reconcile';

describe('TC-15 bộ lọc đối soát', () => {
  const today = new Date(2026, 10, 18);
  it('mặc định lọc theo tuần này (ngày thu)', () => {
    const f = buildReconcileFilters(emptyReconcileState(), today);
    expect(f.from).toBe('2026-11-16');
    expect(f.to).toBe('2026-11-22');
  });
  it('tìm, sao kê, hình thức, tài khoản nhận (một lựa chọn), cơ sở', () => {
    const state = {
      ...emptyReconcileState(),
      datePreset: '',
      search: ' FT26 ',
      quick: { matched: ['CHUA'], method: ['CHUYEN_KHOAN'], account: [NO_ACCOUNT] },
      conditions: [{ id: 'c1', field: 'branch', op: 'eq' as const, value: 'b-1' }],
    };
    expect(buildReconcileFilters(state, today)).toEqual({
      q: 'FT26',
      matched: 'CHUA',
      method: 'CHUYEN_KHOAN',
      account: 'NONE',
      branch_id: 'b-1',
    });
  });
  it('chọn hai lựa chọn cùng nhóm thì không lọc (tất cả)', () => {
    const state = {
      ...emptyReconcileState(),
      datePreset: '',
      quick: { matched: ['KHOP', 'CHUA'] },
    };
    expect(buildReconcileFilters(state, today)).toEqual({});
  });
  it('sắp xếp', () => {
    expect(reconcileSortParam(null, null)).toBe('date_desc');
    expect(reconcileSortParam('paid', 'asc')).toBe('date_asc');
    expect(reconcileSortParam('amount', 'desc')).toBe('amount_desc');
  });
});
