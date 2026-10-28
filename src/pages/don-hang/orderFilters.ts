// Đổi trạng thái màn danh sách Đơn hàng (ListState) thành bộ lọc gửi list_orders và export_orders (một bộ lọc dùng chung).
// Hàm thuần, có kiểm thử. Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ (R-CRM-07).
import { datePresetRange } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';
import type { SortState } from '../../ui/Data';

export type OrderFilters = Record<string, unknown>;

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)

/** Trạng thái lưu của đơn (R-TIEN-06: bị từ chối thì về Nháp, nên không có trạng thái Từ chối). */
const STATUS_CODES = ['NHAP', 'DA_TRINH', 'DA_DUYET', 'HUY'];

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

export function buildOrderFilters(state: ListState, today: Date = new Date()): OrderFilters {
  const filters: OrderFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;

  const status = new Set<string>(
    (state.quick.status ?? []).filter((v) => STATUS_CODES.includes(v)),
  );
  if ((state.quick.mine ?? []).includes('mine')) filters.mine = true;

  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'status') {
      for (const v of values) if (STATUS_CODES.includes(v)) status.add(v);
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
  if (status.size > 0) filters.status = [...status];

  const range = datePresetRange(state.datePreset, today);
  if (range && state.dateField === 'created') {
    filters.created_from = range.from.toISOString();
    filters.created_to = new Date(range.to.getTime() + 1).toISOString();
  }
  return filters;
}

/** Sắp xếp: các kiểu máy chủ hỗ trợ (mới nhất, cũ nhất, tổng tiền giảm dần); khác thì mặc định. */
export function orderSortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'created') return sort.direction === 'asc' ? 'created_asc' : 'created_desc';
  if (sort.key === 'total' && sort.direction === 'desc') return 'total_desc';
  return undefined;
}

/** Bấm đổi chiều: cột chỉ hỗ trợ một chiều thì lần bấm thứ hai bỏ sắp xếp. */
export function nextOrderSort(sort: SortState): SortState {
  if (sort && orderSortParam(sort) === undefined) return null;
  return sort;
}
