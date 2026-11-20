// LOP-09 Học sinh của lớp (danh sách K03): kiểu dữ liệu, bộ lọc gửi app.list_class_students, sắp xếp, gọi dữ liệu. Hàm thuần có kiểm thử.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { ListState } from '../../list/types';

export type ClassStudentRow = {
  id: string;
  student_id: string;
  student_code: string;
  full_name: string;
  enrollment_id: string;
  enrollment_code: string;
  enrollment_status: string;
  branch_code: string | null;
  delivery_mode_code: string | null;
  start_date: string;
  end_date: string | null;
  end_reason: string | null;
  hours_left: number;
};
export type ClassStudentPage = { total: number; rows: ClassStudentRow[] };
export type ClassStudentFilters = Record<string, unknown>;

export const EMPTY_CLASS_STUDENT_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

/** Tìm theo tên, mã học sinh, mã ghi danh; nhóm lọc nhanh «Tình trạng» (đang học, đã rời) và «Hình thức học» (cùng nhóm là HOẶC). */
export function buildClassStudentFilters(state: ListState): ClassStudentFilters {
  const filters: ClassStudentFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.search = q;
  const have = state.quick.state ?? [];
  if (have.length > 0) filters.state = have;
  const delivery = state.quick.delivery ?? [];
  if (delivery.length > 0) filters.delivery = delivery;
  return filters;
}

export function classStudentSortParam(
  key: string | null,
  direction: 'asc' | 'desc' | null,
): string {
  if (key === 'start' && direction === 'desc') return 'start_desc';
  if (key === 'hours' && direction === 'asc') return 'hours_asc';
  return 'name_asc';
}

export function useClassStudentPage(
  classId: string | undefined,
  filters: ClassStudentFilters,
  sort: string,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['class-students', classId, filters, sort, offset, limit],
    enabled: classId !== undefined && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ClassStudentPage>(supabase, 'list_class_students', {
        p_class_id: classId,
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Tên lớp ở tiêu đề LOP-09 (canvas LOP09): «Đại số 9 · cơ bản A»; Lớp riêng không có trình độ thì chỉ «Lớp riêng». */
export function classTitleLabel(c: {
  subject_name: string | null;
  subject_code: string;
  grade_code: string;
  class_type_name: string | null;
  level_name: string | null;
}): string {
  const grade = c.grade_code.replace(/^K0?/, '');
  const kind = [c.class_type_name?.toLowerCase(), c.level_name].filter(Boolean).join(' ');
  return [`${c.subject_name ?? c.subject_code} ${grade}`, kind].filter((x) => x.trim()).join(' · ');
}
