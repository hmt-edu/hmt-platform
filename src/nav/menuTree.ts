// Cây menu CRM ba bậc (anh Trường chốt 28/11/2026): nhóm → nhóm con đóng/mở được → mục. Hàm thuần, dùng chung cho thanh
// bên, ngăn kéo điện thoại và đường dẫn đầu trang.
import { sidebarEntries, type MenuEntry, type MenuGroup } from './crmMenu';

export type MenuNode =
  { kind: 'entry'; entry: MenuEntry } | { kind: 'sub'; label: string; entries: MenuEntry[] };

/** Dòng của một nhóm theo thứ tự menu. Nhóm con chỉ có một mục thì hiện thẳng mục, không nhãn. */
export function menuTree(group: MenuGroup): MenuNode[] {
  const entries = sidebarEntries(group);
  const nodes: MenuNode[] = [];
  for (const entry of entries) {
    const label = shownSub(group, entry);
    if (!label) {
      nodes.push({ kind: 'entry', entry });
      continue;
    }
    const last = nodes.at(-1);
    if (last?.kind === 'sub' && last.label === label) last.entries.push(entry);
    else nodes.push({ kind: 'sub', label, entries: [entry] });
  }
  return nodes;
}

/** Tên nhóm con mà menu thật sự hiện cho mục này (mục tab tính theo mục cha); null nếu mục đứng thẳng trong nhóm. */
export function shownSub(group: MenuGroup, entry: MenuEntry): string | null {
  if (!entry.sub) return null;
  const same = sidebarEntries(group).filter((e) => e.sub === entry.sub);
  return same.length > 1 ? entry.sub : null;
}

const entryPath = (slug: string) => (slug ? `/crm/${slug}` : '/crm');

/**
 * Đường dẫn của dòng menu «đang ở trong» khi xem `pathname` (kể cả trang con của mục, và tab thì trả dòng của mục cha);
 * null nếu trang không thuộc nhóm.
 */
export function activeSlug(group: MenuGroup, pathname: string): string | null {
  const entry =
    group.entries.find((e) => entryPath(e.slug) === pathname) ??
    group.entries.find((e) => e.slug !== '' && pathname.startsWith(`${entryPath(e.slug)}/`));
  if (!entry) return null;
  const rows = sidebarEntries(group);
  return rows.some((r) => r.slug === entry.tabOf) ? (entry.tabOf ?? entry.slug) : entry.slug;
}
