import { describe, expect, it } from 'vitest';
import { hoursText, lateText, monthTitle, roleText, rowDay, shiftMonth } from './hoursLogic';

describe('giờ dạy của tôi (GV-16)', () => {
  it('shiftMonth: qua năm, lùi tháng', () => {
    expect(shiftMonth('2026-11-01', 1)).toBe('2026-12-01');
    expect(shiftMonth('2026-12-01', 1)).toBe('2027-01-01');
    expect(shiftMonth('2026-01-01', -1)).toBe('2025-12-01');
  });
  it('monthTitle', () => expect(monthTitle('2026-11-01')).toBe('Tháng 11/2026'));
  it('hoursText: bỏ số 0 thừa, dấu phẩy', () => {
    expect(hoursText(12)).toBe('12');
    expect(hoursText(1.5)).toBe('1,5');
    expect(hoursText(0)).toBe('0');
  });
  it('lateText: đúng hạn, trễ hạn kèm giờ, chưa ghi nhận (buổi Done trước khi có dấu)', () => {
    expect(lateText({ late: false, late_hours: 0 })).toBe('Đúng hạn');
    expect(lateText({ late: true, late_hours: 2.5 })).toBe('Trễ hạn 2,5 giờ');
    expect(lateText({ late: null, late_hours: null })).toBe('Chưa ghi nhận');
  });
  it('roleText, rowDay', () => {
    expect(roleText('GIAO_VIEN')).toBe('Giáo viên');
    expect(roleText('TRO_GIANG')).toBe('Trợ giảng');
    expect(rowDay({ session_date: '2026-10-24', session_no: 5 })).toBe('24/10 · Buổi 5');
    expect(rowDay({ session_date: '2026-10-24', session_no: null })).toBe('24/10');
  });
});
