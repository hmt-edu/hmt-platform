// Tóm tắt lớp cho hộp Duyệt phiếu Chuyển lớp (CSN07_duyet_chuyen_lop). Dữ liệu do app.get_ticket_task trả ở khoá `transfer`; màn chỉ hiện.
export type ClassSummary = {
  code: string;
  slots: { weekday: number; start_time: string; end_time: string; teacher_name: string | null }[];
} | null;

export type TaskTransfer = {
  from_class: ClassSummary;
  to_class: ClassSummary;
  start_date: string | null;
  hours_left: number;
};

// Thứ trong tuần của khung lớp: 1 = Thứ Hai … 6 = Thứ Bảy, 7 = Chủ nhật.
const WEEKDAY: Record<number, string> = {
  1: 'T2',
  2: 'T3',
  3: 'T4',
  4: 'T5',
  5: 'T6',
  6: 'T7',
  7: 'CN',
};

/** «LC-TOAN-K06 · T3 17:30–19:00, T5 17:30–19:00»; lớp chưa có khung thì chỉ mã lớp, chưa có lớp thì «—». */
export function classLine(c: ClassSummary): string {
  if (c === null) return '—';
  const slots = c.slots
    .map((s) => `${WEEKDAY[s.weekday] ?? s.weekday} ${s.start_time}–${s.end_time}`)
    .join(', ');
  return slots === '' ? c.code : `${c.code} · ${slots}`;
}

/** Giáo viên của lớp (không trùng, giữ thứ tự khung); không có thì chuỗi rỗng. */
export function classTeachers(c: ClassSummary): string {
  if (c === null) return '';
  return [...new Set(c.slots.map((s) => s.teacher_name).filter((n): n is string => !!n))].join(
    ', ',
  );
}
