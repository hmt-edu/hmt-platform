import { describe, expect, it } from 'vitest';
import { ALL_BRANCHES, buildAccess } from './access';
import type { AccessData } from './accessData';
import { CRM_MENU, checkRoute, visibleMenu } from './crmMenu';

const CS1 = { id: 'b1', code: 'CS1', name: 'Cơ sở 1', is_office: false };
const CS3 = { id: 'b3', code: 'CS3', name: 'Hội sở', is_office: true };
const CS5 = { id: 'b5', code: 'CS5', name: 'Cơ sở 5', is_office: false };

function data(over: Partial<AccessData> = {}): AccessData {
  return {
    permissions: [],
    roles: [
      { code: 'SALE', name: 'Tư vấn tuyển sinh', default_scope: 'CO_SO', portals: ['crm'] },
      { code: 'ADMIN', name: 'Quản trị', default_scope: 'TOAN_HE_THONG', portals: ['crm'] },
    ],
    branches: [CS1, CS3, CS5],
    // Bán hàng chỉ bật ở CS5.
    features: [{ module_code: 'BAN_HANG', branch_id: 'b5', enabled: true }],
    ...over,
  };
}
const perm = (module_code: string, action_code: string, role_code = 'SALE') => ({
  role_code,
  module_code,
  action_code,
  scope_code: 'CO_SO',
});
const slugs = (menu: ReturnType<typeof visibleMenu>) =>
  menu.flatMap((g) => g.entries.map((e) => e.slug));

describe('buildAccess', () => {
  it('quyền đọc từ ma trận: có dòng (phân hệ, hành động) mới được', () => {
    const access = buildAccess(
      data({ permissions: [perm('LEAD', 'XEM')] }),
      { roles: ['SALE'], branchCode: 'CS5' },
      ALL_BRANCHES,
    );
    expect(access.can('LEAD', 'XEM')).toBe(true);
    expect(access.can('LEAD', 'DUYET')).toBe(false);
    expect(access.can('ADMIN', 'XEM')).toBe(false);
    expect(access.canAnyModule('XEM')).toBe(true);
    expect(access.canAnyModule('DUYET')).toBe(false);
    expect(access.roleNames).toEqual(['Tư vấn tuyển sinh']);
  });

  it('người một cơ sở: công tắc tính năng xét theo cơ sở của mình', () => {
    const at = (branchCode: string) =>
      buildAccess(data(), { roles: ['SALE'], branchCode }, ALL_BRANCHES);
    expect(at('CS5').featureOn('BAN_HANG')).toBe(true);
    expect(at('CS1').featureOn('BAN_HANG')).toBe(false);
    expect(at('CS5').seesAllBranches).toBe(false);
  });

  it('người thấy mọi cơ sở: xét theo cơ sở đang chọn; "Tất cả cơ sở" là bật ở ít nhất một cơ sở', () => {
    const at = (selected: string) =>
      buildAccess(data(), { roles: ['ADMIN'], branchCode: 'CS3' }, selected);
    expect(at(ALL_BRANCHES).seesAllBranches).toBe(true);
    expect(at(ALL_BRANCHES).featureOn('BAN_HANG')).toBe(true);
    expect(at('b5').featureOn('BAN_HANG')).toBe(true);
    expect(at('b1').featureOn('BAN_HANG')).toBe(false);
  });

  it('công tắc đang tắt thì coi như chưa bật', () => {
    const access = buildAccess(
      data({ features: [{ module_code: 'BAN_HANG', branch_id: 'b5', enabled: false }] }),
      { roles: ['SALE'], branchCode: 'CS5' },
      ALL_BRANCHES,
    );
    expect(access.featureOn('BAN_HANG')).toBe(false);
  });

  it('ô chọn cơ sở không có Hội sở CS3 (R-HT-02)', () => {
    const access = buildAccess(data(), { roles: ['ADMIN'], branchCode: 'CS3' }, ALL_BRANCHES);
    expect(access.teachingBranches.map((b) => b.code)).toEqual(['CS1', 'CS5']);
  });
});

