// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi app.list_parents, app.list_students. Hàm thuần, có kiểm thử.
import type { Condition, ListState } from '../../list/types';

export type CustFilters = Record<string, unknown>;

const valuesOf = (c: Condition): string[] =>
  (Array.isArray(c.value) ? c.value : [c.value]).map((v) => v.trim()).filter(Boolean);

/** Phụ huynh: tìm theo tên, SĐT, mã; nhóm lọc nhanh Tình trạng (Có con đang học / Chưa có con đang học); điều kiện cơ sở tiếp nhận. */
export function buildParentFilters(state: ListState): CustFilters {
  const f: CustFilters = {};
  const q = state.search.trim();
  if (q !== '') f.search = q;
  const status = state.quick.status ?? [];
  if (status.length > 0) f.status = status;
  for (const c of state.conditions) {
    const v = valuesOf(c);
    if (v.length > 0 && c.op === 'eq' && c.field === 'branch') f.branch_id = v[0];
    if (v.length > 0 && c.op === 'eq' && c.field === 'studying') f.studying_branch_id = v[0];
  }
  return f;
}

/** Học sinh: tìm theo tên, mã, mã cũ; nhóm lọc nhanh Tình trạng; điều kiện cơ sở, khối. */
export function buildStudentFilters(state: ListState): CustFilters {
  const f: CustFilters = {};
  const q = state.search.trim();
  if (q !== '') f.search = q;
  const status = state.quick.status ?? [];
  if (status.length > 0) f.status = status;
  for (const c of state.conditions) {
    const v = valuesOf(c);
    if (v.length === 0 || c.op !== 'eq') continue;
    if (c.field === 'branch') f.branch_id = v[0];
    else if (c.field === 'grade') f.grade = v[0];
  }
  return f;
}

/** Trường nhóm của giao diện Phụ huynh (khoá cấu hình) → tên trường của app.parent_group_counts. */
export const PARENT_GROUP_FIELD_OF: Record<string, string> = { status: 'status', branch: 'branch' };

/** Bộ lọc của MỘT nhóm (để mở nhóm tải dòng bằng list_parents). */
export function parentGroupFilter(field: string, key: string): CustFilters {
  if (key === '') return {};
  if (field === 'status') return { status: [key] };
  if (field === 'branch') return { branch_id: key };
  return {};
}

/** Đường dẫn «Tạo ticket» từ hồ sơ phụ huynh: màn tạo ticket điền sẵn phụ huynh (id) và ô tìm theo mã. */
export function newTicketForParentPath(id: string, code: string): string {
  return `/crm/ticket/moi?phu-huynh=${id}&ma=${encodeURIComponent(code)}`;
}

export function custSortParam(key: string | null, direction: 'asc' | 'desc' | null): string {
  if (key === 'name') return 'name_asc';
  if (key === 'code' && direction === 'desc') return 'code_desc';
  return 'code_asc';
}
