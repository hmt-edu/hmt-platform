// Hàm thuần của cụm Buổi A: đổi trạng thái màn danh sách (ListState) thành bộ lọc gửi máy chủ, nhãn lớp, nhãn lý do loại khỏi danh sách.
// Cùng nhóm lọc nhanh là HOẶC, khác nhóm là VÀ (R-CRM-07). Lọc, sắp xếp, phân trang làm ở máy chủ.
import { datePresetRange } from '../../lib/dateRange';
import type { Condition, ListState } from '../../list/types';
import type { SortState } from '../../ui/Data';
import type { SessionFilters } from './useSessionData';

/** Mặc định BUOI-01: ngày hôm nay (R-BUOI-02, canvas BUOI01 "mặc định hôm nay"). */
export const EMPTY_SESSION_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: 'session_date',
  datePreset: 'today',
};

export const EMPTY_ABSENT_STATE: ListState = { ...EMPTY_SESSION_STATE, datePreset: '' };

function valuesOf(cond: Condition): string[] {
  return (Array.isArray(cond.value) ? cond.value : [cond.value])
    .map((v) => v.trim())
    .filter(Boolean);
}

const pad2 = (n: number) => String(n).padStart(2, '0'); // allow-number: độ rộng hai chữ số của ngày, tháng
/** yyyy-mm-dd theo ngày lịch của Date (datePresetRange đã dựng Date theo ngày Việt Nam). */
export function ymd(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

/** `statusCodes`: mã tình trạng hợp lệ (từ danh mục); mã lạ bị bỏ để không gửi lên máy chủ. */
export function buildSessionFilters(
  state: ListState,
  statusCodes: string[],
  now: Date = new Date(),
): SessionFilters {
  const filters: SessionFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const status = new Set<string>((state.quick.status ?? []).filter((v) => statusCodes.includes(v)));
  const range = datePresetRange(state.datePreset, now);
  if (range) {
    filters.date_from = ymd(range.from);
    filters.date_to = ymd(range.to);
  }
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'status') {
      for (const v of values) if (statusCodes.includes(v)) status.add(v);
    } else if (cond.field === 'branch' && cond.op === 'eq') {
      filters.branch_id = values[0];
    } else if (cond.field === 'session_date' && cond.op === 'from') {
      filters.date_from = values[0];
    } else if (cond.field === 'session_date' && cond.op === 'to') {
      filters.date_to = values[0];
    }
  }
  if (status.size > 0) filters.status = [...status];
  return filters;
}

/** BUOI-11: tìm theo tên học sinh, mã lớp; lọc nhanh Vắng / Chưa đến; cơ sở. */
export function buildAbsentFilters(state: ListState): SessionFilters {
  const filters: SessionFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const kinds = new Set<string>(state.quick.kind ?? []);
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = values[0];
    else if (cond.field === 'kind') for (const v of values) kinds.add(v);
  }
  // Chọn đủ cả hai loại = không lọc.
  if (kinds.size === 1) filters.kind = [...kinds][0];
  return filters;
}

/** Sắp xếp BUOI-01: chỉ theo giờ (tăng dần mặc định). */
export function sessionSortParam(sort: SortState): string {
  return sort?.key === 'time' && sort.direction === 'desc' ? 'time_desc' : 'time_asc';
}

/** Nhãn lớp "môn + mã lớp", giống cụm Lớp (Chat 10/11). */
export const classLabel = (subjectName: string | null, classCode: string) =>
  subjectName ? `${subjectName} · ${classCode}` : classCode;

/** "Buổi N" hoặc "—" khi buổi chưa đánh số. */
export const sessionNoLabel = (n: number | null) => (n === null ? '—' : `Buổi ${n}`);

/** Lý do em không vào danh sách buổi (R-GIO-02). Mã kỹ thuật cố định của D1c. */
export const EXCLUDED_LABEL: Record<string, string> = {
  CHUA_TOI_NGAY_VAO: 'Chưa tới ngày vào lớp',
  BAO_LUU: 'Đang bảo lưu',
  KET_THUC: 'Đã kết thúc ghi danh',
  HET_GIO: 'Hết giờ',
};

const MINUTES_PER_HOUR = 60; // allow-number: số phút trong một giờ

/** Hạn hoàn tất của giáo viên (BUOI-12): "Quá hạn 8 giờ" hoặc "Còn 2 giờ"; dưới một giờ thì nói phút. Số phút âm = đã quá hạn. */
export function deadlineLabel(minutesLeft: number): string {
  const abs = Math.abs(minutesLeft);
  const text = abs < MINUTES_PER_HOUR ? `${abs} phút` : `${Math.floor(abs / MINUTES_PER_HOUR)} giờ`;
  return minutesLeft < 0 ? `Quá hạn ${text}` : `Còn ${text}`;
}

/** Lý do huỷ theo bên huỷ: mã TT_ của trung tâm, HS_ của học sinh (quy ước danh mục SESSION_CANCEL_REASON, cùng quy ước với app.cancel_session). */
export function cancelReasonOptions<T extends { value: string }>(all: T[], who: 'TT' | 'HS'): T[] {
  const prefix = who === 'TT' ? 'TT_' : 'HS_';
  return all.filter((o) => o.value.startsWith(prefix));
}

/** Đối số dời buổi; null khi thiếu hoặc giờ kết thúc không sau giờ bắt đầu (máy chủ vẫn kiểm lại). */
export function moveArgsOf(
  date: string,
  start: string,
  end: string,
  roomId: string | null,
): { date: string; start: string; end: string; roomId: string | null } | null {
  if (date === '' || start === '' || end === '' || end <= start) return null;
  return { date, start, end, roomId };
}

/** BUOI-12: tìm theo mã lớp; lọc nhanh Quá hạn / Còn hạn (chọn cả hai = không lọc); cơ sở. */
export function buildPendingFilters(state: ListState): SessionFilters {
  const filters: SessionFilters = {};
  const q = state.search.trim();
  if (q !== '') filters.q = q;
  const kinds = new Set<string>(state.quick.kind ?? []);
  for (const cond of state.conditions) {
    const values = valuesOf(cond);
    if (values.length === 0) continue;
    if (cond.field === 'branch' && cond.op === 'eq') filters.branch_id = values[0];
    else if (cond.field === 'kind') for (const v of values) kinds.add(v);
  }
  if (kinds.size === 1) filters.kind = [...kinds][0];
  return filters;
}

/** Trường nhóm của giao diện → tên trường máy chủ (session_group_counts). */
export const SESSION_GROUP_FIELD_OF: Record<string, string> = {
  date: 'date',
  class: 'class',
  branch: 'branch',
  teacher: 'teacher',
  type: 'type',
  status: 'status',
};

/** Bộ lọc của một nhóm Group By để mở dòng của nhóm đó (khoá trống: nhóm «Chưa có»; giáo viên trống = chưa có giáo viên). */
export function sessionGroupFilter(field: string, key: string): SessionFilters {
  if (field === 'date') return key === '' ? {} : { date_from: key, date_to: key };
  if (field === 'class') return key === '' ? {} : { class_id: key };
  if (field === 'branch') return key === '' ? {} : { branch_id: key };
  if (field === 'teacher') return key === '' ? { no_teacher: true } : { teacher_id: key };
  if (field === 'type') return key === '' ? {} : { type_code: [key] };
  if (field === 'status') return key === '' ? {} : { status: [key] };
  return {};
}
