// Hàm thuần của màn Lên khối đầu năm (KH-08): bộ lọc gửi máy chủ, chữ khối mới, số em sẽ lên khối sau khi loại trừ.
import type { ListState } from '../../list/types';
import type { PromotionPreview, PromotionRow } from './gradePromotionTypes';

export function buildPromotionFilters(state: ListState): Record<string, unknown> {
  const filters: Record<string, unknown> = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (cond.field === 'branch' && cond.op === 'eq' && value !== '') filters.branch_id = value;
  }
  return filters;
}

/** «Khối 9» hoặc «Tốt nghiệp» (khối mới trống). */
export function newGradeText(row: Pick<PromotionRow, 'new_grade'>): string {
  return row.new_grade === null ? 'Tốt nghiệp' : `Khối ${row.new_grade}`;
}

/** Số em chạy thật sau khi bỏ em loại trừ; tốt nghiệp tính riêng. Em loại trừ lạ (không còn trong danh sách) không làm lệch số. */
export function afterExclusion(
  preview: Pick<PromotionPreview, 'eligible' | 'graduating'>,
  excluded: { count: number; graduating: number },
): { total: number; graduating: number; promoting: number } {
  const total = Math.max(preview.eligible - excluded.count, 0);
  const graduating = Math.max(preview.graduating - excluded.graduating, 0);
  return { total, graduating, promoting: Math.max(total - graduating, 0) };
}
