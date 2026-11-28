import { describe, expect, it } from 'vitest';
import { lastAssignedAt, monthOf, orderStages } from './upsaleStages';
import type { UpsaleEvent } from './upsaleTypes';

const event = (event_type: UpsaleEvent['event_type'], created_at: string): UpsaleEvent => ({
  id: created_at,
  event_type,
  from_stage: null,
  to_stage: null,
  note: null,
  created_at,
  created_by_name: null,
});

describe('upsaleStages (TT-02)', () => {
  it('«Không tái tục» (L5) đứng cuối thanh giai đoạn', () => {
    const stages = ['L1', 'L5', 'L8'].map((value) => ({ value }));
    expect(orderStages(stages).map((s) => s.value)).toEqual(['L1', 'L8', 'L5']);
  });
  it('Campaign là tháng/năm của ngày hết giờ dự kiến, chưa có ngày thì trống', () => {
    expect(monthOf('2027-03-15')).toBe('03/2027');
    expect(monthOf(null)).toBe('');
  });
  it('Ngày giao lấy lần giao mới nhất; chưa giao thì không có', () => {
    expect(lastAssignedAt([event('GIAO', 'a'), event('GIAO', 'b'), event('TAO', 'c')])).toBe('b');
    expect(lastAssignedAt([event('TAO', 'a')])).toBeNull();
  });
});
