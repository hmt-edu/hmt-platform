import { describe, expect, it } from 'vitest';
import { accountLabel } from './accountLabel';

describe('accountLabel (nhãn nút tài khoản, luật label-content-name-mismatch)', () => {
  it('dạng đầy đủ: chứa cả tên và dòng vai trò đang hiện trên nút', () => {
    const label = accountLabel('Nguyễn Văn An (giả)', 'CSKH · CS5', false);
    expect(label).toBe('Nguyễn Văn An (giả) CSKH · CS5 Tài khoản');
    expect(label).toContain('Nguyễn Văn An (giả) CSKH · CS5');
  });
  it('dạng gọn: chỉ có tên (nút chỉ hiện ảnh đại diện)', () => {
    expect(accountLabel('Nguyễn Văn An (giả)', 'CSKH · CS5', true)).toBe(
      'Nguyễn Văn An (giả) Tài khoản',
    );
  });
  it('dòng vai trò trống: không thừa khoảng trắng', () => {
    expect(accountLabel('Giáo viên giả', '', false)).toBe('Giáo viên giả Tài khoản');
    expect(accountLabel('Giáo viên giả', '  ', false)).toBe('Giáo viên giả Tài khoản');
  });
  it('vẫn khớp bài đăng nhập: có «(giả)» rồi kết thúc bằng «Tài khoản»', () => {
    expect(accountLabel('Quản trị (giả)', 'Admin · CS5', false)).toMatch(/\(giả\).*Tài khoản$/);
  });
});
