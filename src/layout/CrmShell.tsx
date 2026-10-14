import { useMemo, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { ALL_BRANCHES } from '../nav/access';
import { useAccess } from '../nav/AccessContext';
import { CRM_MENU, visibleMenu, type MenuGroup } from '../nav/crmMenu';
import { IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Icon } from '../ui/icons';
import { Drawer, Select } from '../ui/Overlays';
import { AccountMenu } from './AccountMenu';
import { useProduct } from './useProduct';

const COLLAPSE_KEY = 'hmt:menu-thu-gon';

function readCollapsed(): boolean {
  try {
    return localStorage.getItem(COLLAPSE_KEY) === '1';
  } catch {
    return false;
  }
}

function entryClass({ isActive }: { isActive: boolean }): string {
  return cn(
    'focus-ring tap relative flex min-h-9 items-center rounded-control py-1 pr-2 pl-9 text-body',
    isActive
      ? 'bg-selected font-medium text-on-selected before:absolute before:inset-y-1.5 before:left-6 before:w-0.5 before:rounded-full before:bg-action'
      : 'text-fg hover:bg-hover-overlay',
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
  const hasActive = group.entries.some(
    (e) => location.pathname === `/crm${e.slug ? `/${e.slug}` : ''}`,
  );
  const [open, setOpen] = useState(hasActive || group.id === 'tong-quan');
  const expanded = open || hasActive;
  const panelId = `menu-${group.id}`;
  return (
    <li>
      <button
        type="button"
        aria-expanded={expanded}
        aria-controls={panelId}
        onClick={() => setOpen(!expanded)}
        className="focus-ring tap flex min-h-9 w-full items-center gap-2 rounded-control px-2 text-left text-body font-semibold text-fg hover:bg-hover-overlay"
      >
        <Icon name={group.icon} className="shrink-0 text-fg-muted" />
        <span className="min-w-0 flex-1 truncate">{group.label}</span>
        <Icon
          name={expanded ? 'chevronDown' : 'chevronRight'}
          size={16}
          className="text-fg-muted"
        />
      </button>
      {expanded && (
        <ul id={panelId} className="mt-0.5 flex flex-col gap-0.5">
          {group.entries.map((entry, index) => {
            // Tiêu đề nhóm con hiện một lần, trước mục đầu tiên của nhóm con đó.
            const heading =
              entry.sub && entry.sub !== group.entries[index - 1]?.sub ? entry.sub : null;
            return (
              <li key={entry.code}>
                {heading && (
                  <p className="pt-2 pb-0.5 pl-9 text-caption font-medium text-fg-muted">
                    {heading}
                  </p>
                )}
                <NavLink
                  to={entry.slug ? `/crm/${entry.slug}` : '/crm'}
                  end
                  onClick={onNavigate}
                  className={entryClass}
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
  const { claims } = useAuth();
  const access = useAccess();
  if (!access.seesAllBranches) {
    return (
      <p className={cn('flex items-center gap-2 text-body text-fg-muted', className)}>
        <Icon name="location" size={16} />
        <span>Cơ sở: {claims?.branchCode ?? 'chưa gán'}</span>
      </p>
    );
  }
  // Ô chọn cơ sở của dữ liệu nghiệp vụ không có Hội sở CS3 (R-HT-02).
  const options = [
    { value: ALL_BRANCHES, label: 'Tất cả cơ sở' },
    ...access.teachingBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` })),
  ];
  return (
    <Select
      label="Cơ sở đang xem"
      icon="location"
      value={access.selectedBranch}
      onChange={access.setSelectedBranch}
      options={options}
      className={className}
    />
  );
}

/** CHUNG-10 · Khung ứng dụng CRM (khuôn K01): menu trái theo quyền, thanh trên, vùng nội dung. */
export function CrmShell() {
  useProduct('crm');
  const { claims } = useAuth();
  const access = useAccess();
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const menu = useMemo(() => visibleMenu(CRM_MENU, access), [access]);
  const roleLine = [access.roleNames.join(', '), claims?.branchCode].filter(Boolean).join(' · ');

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
    <ul className="flex flex-col gap-1 p-2">
      {menu.map((group) => (
        <MenuGroupSection key={group.id} group={group} onNavigate={onNavigate} />
      ))}
    </ul>
  );

  return (
    <div className="flex min-h-dvh bg-canvas">
      {/* Menu trái: từ 1024px. Hẹp hơn thì nằm trong ngăn kéo. */}
      <aside
        className={cn(
          'sticky top-0 hidden h-dvh shrink-0 flex-col border-r border-border bg-surface lg:flex',
          collapsed ? 'w-14' : 'w-64',
        )}
      >
        <div className="flex h-14 items-center gap-2 border-b border-border px-3">
          {!collapsed && (
            <p className="min-w-0 leading-tight">
              <span className="block truncate font-display text-h3">Hòa Ma Toán</span>
              <span className="block text-caption text-fg-muted">CRM</span>
            </p>
          )}
        </div>
        <nav aria-label="Menu CRM" className="min-h-0 flex-1 overflow-y-auto">
          {collapsed ? (
            <ul className="flex flex-col items-center gap-1 p-2">
              {menu.map((group) => (
                <li key={group.id}>
                  <IconButton
                    icon={group.icon}
                    label={`${group.label} (mở rộng menu)`}
                    onClick={toggleCollapsed}
                  />
                </li>
              ))}
            </ul>
          ) : (
            menuList()
          )}
        </nav>
        <div className="border-t border-border p-2">
          {collapsed ? (
            <IconButton icon="sidebar" label="Mở rộng menu" onClick={toggleCollapsed} />
          ) : (
            <button
              type="button"
              onClick={toggleCollapsed}
              className="focus-ring flex min-h-9 w-full items-center gap-2 rounded-control px-2 text-body text-fg hover:bg-hover-overlay"
            >
              <Icon name="sidebar" />
              Thu gọn
            </button>
          )}
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-10 flex h-14 items-center gap-2 border-b border-border bg-surface px-2 sm:px-4">
          <IconButton
            icon="menu"
            label="Mở menu"
            className="lg:hidden"
            onClick={() => setDrawerOpen(true)}
          />
          <p className="min-w-0 flex-1 truncate font-display text-h3 lg:hidden">
            Hòa Ma Toán · CRM
          </p>
          <div className="hidden min-w-0 flex-1 lg:block" />
          <BranchPicker className="hidden w-56 lg:flex" />
          <AccountMenu portal="crm" roleLine={roleLine} />
        </header>
        <main className="min-w-0 flex-1 p-4 lg:p-6">
          <Outlet />
        </main>
      </div>

      <Drawer open={drawerOpen} onOpenChange={setDrawerOpen} title="Hòa Ma Toán · CRM">
        <div className="border-b border-border p-3">
          <BranchPicker className="w-full" />
        </div>
        <nav aria-label="Menu CRM">{menuList(() => setDrawerOpen(false))}</nav>
      </Drawer>
    </div>
  );
}
