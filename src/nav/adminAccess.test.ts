// Quản trị viên vào được mọi mục menu và mọi phân hệ để xem (anh Trường chốt 21/11/2026); vai trò khác giữ nguyên luật quyền và công tắc.
import { describe, expect, it } from 'vitest';
import { ALL_BRANCHES, buildAccess } from './access';
import type { AccessData } from './accessData';
import { CRM_MENU, checkRoute, visibleMenu } from './crmMenu';

const CS1 = { id: 'b1', code: 'CS1', name: 'Cơ sở 1', is_office: false };

function accessFor(modules: string[], features: AccessData['features'] = []) {
  const data: AccessData = {
    permissions: modules.map((module_code) => ({
      role_code: 'R',
      module_code,
      action_code: 'XEM',
      scope_code: 'TOAN_HE_THONG',
    })),
    roles: [{ code: 'R', name: 'Vai trò thử', default_scope: 'TOAN_HE_THONG', portals: ['crm'] }],
    branches: [CS1],
    features,
  };
  return buildAccess(data, { roles: ['R'], branchCode: 'CS1' }, ALL_BRANCHES);
}

const ALL_CODES = CRM_MENU.flatMap((g) => g.entries.map((e) => e.code));

describe('Quản trị viên xem mọi màn', () => {
  it('thấy mọi mục menu dù ma trận thiếu quyền riêng và công tắc phân hệ đều tắt', () => {
    const admin = accessFor(['ADMIN']);
    const codes = visibleMenu(CRM_MENU, admin).flatMap((g) => g.entries.map((e) => e.code));
    expect(codes).toEqual(expect.arrayContaining(['TC-04', 'CS-01', 'BC-01']));
    expect(codes.length).toBe(ALL_CODES.length);
  });

  it('mở thẳng Hàng chờ kế toán duyệt, Ticket, Tổng quan Ban giám đốc đều qua cửa', () => {
    const admin = accessFor(['ADMIN']);
    for (const slug of ['cho-ke-toan-duyet', 'ticket', 'bao-cao/tong-quan']) {
      expect(checkRoute(CRM_MENU, slug, admin).status).toBe('ok');
    }
  });

  it('người không có quyền Quản trị vẫn bị chặn đúng như trước', () => {
    const sale = accessFor(['LEAD']);
    expect(checkRoute(CRM_MENU, 'cho-ke-toan-duyet', sale).status).toBe('forbidden');
    expect(checkRoute(CRM_MENU, 'ticket', sale).status).toBe('forbidden');
    const codes = visibleMenu(CRM_MENU, sale).flatMap((g) => g.entries.map((e) => e.code));
    expect(codes).not.toContain('TC-04');
  });

  it('người có quyền nhưng phân hệ tắt vẫn gặp «phân hệ tắt»', () => {
    const report = accessFor(['REPORT']);
    expect(checkRoute(CRM_MENU, 'bao-cao/tong-quan', report).status).toBe('feature-off');
  });
});
