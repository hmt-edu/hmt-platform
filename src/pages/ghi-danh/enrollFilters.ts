// Đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi enrollment_list. Hàm thuần, có kiểm thử.
// Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ (R-CRM-07). Lọc, sắp xếp, phân trang làm ở máy chủ.
import type { Condition, ListState } from '../../list/types';
import type { SortState } from '../../ui/Data';
import type { EnrollFilters } from './useEnrollmentData';

export const EMPTY_ENROLL_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

/** Trạng thái mở đầu của danh sách: `?loc=cho-xep-lop` bật sẵn bộ lọc nhanh «Chờ xếp lớp» (đường dẫn Hàng chờ xếp lớp cũ chuyển về đây). */
export function initialEnrollState(preset: string | null): ListState {
  return preset === 'cho-xep-lop'
    ? { ...EMPTY_ENROLL_STATE, quick: { status: ['CHO_XEP_LOP'] } }
    : EMPTY_ENROLL_STATE;
}

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

/** `statusCodes`: mã tình trạng hợp lệ (từ danh mục); mã lạ bị bỏ để không gửi lên máy chủ. */
export function buildEnrollFilters(state: ListState, statusCodes: string[]): EnrollFilters {
  const filters: EnrollFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const status = new Set<string>((state.quick.status ?? []).filter((v) => statusCodes.includes(v)));
  const mode = new Set<string>(state.quick.mode ?? []);
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'status') {
      for (const v of values) if (statusCodes.includes(v)) status.add(v);
    } else if (cond.field === 'branch' && cond.op === 'eq') {
      filters.branch_id = values[0];
    } else if (cond.field === 'mode') {
      for (const v of values) mode.add(v);
    }
  }
  if (status.size > 0) filters.status = [...status];
  if (mode.size === 1) filters.delivery_mode_code = [...mode][0];
  return filters;
}

/** Sắp xếp các kiểu máy chủ hỗ trợ: mã, học sinh, giờ còn lại; khác thì mặc định (mã giảm dần). */
export function enrollSortParam(sort: SortState): string | undefined {
  if (!sort) return undefined;
  const dir = sort.direction === 'asc' ? 'asc' : 'desc';
  if (sort.key === 'code') return `code_${dir}`;
  if (sort.key === 'student') return `student_${dir}`;
  if (sort.key === 'remaining') return `remaining_${dir}`;
  return undefined;
}

/** Trường nhóm của giao diện → tên trường máy chủ (enrollment_group_counts). */
export const ENROLL_GROUP_FIELD_OF: Record<string, string> = {
  mode: 'mode',
  class: 'class',
  status: 'status',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó (khoá trống: nhóm «Chưa có»; lớp trống = chưa có lớp hiện tại). */
export function enrollGroupFilter(field: string, key: string): EnrollFilters {
  if (field === 'mode') return key === '' ? {} : { delivery_mode_code: [key] };
  if (field === 'class') return key === '' ? { no_class: true } : { class_id: key };
  if (field === 'status') return key === '' ? {} : { status: [key] };
  return {};
}
