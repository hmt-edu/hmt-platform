import { describe, expect, it } from 'vitest';
import { calendarWindowVn, vnToday, vnWall } from './calendarLogic';

// A26 (R-HT-07): cửa sổ tải của Calendar theo 00:00 giờ Việt Nam, không theo múi giờ máy. Chạy với TZ=UTC, America/Los_Angeles, Asia/Tokyo: kết quả như nhau.
// 18/11/2026 23:30 giờ Việt Nam = 16:30 UTC cùng ngày; 19/11/2026 01:00 giờ Việt Nam = 18/11 18:00 UTC (lúc ngày UTC còn hôm trước).
describe('vnToday', () => {
  it('23:30 giờ VN ngày 18 vẫn là ngày 18; 01:00 giờ VN ngày 19 là ngày 19 (dù UTC còn ngày 18)', () => {
    const a = vnToday(new Date('2026-11-18T16:30:00Z'));
    const b = vnToday(new Date('2026-11-18T18:00:00Z'));
    expect([a.getFullYear(), a.getMonth() + 1, a.getDate()]).toEqual([2026, 11, 18]);
    expect([b.getFullYear(), b.getMonth() + 1, b.getDate()]).toEqual([2026, 11, 19]);
  });
});

describe('calendarWindowVn (cửa sổ tải theo ngày giờ Việt Nam)', () => {
  const anchor19 = new Date(2026, 10, 19); // ngày lịch 19/11/2026
  it('chế độ Ngày: từ 00:00 VN ngày 19 (17:00 UTC ngày 18) đến 00:00 VN ngày 20', () => {
    const w = calendarWindowVn('day', anchor19);
    expect(w.from.toISOString()).toBe('2026-11-18T17:00:00.000Z');
    expect(w.to.toISOString()).toBe('2026-11-19T17:00:00.000Z');
  });
  it('chế độ Tuần: thứ Hai 16/11 đến hết chủ nhật 22/11 giờ VN', () => {
    const w = calendarWindowVn('week', anchor19);
    expect(w.from.toISOString()).toBe('2026-11-15T17:00:00.000Z');
    expect(w.to.toISOString()).toBe('2026-11-22T17:00:00.000Z');
  });
  it('chế độ Tháng: lưới sáu tuần phủ tháng 11/2026', () => {
    const w = calendarWindowVn('month', anchor19);
    expect(w.to.getTime() - w.from.getTime()).toBe(42 * 86_400_000); // 6 tuần
    expect(w.from.getTime()).toBeLessThanOrEqual(new Date('2026-10-31T17:00:00Z').getTime());
  });
});

describe('vnWall (sự kiện Calendar theo giờ treo tường Việt Nam, Q-172)', () => {
  it('00:30 VN ngày 19 (17:30 UTC ngày 18) vẫn ở ngày 19, giờ 00:30, dù máy ở múi giờ nào', () => {
    const w = vnWall(new Date('2026-11-18T17:30:00Z'));
    expect([w.getFullYear(), w.getMonth() + 1, w.getDate(), w.getHours(), w.getMinutes()]).toEqual([
      2026, 11, 19, 0, 30,
    ]);
  });
  it('23:30 VN ngày 18 (16:30 UTC cùng ngày) ở ngày 18, giờ 23:30', () => {
    const w = vnWall(new Date('2026-11-18T16:30:00Z'));
    expect([w.getDate(), w.getHours(), w.getMinutes()]).toEqual([18, 23, 30]);
  });
});
