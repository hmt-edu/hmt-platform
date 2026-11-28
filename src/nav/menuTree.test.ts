import { describe, expect, it } from 'vitest';
import { CRM_MENU, visibleMenu, type MenuAccess } from './crmMenu';
import { activeSlug, menuTree } from './menuTree';

const admin: MenuAccess = { can: () => true, canAnyModule: () => true, featureOn: () => true };
const group = (id: string) => {
  const found = visibleMenu(CRM_MENU, admin).find((g) => g.id === id);
  if (!found) throw new Error(`Không thấy nhóm ${id}`);
  return found;
};
const rows = (id: string) =>
  menuTree(group(id)).map((n) => (n.kind === 'sub' ? `[${n.label}]` : n.entry.slug));

describe('cây menu ba bậc', () => {
  it('nhóm con một mục thì hiện thẳng mục, Nhật ký và Lên khối đứng riêng cuối Quản trị', () => {
    expect(rows('quan-tri')).toEqual([
      '[Tài khoản]',
      '[Quyền]',
      '[Hệ thống]',
      'quan-tri/nhat-ky',
      'len-khoi-dau-nam',
    ]);
  });

  it('màn đang xem: trang con của mục và tab đều tính về dòng menu của mục', () => {
    expect(activeSlug(group('quan-tri'), '/crm/quan-tri/nguoi-dung/abc')).toBe(
      'quan-tri/nguoi-dung',
    );
    expect(activeSlug(group('quan-tri'), '/crm/quan-tri/nhat-ky-dang-nhap')).toBe(
      'quan-tri/nhat-ky',
    );
    expect(activeSlug(group('quan-tri'), '/crm/lead')).toBeNull();
  });
});
