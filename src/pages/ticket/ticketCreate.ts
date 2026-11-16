// Luật nhập biểu mẫu tạo ticket (CSN-03 Tạo mới): kiểm trước khi gọi app.create_ticket. Luật chặn thật nằm ở hàm DB (AS-02, AS-10).
import type { TicketCategory } from './useTicketData';

export type TicketDraft = {
  type: 'DN' | 'KN';
  title: string;
  channel: string;
  parentId: string;
  groupCode: string;
  categoryCode: string;
  description: string;
  studentId: string;
  priority: string;
};

export const EMPTY_TICKET_DRAFT: TicketDraft = {
  type: 'DN',
  title: '',
  channel: '',
  parentId: '',
  groupCode: '',
  categoryCode: '',
  description: '',
  studentId: '',
  priority: '',
};

export type TicketErrors = Partial<Record<keyof TicketDraft, string>>;

export function validateTicketDraft(
  draft: TicketDraft,
  category: TicketCategory | null,
): TicketErrors {
  const errors: TicketErrors = {};
  if (draft.title.trim() === '') errors.title = 'Nhập tiêu đề.';
  if (draft.channel === '') errors.channel = 'Chọn kênh tiếp nhận.';
  if (draft.parentId === '') errors.parentId = 'Chọn phụ huynh (người gửi).';
  if (draft.categoryCode === '') errors.categoryCode = 'Chọn nhóm con.';
  if (draft.description.trim() === '') errors.description = 'Nhập mô tả.';
  if (category?.requires_student && draft.studentId === '')
    errors.studentId = 'Nhóm con này bắt buộc chọn học sinh.';
  return errors;
}

/** Nhóm cha của loại ticket đang chọn, và nhóm con của một nhóm. */
export const groupsOf = (all: TicketCategory[], type: string) =>
  all.filter((c) => c.kind === 'GROUP' && c.ticket_type === type);
export const subgroupsOf = (all: TicketCategory[], group: string) =>
  all.filter((c) => c.kind === 'SUBGROUP' && c.parent_code === group);

export function buildCreatePayload(draft: TicketDraft) {
  return {
    ticket_type: draft.type,
    title: draft.title.trim(),
    description: draft.description.trim(),
    channel_code: draft.channel,
    category_code: draft.categoryCode,
    parent_id: draft.parentId,
    ...(draft.studentId !== '' && { student_id: draft.studentId }),
    ...(draft.priority !== '' && { priority_code: draft.priority }),
  };
}
