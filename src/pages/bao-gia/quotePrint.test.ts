import { describe, expect, it } from 'vitest';
import { hoursText, maskPhone, overdueText, printStamp } from './quotePrint';

describe('bản in báo giá (BH-03)', () => {
  it('Đ273: nhãn theo tình trạng, Đã gửi không nhãn', () => {
    expect(printStamp('NHAP')).toBe('BẢN NHÁP');
    expect(printStamp('TU_CHOI')).toBe('ĐÃ TỪ CHỐI');
    expect(printStamp('HUY')).toBe('ĐÃ HUỶ');
    expect(printStamp('DA_GUI')).toBeNull();
  });

  it('Đ273: chữ quá hạn chỉ khi quá hạn', () => {
    expect(overdueText(1)).toBe('Đã quá hạn 1 ngày');
    expect(overdueText(0)).toBeNull();
    expect(overdueText(null)).toBeNull();
  });

  it('che giữa số điện thoại, số lạ giữ nguyên', () => {
    expect(maskPhone('0912000345')).toBe('0912 *** 345');
    expect(maskPhone('+8491')).toBe('+8491');
  });

  it('giờ viết gọn', () => {
    expect(hoursText(24)).toBe('24');
    expect(hoursText(1.5)).toBe('1,5');
  });
});
