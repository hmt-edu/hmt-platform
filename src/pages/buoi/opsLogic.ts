// BUOI-03 Điểm danh vận hành: bản nháp từng em (trạng thái trung tâm, lý do liên hệ, ghi chú) và hàm thuần dựng danh sách gửi app.set_attendance_ops.
// Không tự lưu: giữ bản nháp tới khi bấm Lưu. Luật (buổi Đã chốt, danh mục, "Khác" cần ghi chú) do máy chủ quyết; giao diện chỉ chặn sớm ô "Khác" trống ghi chú.
import type { OpsEntry } from './useSessionData';
import type { OpsSheet, OpsStudent } from './sessionTypes';

export type OpsCell = { status: string | null; reason: string | null; note: string };
/** Chỉ các em đã sửa so với máy chủ. */
export type OpsDraft = Record<string, OpsCell>;

export const savedCell = (s: OpsStudent): OpsCell => ({
  status: s.ops_status_code,
  reason: s.contact_reason_code,
  note: s.ops_note ?? '',
});

export const cellOf = (s: OpsStudent, draft: OpsDraft): OpsCell =>
  draft[s.student_id] ?? savedCell(s);

const same = (a: OpsCell, b: OpsCell) =>
  a.status === b.status && a.reason === b.reason && a.note.trim() === b.note.trim();

/** Sửa một em; sửa về đúng giá trị đã lưu thì bỏ khỏi bản nháp (không còn "chưa lưu"). */
export function patchDraft(draft: OpsDraft, s: OpsStudent, patch: Partial<OpsCell>): OpsDraft {
  const next = { ...draft };
  const cell = { ...cellOf(s, draft), ...patch };
  if (same(cell, savedCell(s))) delete next[s.student_id];
  else next[s.student_id] = cell;
  return next;
}

/** Danh sách gửi máy chủ: chỉ em đã sửa. */
export function buildOpsEntries(students: OpsStudent[], draft: OpsDraft): OpsEntry[] {
  return students
    .filter((s) => s.student_id in draft)
    .map((s) => {
      const c = cellOf(s, draft);
      return {
        student_id: s.student_id,
        status_code: c.status,
        contact_reason_code: c.reason,
        note: c.note.trim() === '' ? null : c.note.trim(),
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
