// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi app.list_users. Hàm thuần, có kiểm thử.
import type { Condition, ListState } from '../../list/types';

export type UserFilters = Record<string, unknown>;

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

/**
 * Nhóm lọc nhanh "Trạng thái" (Đang hoạt động, Đã khoá): chọn cả hai thì không lọc. Điều kiện: vai trò (một trong), cơ sở, loại
 * (NV, GV, TG). Điều kiện "khác" (ne) máy chủ chưa hiểu nên bỏ qua (ô chọn chỉ cho phép "là").
 */
export function buildUserFilters(state: ListState): UserFilters {
  const filters: UserFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const status = state.quick.status ?? [];
  if (status.length === 1) filters.status = status[0] === 'locked' ? 'LOCKED' : 'ACTIVE';
  const roles: string[] = [];
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'role' && cond.op === 'in') roles.push(...values);
    else if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = values[0];
    else if (cond.field === 'kind' && cond.op === 'eq') filters.kind = values[0];
  }
  if (roles.length > 0) filters.role = roles;
  return filters;
}

/** Sắp xếp: chỉ các kiểu máy chủ hỗ trợ (tên A-Z mặc định, đăng nhập gần nhất, mới tạo). */
export function userSortParam(key: string | null, direction: 'asc' | 'desc' | null): string {
  if (key === 'last_login' && direction === 'desc') return 'last_login_desc';
  if (key === 'created' && direction === 'desc') return 'created_desc';
  return 'name_asc';
}
