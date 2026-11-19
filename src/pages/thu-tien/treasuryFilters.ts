// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi list_money_in / list_receivables. Hàm thuần, có kiểm thử.
import { datePresetDateKeys, datePresetInstants } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';
import type { SortState } from '../../ui/Data';
import type { DebtStatus } from './treasuryTypes';

export type TreasuryFilters = Record<string, unknown>;

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)
export const DEBT_STATUSES: DebtStatus[] = ['QUA_HAN', 'SAP_DEN_HAN', 'CHUA_DEN_HAN'];

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

/** Ngày yyyy-mm-dd hợp lệ (bộ lọc ngày của khuôn K03 đã cho dạng này); null nếu không đọc được. */
function dayKey(text: string): string | null {
  return vnDayStartOf(text) ? text : null;
}

/** TC-08: q, branch_id, kind (THU/DAO), created_from/created_to (mốc thời gian, đến trước mốc cuối). */
export function buildMoneyInFilters(state: ListState, today: Date = new Date()): TreasuryFilters {
  const filters: TreasuryFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const kind = state.quick.kind ?? [];
  if (kind.length === 1) filters.kind = kind[0];
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = values[0];
    if (cond.field === 'created' && cond.op === 'from') {
      const start = vnDayStartOf(values[0] ?? '');
      if (start) filters.created_from = start.toISOString();
    }
    if (cond.field === 'created' && cond.op === 'to') {
      const start = vnDayStartOf(values[0] ?? '');
      if (start) filters.created_to = new Date(start.getTime() + DAY_MS).toISOString();
    }
  }
  const range = datePresetInstants(state.datePreset, today);
  if (range && state.dateField === 'created') {
    filters.created_from = range.from.toISOString();
    filters.created_to = new Date(range.to.getTime() + 1).toISOString();
  }
  return filters;
}

/** TC-13: q, status[], branch_id, due_from/due_to (ngày). */
export function buildReceivableFilters(
  state: ListState,
  today: Date = new Date(),
): TreasuryFilters {
  const filters: TreasuryFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const status = new Set<string>(
    (state.quick.status ?? []).filter((v) => (DEBT_STATUSES as string[]).includes(v)),
  );
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'status') {
      for (const v of values) if ((DEBT_STATUSES as string[]).includes(v)) status.add(v);
    } else if (cond.field === 'branch' && cond.op === 'eq') {
      filters.branch_id = values[0];
    } else if (cond.field === 'due' && cond.op === 'from') {
      const key = dayKey(values[0] ?? '');
      if (key) filters.due_from = key;
    } else if (cond.field === 'due' && cond.op === 'to') {
      const key = dayKey(values[0] ?? '');
      if (key) filters.due_to = key;
    }
  }
  if (status.size > 0) filters.status = [...status];
  const keys = datePresetDateKeys(state.datePreset, today);
  if (keys && state.dateField === 'due') {
    filters.due_from = keys.from;
    filters.due_to = keys.to;
  }
  return filters;
}

/** TC-08: mặc định mới nhất trước; chỉ hỗ trợ Ngày (hai chiều) và Số tiền (hai chiều). */
export function moneyInSortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'date') return sort.direction === 'asc' ? 'date_asc' : 'date_desc';
  if (sort.key === 'amount') return sort.direction === 'asc' ? 'amount_asc' : 'amount_desc';
  return undefined;
}

/** TC-13: mặc định hạn sớm nhất trước; Hạn đóng hai chiều, Còn nợ giảm dần. */
export function receivableSortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'due') return sort.direction === 'asc' ? 'due_asc' : 'due_desc';
  if (sort.key === 'owed' && sort.direction === 'desc') return 'owed_desc';
  return undefined;
}

/** Cột chỉ hỗ trợ một chiều thì lần bấm thứ hai bỏ sắp xếp. */
export function nextReceivableSort(sort: SortState): SortState {
  if (sort && receivableSortParam(sort) === undefined) return null;
  return sort;
}
