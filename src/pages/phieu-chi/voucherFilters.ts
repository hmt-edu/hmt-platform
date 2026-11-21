// Đổi trạng thái màn danh sách Phiếu chi (ListState) thành bộ lọc gửi list_payment_vouchers. Hàm thuần, có kiểm thử.
import { datePresetRange } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';

export type VoucherFilters = Record<string, unknown>;

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)
const STATUS_CODES = ['CHO_CHI', 'DA_CHI'];

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

export function buildVoucherFilters(state: ListState, today: Date = new Date()): VoucherFilters {
  const filters: VoucherFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const status = new Set<string>(
    (state.quick.status ?? []).filter((v) => STATUS_CODES.includes(v)),
  );
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

/** Trường nhóm của giao diện → tên trường của voucher_group_counts (Group By ở máy chủ, K1_nhom). */
export const VOUCHER_GROUP_FIELD_OF: Record<string, string> = {
  status: 'status',
  branch: 'branch',
  // Canvas TC10: nhóm «Hình thức» (migration 604).
  method: 'method',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó (khoá trống: nhóm «Chưa có», không lọc thêm). */
export function voucherGroupFilter(field: string, key: string): VoucherFilters {
  if (key === '') return {};
  if (field === 'status') return { status: [key] };
  if (field === 'branch') return { branch_id: key };
  if (field === 'method') return { payment_method: [key] };
  return {};
}
