import { useMemo, useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { ALL_BRANCHES } from '../nav/access';
import { useAccess } from '../nav/AccessContext';
import {
  CRM_MENU,
  routeModes,
  routeTabs,
  sidebarEntries,
  visibleMenu,
  type MenuGroup,
} from '../nav/crmMenu';
import { IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Icon } from '../ui/icons';
import { Drawer, Select } from '../ui/Overlays';
import { ButtonLink } from '../ui/Button';
import { RouteTabs } from '../ui/RouteTabs';
import { AccountMenu } from './AccountMenu';
import { CrumbTailContext } from './CrumbTail';
import { GlobalSearch } from './GlobalSearch';
import { NotificationBell } from './NotificationBell';
import { CrumbsContext, fromOf, mergeTrail, type Crumb } from './crumbTrail';
import { useProduct } from './useProduct';

const COLLAPSE_KEY = 'hmt:menu-thu-gon';

function readCollapsed(): boolean {
  try {
    return localStorage.getItem(COLLAPSE_KEY) === '1';
  } catch {
    return false;
  }
}

const crmPath = (slug: string) => (slug ? `/crm/${slug}` : '/crm');

// Mục cấp 2 theo .hmt-sb-l2 của gói: chữ phụ, lề trái 37px; mục đang mở có vạch cam 3px bên trái.
function entryClass({ isActive }: { isActive: boolean }): string {
  return cn(
    'focus-ring tap flex min-h-8 items-center rounded-control border-l-[3px] py-1.5 pr-2.5 pl-[37px] text-body',
    isActive
      ? 'border-sidebar-marker bg-sidebar-hover font-semibold text-neutral-0'
      : 'border-transparent text-sidebar-fg-muted hover:bg-sidebar-hover hover:text-neutral-0',
  );
}

function MenuGroupSection({
  group,
  onNavigate,
}: {
  group: MenuGroup;
  onNavigate?: (() => void) | undefined;
}) {
  const location = useLocation();
  const entries = sidebarEntries(group);
  const current = group.entries.find((e) => location.pathname === crmPath(e.slug));
  const hasActive = current !== undefined;
  // Đang ở một tab thì dòng menu của mục cha được tô.
  const activeTabParent = entries.some((e) => e.slug === current?.tabOf) ? current?.tabOf : null;
  const [open, setOpen] = useState(hasActive || group.id === 'tong-quan');
  const expanded = open || hasActive;
  const panelId = `menu-${group.id}`;
  return (
    <li>
      {/* Mục cấp 1 theo .hmt-sb-l1: biểu tượng 20px, chữ 13px/500, mũi tên ở cuối. */}
      <button
        type="button"
        aria-expanded={expanded}
        aria-controls={panelId}
        onClick={() => setOpen(!expanded)}
        className={cn(
          'focus-ring tap flex min-h-9 w-full items-center gap-2.5 rounded-control px-2.5 py-2 text-left text-body font-medium hover:bg-sidebar-hover hover:text-neutral-0',
          expanded ? 'bg-sidebar-hover text-neutral-0' : 'text-sidebar-fg',
        )}
      >
        <Icon name={group.icon} className="shrink-0" />
        <span className="min-w-0 flex-1 truncate">{group.label}</span>
        <Icon
          name={expanded ? 'chevronDown' : 'chevronRight'}
          size={16}
          className="shrink-0 text-sidebar-fg-muted"
        />
      </button>
      {expanded && (
        <ul id={panelId} className="mt-0.5 flex flex-col gap-0.5">
          {entries.map((entry, index) => {
            // Tiêu đề nhóm con hiện một lần, trước mục đầu tiên của nhóm con đó.
            const heading = entry.sub && entry.sub !== entries[index - 1]?.sub ? entry.sub : null;
            return (
              <li key={entry.code}>
                {heading && (
                  <p className="pt-2 pb-0.5 pl-[37px] text-caption font-semibold text-sidebar-fg-muted">
                    {heading}
                  </p>
                )}
                <NavLink
                  to={crmPath(entry.slug)}
                  end
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    entryClass({ isActive: isActive || entry.slug === activeTabParent })
                  }
                >
                  <span className="truncate">{entry.label}</span>
                </NavLink>
              </li>
            );
          })}
        </ul>
      )}
    </li>
  );
}

