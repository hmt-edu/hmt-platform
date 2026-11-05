import { describe, expect, it } from 'vitest';
import { formatIdleDuration, sessionEndText } from './formatIdle';
import { markSessionEnded, takeSessionEnded } from './sessionEnd';
import { IDLE_SETTING_KEY, idleGroup } from './claims';

// Giá trị mặc định của ba tham số trong migration 20261010000011 (luật R-HT-03).
describe('hộp thoại hết phiên (DN09, R-HT-03): số thời gian theo nhóm vai trò', () => {
  const groups = [
    { roles: ['SALES'], key: 'staff_idle_logout_minutes', minutes: 60, text: '60 phút' },
    { roles: ['TEACHER'], key: 'teacher_idle_logout_minutes', minutes: 10080, text: '7 ngày' },
    { roles: ['STUDENT'], key: 'student_idle_logout_minutes', minutes: 10080, text: '7 ngày' },
  ];
  for (const g of groups) {
    it(`nhóm ${g.roles[0]}: tham số ${g.key} → "${g.text}"`, () => {
      expect(IDLE_SETTING_KEY[idleGroup(g.roles, { SALES: 'staff', TEACHER: 'teacher' })]).toBe(
        g.key,
      );
      markSessionEnded('idle', g.minutes);
      const end = takeSessionEnded();
      expect(end).toEqual({ reason: 'idle', minutes: g.minutes });
      expect(sessionEndText(end!)).toBe(
        `Bạn không thao tác quá ${g.text} nên hệ thống đã đăng xuất để bảo vệ dữ liệu. Phần đang nhập dở chưa được lưu.`,
      );
    });
  }

  it('đọc xong thì xoá: hộp thoại chỉ hiện một lần', () => {
    markSessionEnded('idle', 60);
    takeSessionEnded();
    expect(takeSessionEnded()).toBeNull();
  });

  it('phiên bị kết thúc không do hết giờ: không nêu số phút', () => {
    markSessionEnded('ended');
    expect(sessionEndText(takeSessionEnded()!)).not.toMatch(/\d/);
  });

  it('đổi số phút sang giờ, ngày cho dễ đọc', () => {
    expect(formatIdleDuration(45)).toBe('45 phút');
    expect(formatIdleDuration(60)).toBe('60 phút');
    expect(formatIdleDuration(120)).toBe('2 giờ');
    expect(formatIdleDuration(1440)).toBe('1 ngày');
    expect(formatIdleDuration(10080)).toBe('7 ngày');
    expect(formatIdleDuration(1500)).toBe('25 giờ');
  });
});
