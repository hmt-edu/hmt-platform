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
