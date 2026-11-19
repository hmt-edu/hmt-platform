// TC-15 Đối soát thu tiền: kiểu dữ liệu, bộ lọc gửi app.list_receipt_reconciliation, gọi dữ liệu và đánh dấu khớp. Hàm thuần có kiểm thử.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import { datePresetDateKeys } from '../../lib/dateRange';
import type { ListState } from '../../list/types';
import type { SupabaseClient } from '@supabase/supabase-js';

export type ReconcileRow = {
  id: string;
  code: string;
  paid_on: string;
  amount: number;
  txn_ref: string | null;
  payment_method_code: string;
  receiving_account_code: string | null;
  matched: boolean;
  bank_matched_at: string | null;
  collect_branch_code: string;
  receiver_name: string | null;
  parent_name: string | null;
};
export type ReconcilePage = {
  total: number;
  sum_all: number;
  sum_matched: number;
  sum_unmatched: number;
  count_unmatched: number;
  rows: ReconcileRow[];
};
export type ReconcileFilters = Record<string, unknown>;

/** Mã «chưa ghi tài khoản nhận» ở bộ lọc (máy chủ hiểu NONE). */
export const NO_ACCOUNT = 'NONE';

export function emptyReconcileState(): ListState {
  return {
    search: '',
    quick: {},
    conditions: [],
    group: [],
    columns: [],
    dateField: 'paid',
    datePreset: 'week',
  };
}

function valuesOf(value: string | string[]): string[] {
  return (Array.isArray(value) ? value : [value]).map((v) => v.trim()).filter(Boolean);
}

/**
 * Tìm theo mã giao dịch, mã phiếu; lọc nhanh Sao kê (một lựa chọn), Hình thức, Tài khoản nhận (một lựa chọn);
 * điều kiện Cơ sở thu; khoảng ngày thu theo mốc nhanh hoặc điều kiện từ/đến ngày.
 */
export function buildReconcileFilters(
  state: ListState,
  today: Date = new Date(),
): ReconcileFilters {
  const filters: ReconcileFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const matched = state.quick.matched ?? [];
  if (matched.length === 1) filters.matched = matched[0];
  const method = state.quick.method ?? [];
  if (method.length === 1) filters.method = method[0];
  const account = state.quick.account ?? [];
  if (account.length === 1) filters.account = account[0];
  for (const cond of state.conditions) {
    const values = valuesOf(cond.value);
    if (values.length === 0) continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = values[0];
    if (cond.field === 'paid' && cond.op === 'from') filters.from = values[0];
    if (cond.field === 'paid' && cond.op === 'to') filters.to = values[0];
  }
  const range = datePresetDateKeys(state.datePreset, today);
  if (range && state.dateField === 'paid') {
    filters.from = range.from;
    filters.to = range.to;
  }
  return filters;
}

export function reconcileSortParam(key: string | null, direction: 'asc' | 'desc' | null): string {
  if (key === 'paid' && direction === 'asc') return 'date_asc';
  if (key === 'amount' && direction === 'desc') return 'amount_desc';
  return 'date_desc';
}

export function useReconcilePage(
  filters: ReconcileFilters,
  sort: string,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['reconcile-list', filters, sort, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ReconcilePage>(supabase, 'list_receipt_reconciliation', {
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Đánh dấu (hoặc bỏ đánh dấu) khớp sao kê cho các phiếu, tuỳ chọn gán tài khoản nhận. Trả số phiếu đã đổi. */
export function markReceiptsMatched(
  supabase: SupabaseClient,
  ids: string[],
  matched: boolean,
  account: string | null,
): Promise<number> {
  return rpc<number>(supabase, 'mark_receipts_bank_matched', {
    p_ids: ids,
    p_matched: matched,
    p_account: account,
  });
}
