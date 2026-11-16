import { describe, expect, it } from 'vitest';
import {
  EMPTY_TICKET_DRAFT,
  buildCreatePayload,
  groupsOf,
  subgroupsOf,
  validateTicketDraft,
} from './ticketCreate';
import type { TicketCategory } from './useTicketData';

const cat = (over: Partial<TicketCategory>): TicketCategory => ({
  code: 'C',
  name: 'C',
  kind: 'SUBGROUP',
  parent_code: 'G',
  ticket_type: 'DN',
  default_priority: null,
  requires_student: false,
  ...over,
});

describe('Tạo ticket: kiểm biểu mẫu (AS-02, AS-10)', () => {
  it('trống thì báo đủ ô bắt buộc', () => {
    const e = validateTicketDraft(EMPTY_TICKET_DRAFT, null);
    expect(Object.keys(e).sort()).toEqual([
      'categoryCode',
      'channel',
      'description',
      'parentId',
      'title',
    ]);
  });
  it('nhóm con cần học sinh thì chặn khi chưa chọn', () => {
    const d = {
      ...EMPTY_TICKET_DRAFT,
      title: 'a',
      channel: 'x',
      parentId: 'p',
      categoryCode: 'C',
      description: 'd',
    };
    expect(validateTicketDraft(d, cat({ requires_student: true })).studentId).toBeDefined();
    expect(validateTicketDraft({ ...d, studentId: 's' }, cat({ requires_student: true }))).toEqual(
      {},
    );
  });
  it('nhóm theo loại; nhóm con theo nhóm cha', () => {
    const all = [
      cat({ code: 'G', kind: 'GROUP', parent_code: null }),
      cat({ code: 'H', kind: 'GROUP', parent_code: null, ticket_type: 'KN' }),
      cat({ code: 'S1' }),
    ];
    expect(groupsOf(all, 'DN').map((c) => c.code)).toEqual(['G']);
    expect(subgroupsOf(all, 'G').map((c) => c.code)).toEqual(['S1']);
  });
  it('payload bỏ học sinh và mức độ khi để trống', () => {
    const p = buildCreatePayload({ ...EMPTY_TICKET_DRAFT, title: ' T ', description: ' D ' });
    expect(p).toMatchObject({ title: 'T', description: 'D' });
    expect(p).not.toHaveProperty('student_id');
    expect(p).not.toHaveProperty('priority_code');
  });
});
