// BUOI-03 Điểm danh vận hành: bản nháp từng em (trạng thái trung tâm, lý do liên hệ, ghi chú) và hàm thuần dựng danh sách gửi app.set_attendance_ops.
// Không tự lưu: giữ bản nháp tới khi bấm Lưu. Luật (buổi Đã chốt, danh mục, "Khác" cần ghi chú) do máy chủ quyết; giao diện chỉ chặn sớm ô "Khác" trống ghi chú.
import type { OpsEntry } from './useSessionData';
import type { OpsSheet, OpsStudent } from './sessionTypes';

export type OpsCell = { status: string | null; reason: string | null; note: string };
/** Chỉ các em đã sửa so với máy chủ, và chỉ những ô đã sửa (ô khác theo máy chủ, kể cả ô vừa chép từ giáo viên). */
export type OpsDraft = Record<string, Partial<OpsCell>>;

export const savedCell = (s: OpsStudent): OpsCell => ({
  status: s.ops_status_code,
  reason: s.contact_reason_code,
  note: s.ops_note ?? '',
});

export const cellOf = (s: OpsStudent, draft: OpsDraft): OpsCell => ({
  ...savedCell(s),
  ...draft[s.student_id],
});

/** Sửa một em; sửa về đúng giá trị đã lưu thì bỏ khỏi bản nháp (không còn "chưa lưu"). */
export function patchDraft(draft: OpsDraft, s: OpsStudent, patch: Partial<OpsCell>): OpsDraft {
  const next = { ...draft };
  const saved = savedCell(s);
  const cell = { ...draft[s.student_id], ...patch };
  if (cell.status === saved.status) delete cell.status;
  if (cell.reason === saved.reason) delete cell.reason;
  if (cell.note?.trim() === saved.note.trim()) delete cell.note;
  if (Object.keys(cell).length === 0) delete next[s.student_id];
  else next[s.student_id] = cell;
  return next;
}

/** Danh sách gửi máy chủ: chỉ em đã sửa, mỗi em chỉ ô đã sửa (máy chủ giữ ô không gửi). */
export function buildOpsEntries(students: OpsStudent[], draft: OpsDraft): OpsEntry[] {
  return students
    .filter((s) => s.student_id in draft)
    .map((s) => {
      const { status, reason, note } = draft[s.student_id] ?? {};
      return {
        student_id: s.student_id,
        ...(status !== undefined && { status_code: status }),
        ...(reason !== undefined && { contact_reason_code: reason }),
        ...(note !== undefined && { note: note.trim() === '' ? null : note.trim() }),
      };
    });
}

/** Số em đã có trạng thái trung tâm (kể cả bản nháp). */
export function countOpsMarked(students: OpsStudent[], draft: OpsDraft): number {
  return students.filter((s) => cellOf(s, draft).status !== null).length;
}

/** Em có lý do cần ghi chú (như "Khác") mà ghi chú còn trống: chặn nút Lưu. */
export function missingNote(sheet: OpsSheet, draft: OpsDraft): string[] {
  const needs = new Set(sheet.reasons.filter((r) => r.requires_note).map((r) => r.code));
  return sheet.students
    .filter((s) => {
      const c = cellOf(s, draft);
      return (
        s.student_id in draft && c.reason !== null && needs.has(c.reason) && c.note.trim() === ''
      );
    })
    .map((s) => s.full_name);
}
