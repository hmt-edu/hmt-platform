import { describe, expect, it } from 'vitest';
import { assigneeInitials } from './ticketInitials';

describe('assigneeInitials (thẻ Kanban CSN-02)', () => {
  it('họ và tên: chữ đầu của họ và của tên', () => {
    expect(assigneeInitials('Nguyễn Thị Lan')).toBe('NL');
  });
  it('một từ: chữ đầu; chưa giao: dấu hỏi', () => {
    expect(assigneeInitials('Hùng')).toBe('H');
    expect(assigneeInitials(null)).toBe('?');
    expect(assigneeInitials('  ')).toBe('?');
  });
});
