// E-23-39: tài khoản tập theo cơ sở lấy từ danh sách cơ sở, không viết cứng.
import { describe, expect, it } from 'vitest';
import { buildPracticeUsers } from './seed-users';

const branches = [
  { code: 'CS1', is_office: false },
  { code: 'CS3', is_office: true },
  { code: 'CS5', is_office: false },
];

describe('buildPracticeUsers', () => {
  const users = buildPracticeUsers(branches);

  it('mỗi cơ sở dạy học có 1 quản lý, 3 tư vấn tuyển sinh, 3 CSKH, 3 vận hành; văn phòng không có', () => {
    for (const code of ['CS1', 'CS5']) {
      const of = users.filter((u) => u.branch === code);
      expect(of.filter((u) => u.roles[0] === 'BRANCH_MANAGER')).toHaveLength(1);
      expect(of.filter((u) => u.roles[0] === 'SALES')).toHaveLength(3);
      expect(of.filter((u) => u.key.startsWith('cskh'))).toHaveLength(3);
      expect(of.filter((u) => u.key.startsWith('vh'))).toHaveLength(3);
    }
    expect(users.filter((u) => u.branch === 'CS3').map((u) => u.key)).toEqual([
      'ketoan.tap',
      'mkt.tap',
      'bgd.tap',
    ]);
  });

  it('toàn hệ thống có đúng 1 Kế toán, 1 Trưởng nhóm Marketing, 1 Admin; tên đăng nhập không trùng', () => {
    expect(users.filter((u) => u.roles[0] === 'ACCOUNTANT')).toHaveLength(1);
    expect(users.filter((u) => u.roles[0] === 'MARKETING_MANAGER')).toHaveLength(1);
    expect(users.filter((u) => u.roles[0] === 'ADMIN')).toHaveLength(1);
    expect(new Set(users.map((u) => u.key)).size).toBe(users.length);
  });

  it('thêm cơ sở mới thì có thêm tài khoản (không viết cứng cơ sở); tên giả rõ ràng', () => {
    const more = buildPracticeUsers([...branches, { code: 'CS7', is_office: false }]);
    expect(more.length - users.length).toBe(10);
    expect(users.every((u) => u.name.endsWith('(giả)'))).toBe(true);
  });

  it('không đụng tên đăng nhập của tài khoản e2e hiện có', () => {
    const existing = new Set(['ketoan2.cs5', 'ketoan3.cs5', 'ketoan4.cs5', 'sale.cs5', 'cskh.cs5']);
    expect(users.some((u) => existing.has(u.key))).toBe(false);
  });
});
