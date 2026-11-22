import { describe, expect, it } from 'vitest';
import type { HmtClaims } from './claims';
import { afterLoginPath } from './redirect';

function claims(over: Partial<HmtClaims> = {}): HmtClaims {
  return {
    userId: 'u1',
    name: 'Người dùng (giả)',
    roles: ['SALE'],
    branchCode: 'CS1',
    portals: ['crm'],
    viewOnlyPortals: [],
    requireMfa: false,
    mfaOptional: false,
    mustChangePassword: false,
    aal: 'aal1',
    ...over,
  };
}

describe('afterLoginPath · phụ huynh (CHUNG-23)', () => {
  it('phụ huynh chỉ có cổng ph thì vào /ph', () => {
    expect(afterLoginPath(claims({ roles: ['PARENT'], portals: ['ph'] }), null)).toBe('/ph');
  });
  it('phụ huynh không mở được địa chỉ cổng CRM đang mở dở', () => {
    expect(afterLoginPath(claims({ roles: ['PARENT'], portals: ['ph'] }), '/crm/lead')).toBe('/ph');
  });
});

describe('afterLoginPath', () => {
  it('phải đổi mật khẩu lần đầu thì làm trước mọi thứ', () => {
    expect(afterLoginPath(claims({ mustChangePassword: true }), '/crm/lead')).toBe('/doi-mat-khau');
  });

  it('vai trò bắt hai bước mà chưa xác thực thì sang bước hai', () => {
    expect(afterLoginPath(claims({ requireMfa: true }), null)).toBe('/xac-thuc-hai-buoc');
    expect(afterLoginPath(claims({ requireMfa: true, aal: 'aal2' }), null)).toBe('/crm');
  });

  it('quay lại trang đang mở dở nếu thuộc cổng được vào', () => {
    expect(afterLoginPath(claims(), '/crm/lead?x=1')).toBe('/crm/lead?x=1');
  });

  it('bỏ địa chỉ mở dở khi thuộc cổng không được vào hoặc trỏ ra ngoài', () => {
    expect(afterLoginPath(claims(), '/gv/lop')).toBe('/crm');
    expect(afterLoginPath(claims(), '//evil.example/crm')).toBe('/crm');
    expect(afterLoginPath(claims(), 'https://evil.example')).toBe('/crm');
    expect(afterLoginPath(claims(), '/dang-nhap')).toBe('/crm');
  });

  it('dùng đầy đủ từ hai cổng trở lên thì chọn cổng (CHUNG-25)', () => {
    expect(afterLoginPath(claims({ portals: ['crm', 'gv'] }), null)).toBe('/chon-cong');
  });

  it('chỉ có cổng xem thì vào cổng đó; không có cổng nào thì báo không có quyền', () => {
    expect(afterLoginPath(claims({ portals: [], viewOnlyPortals: ['gv'] }), null)).toBe('/gv');
    expect(afterLoginPath(claims({ portals: [] }), null)).toBe('/khong-co-quyen');
  });
});
