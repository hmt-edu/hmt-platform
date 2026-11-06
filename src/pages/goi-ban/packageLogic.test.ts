import { describe, expect, it } from 'vitest';
import { buildPackageCode, gradeRangeError, isHourType } from './packageLogic';

const base = { type: 'LC', subject: 'TOAN', gradeFrom: 'K09', gradeTo: '', suffix: '' };

describe('packageLogic', () => {
  it('mã gói giờ học: Loại-Môn-Khối, một khối hoặc dải khối', () => {
    expect(buildPackageCode(base)).toBe('LC-TOAN-K09');
    expect(buildPackageCode({ ...base, gradeTo: 'K09' })).toBe('LC-TOAN-K09');
    expect(buildPackageCode({ ...base, type: 'VIP', gradeFrom: 'K03', gradeTo: 'K07' })).toBe(
      'VIP-TOAN-K03K07',
    );
  });
  it('chưa đủ ô thì chưa có mã', () => {
    expect(buildPackageCode({ ...base, subject: '' })).toBe('');
    expect(buildPackageCode({ ...base, type: '' })).toBe('');
  });
  it('dịch vụ, tài liệu: Loại-TÊN viết hoa, bỏ ký tự lạ', () => {
    expect(buildPackageCode({ ...base, type: 'DV', suffix: ' csgk ' })).toBe('DV-CSGK');
    expect(buildPackageCode({ ...base, type: 'TL', suffix: 'Ma Toán!' })).toBe('TL-MATON');
    expect(buildPackageCode({ ...base, type: 'TL', suffix: '' })).toBe('');
    expect(isHourType('DV')).toBe(false);
  });
  it('khối đến nhỏ hơn khối từ bị báo', () => {
    const order = ['K06', 'K07', 'K08'];
    expect(gradeRangeError(order, 'K08', 'K06')).not.toBeNull();
    expect(gradeRangeError(order, 'K06', 'K08')).toBeNull();
    expect(gradeRangeError(order, 'K06', '')).toBeNull();
  });
});
