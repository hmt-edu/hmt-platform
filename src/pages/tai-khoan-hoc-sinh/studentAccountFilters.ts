// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi app.list_student_accounts. Hàm thuần, có kiểm thử.
import type { ListState } from '../../list/types';
import type { StudentAccountRow, StudentAccountState } from './studentAccountTypes';

export type StudentAccountFilters = Record<string, unknown>;

const STATE_OF_QUICK: Record<string, StudentAccountState> = {
  none: 'CHUA_CAP',
  active: 'HOAT_DONG',
  locked: 'BI_KHOA',
};

/** Tìm (tên, mã HS, tên phụ huynh), lọc nhanh Tình trạng tài khoản (chọn một), điều kiện Cơ sở. Chọn nhiều tình trạng thì không lọc. */
export function buildStudentAccountFilters(state: ListState): StudentAccountFilters {
  const filters: StudentAccountFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const quick = state.quick.state ?? [];
  const only = quick.length === 1 ? STATE_OF_QUICK[quick[0] ?? ''] : undefined;
  if (only) filters.state = only;
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (cond.field === 'branch' && cond.op === 'eq' && value !== '') filters.branch_id = value;
  }
  return filters;
}

/** Dòng nào chọn để cấp hàng loạt được: chỉ em chưa có tài khoản. */
export function issuable(
  rows: StudentAccountRow[],
  selected: ReadonlySet<string>,
): StudentAccountRow[] {
  return rows.filter((r) => selected.has(r.student_id) && r.state === 'CHUA_CAP');
}
