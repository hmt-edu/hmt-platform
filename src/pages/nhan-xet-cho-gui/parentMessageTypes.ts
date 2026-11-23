// CS-16 Nhận xét chờ gửi phụ huynh: kiểu dữ liệu khớp app.list_parent_messages (migration 622) và hàm thuần dựng bộ lọc, ảnh xuất.
import type { ListState } from '../../list/types';
import type { ExportCard } from '../gv/exportCard';

export type ParentMessageRow = {
  attendance_id: string;
  student_name: string;
  class_code: string;
  session_no: number | null;
  session_date: string;
  parent_name: string;
  message: string;
  sent: boolean;
  sent_at: string | null;
};
export type ParentMessagePage = {
  total: number;
  counts: { cho_gui: number; da_gui: number };
  rows: ParentMessageRow[];
};
export type ParentMessageFilters = {
  status?: 'CHO_GUI' | 'DA_GUI';
  q?: string;
  branch_id?: string;
};

export const EMPTY_PARENT_MESSAGE_STATE: ListState = {
  search: '',
  quick: { status: ['CHO_GUI'] },
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

/** Trạng thái màn → bộ lọc gửi máy chủ. Chip Chờ gửi / Đã gửi chỉ nhận một giá trị; mặc định Chờ gửi. */
export function buildParentMessageFilters(state: ListState): ParentMessageFilters {
  const f: ParentMessageFilters = {};
  const s = state.quick.status ?? [];
  f.status = s.length === 1 && s[0] === 'DA_GUI' ? 'DA_GUI' : 'CHO_GUI';
  const q = state.search.trim();
  if (q !== '') f.q = q;
  for (const c of state.conditions) {
    const v = (Array.isArray(c.value) ? c.value[0] : c.value)?.trim() ?? '';
    if (v !== '' && c.field === 'branch' && c.op === 'eq') f.branch_id = v;
  }
  return f;
}

/** «Buổi 9 · 10/11» (canvas CSN10); thiếu số buổi thì chỉ ngày. */
export function sessionLabel(no: number | null, isoDate: string): string {
  const d = `${isoDate.slice(8, 10)}/${isoDate.slice(5, 7)}`; // allow-number: cắt chuỗi yyyy-mm-dd
  return no ? `Buổi ${no} · ${d}` : d;
}

/** Cắt lời nhắn một dòng bằng «…» (canvas CSN10); giữ nguyên nếu ngắn. */
export function clipMessage(text: string, max: number): string {
  const t = text.replace(/\s+/g, ' ').trim();
  return t.length <= max ? t : `${t.slice(0, max).trimEnd()}…`;
}

/** Phiếu ảnh của lời nhắn (xuất bằng khuôn GV07X, chỉ lời nhắn; điểm trung bình không in, R-V2-39). */
export function messageCard(row: ParentMessageRow): ExportCard {
  return {
    kind: 'THUONG',
    title: `${row.class_code} · ${sessionLabel(row.session_no, row.session_date)}`,
    subtitle: `Gửi ${row.parent_name}`,
    studentName: row.student_name,
    sections: [],
    message: row.message,
    improvement: null,
  };
}
