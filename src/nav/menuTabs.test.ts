import { describe, expect, it } from 'vitest';
import {
  CRM_MENU,
  checkRoute,
  routeTabs,
  sidebarEntries,
  visibleMenu,
  type MenuAccess,
} from './crmMenu';

const admin: MenuAccess = { can: () => true, canAnyModule: () => true, featureOn: () => true };
const group = (access: MenuAccess, id: string) => {
  const found = visibleMenu(CRM_MENU, access).find((g) => g.id === id);
  if (!found) throw new Error(`Không thấy nhóm ${id}`);
  return found;
};
const sidebar = (id: string) => sidebarEntries(group(admin, id)).map((e) => e.slug);

describe('menu đợt 1 (A-26-11)', () => {
  it('tách Bán hàng và Kế toán', () => {
    expect(sidebar('ban-hang')).toEqual(['bao-gia', 'don-hang']);
    expect(sidebar('ke-toan')).toEqual([
      'phieu-thu',
      'khoan-tien-vao',
      'cong-no',
      'phieu-chi',
      'so-du-khach-hang',
      'doi-soat-thu-tien',
    ]);
  });

  it.each([
    ['ghi-danh', 'cho-xep-lop'],
    ['buoi-hoc', 'yeu-cau-buoi'],
    ['phieu-thu', 'cho-ke-toan-duyet'],
    ['tai-tuc', 'doi-chieu-tai-tuc'],
    ['phieu-nghiep-vu', 'phieu-chuyen-co-so-den'],
  ])('%s có tab %s; đường dẫn cũ vẫn mở được', (parent, child) => {
    const menu = visibleMenu(CRM_MENU, admin);
    expect(routeTabs(menu, parent).map((t) => t.slug)).toEqual([parent, child]);
    expect(routeTabs(menu, child).map((t) => t.slug)).toEqual([parent, child]);
    expect(checkRoute(CRM_MENU, child, admin).status).toBe('ok');
    expect(menu.flatMap(sidebarEntries).map((e) => e.slug)).not.toContain(child);
  });

  it('thiếu quyền tab con thì không có thanh tab', () => {
    const viewOnly: MenuAccess = { ...admin, can: (_m, action) => action === 'XEM' };
    expect(routeTabs(visibleMenu(CRM_MENU, viewOnly), 'phieu-thu')).toEqual([]);
  });

  it('không thấy mục cha thì mục con hiện thành dòng menu', () => {
    const approverOnly: MenuAccess = {
      ...admin,
      can: (module, action) => module === 'TICKET' && action === 'DUYET',
    };
    const slugs = sidebarEntries(group(approverOnly, 'cham-soc')).map((e) => e.slug);
    expect(slugs).toContain('phieu-chuyen-co-so-den');
  });

  it('công tắc riêng của tab vẫn giữ: tắt Yêu cầu buổi thì Buổi học không còn tab', () => {
    const off: MenuAccess = { ...admin, featureOn: (f) => f !== 'YEU_CAU_BUOI' };
    expect(routeTabs(visibleMenu(CRM_MENU, off), 'buoi-hoc')).toEqual([]);
    expect(checkRoute(CRM_MENU, 'yeu-cau-buoi', off).status).toBe('feature-off');
  });

  it('Sắp hết giờ nằm ở Chăm sóc khách hàng, vẫn theo công tắc Vận hành lớp', () => {
    expect(sidebar('cham-soc')).toContain('sap-het-gio');
    expect(sidebar('dao-tao')).not.toContain('sap-het-gio');
    const off: MenuAccess = { ...admin, featureOn: (f) => f !== 'VAN_HANH_LOP' };
    expect(checkRoute(CRM_MENU, 'sap-het-gio', off).status).toBe('feature-off');
  });

  it('Cấu hình và Quản trị chia nhóm con liền nhau; Lên khối ở Quản trị', () => {
    const subs = (id: string) =>
      group(admin, id)
        .entries.map((e) => e.sub)
        .filter((s, i, all) => s !== all[i - 1]);
    expect(subs('cau-hinh')).toEqual(['Bán hàng', 'Đào tạo', 'Chăm sóc']);
    expect(subs('quan-tri')).toEqual(['Tài khoản', 'Quyền', 'Hệ thống', 'Nhật ký']);
    expect(sidebar('quan-tri')).toContain('len-khoi-dau-nam');
    expect(sidebar('khach-hang')).toEqual(['phu-huynh', 'hoc-sinh']);
  });
});
