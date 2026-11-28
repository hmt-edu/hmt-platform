import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import {
  EMPTY_RECONCILE_STATE,
  buildReconcileQuery,
  currentMonthVn,
  monthStart,
  reasonLabel,
  reconcileGroupFilter,
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
  it('đổi tháng bằng bộ lọc Tháng hết giờ; tháng sai định dạng bị bỏ', () => {
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

describe('Group By TT-04: bộ lọc mở nhóm', () => {
  it('nhóm cơ sở lọc theo branch_id, nhóm lý do lọc theo mã lý do', () => {
    expect(reconcileGroupFilter('branch', 'b1')).toEqual({ branch_id: 'b1' });
    expect(reconcileGroupFilter('reason', 'CHO_QUET_DEM')).toEqual({ reason: ['CHO_QUET_DEM'] });
    expect(reconcileGroupFilter('reason', 'DA_CO_PHIEU')).toEqual({ reason: ['DA_CO_PHIEU'] });
  });
  it('campaign là tháng đang xem nên không lọc thêm; khoá trống không lọc', () => {
    expect(reconcileGroupFilter('campaign', '2026-11')).toEqual({});
    expect(reconcileGroupFilter('branch', '')).toEqual({});
    expect(reconcileGroupFilter('reason', '')).toEqual({});
  });
});
