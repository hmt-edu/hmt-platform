import { describe, expect, it } from 'vitest';
import { lockReasonText, roleNames, rolesError, sameRoles, staffKind } from './userLogic';

describe('userLogic', () => {
  it('lý do khoá: tên mục, kèm ghi chú khi có', () => {
    expect(lockReasonText('Nghỉ việc', '')).toBe('Nghỉ việc');
    expect(lockReasonText('Nghỉ việc', '   ')).toBe('Nghỉ việc');
    expect(lockReasonText('Khác', ' Nghỉ thai sản ')).toBe('Khác: Nghỉ thai sản');
  });
  it('phải có ít nhất một vai trò', () => {
    expect(rolesError([])).toBe('Chọn ít nhất một vai trò.');
    expect(rolesError(['SALES'])).toBeNull();
  });
  it('so sánh tập vai trò không phân biệt thứ tự', () => {
    expect(sameRoles(['A', 'B'], ['B', 'A'])).toBe(true);
    expect(sameRoles(['A'], ['A', 'B'])).toBe(false);
  });
  it('tên vai trò nối bằng dấu phẩy; loại tài khoản theo mã', () => {
    expect(
      roleNames([
        { code: 'A', name: 'Một' },
        { code: 'B', name: 'Hai' },
      ]),
    ).toBe('Một, Hai');
    expect(staffKind('NV000001')).toBe('Nhân viên');
    expect(staffKind('GV000001')).toBe('Giáo viên');
    expect(staffKind('TG000001')).toBe('Trợ giảng');
    expect(staffKind(null)).toBe('');
  });
});
