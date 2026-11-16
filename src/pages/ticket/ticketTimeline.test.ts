import { describe, expect, it } from 'vitest';
import { ticketTimeline } from './ticketTimeline';
import type { TicketEvent } from './ticketTypes';

const ev = (over: Partial<TicketEvent>): TicketEvent => ({
  id: 'e',
  event_type: 'TAO',
  from_status: null,
  to_status: null,
  note: null,
  created_at: '2026-11-15T01:00:00Z',
  created_by_name: 'Lan',
  ...over,
});
const name = (c: string | null) => c ?? '';

describe('ticketTimeline (dòng thời gian CSN-03)', () => {
  it('mới nhất lên đầu', () => {
    const list = ticketTimeline([ev({ id: 'a' }), ev({ id: 'b', event_type: 'GHI_CHU' })], name);
    expect(list.map((e) => e.id)).toEqual(['b', 'a']);
  });
  it('ghi chú tay là mục ghi chú; sự kiện khác là mục hệ thống', () => {
    const [note, sys] = ticketTimeline(
      [
        ev({ id: 'a', event_type: 'DOI_TRANG_THAI', from_status: 'MOI', to_status: 'DA_GIAO' }),
        ev({ id: 'b', event_type: 'GHI_CHU', note: 'Đã gọi' }),
      ],
      name,
    );
    expect(note).toMatchObject({ kind: 'note', body: 'Đã gọi' });
    expect(sys).toMatchObject({ kind: 'system', text: 'Đổi trạng thái: MOI → DA_GIAO.' });
  });
  it('người tạo trống thì ghi Hệ thống', () => {
    const [e] = ticketTimeline([ev({ created_by_name: null })], name);
    expect(e?.author).toBe('Hệ thống');
  });
});
