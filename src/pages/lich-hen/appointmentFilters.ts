// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi app.list_appointments. Hàm thuần, có kiểm thử.
// R-CRM-07: cùng nhóm HOẶC, khác nhóm VÀ. Khoảng thời gian: mốc nhanh của ô "Thời gian", điều kiện "từ ngày"/"đến ngày",
// và (kiểu xem Lịch) cửa sổ đang xem; các khoảng chồng nhau thì lấy phần chung.
import { datePresetRange } from '../../lib/dateRange';
import { vnDayBounds, vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';
import type { AppointmentStatus } from './appointmentTypes';

export type AppointmentFilters = Record<string, unknown>;

const STATUS_KEYS: Record<string, AppointmentStatus> = {
  open: 'CHUA_LAM',
  done: 'HOAN_THANH',
  cancelled: 'HUY',
};
/** Giá trị không khớp trạng thái nào: bộ lọc rỗng có chủ ý (ví dụ chọn "Hoàn thành" và "Quá hạn" cùng lúc). */
const NO_MATCH = 'KHONG_KHOP';
const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

type Range = { from?: Date | undefined; to?: Date | undefined };

function narrow(range: Range, next: Range): Range {
  const from = [range.from, next.from].filter((d): d is Date => d !== undefined);
  const to = [range.to, next.to].filter((d): d is Date => d !== undefined);
  return {
    from: from.length > 0 ? new Date(Math.max(...from.map((d) => d.getTime()))) : undefined,
    to: to.length > 0 ? new Date(Math.min(...to.map((d) => d.getTime()))) : undefined,
  };
}

/**
 * `window`: cửa sổ thời gian của kiểu xem Lịch (thay cho mốc nhanh của ô "Thời gian", vì Lịch tự có thanh chuyển kỳ).
 * `to` của cửa sổ là mốc loại trừ (đầu ngày sau ngày cuối).
 */
export function buildAppointmentFilters(
  state: ListState,
  today: Date = new Date(),
  window?: { from: Date; to: Date },
): AppointmentFilters {
  const filters: AppointmentFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  if ((state.quick.mine ?? []).includes('owner')) filters.mine = true;

  let status = (state.quick.status ?? []).flatMap((k) => (STATUS_KEYS[k] ? [STATUS_KEYS[k]] : []));
  let range: Range = {};
  if ((state.quick.overdue ?? []).includes('overdue')) {
    // Quá hạn = Chưa làm và trước đầu ngày hôm nay (giờ Việt Nam).
    status = status.length === 0 ? ['CHUA_LAM'] : status.filter((s) => s === 'CHUA_LAM');
    range = narrow(range, { to: vnDayBounds(today).start });
    if (status.length === 0) status = [NO_MATCH as AppointmentStatus];
  }
  if (status.length > 0) filters.status = status;

  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'activity') {
      const current = (filters.activity as string[] | undefined) ?? [];
      filters.activity = [...new Set([...current, ...values])];
    } else if (cond.field === 'owner' && cond.op === 'eq') {
      filters.owner_id = values[0];
    } else if (cond.field === 'branch' && cond.op === 'eq') {
      filters.branch_id = values[0];
    } else if (cond.field === 'time' && cond.op === 'from') {
      const start = vnDayStartOf(values[0] ?? '');
      if (start) range = narrow(range, { from: start });
    } else if (cond.field === 'time' && cond.op === 'to') {
      const start = vnDayStartOf(values[0] ?? '');
      if (start) range = narrow(range, { to: new Date(start.getTime() + DAY_MS) });
    }
  }

  if (window) {
    range = narrow(range, window);
  } else {
    const preset = datePresetRange(state.datePreset, today);
    if (preset) range = narrow(range, { from: preset.from, to: new Date(preset.to.getTime() + 1) });
  }
  if (range.from) filters.from = range.from.toISOString();
  if (range.to) filters.to = range.to.toISOString();
  return filters;
}

/** Số lịch quá hạn bị ẩn: có mốc thời gian đang lọc thì đếm lịch Chưa làm trước đầu khoảng đó. */
export function hiddenOverdueBefore(state: ListState, today: Date = new Date()): Date | null {
  if ((state.quick.overdue ?? []).includes('overdue')) return null;
  const preset = datePresetRange(state.datePreset, today);
  return preset ? preset.from : null;
}
