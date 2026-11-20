// Đổi trạng thái màn danh sách Phiếu thu (ListState) thành bộ lọc gửi list_receipts. Hàm thuần, có kiểm thử. Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ.
import { datePresetInstants } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';
import type { SortState } from '../../ui/Data';

export type ReceiptFilters = Record<string, unknown>;

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)
const STATUS_CODES = ['NHAP', 'DA_GUI', 'CHO_KE_TOAN', 'DA_DUYET', 'HUY'];

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

/** `fixed` là bộ lọc cố định của màn (TC-04 Chờ kế toán duyệt luôn lọc waiting_accounting). */
export function buildReceiptFilters(
  state: ListState,
  fixed: ReceiptFilters = {},
  today: Date = new Date(),
): ReceiptFilters {
  const filters: ReceiptFilters = { ...fixed };
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const status = new Set<string>(
    (state.quick.status ?? []).filter((v) => STATUS_CODES.includes(v)),
  );
  const mine = state.quick.mine ?? [];
  if (mine.includes('mine')) filters.mine = true;
  if (mine.includes('waiting_manager')) filters.waiting_manager = true;
  // «Hình thức» (TC-01, TC-04): cùng nhóm là HOẶC; máy chủ lọc theo mảng payment_method.
  const methods = (state.quick.method ?? []).filter(Boolean);
  if (methods.length > 0) filters.payment_method = methods;
  // «Cơ sở» (chip nhiều cơ sở, TC-01, TC-04): máy chủ nhận mảng branch_ids và vẫn cắt theo phạm vi của người gọi.
  const branchIds = (state.quick.branches ?? []).filter(Boolean);
  if (branchIds.length > 0) filters.branch_ids = branchIds;
  // «Sao kê» (TC-04): chọn đúng một bên thì lọc; chọn cả hai hoặc không chọn thì không lọc.
  const bank = (state.quick.bank ?? []).filter((v) => v === 'KHOP' || v === 'CHUA');
  if (bank.length === 1) filters.bank_matched = bank[0];
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
  const range = datePresetInstants(state.datePreset, today);
  if (range && state.dateField === 'created') {
    filters.created_from = range.from.toISOString();
    filters.created_to = new Date(range.to.getTime() + 1).toISOString();
  }
  return filters;
}

/** Sắp xếp: các kiểu máy chủ hỗ trợ (mới nhất, cũ nhất, số tiền giảm dần); khác thì mặc định. */
export function receiptSortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'created') return sort.direction === 'asc' ? 'created_asc' : 'created_desc';
  if (sort.key === 'amount' && sort.direction === 'desc') return 'amount_desc';
  return undefined;
}

/** Cột chỉ hỗ trợ một chiều thì lần bấm thứ hai bỏ sắp xếp. */
export function nextReceiptSort(sort: SortState): SortState {
  if (sort && receiptSortParam(sort) === undefined) return null;
  return sort;
}

/** Trường nhóm của giao diện → tên trường của receipt_group_counts (Group By ở máy chủ, K1_nhom). */
export const RECEIPT_GROUP_FIELD_OF: Record<string, string> = {
  status: 'status',
  method: 'method',
  branch: 'branch',
  // Canvas TC04: nhóm «Sao kê» (Đã khớp, Chưa khớp), chỉ ở TC-04.
  bank: 'bank',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó (khoá trống: nhóm «Chưa có», không lọc thêm). */
export function receiptGroupFilter(field: string, key: string): ReceiptFilters {
  if (key === '') return {};
  if (field === 'status') return { status: [key] };
  if (field === 'method') return { payment_method: [key] };
  if (field === 'branch') return { branch_id: key };
  if (field === 'bank') return { bank_matched: key };
  return {};
}
