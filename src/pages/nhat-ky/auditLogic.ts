// Hàm thuần của QT-11 Nhật ký thao tác: nhãn loại thao tác, rút gọn nội dung đổi, bộ lọc gửi app.list_audit_log.
import { datePresetRange } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';
import type { AuditRow } from './auditTypes';

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày
const MAX_SHOWN = 3; // allow-number: số trường hiện ở dòng, còn lại gộp "và N trường khác"

export const ACTION_LABEL: Record<AuditRow['action'], string> = { I: 'Tạo', U: 'Sửa', D: 'Xoá' };

function valueOf(c: Condition): string {
  return (Array.isArray(c.value) ? (c.value[0] ?? '') : c.value).trim();
}

function show(v: unknown): string {
  if (v === null || v === undefined || v === '') return '(trống)';
  return typeof v === 'string' ? v : JSON.stringify(v);
}

/** Tóm tắt nội dung đổi để hiện ở một dòng: sửa → "cột: cũ → mới"; tạo → "Tạo mới"; xoá → "Đã xoá bản ghi". */
export function summarizeChanges(row: Pick<AuditRow, 'action' | 'changes'>): string {
  if (row.action === 'I') return 'Tạo mới';
  if (row.action === 'D') return 'Đã xoá bản ghi';
  const entries = Object.entries(row.changes ?? {});
  if (entries.length === 0) return '—';
  const parts = entries.slice(0, MAX_SHOWN).map(([col, pair]) => {
    const [from, to] = Array.isArray(pair) ? (pair as unknown[]) : [undefined, pair];
    return `${col}: ${show(from)} → ${show(to)}`;
  });
  const rest = entries.length - parts.length;
  return rest > 0 ? `${parts.join('; ')}; và ${rest} trường khác` : parts.join('; ');
}

/** Đổi ListState thành bộ lọc gửi máy chủ: bảng, loại thao tác, mã bản ghi, khoảng ngày (theo ngày Việt Nam). */
export function buildAuditFilters(state: ListState, today = new Date()): Record<string, unknown> {
  const filters: Record<string, unknown> = {};
  const q = state.search.trim();
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(q))
    filters.record_id = q;
  const action = state.quick.action ?? [];
  if (action.length === 1) filters.action = action[0];
  for (const c of state.conditions) {
    const v = valueOf(c);
    if (v === '') continue;
    if (c.field === 'table' && c.op === 'eq') filters.table = v;
    else if (c.field === 'at' && c.op === 'from') {
      const start = vnDayStartOf(v);
      if (start) filters.from = start.toISOString();
    } else if (c.field === 'at' && c.op === 'to') {
      const start = vnDayStartOf(v);
      if (start) filters.to = new Date(start.getTime() + DAY_MS).toISOString();
    }
  }
  const range = datePresetRange(state.datePreset, today);
  if (range && state.dateField === 'at') {
    filters.from = range.from.toISOString();
    filters.to = new Date(range.to.getTime() + 1).toISOString();
  }
  return filters;
}
