import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import {
  EMPTY_RECONCILE_STATE,
  buildReconcileQuery,
  currentMonthVn,
  monthStart,
  reasonLabel,
} from './reconcileLogic';

const NOW = new Date('2026-11-18T05:00:00Z');
const withCond = (field: string, value: string): ListState => ({
  ...EMPTY_RECONCILE_STATE,
  conditions: [{ id: 'c1', field, op: 'eq', value }],
});

describe('đối chiếu tái tục (TT-04)', () => {
  it('mặc định là tháng hiện tại theo giờ Việt Nam', () => {
    expect(currentMonthVn(NOW)).toBe('2026-11');
    expect(currentMonthVn(new Date('2026-10-31T18:00:00Z'))).toBe('2026-11');
    expect(buildReconcileQuery(EMPTY_RECONCILE_STATE, NOW)).toEqual({
      month: '2026-11',
      filters: {},
    });
  });
  it('đổi tháng bằng bộ lọc Campaign; tháng sai định dạng bị bỏ', () => {
    expect(buildReconcileQuery(withCond('month', '2026-10'), NOW).month).toBe('2026-10');
    expect(buildReconcileQuery(withCond('month', '2026-13'), NOW).month).toBe('2026-11');
    expect(monthStart('2026-10')).toBe('2026-10-01');
  });
  it('lọc nhanh «còn thiếu», tìm kiếm và cơ sở được chuyển cho máy chủ', () => {
    const state: ListState = {
      ...withCond('branch', 'b1'),
      search: ' Nam ',
      quick: { missing: ['missing'] },
    };
    expect(buildReconcileQuery(state, NOW).filters).toEqual({
      q: 'Nam',
      only_missing: true,
      branch_id: 'b1',
    });
  });
  it('nhãn lý do chưa có phiếu', () => {
    expect(reasonLabel('CO_PHIEU_L5')).toBe('Có phiếu L5 gần đây');
    expect(reasonLabel('LOP_CHUA_CO_LICH')).toBe('Lớp chưa có lịch');
    expect(reasonLabel('CHO_QUET_DEM')).toBe('Chờ đợt quét đêm');
    expect(reasonLabel(null)).toBe('');
  });
});
