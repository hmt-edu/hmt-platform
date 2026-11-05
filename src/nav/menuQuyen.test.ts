import { describe, expect, it } from 'vitest';
import { ALL_BRANCHES, buildAccess } from './access';
import type { AccessData } from './accessData';
import { CRM_MENU, visibleMenu } from './crmMenu';

const CS5 = { id: 'b5', code: 'CS5', name: 'Cơ sở 5', is_office: false };

function menuFor(modules: string[]) {
  const data: AccessData = {
    permissions: modules.map((module_code) => ({
      role_code: 'R',
      module_code,
      action_code: 'XEM',
      scope_code: 'TOAN_HE_THONG',
    })),
    roles: [{ code: 'R', name: 'Vai trò thử', default_scope: 'TOAN_HE_THONG', portals: ['crm'] }],
    branches: [CS5],
    // Nhóm Tuyển sinh nằm sau công tắc Bán hàng: bật ở cơ sở thử.
    features: [{ module_code: 'BAN_HANG', branch_id: 'b5', enabled: true }],
  };
  const access = buildAccess(data, { roles: ['R'], branchCode: 'CS5' }, ALL_BRANCHES);
  return visibleMenu(CRM_MENU, access).flatMap((g) => g.entries.map((e) => e.code));
}

describe('menu Cấu hình theo phân hệ quyền (PR 6e)', () => {
  it('Cấu hình bán hàng: năm mục, không lẫn Cấu hình đào tạo hay Quản trị', () => {
    const codes = menuFor(['CONFIG_SALES']);
    expect(codes).toEqual(expect.arrayContaining(['CH-01', 'CH-03', 'CH-04', 'CH-09', 'CH-08']));
    expect(codes).not.toContain('CH-05');
    expect(codes).not.toContain('QT-01');
    expect(codes).not.toContain('QT-14');
  });

  it('Cấu hình đào tạo: Khung chương trình và Rubric', () => {
    const codes = menuFor(['CONFIG_TRAINING']);
    expect(codes).toEqual(expect.arrayContaining(['CH-05', 'CH-07']));
    expect(codes).not.toContain('CH-01');
  });

  it('Ngày nghỉ lễ có phân hệ riêng; Người duyệt ticket vẫn chỉ Quản trị', () => {
    expect(menuFor(['HOLIDAY'])).toContain('QT-14');
    expect(menuFor(['HOLIDAY'])).not.toContain('QT-15');
    expect(menuFor(['CONFIG_SALES', 'CONFIG_TRAINING', 'HOLIDAY'])).not.toContain('QT-15');
    expect(menuFor(['ADMIN'])).toContain('QT-15');
  });

  it('Nhập dữ liệu (QT-18) chỉ Quản trị', () => {
    expect(menuFor(['ADMIN'])).toContain('QT-18');
    expect(menuFor(['CONFIG_SALES', 'HOLIDAY'])).not.toContain('QT-18');
  });

  it('Lịch hẹn theo phân hệ Lịch hẹn, không còn đi theo Cơ hội', () => {
    expect(menuFor(['APPOINTMENT'])).toContain('TS-11');
    expect(menuFor(['OPPORTUNITY'])).not.toContain('TS-11');
  });
});
