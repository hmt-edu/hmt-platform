// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi app.list_upsale_tickets (TT-01). Hàm thuần, có kiểm thử.
// Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ (R-CRM-07); máy chủ nhận một giá trị mỗi khoá, nhiều giá trị cùng nhóm thì không gửi.
import type { ListState } from '../../list/types';
import type { UpsaleFilters } from './upsaleTypes';

export const EMPTY_UPSALE_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const STAGE_CODES = ['L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8'];
export const OWNER_VALUES = ['mine', 'unassigned'];

function only(values: string[] | undefined, allowed: string[]): string | undefined {
  const ok = (values ?? []).filter((v) => allowed.includes(v));
  return ok.length === 1 ? ok[0] : undefined;
}

export function buildUpsaleFilters(state: ListState): UpsaleFilters {
  const filters: UpsaleFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const stage = only(state.quick.stage, STAGE_CODES);
  if (stage) filters.stage_code = stage;
  const owner = only(state.quick.owner, OWNER_VALUES);
  if (owner) filters.owner = owner;
  if ((state.quick.risk ?? []).includes('risk')) filters.risk = true;
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (value === '') continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = value;
    if (cond.field === 'month' && cond.op === 'eq' && /^\d{4}-\d{2}$/.test(value))
      filters.campaign_month = value;
  }
  return filters;
}
