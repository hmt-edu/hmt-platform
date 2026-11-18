import { describe, expect, it } from 'vitest';
import { HmtError } from '../../lib/db';
import { isForbidden } from './forbidden';

describe('isForbidden (trạng thái không có quyền ở cổng Giáo viên)', () => {
  it('lỗi mã HMT_KHONG_CO_QUYEN là không có quyền', () => {
    expect(isForbidden(new HmtError('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền.'))).toBe(true);
  });
  it('lỗi khác, lỗi mạng, không phải lỗi: không phải không có quyền', () => {
    expect(isForbidden(new HmtError('HMT_LOI', 'Lỗi.'))).toBe(false);
    expect(isForbidden(new Error('Failed to fetch'))).toBe(false);
    expect(isForbidden(null)).toBe(false);
  });
});
