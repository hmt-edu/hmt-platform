// Đổi trạng thái màn danh sách Báo giá (ListState) thành bộ lọc gửi list_quotations và export_quotations (một bộ lọc dùng chung).
// Hàm thuần, có kiểm thử. Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ (R-CRM-07).
import { datePresetRange } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';
import type { SortState } from '../../ui/Data';

export type QuoteFilters = Record<string, unknown>;

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)

/** Trạng thái lưu trong cơ sở dữ liệu của lọc nhanh "Tình trạng". Đã chuyển đơn không lưu (tính từ dòng, R-TIEN-02): gửi bằng khoá `converted`. */
const STATUS_CODES = ['NHAP', 'DA_GUI', 'TU_CHOI', 'HUY'];
const CONVERTED = 'DA_CHUYEN_DON';

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

export function buildQuoteFilters(state: ListState, today: Date = new Date()): QuoteFilters {
  const filters: QuoteFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;

  const status = new Set<string>(
    (state.quick.status ?? []).filter((v) => STATUS_CODES.includes(v)),
  );
  let converted = (state.quick.status ?? []).includes(CONVERTED);
  if ((state.quick.mine ?? []).includes('mine')) filters.mine = true;
  if ((state.quick.valid ?? []).includes('expired')) filters.expired = true;

  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'status') {
      for (const v of values) if (STATUS_CODES.includes(v)) status.add(v);
      if (values.includes(CONVERTED)) converted = true;
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
  // Đã chuyển đơn là một phần của Đã gửi: chọn cả hai thì Đã gửi đã bao gồm. Máy chủ ghép các khoá bằng VÀ, nên chỉ gửi `converted` khi
  // không chọn tình trạng nào khác; chọn kèm Nháp, Từ chối, Huỷ (không có Đã gửi) thì chỉ lọc theo các tình trạng đó (hạn chế ghi trong PR).
  if (converted && status.size === 0) filters.converted = true;

  const range = datePresetRange(state.datePreset, today);
  if (range && state.dateField === 'created') {
    filters.created_from = range.from.toISOString();
    filters.created_to = new Date(range.to.getTime() + 1).toISOString();
  }
  return filters;
}

/** Sắp xếp: các kiểu máy chủ hỗ trợ (mới nhất, cũ nhất, tổng tiền giảm dần, hạn gần nhất); khác thì mặc định. */
export function quoteSortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  if (sort.key === 'created') return sort.direction === 'asc' ? 'created_asc' : 'created_desc';
  if (sort.key === 'total' && sort.direction === 'desc') return 'total_desc';
  if (sort.key === 'valid' && sort.direction === 'asc') return 'valid_asc';
  return undefined;
}

/** Bấm đổi chiều: cột chỉ hỗ trợ một chiều thì lần bấm thứ hai bỏ sắp xếp. */
export function nextQuoteSort(sort: SortState): SortState {
  if (sort && quoteSortParam(sort) === undefined) return null;
  return sort;
}
