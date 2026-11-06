import { describe, expect, it } from 'vitest';
import {
  conventionalEmail,
  emailFormatError,
  lockReasonText,
  roleNames,
  rolesError,
  sameRoles,
  staffKind,
  suggestUsername,
  usernameFormatError,
} from './userLogic';

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
  it('gợi ý tên đăng nhập: tên + chữ cái đầu họ và tên đệm, bỏ dấu', () => {
    expect(suggestUsername('Nguyễn Văn An')).toBe('annv');
    expect(suggestUsername('Đặng Thị Hương')).toBe('huongdt');
    expect(suggestUsername('An')).toBe('an');
    expect(suggestUsername('  ')).toBe('');
  });
  it('tên đăng nhập sai dạng bị báo', () => {
    expect(usernameFormatError('giaovien.b')).toBeNull();
    expect(usernameFormatError('Giao Vien')).not.toBeNull();
    expect(usernameFormatError('1abc')).not.toBeNull();
    expect(usernameFormatError('a')).not.toBeNull();
  });
  it('email quy ước và kiểm dạng email', () => {
    expect(conventionalEmail('giaovien.b', 'nv.hmt.invalid')).toBe('giaovien.b@nv.hmt.invalid');
    expect(conventionalEmail('', 'nv.hmt.invalid')).toBe('');
    expect(emailFormatError('a@b.vn')).toBeNull();
    expect(emailFormatError('a@b')).not.toBeNull();
  });
});
