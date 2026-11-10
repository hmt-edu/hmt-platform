// Đổi trạng thái màn danh sách lớp (ListState) thành bộ lọc gửi app.list_classes. Hàm thuần, có kiểm thử.
import type { Condition, ListState } from '../../list/types';

export type ClassFilters = Record<string, unknown>;

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

/**
 * Tìm theo mã lớp hoặc mã cũ (R-LOP-15). Nhóm lọc nhanh "Tình trạng duyệt" và "Tình trạng vận hành" (cùng nhóm là HOẶC).
 * Điều kiện nâng cao: cơ sở, môn, khối, phân loại (là). Điều kiện "khác" máy chủ chưa hiểu nên bỏ qua.
 */
export function buildClassFilters(state: ListState): ClassFilters {
  const filters: ClassFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.search = q;
  const status = state.quick.status ?? [];
  if (status.length > 0) filters.status = status;
  const operating = state.quick.operating ?? [];
  if (operating.length > 0) filters.operating = operating;
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0 || cond.op !== 'eq') continue;
    if (cond.field === 'branch') filters.branch_id = values[0];
    else if (cond.field === 'subject') filters.subject_code = values[0];
    else if (cond.field === 'grade') filters.grade_code = values[0];
    else if (cond.field === 'type') filters.class_type_code = values[0];
  }
  return filters;
}

export function classSortParam(key: string | null, direction: 'asc' | 'desc' | null): string {
  if (key === 'code' && direction === 'desc') return 'code_desc';
  if (key === 'start' && direction === 'desc') return 'start_desc';
  return 'code_asc';
}
