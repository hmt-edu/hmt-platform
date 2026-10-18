import { describe, expect, it } from 'vitest';
import { formatVnTime, vnDayBounds } from './vnDay';

describe('ranh giới "hôm nay" theo giờ Việt Nam (Asia/Ho_Chi_Minh)', () => {
  it('01:30 sáng 18/10 giờ Việt Nam (còn là 17/10 ở UTC) vẫn là ngày 18/10', () => {
    const b = vnDayBounds(new Date('2026-10-17T18:30:00Z'));
    expect(b.dateKey).toBe('2026-10-18');
    expect(b.start.toISOString()).toBe('2026-10-17T17:00:00.000Z');
    expect(b.end.toISOString()).toBe('2026-10-18T17:00:00.000Z');
  });

  it('23:59:59 giờ Việt Nam vẫn thuộc ngày đó; 00:00:00 là sang ngày mới', () => {
    expect(vnDayBounds(new Date('2026-10-18T16:59:59Z')).dateKey).toBe('2026-10-18');
    expect(vnDayBounds(new Date('2026-10-18T17:00:00Z')).dateKey).toBe('2026-10-19');
  });

  it('cuối tháng: ngày mai là mùng 1 tháng sau', () => {
    const b = vnDayBounds(new Date('2026-10-31T10:00:00Z'));
    expect(b.dateKey).toBe('2026-10-31');
    expect(b.end.toISOString()).toBe('2026-10-31T17:00:00.000Z');
  });

  it('giờ hiển thị của lịch hẹn theo giờ Việt Nam', () => {
    expect(formatVnTime('2026-10-18T02:00:00Z')).toBe('09:00');
    expect(formatVnTime('2026-10-17T17:00:00Z')).toBe('00:00');
  });
});
