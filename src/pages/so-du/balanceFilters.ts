// Đổi trạng thái màn danh sách Số dư khách hàng (ListState) thành bộ lọc gửi list_customer_balances. Hàm thuần, có kiểm thử.
import type { Condition, ListState } from '../../list/types';

export type BalanceFilters = Record<string, unknown>;

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

export function buildBalanceFilters(state: ListState): BalanceFilters {
  const filters: BalanceFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  if ((state.quick.balance ?? []).includes('positive')) filters.only_positive = true;
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = values[0];
  }
  return filters;
}
