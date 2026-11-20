// Hàm thuần của TT-04: đổi trạng thái danh sách thành tham số gọi máy chủ, nhãn lý do chưa có phiếu. Có kiểm thử.
import { vnDayBounds } from '../../lib/vnDay';
import type { ListState } from '../../list/types';
import type { ReconcileQuery, ReconcileRow } from './reconcileTypes';

export const EMPTY_RECONCILE_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

/** Tháng hiện tại theo giờ Việt Nam, dạng YYYY-MM. */
export function currentMonthVn(now: Date = new Date()): string {
  return vnDayBounds(now).dateKey.slice(0, 7);
}

const REASONS: Record<string, string> = {
  CO_PHIEU_L5: 'Có phiếu L5 gần đây',
  LOP_CHUA_CO_LICH: 'Lớp chưa có lịch',
  CHO_QUET_DEM: 'Chờ đợt quét đêm',
};
export const reasonLabel = (code: ReconcileRow['missing_reason']): string =>
  (code && REASONS[code]) || '';

export function buildReconcileQuery(state: ListState, now: Date = new Date()): ReconcileQuery {
  const filters: Record<string, unknown> = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  if ((state.quick.missing ?? []).includes('missing')) filters.only_missing = true;
  let month = currentMonthVn(now);
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (value === '') continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = value;
    if (cond.field === 'month' && cond.op === 'eq' && MONTH_RE.test(value)) month = value;
  }
  return { month, filters };
}

/** Ngày đầu tháng (YYYY-MM-01) gửi cho p_month. */
export const monthStart = (month: string): string => `${month}-01`;

/** Trường nhóm của giao diện → tên trường máy chủ (upsale_reconcile_group_counts). */
export const RECONCILE_GROUP_FIELD_OF: Record<string, string> = {
  branch: 'branch',
  campaign: 'campaign',
  reason: 'reason',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó (campaign là tháng đang xem nên không lọc thêm; khoá trống: nhóm «Chưa có»). */
export function reconcileGroupFilter(field: string, key: string): Record<string, unknown> {
  if (field === 'branch') return key === '' ? {} : { branch_id: key };
  if (field === 'reason') return key === '' ? {} : { reason: [key] };
  return {};
}