describe('menu CRM theo quyền', () => {
  const sale = (branchCode: string) =>
    buildAccess(
      data({ permissions: [perm('LEAD', 'XEM')] }),
      { roles: ['SALE'], branchCode },
      ALL_BRANCHES,
    );

  it('không có quyền thì không thấy mục; nhóm không còn mục nào thì ẩn cả nhóm', () => {
    const menu = visibleMenu(CRM_MENU, sale('CS5'));
    expect(slugs(menu)).toContain('lead');
    expect(slugs(menu)).not.toContain('co-hoi');
    expect(slugs(menu)).not.toContain('quan-tri/nguoi-dung');
    expect(menu.map((g) => g.id)).not.toContain('quan-tri');
  });

  it('Trang chủ luôn có; "Việc chờ tôi duyệt" chỉ hiện khi có quyền Duyệt ở phân hệ nào đó', () => {
    expect(slugs(visibleMenu(CRM_MENU, sale('CS5')))).toEqual(expect.arrayContaining(['']));
    expect(slugs(visibleMenu(CRM_MENU, sale('CS5')))).not.toContain('viec-cho-duyet');
    const approver = buildAccess(
      data({ permissions: [perm('RECEIPT', 'DUYET')] }),
      { roles: ['SALE'], branchCode: 'CS5' },
      ALL_BRANCHES,
    );
    expect(slugs(visibleMenu(CRM_MENU, approver))).toContain('viec-cho-duyet');
  });

  it('mục có công tắc riêng (Yêu cầu buổi): tắt thì ẩn mục và mở thẳng báo chưa bật; bật thì thấy', () => {
    const trainer = (features: AccessData['features']) =>
      buildAccess(
        data({
          permissions: [perm('SESSION', 'XEM')],
          features: [{ module_code: 'VAN_HANH_LOP', branch_id: 'b5', enabled: true }, ...features],
        }),
        { roles: ['SALE'], branchCode: 'CS5' },
        ALL_BRANCHES,
      );
    const off = trainer([]);
    expect(slugs(visibleMenu(CRM_MENU, off))).not.toContain('yeu-cau-buoi');
    expect(checkRoute(CRM_MENU, 'yeu-cau-buoi', off).status).toBe('feature-off');
    const on = trainer([{ module_code: 'YEU_CAU_BUOI', branch_id: 'b5', enabled: true }]);
    expect(slugs(visibleMenu(CRM_MENU, on))).toContain('yeu-cau-buoi');
    expect(checkRoute(CRM_MENU, 'yeu-cau-buoi', on).status).toBe('ok');
  });

  it('phân hệ chưa bật ở cơ sở thì ẩn cả nhóm dù có quyền', () => {
    expect(visibleMenu(CRM_MENU, sale('CS1')).map((g) => g.id)).not.toContain('tuyen-sinh');
  });

  it('mở thẳng đường dẫn: đủ quyền, không có quyền (CHUNG-16), chưa bật (CHUNG-24), không tồn tại (CHUNG-17)', () => {
    expect(checkRoute(CRM_MENU, 'lead', sale('CS5')).status).toBe('ok');
    expect(checkRoute(CRM_MENU, 'quan-tri/nguoi-dung', sale('CS5')).status).toBe('forbidden');
    expect(checkRoute(CRM_MENU, 'lead', sale('CS1')).status).toBe('feature-off');
    expect(checkRoute(CRM_MENU, 'khong-co-trang-nay', sale('CS5')).status).toBe('not-found');
  });

  it('không có quyền thì báo không có quyền trước, không lộ phân hệ đang bật hay tắt', () => {
    expect(checkRoute(CRM_MENU, 'co-hoi', sale('CS1')).status).toBe('forbidden');
  });

  it('mã màn và đường dẫn trong menu không trùng nhau', () => {
    const entries = CRM_MENU.flatMap((g) => g.entries);
    expect(new Set(entries.map((e) => e.slug)).size).toBe(entries.length);
    expect(new Set(entries.map((e) => e.code)).size).toBe(entries.length);
  });
});