function BranchPicker({ className }: { className?: string }) {
  const access = useAccess();
  // Người một cơ sở không chọn cơ sở: cơ sở của mình nằm ở dòng dưới tên (xem AccountMenu).
  if (!access.seesAllBranches) return null;
  // Ô chọn cơ sở của dữ liệu nghiệp vụ không có Hội sở CS3 (R-HT-02).
  const options = [
    { value: ALL_BRANCHES, label: 'Tất cả cơ sở' },
    ...access.teachingBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
  ];
  return (
    <Select
      label="Cơ sở đang xem"
      icon="branch"
      value={access.selectedBranch}
      onChange={access.setSelectedBranch}
      options={options}
      className={className}
    />
  );
}

/**
 * Đường dẫn "Nhóm > Mục" của trang đang mở, lấy từ menu (cùng nguồn với thanh bên). Trang con của một mục (bản ghi, màn Tạo)
 * thêm chữ cuối `tail` do trang đặt (tên bản ghi); mục là liên kết để quay về danh sách.
 */
function useBreadcrumb(menu: MenuGroup[], tail: string | null): Crumb[] {
  const location = useLocation();
  const { pathname } = location;
  const state: unknown = location.state;
  return mergeTrail(fromOf(state), menuBreadcrumb(menu, tail, pathname), pathname);
}

function menuBreadcrumb(menu: MenuGroup[], tail: string | null, pathname: string): Crumb[] {
  for (const group of menu) {
    const entry = group.entries.find((e) => crmPath(e.slug) === pathname);
    if (entry) {
      if (pathname === '/crm') return [{ label: entry.label }];
      const tabParent = group.entries.find((e) => e.slug === entry.tabOf);
      return tabParent
        ? [
            { label: group.label },
            { label: tabParent.label, to: crmPath(tabParent.slug) },
            { label: entry.tabLabel ?? entry.label },
          ]
        : [{ label: group.label }, { label: entry.label }];
    }
    const parent = group.entries.find(
      (e) => e.slug !== '' && pathname.startsWith(`${crmPath(e.slug)}/`),
    );
    if (parent) {
      return [
        { label: group.label },
        { label: parent.label, to: crmPath(parent.slug) },
        { label: tail ?? '…' },
      ];
    }
  }
  if (pathname === '/crm/tai-khoan') return [{ label: 'Hồ sơ cá nhân' }];
  if (pathname.startsWith('/crm/huong-dan')) return [{ label: 'Hướng dẫn sử dụng' }];
  return [{ label: 'CRM' }];
}

/**
 * Khung ứng dụng CRM (khuôn K01 của gói): thanh bên tối 236px (thu gọn 64px) dựng từ ma trận quyền,
 * thanh trên 52px gồm đường dẫn, chọn cơ sở, chuông, tài khoản. Dưới 1024px thanh bên nằm trong ngăn kéo.
 * Ô tìm kiếm toàn hệ thống (CHUNG-11) và chuông thông báo (CHUNG-12) ở thanh trên.
 */
