import { describe, expect, it } from 'vitest';
import { cardTag, cardTitle, dueText, isOverdue, itemLink } from './workLogic';
import type { WorkCard, WorkItem } from './workTypes';

const now = new Date('2026-11-26T03:00:00Z'); // 10:00 giờ Việt Nam

const item = (over: Partial<WorkItem>): WorkItem => ({
  signal: 'APPOINTMENT',
  entity_type: 'APPOINTMENT',
  entity_id: 'x',
  urgency: 'TODAY',
  title: 'Gọi tư vấn',
  why: 'Lịch hẹn sắp tới giờ',
  due_at: '2026-11-26T09:00:00Z',
  owner_name: null,
  branch_code: 'CS1',
  ...over,
});

const card = (over: Partial<WorkCard>): WorkCard => ({
  group_key: 'k',
  parent_id: null,
  parent_name: null,
  phone: null,
  urgency: 'TODAY',
  items: [item({})],
  ...over,
});

describe('Việc của tôi', () => {
  it('mỗi loại việc mở đúng màn; việc chờ duyệt đi qua màn chuyên', () => {
    expect(itemLink(item({ signal: 'TEST' })).to).toBe('/crm/phieu-kiem-tra/x');
    expect(itemLink(item({ signal: 'APPROVAL' })).to).toBe('/crm/viec-cho-duyet');
    expect(itemLink(item({ signal: 'RENEWAL' })).to).toBe('/crm/tai-tuc/x');
  });

  it('buổi chưa điểm danh: có quyền sửa điểm danh thì mở màn điểm danh vận hành, không thì mở buổi', () => {
    const pending = item({ signal: 'SESSION_NO_ATTENDANCE' });
    expect(itemLink(pending, true)).toEqual({ to: '/crm/diem-danh/buoi/x', label: 'Mở điểm danh' });
    expect(itemLink(pending)).toEqual({ to: '/crm/buoi-hoc/x', label: 'Mở buổi' });
  });

  it('chữ hạn: hôm nay chỉ ghi giờ, ngày khác ghi cả ngày', () => {
    expect(dueText(item({}), now)).toBe('Hẹn 16:00');
    expect(dueText(item({ due_at: '2026-11-24T07:00:00Z' }), now)).toContain('24/11/2026');
    expect(dueText(item({ signal: 'RENEWAL' }), now)).toBeNull();
  });

  it('việc chờ duyệt không bị gắn Quá hạn dù mốc ở quá khứ', () => {
    const past = '2026-11-20T00:00:00Z';
    expect(isOverdue(item({ due_at: past }), now)).toBe(true);
    expect(isOverdue(item({ signal: 'APPROVAL', due_at: past }), now)).toBe(false);
    expect(cardTag(card({ items: [item({ due_at: past })] }), now).label).toBe('Quá hạn');
    expect(cardTag(card({}), now).label).toBe('Hôm nay');
  });

  it('tiêu đề thẻ: phụ huynh, số điện thoại, rồi tên loại việc', () => {
    expect(cardTitle(card({ parent_name: 'Phụ huynh giả', phone: '0900000000' }))).toBe(
      'Phụ huynh giả',
    );
    expect(cardTitle(card({ phone: '0900000000' }))).toBe('0900000000');
    expect(cardTitle(card({ items: [item({ signal: 'SESSION_PENDING' })] }))).toBe('Buổi học');
  });
});

describe('ticket và công nợ quá hạn', () => {
  it('mở đúng bản ghi, ghi hạn; công nợ chỉ ghi ngày; ticket giáo viên không phụ huynh có tên thẻ riêng', () => {
    const ticket = item({
      signal: 'TICKET_OVERDUE',
      entity_id: 't1',
      due_at: '2026-11-20T03:00:00Z',
    });
    const debt = item({ signal: 'DEBT_OVERDUE', entity_id: 'o1', due_at: '2026-11-19T17:00:00Z' });
    expect(itemLink(ticket)).toEqual({ to: '/crm/ticket/t1', label: 'Mở ticket' });
    expect(itemLink(debt)).toEqual({ to: '/crm/don-hang/o1', label: 'Mở đơn' });
    const now = new Date('2026-11-27T05:00:00Z');
    expect(dueText(ticket, now)).toMatch(/^Hạn 20\/11\/2026/);
    expect(dueText(debt, now)).toBe('Hạn 20/11/2026');
    expect(isOverdue(debt, now)).toBe(true);
    expect(cardTitle(card({ items: [ticket] }))).toBe('Ticket');
  });
});
