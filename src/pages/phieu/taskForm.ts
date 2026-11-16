// Biểu mẫu tạo phiếu Cập nhật hồ sơ từ chi tiết ticket: kiểm sớm và dựng dữ liệu gửi app.create_ticket_task. Luật chặn thật ở DB (migration 226).
export type TaskFieldDef = { entity: 'PARENT' | 'STUDENT'; field_code: string; label: string };
export type TaskDraft = {
  entity: 'PARENT' | 'STUDENT';
  values: Record<string, string>;
  reason: string;
};
export type TaskErrors = Partial<Record<'values' | 'reason', string>>;

export const EMPTY_TASK_DRAFT: TaskDraft = { entity: 'STUDENT', values: {}, reason: '' };

/** Chỉ các ô đã gõ (không rỗng) là thay đổi; ô để trống nghĩa là giữ nguyên. */
export const changesOf = (draft: TaskDraft, fields: TaskFieldDef[]): Record<string, string> =>
  Object.fromEntries(
    fields
      .filter((f) => f.entity === draft.entity)
      .map((f) => [f.field_code, (draft.values[f.field_code] ?? '').trim()] as const)
      .filter(([, v]) => v !== ''),
  );

export function validateTaskDraft(
  draft: TaskDraft,
  fields: TaskFieldDef[],
  hasStudent: boolean,
): TaskErrors {
  const errors: TaskErrors = {};
  if (draft.entity === 'STUDENT' && !hasStudent)
    errors.values = 'Ticket chưa gắn học sinh nên chưa sửa hồ sơ học sinh được.';
  else if (Object.keys(changesOf(draft, fields)).length === 0)
    errors.values = 'Nhập giá trị mới cho ít nhất một trường.';
  if (draft.reason.trim() === '') errors.reason = 'Nhập lý do của phiếu.';
  return errors;
}

export const buildTaskPayload = (draft: TaskDraft, fields: TaskFieldDef[]) => ({
  entity: draft.entity,
  changes: changesOf(draft, fields),
});
