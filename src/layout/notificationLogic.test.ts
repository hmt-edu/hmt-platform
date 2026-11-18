import { describe, expect, it } from 'vitest';
import { notificationPath, timeAgo } from './notificationLogic';

describe('CHUNG-12 thông báo', () => {
  it('đường dẫn mở bản ghi', () => {
    expect(notificationPath({ entity_type: 'OPPORTUNITY', entity_id: 'a' })).toBe('/crm/co-hoi/a');
    expect(notificationPath({ entity_type: 'SALES_ORDER', entity_id: 'b' })).toBe(
      '/crm/don-hang/b',
    );
    expect(notificationPath({ entity_type: 'ROOM', entity_id: 'c' })).toBeNull();
    expect(notificationPath({ entity_type: null, entity_id: null })).toBeNull();
  });
  it('thời gian tương đối', () => {
    const now = new Date('2026-11-18T10:00:00Z');
    expect(timeAgo('2026-11-18T09:59:40Z', now)).toBe('Vừa xong');
    expect(timeAgo('2026-11-18T09:50:00Z', now)).toBe('10 phút trước');
    expect(timeAgo('2026-11-18T08:00:00Z', now)).toBe('2 giờ trước');
    expect(timeAgo('2026-11-15T10:00:00Z', now)).toBe('3 ngày trước');
  });
});