export function CrmShell() {
  useProduct('crm');
  const { claims } = useAuth();
  const access = useAccess();
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const menu = useMemo(() => visibleMenu(CRM_MENU, access), [access]);
  const [tail, setTail] = useState<string | null>(null);
  const crumbs = useBreadcrumb(menu, tail);
  const { pathname, search } = useLocation();
  const slug = pathname.replace(/^\/crm\/?/, '');
  const tabs = routeTabs(menu, slug);
  const modes = routeModes(menu, slug);
  const crumbsValue = useMemo(
    () => ({ crumbs, here: `${pathname}${search}` }),
    [crumbs, pathname, search],
  );
  const branchName = access.branchName(claims?.branchCode ?? null);
  const roleLines = [access.roleNames.join(', '), branchName].filter((line): line is string =>
    Boolean(line),
  );

  const toggleCollapsed = () => {
    const next = !collapsed;
    setCollapsed(next);
    try {
      localStorage.setItem(COLLAPSE_KEY, next ? '1' : '0');
    } catch {
      // Không lưu được thì chỉ nhớ trong trang đang mở.
    }
  };

  const menuList = (onNavigate?: () => void) => (
    <ul className="flex flex-col gap-0.5">
      {menu.map((group) => (
        <MenuGroupSection key={group.id} group={group} onNavigate={onNavigate} />
      ))}
    </ul>
  );

  return (
    <CrumbTailContext.Provider value={setTail}>
      <CrumbsContext.Provider value={crumbsValue}>
        <div className="flex min-h-dvh bg-canvas">
          <aside
            className={cn(
              'sticky top-0 hidden h-dvh shrink-0 flex-col bg-sidebar text-sidebar-fg lg:flex',
              collapsed ? 'w-sidebar-narrow' : 'w-sidebar',
            )}
          >
            {/* Đầu thanh bên trắng, cao bằng thanh trên (.hmt-sb-head). */}
            <div
              className={cn(
                'flex h-topbar shrink-0 items-center border-b border-border bg-surface',
                collapsed ? 'justify-center' : 'gap-2 pr-2 pl-3.5',
              )}
            >
              {!collapsed && (
                <p className="min-w-0 flex-1 truncate font-display text-h3 font-bold text-fg">
                  CRM
                </p>
              )}
              <IconButton
                icon="collapse"
                label={collapsed ? 'Mở rộng menu' : 'Thu gọn menu'}
                onClick={toggleCollapsed}
              />
            </div>
            <nav
              aria-label="Menu CRM"
              className="min-h-0 flex-1 overflow-y-auto px-2.5 pt-2.5 pb-3.5"
            >
              {collapsed ? (
                <ul className="flex flex-col items-center gap-0.5">
                  {menu.map((group) => (
                    <li key={group.id}>
                      <button
                        type="button"
                        aria-label={`${group.label} (mở rộng menu)`}
                        title={group.label}
                        onClick={toggleCollapsed}
                        className="focus-ring flex size-10 items-center justify-center rounded-control text-sidebar-fg hover:bg-sidebar-hover hover:text-neutral-0"
                      >
                        <Icon name={group.icon} />
                      </button>
                    </li>
                  ))}
                </ul>
              ) : (
                menuList()
              )}
            </nav>
          </aside>

          <div className="flex min-w-0 flex-1 flex-col">
            <header className="sticky top-0 z-10 flex h-topbar shrink-0 items-center gap-3 border-b border-border bg-surface px-3 lg:gap-4 lg:px-5">
              <IconButton
                icon="menu"
                label="Mở menu"
                className="lg:hidden"
                onClick={() => setDrawerOpen(true)}
              />
              <nav aria-label="Đường dẫn" className="min-w-0 flex-1">
                <ol className="flex min-w-0 items-center gap-1.5 text-body text-fg-muted">
                  {crumbs.map((crumb, index) => {
                    const last = index === crumbs.length - 1;
                    return (
                      <li
                        key={crumb.label}
                        className={cn(
                          'flex items-center gap-1.5',
                          last ? 'min-w-0' : 'shrink-0',
                          // Điện thoại hẹp: chỉ hiện hai mục cuối (mục cha và trang hiện tại), đủ để quay lại.
                          index < crumbs.length - 2 && 'hidden md:flex',
                        )}
                      >
                        {index > 0 && <Icon name="chevronRight" size={16} className="shrink-0" />}
                        {crumb.to && !last ? (
                          <Link
                            to={crumb.to}
                            className="focus-ring truncate text-link hover:underline"
                          >
                            {crumb.label}
                          </Link>
                        ) : (
                          <span
                            aria-current={last ? 'page' : undefined}
                            className={cn('truncate', last && 'font-semibold text-fg')}
                          >
                            {crumb.label}
                          </span>
                        )}
                      </li>
                    );
                  })}
                </ol>
              </nav>
              <GlobalSearch />
              <div className="ml-auto hidden shrink-0 lg:block">
                <BranchPicker className="w-56" />
              </div>
              <NotificationBell />
              <AccountMenu portal="crm" roleLines={roleLines} />
            </header>
            <main className="min-w-0 flex-1">
              <div className="p-4 lg:p-5">
                {tabs.length > 0 && (
                  <RouteTabs
                    label="Các màn cùng mục"
                    items={tabs.map((t) => ({ to: crmPath(t.slug), label: t.label }))}
                    activeTo={modes[0] ? crmPath(modes[0].slug) : undefined}
                  />
                )}
                {modes.length > 0 && (
                  <nav aria-label="Chế độ xem" className="mb-3 flex flex-wrap gap-1">
                    {modes.map((m) => (
                      <ButtonLink
                        key={m.slug}
                        to={crmPath(m.slug)}
                        variant={m.slug === slug ? 'primary' : 'secondary'}
                        aria-current={m.slug === slug ? 'page' : undefined}
                      >
                        {m.label}
                      </ButtonLink>
                    ))}
                  </nav>
                )}
                <Outlet />
              </div>
            </main>
          </div>

          <Drawer open={drawerOpen} onOpenChange={setDrawerOpen} title="CRM">
            <div className="bg-sidebar px-2.5 py-2.5 text-sidebar-fg">
              <div className="pb-2.5 [&_button]:w-full">
                <BranchPicker className="w-full" />
              </div>
              <nav aria-label="Menu CRM">{menuList(() => setDrawerOpen(false))}</nav>
            </div>
          </Drawer>
        </div>
      </CrumbsContext.Provider>
    </CrumbTailContext.Provider>
  );
}
