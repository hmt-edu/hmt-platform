import { describe, expect, it } from 'vitest';
import { combineVn, parseTime, quickDays, vnToday } from './appointmentTime';

const labels = (now: string) =>
  quickDays(new Date(now)).map((d) => `${d.label}|${d.date.getDate()}/${d.date.getMonth() + 1}`);

describe('chọn nhanh ngày (theo ngày lịch Việt Nam)', () => {
  it('thứ Tư 14/10/2026: Hôm nay, Ngày mai, Ngày kia, T7, CN, T2, Tuần sau (đúng bản vẽ TS-13)', () => {
    // 10:00 giờ Việt Nam thứ Tư 14/10/2026.
    expect(labels('2026-10-14T03:00:00Z')).toEqual([
      'Hôm nay|14/10',
      'Ngày mai|15/10',
      'Ngày kia|16/10',
      'T7 17/10|17/10',
      'CN 18/10|18/10',
      'T2 19/10|19/10',
      'Tuần sau|21/10',
    ]);
  });
  it('00:30 sáng giờ Việt Nam (còn là hôm trước ở UTC) vẫn tính theo ngày Việt Nam', () => {
    const today = vnToday(new Date('2026-10-13T17:30:00Z'));
    expect([today.getFullYear(), today.getMonth() + 1, today.getDate()]).toEqual([2026, 10, 14]);
  });
  it('thứ Sáu: ngày mai đã là T7 nên T7, CN, T2 chọn nhanh là của tuần sau, không trùng ngày', () => {
    const out = labels('2026-10-16T03:00:00Z');
    expect(out.slice(0, 3)).toEqual(['Hôm nay|16/10', 'Ngày mai|17/10', 'Ngày kia|18/10']);
    expect(new Set(out).size).toBe(out.length);
    expect(out).toContain('T7 24/10|24/10');
    expect(out).toContain('Tuần sau|23/10');
  });
});

describe('giờ và ghép ngày giờ theo giờ Việt Nam', () => {
  it('đọc giờ HH:mm; sai dạng thì null', () => {
    expect(parseTime('08:30')).toBe(510);
    expect(parseTime('00:00')).toBe(0);
    expect(parseTime('24:00')).toBeNull();
    expect(parseTime('8:30')).toBeNull();
    expect(parseTime('')).toBeNull();
  });
  it('ngày 15/10/2026 giờ 09:00 là 02:00 UTC (không theo múi giờ trình duyệt)', () => {
    expect(combineVn(new Date(2026, 9, 15), '09:00')?.toISOString()).toBe(
      '2026-10-15T02:00:00.000Z',
    );
    expect(combineVn(new Date(2026, 9, 15), '00:00')?.toISOString()).toBe(
      '2026-10-14T17:00:00.000Z',
    );
  });
  it('thiếu ngày hoặc giờ thì chưa có thời điểm', () => {
    expect(combineVn(null, '09:00')).toBeNull();
    expect(combineVn(new Date(2026, 9, 15), '')).toBeNull();
  });
});
