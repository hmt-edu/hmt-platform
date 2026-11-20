import { describe, expect, it } from 'vitest';
import { formError, levelsText, orderedLevels } from './approverConfig';

describe('QT-15 người duyệt ticket', () => {
  it('chữ cấp duyệt theo thứ tự', () => {
    expect(levelsText(['QUAN_LY_CO_SO', 'KE_TOAN'])).toBe('Quản lý cơ sở, rồi Kế toán');
    expect(levelsText(['QUAN_LY_CO_SO'])).toBe('Quản lý cơ sở');
  });
  it('cấp được chọn luôn xếp Quản lý cơ sở trước Kế toán', () => {
    expect(orderedLevels(new Set(['KE_TOAN', 'QUAN_LY_CO_SO']))).toEqual([
      'QUAN_LY_CO_SO',
      'KE_TOAN',
    ]);
    expect(orderedLevels(new Set(['KE_TOAN']))).toEqual(['KE_TOAN']);
  });
  it('kiểm biểu mẫu: cần ít nhất một cấp, ngày hiệu lực từ hôm nay', () => {
    expect(formError([], '2026-11-20', '2026-11-19')).toMatch(/ít nhất một cấp/);
    expect(formError(['KE_TOAN'], '', '2026-11-19')).toMatch(/ngày hiệu lực/i);
    expect(formError(['KE_TOAN'], '2026-11-18', '2026-11-19')).toMatch(/từ hôm nay/);
    expect(formError(['KE_TOAN'], '2026-11-19', '2026-11-19')).toBeNull();
  });
});
