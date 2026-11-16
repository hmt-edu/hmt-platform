import { describe, expect, it } from 'vitest';
import { taskTimeline } from './phieuTimeline';
import type { TaskEvent } from './phieuTypes';

const ev = (over: Partial<TaskEvent>): TaskEvent => ({
  id: 'e',
  event_type: 'TAO',
  from_status: null,
  to_status: null,
  note: null,
  created_at: '2026-11-16T01:00:00Z',
  created_by_name: 'Lan',
  ...over,
});

describe('Phiếu nghiệp vụ: dòng thời gian (CSN-06)', () => {
  it('mới nhất lên đầu; ghi trạng thái cũ và mới; kèm ghi chú', () => {
    const [last, first] = taskTimeline([
      ev({ id: 'a' }),
      ev({
        id: 'b',
        event_type: 'DUYET',
        from_status: 'CHO_DUYET',
        to_status: 'DA_DUYET',
        note: 'Đồng ý',
      }),
    ]);
    expect(first?.id).toBe('a');
    expect(last).toMatchObject({ kind: 'system', text: 'Duyệt. Chờ duyệt → Đã duyệt. Đồng ý' });
  });
  it('không có người tạo thì ghi Hệ thống; duyệt cấp giữa (cùng trạng thái) không ghi mũi tên', () => {
    const [e] = taskTimeline([
      ev({
        event_type: 'DUYET',
        from_status: 'CHO_DUYET',
        to_status: 'CHO_DUYET',
        created_by_name: null,
      }),
    ]);
    expect(e).toMatchObject({ author: 'Hệ thống', text: 'Duyệt.' });
  });
});
