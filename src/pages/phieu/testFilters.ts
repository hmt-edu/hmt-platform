// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi các hàm phiếu (list_student_tests, student_test_board,
// student_test_group_counts, export_student_tests). Hàm thuần, có kiểm thử. R-CRM-07: cùng nhóm HOẶC, khác nhóm VÀ.
import { datePresetRange } from '../../lib/dateRange';
import { vnDayStartOf } from '../../lib/vnDay';
import type { Condition, ListState } from '../../list/types';

export type TestFilters = Record<string, unknown>;

/** Khoá lọc nhanh "Của tôi" → vai trò trong cơ sở dữ liệu. */
const MINE: Record<string, string> = { owner: 'OWNER', creator: 'CREATOR', grader: 'GRADER' };
/** Khoá lọc nhanh thời gian → mốc trong cơ sở dữ liệu (mốc hôm nay tính ở máy chủ, theo giờ Việt Nam). */
const WHEN: Record<string, string> = { overdue: 'OVERDUE', today: 'TODAY', upcoming: 'UPCOMING' };
const STATUS: Record<string, string> = {
  draft: 'DRAFT',
  testing: 'TESTING',
  review: 'TEACHER_REVIEW',
  done: 'COMPLETED',
  cancelled: 'CANCELLED',
};
/** Trường lọc nâng cao dạng danh sách → khoá bộ lọc. */
const LIST_FIELDS: Record<string, string> = { subject: 'subject', mode: 'mode', level: 'level' };
const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày (mốc "đến ngày" tính hết ngày)

type Range = { from?: Date | undefined; to?: Date | undefined };

function narrow(a: Range, b: Range): Range {
  const from = [a.from, b.from].filter((d): d is Date => d !== undefined);
  const to = [a.to, b.to].filter((d): d is Date => d !== undefined);
  return {
    from: from.length > 0 ? new Date(Math.max(...from.map((d) => d.getTime()))) : undefined,
    to: to.length > 0 ? new Date(Math.min(...to.map((d) => d.getTime()))) : undefined,
  };
}

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

const pick = (map: Record<string, string>, keys: string[] | undefined): string[] =>
  (keys ?? []).flatMap((k) => (map[k] ? [map[k]] : []));

/**
 * `window`: cửa sổ thời gian của kiểu xem Lịch (thay mốc nhanh của ô "Ngày giờ test", vì Lịch tự có thanh chuyển kỳ);
 * `to` của cửa sổ là mốc loại trừ.
 */
export function buildTestFilters(
  state: ListState,
  today: Date = new Date(),
  window?: { from: Date; to: Date },
): TestFilters {
  const filters: TestFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const mine = pick(MINE, state.quick.mine);
  if (mine.length > 0) filters.mine_roles = mine;
  const when = pick(WHEN, state.quick.when);
  if (when.length > 0) filters.when = when;
  const status = pick(STATUS, state.quick.status);
  if (status.length > 0) filters.status = status;

  let range: Range = {};
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    const listKey = LIST_FIELDS[cond.field];
    if (listKey) {
      const current = (filters[listKey] as string[] | undefined) ?? [];
      filters[listKey] = [...new Set([...current, ...values])];
    } else if (cond.field === 'test_branch' && cond.op === 'eq') {
      filters.test_branch_id = values[0];
    } else if (cond.field === 'branch' && cond.op === 'eq') {
      filters.branch_id = values[0];
    } else if (cond.field === 'owner' && cond.op === 'eq') {
      filters.owner_id = values[0];
    } else if (cond.field === 'grader' && cond.op === 'eq') {
      filters.grader_id = values[0];
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

/** Trường nhóm của giao diện → tên trường của student_test_group_counts. */
export const TEST_GROUP_FIELD_OF: Record<string, string> = {
  status: 'status',
  subject: 'subject',
  mode: 'mode',
  level: 'level',
  owner: 'owner',
  grader: 'grader',
  test_branch: 'test_branch',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó. */
export function testGroupFilter(field: string, key: string): TestFilters {
  if (key === '') return {};
  if (field === 'status') return { status: [key] };
  if (field === 'subject') return { subject: [key] };
  if (field === 'mode') return { mode: [key] };
  if (field === 'level') return { level: [key] };
  if (field === 'owner') return { owner_id: key };
  if (field === 'grader') return { grader_id: key };
  if (field === 'test_branch') return { test_branch_id: key };
  return {};
}
