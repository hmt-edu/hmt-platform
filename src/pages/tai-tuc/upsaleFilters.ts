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

/** Trường nhóm của giao diện → tên trường của upsale_group_counts (Group By ở máy chủ, K1_nhom). */
export const UPSALE_GROUP_FIELD_OF: Record<string, string> = {
  stage: 'stage',
  substage: 'substage',
  campaign: 'campaign',
  owner: 'owner',
  branch: 'branch',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó (khoá trống: nhóm «Chưa có», không lọc thêm). */
export function upsaleGroupFilter(field: string, key: string): UpsaleFilters {
  if (key === '') return {};
  if (field === 'stage') return { stage_code: key };
  if (field === 'substage') return { substage_code: key };
  if (field === 'campaign') return { campaign_month: key };
  if (field === 'owner') return { owner_id: key };
  if (field === 'branch') return { branch_id: key };
  return {};
}
