// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi các hàm Lead trong cơ sở dữ liệu (list_leads, lead_board,
// lead_group_counts, export_leads dùng chung một bộ lọc). Hàm thuần, có kiểm thử. R-CRM-07: cùng nhóm HOẶC, khác nhóm VÀ.
import { datePresetInstants } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { SortState } from '../../ui/Data';
import type { Condition, ListState } from '../../list/types';

export type LeadFilters = Record<string, unknown>;

/** Khoá lọc nhanh "Lịch hẹn" → mốc trong cơ sở dữ liệu (mốc hôm nay tính ở máy chủ, theo giờ Việt Nam). */
const APPOINTMENT: Record<string, string> = {
  overdue: 'OVERDUE',
  today: 'TODAY',
  upcoming: 'UPCOMING',
  none: 'NONE',
};
const MINE: Record<string, string> = { owner: 'OWNER', support: 'SUPPORT' };

/** Trường lọc nâng cao → khoá bộ lọc dạng danh sách. */
const LIST_FIELDS: Record<string, string> = {
  stage: 'stage',
  substage: 'substage',
  source_type: 'source_type',
  source: 'source',
  channel: 'channel',
};

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

function pick(map: Record<string, string>, values: string[] | undefined): string[] {
  return (values ?? []).flatMap((v) => (map[v] ? [map[v]] : []));
}

export function buildLeadFilters(state: ListState, today: Date = new Date()): LeadFilters {
  const filters: LeadFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;

  const mine = pick(MINE, state.quick.mine);
  if (mine.length > 0) filters.mine_roles = mine;
  const appointment = pick(APPOINTMENT, state.quick.appt);
  if (appointment.length > 0) filters.appointment = appointment;
  if ((state.quick.status ?? []).includes('merged')) filters.include_merged = true;
  // «Thùng rác»: chỉ lead Đã gộp và Đã huỷ (R-CRM-45).
  if ((state.quick.status ?? []).includes('trash')) filters.trash = true;

  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    const listKey = LIST_FIELDS[cond.field];
    if (listKey) {
      const current = (filters[listKey] as string[] | undefined) ?? [];
      filters[listKey] = [...new Set([...current, ...values])];
    } else if (cond.field === 'campaign' && cond.op === 'eq') {
      filters.campaign_id = values[0];
    } else if (cond.field === 'branch' && cond.op === 'eq') {
      filters.branch_id = values[0];
    } else if (cond.field === 'created' && cond.op === 'from') {
      const start = vnDayStartOf(values[0] ?? '');
      if (start) filters.created_from = start.toISOString();
    } else if (cond.field === 'created' && cond.op === 'to') {
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

/** Bộ lọc của một nhóm Group By (giai đoạn, nguồn, người phụ trách) để mở dòng của nhóm đó. */
export function groupFilter(field: string, key: string): LeadFilters {
  if (key === '') return {};
  if (field === 'stage') return { stage: [key] };
  if (field === 'source') return { source: [key] };
  if (field === 'owner') return { owner_id: key };
  return {};
}

/** Trường nhóm của giao diện → tên trường của lead_group_counts. */
export const GROUP_FIELD_OF: Record<string, string> = {
  stage: 'stage',
  source: 'source',
  owner: 'owner',
};

/** Sắp xếp: chỉ các kiểu máy chủ hỗ trợ (mới nhất, cũ nhất, lịch hẹn gần nhất, tên A-Z); khác thì mặc định. */
export function sortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'created') return sort.direction === 'asc' ? 'created_asc' : 'created_desc';
  if (sort.key === 'next' && sort.direction === 'asc') return 'next_appointment_asc';
  if (sort.key === 'parent' && sort.direction === 'asc') return 'name_asc';
  return undefined;
}

/** Bấm đổi chiều sắp xếp: cột chỉ hỗ trợ một chiều thì lần bấm thứ hai bỏ sắp xếp (không hiện mũi tên sai). */
export function nextSort(sort: SortState): SortState {
  if (sort && sortParam(sort) === undefined) return null;
  return sort;
}
