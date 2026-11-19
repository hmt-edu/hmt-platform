// QT-16 Hồ sơ giáo viên, trợ giảng: kiểu dữ liệu, bộ lọc và kiểm nhập thuần (có kiểm thử). Máy chủ (app.save_teaching_profile) kiểm lại mọi luật.
// Hồ sơ chỉ là thông tin tham khảo khi xếp lịch (R-LOP-08, R-LOP-10), không chặn việc chọn giáo viên khi tạo lớp.
import type { ListState } from '../../list/types';

export type TeachingKind = 'GV' | 'TG';

export type TeachingProfile = {
  id: string;
  user_id: string;
  name: string;
  staff_code: string | null;
  login_name: string;
  kind: TeachingKind;
  is_active: boolean;
  note: string | null;
  subject_codes: string[];
  grade_codes: string[];
  branch_ids: string[];
  subject_names: string[];
  grade_names: string[];
  branch_codes: string[];
};
export type TeachingPage = { total: number; rows: TeachingProfile[] };
export type TeachingCandidate = {
  user_id: string;
  name: string;
  staff_code: string | null;
  kind: TeachingKind;
};
export type TeachingFilters = Record<string, unknown>;

export const KIND_LABEL: Record<TeachingKind, string> = { GV: 'Giáo viên', TG: 'Trợ giảng' };

export const EMPTY_TEACHING_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

/** Đổi trạng thái màn danh sách thành bộ lọc app.list_teaching_profiles. Lọc nhanh «Loại» và «Tình trạng»; điều kiện nâng cao: môn, khối, cơ sở (là). */
export function buildTeachingFilters(state: ListState): TeachingFilters {
  const filters: TeachingFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.search = q;
  const kind = state.quick.kind ?? [];
  if (kind.length === 1) filters.kind = kind[0];
  const active = state.quick.active ?? [];
  if (active.length === 1) filters.active = active[0] === 'DANG_DAY';
  for (const cond of state.conditions) {
    const value = (Array.isArray(cond.value) ? cond.value[0] : cond.value)?.trim() ?? '';
    if (value === '' || cond.op !== 'eq') continue;
    if (cond.field === 'subject') filters.subject = value;
    else if (cond.field === 'grade') filters.grade = value;
    else if (cond.field === 'branch') filters.branch_id = value;
  }
  return filters;
}

/** Đổi/bỏ một mã trong danh sách chọn nhiều (ô tích môn, khối, cơ sở). */
export function toggleCode(list: string[], code: string, on: boolean): string[] {
  const without = list.filter((c) => c !== code);
  return on ? [...without, code] : without;
}

/** Ghi chú tối đa độ dài hợp lý; trả câu lỗi hoặc null. Môn, khối, cơ sở có thể để trống (hồ sơ mới chưa biết). */
export const NOTE_MAX_LENGTH = 500; // allow-number: giới hạn độ dài ghi chú ở giao diện
export function noteError(note: string): string | null {
  return note.trim().length > NOTE_MAX_LENGTH ? `Ghi chú tối đa ${NOTE_MAX_LENGTH} ký tự.` : null;
}

/** Dữ liệu gửi app.save_teaching_profile. */
export function profilePayload(input: {
  id?: string;
  userId?: string;
  subjects: string[];
  grades: string[];
  branchIds: string[];
  note: string;
}): Record<string, unknown> {
  return {
    ...(input.id ? { id: input.id } : {}),
    ...(input.userId ? { user_id: input.userId } : {}),
    subject_codes: input.subjects,
    grade_codes: input.grades,
    branch_ids: input.branchIds,
    note: input.note.trim() === '' ? null : input.note.trim(),
  };
}
