import { describe, expect, it } from 'vitest';
import { accountLabel } from './accountLabel';

describe('accountLabel (nhãn nút tài khoản, luật label-content-name-mismatch)', () => {
  it('dạng đầy đủ: chứa cả tên và dòng vai trò đang hiện trên nút', () => {
    const label = accountLabel('Nguyễn Văn An (giả)', 'CSKH · CS5', false);
    expect(label).toBe('Tài khoản: Nguyễn Văn An (giả) CSKH · CS5');
    expect(label).toContain('Nguyễn Văn An (giả) CSKH · CS5');
  });
  it('dạng gọn: chỉ có tên (nút chỉ hiện ảnh đại diện)', () => {
    expect(accountLabel('Nguyễn Văn An (giả)', 'CSKH · CS5', true)).toBe(
      'Tài khoản: Nguyễn Văn An (giả)',
    );
  });
  it('dòng vai trò trống: không thừa khoảng trắng', () => {
    expect(accountLabel('Giáo viên giả', '', false)).toBe('Tài khoản: Giáo viên giả');
    expect(accountLabel('Giáo viên giả', '  ', false)).toBe('Tài khoản: Giáo viên giả');
  });
  it('vẫn khớp bài đăng nhập: bắt đầu bằng «Tài khoản: » và có «(giả)»', () => {
    expect(accountLabel('Quản trị (giả)', 'Admin · CS5', false)).toMatch(/^Tài khoản: .*\(giả\)/);
  });
});
