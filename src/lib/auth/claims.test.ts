import { describe, expect, it } from 'vitest';
import { homePortal, idleGroup, pendingStep, portalAccess, readClaims } from './claims';

function token(payload: Record<string, unknown>): string {
  const encode = (o: unknown) =>
    btoa(String.fromCharCode(...new TextEncoder().encode(JSON.stringify(o))))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  return `${encode({ alg: 'HS256' })}.${encode(payload)}.chuky`;
}

const base = {
  sub: 'u1',
  hmt_name: 'Nguyễn Thử',
  hmt_roles: ['ADMIN', 'TEACHER'],
  hmt_branch_code: 'CS1',
  hmt_portals: ['crm', 'gv'],
  hmt_view_only_portals: ['hoc'],
  hmt_require_mfa: true,
  hmt_must_change_password: false,
  aal: 'aal1',
};

describe('đọc token', () => {
  it('đọc vai trò, cổng, tên tiếng Việt', () => {
    const c = readClaims(token(base));
    expect(c?.name).toBe('Nguyễn Thử');
    expect(c?.roles).toEqual(['ADMIN', 'TEACHER']);
    expect(c?.branchCode).toBe('CS1');
  });
  it('token hỏng: null', () => {
    expect(readClaims('khong-phai-token')).toBeNull();
  });
});

describe('quyền vào cổng', () => {
  const c = readClaims(token(base))!;
  it('cổng đầy đủ, chỉ xem, không có quyền', () => {
    expect(portalAccess(c, 'crm')).toBe('full');
    expect(portalAccess(c, 'hoc')).toBe('view');
    expect(
      portalAccess(
        readClaims(token({ ...base, hmt_portals: ['gv'], hmt_view_only_portals: [] }))!,
        'crm',
      ),
    ).toBe('none');
  });
  it('cổng mặc định là cổng đầy đủ đầu tiên', () => {
    expect(homePortal(c)).toBe('crm');
  });
});

describe('bước còn phải làm', () => {
  it('ADMIN chưa xác thực hai bước: phải làm xác thực hai bước', () => {
    expect(pendingStep(readClaims(token(base))!)).toBe('mfa');
    expect(pendingStep(readClaims(token({ ...base, aal: 'aal2' }))!)).toBeNull();
  });
  it('phải đổi mật khẩu lần đầu trước xác thực hai bước', () => {
    expect(pendingStep(readClaims(token({ ...base, hmt_must_change_password: true }))!)).toBe(
      'change-password',
    );
  });
});

describe('nhóm tự đăng xuất', () => {
  it('nhân viên chặt nhất, rồi giáo viên, rồi học sinh', () => {
    expect(idleGroup(['TEACHER', 'SALES'])).toBe('staff');
    expect(idleGroup(['TA'])).toBe('teacher');
    expect(idleGroup(['STUDENT'])).toBe('student');
  });
});
