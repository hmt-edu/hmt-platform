// Hàm thuần của QT-12: nhãn kết quả đăng nhập, bộ lọc gửi máy chủ cho hai tab (Đăng nhập, Xuất file).
import { datePresetRange } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày

export const RESULT_LABEL: Record<string, string> = {
  THANH_CONG: 'Thành công',
  SAI_MAT_KHAU: 'Sai mật khẩu',
  TAI_KHOAN_KHOA: 'Tài khoản bị khoá',
  KHOA_TAM: 'Đang khoá tạm',
  KHONG_CO_TAI_KHOAN: 'Không có tài khoản',
  LOI: 'Lỗi hệ thống',
};

function valueOf(c: Condition): string {
  return (Array.isArray(c.value) ? (c.value[0] ?? '') : c.value).trim();
}

/** Khoảng ngày từ điều kiện "Ngày" và mốc nhanh (theo ngày Việt Nam); mốc `to` loại trừ. */
function dateFilters(state: ListState, today: Date): Record<string, string> {
  const out: Record<string, string> = {};
  for (const c of state.conditions) {
    const v = valueOf(c);
    if (c.field !== 'at' || v === '') continue;
    const start = vnDayStartOf(v);
    if (!start) continue;
    if (c.op === 'from') out.from = start.toISOString();
    else if (c.op === 'to') out.to = new Date(start.getTime() + DAY_MS).toISOString();
  }
  const range = datePresetRange(state.datePreset, today);
  if (range && state.dateField === 'at') {
    out.from = range.from.toISOString();
    out.to = new Date(range.to.getTime() + 1).toISOString();
  }
  return out;
}

/** Tab Đăng nhập: tìm theo tên đăng nhập, lọc nhanh theo kết quả (chọn cả sáu = không lọc), khoảng ngày. */
export function buildLoginFilters(state: ListState, today = new Date()): Record<string, unknown> {
  const filters: Record<string, unknown> = dateFilters(state, today);
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const result = state.quick.result ?? [];
  if (result.length === 1) filters.result = result[0];
  return filters;
}

/** Tab Xuất file: lọc theo phân hệ (điều kiện "Phân hệ") và khoảng ngày. */
export function buildExportFilters(state: ListState, today = new Date()): Record<string, unknown> {
  const filters: Record<string, unknown> = dateFilters(state, today);
  for (const c of state.conditions) {
    const v = valueOf(c);
    if (c.field === 'module' && c.op === 'eq' && v !== '') filters.module = v;
  }
  return filters;
}

/** Bộ lọc xuất file ghi trong nhật ký (jsonb) rút thành chuỗi ngắn để hiện ở một dòng. */
export function summarizeExportFilters(f: Record<string, unknown>): string {
  const keys = Object.keys(f);
  return keys.length === 0
    ? 'Không lọc'
    : keys.map((k) => `${k}: ${JSON.stringify(f[k])}`).join('; ');
}
