import { describe, expect, it } from 'vitest';
import {
  lowHoursNotice,
  orderStatusText,
  orderSubtitle,
  projectedEndText,
  receiptTitle,
} from './feesLogic';

describe('PH-03 học phí', () => {
  it('đơn còn thiếu ghi số tiền, đủ thì ghi Đã thu đủ', () => {
    expect(orderStatusText({ remaining: 0 })).toBe('Đã thu đủ');
    expect(orderStatusText({ remaining: 2400000 })).toContain('Còn thiếu 2.400.000');
  });
  it('dòng phụ của đơn bỏ phần thiếu', () => {
    expect(orderSubtitle({ name: 'Hình 9', hours: 36 })).toBe('Hình 9 · 36 giờ');
    expect(orderSubtitle({ name: null, hours: null })).toBe('');
  });
  it('phiếu thu ghi mã và ngày ngắn', () => {
    expect(receiptTitle({ code: 'PT1', paid_on: '2026-11-10' })).toBe('PT1 · 10/11');
  });
  it('ngày hết dự kiến: có và chưa có lịch', () => {
    expect(projectedEndText('2026-12-05')).toBe('05/12/2026');
    expect(projectedEndText(null)).toBe('Chưa có lịch');
  });
  it('câu nhắc giờ thấp', () => {
    expect(lowHoursNotice('Gia Bảo', { hours_left: 3, projected_end: '2026-12-05' })).toBe(
      'Gia Bảo còn 3,0 giờ, dự kiến hết 05/12. Quý phụ huynh liên hệ cơ sở để đăng ký tiếp.',
    );
    expect(lowHoursNotice('Gia Bảo', { hours_left: 3, projected_end: null })).toBe(
      'Gia Bảo còn 3,0 giờ. Quý phụ huynh liên hệ cơ sở để đăng ký tiếp.',
    );
  });
});
