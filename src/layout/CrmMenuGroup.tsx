// Một nhóm của menu CRM (thanh bên và ngăn kéo điện thoại), ba bậc. Nhóm và nhóm con đóng/mở độc lập, kể cả khi đang chứa
// màn hiện tại; chuyển sang màn khác thì nhóm chứa màn đó tự mở. Nhóm con người dùng mở/đóng tay được nhớ trong trình duyệt.
import { useState, type ReactNode } from 'react';
import { NavLink, useLocation } from 'react-router';
import type { MenuEntry, MenuGroup } from '../nav/crmMenu';
import { activeSlug, menuTree } from '../nav/menuTree';
import { cn } from '../ui/cn';
import { Icon } from '../ui/icons';

const SUB_KEY = 'hmt:menu-nhom-con';

function readSubs(): Record<string, boolean> {
  try {
    const saved: unknown = JSON.parse(localStorage.getItem(SUB_KEY) ?? '{}');
    return typeof saved === 'object' && saved !== null ? (saved as Record<string, boolean>) : {};
  } catch {
    return {};
  }
}

function saveSub(key: string, open: boolean) {
  try {
    localStorage.setItem(SUB_KEY, JSON.stringify({ ...readSubs(), [key]: open }));
  } catch {
    // Không lưu được thì chỉ nhớ trong trang đang mở.
  }
}

/** Đóng/mở theo tay người dùng; mỗi lần sang đường dẫn khác thì tính lại bằng `onNewPath`. */
function useOpenByPath(initial: boolean, onNewPath: (open: boolean) => boolean) {
  const { pathname } = useLocation();
  const [panel, setPanel] = useState({ path: pathname, open: initial });
  if (panel.path !== pathname) setPanel({ path: pathname, open: onNewPath(panel.open) });
  const setOpen = (open: boolean) => setPanel({ path: pathname, open });
  return [panel.open, setOpen] as const;
}

const crmPath = (slug: string) => (slug ? `/crm/${slug}` : '/crm');

// Mục theo .hmt-sb-l2 của gói; mục đang mở có vạch cam 3px bên trái. Mục trong nhóm con thụt sâu hơn.
function EntryLink({
  entry,
  active,
  nested,
  onNavigate,
}: {
  entry: MenuEntry;
  active: boolean;
  nested?: boolean;
  onNavigate?: (() => void) | undefined;
}) {
  return (
    <NavLink
      to={crmPath(entry.slug)}
      end
      onClick={onNavigate}
      className={cn(
        'focus-ring tap flex min-h-8 items-center rounded-control border-l-[3px] py-1.5 pr-2.5 text-body',
        nested ? 'pl-[18px]' : 'pl-[37px]',
        active
          ? 'border-sidebar-marker bg-sidebar-hover font-semibold text-neutral-0'
          : 'border-transparent text-sidebar-fg-muted hover:bg-sidebar-hover hover:text-neutral-0',
      )}
    >
      <span className="truncate">{entry.label}</span>
    </NavLink>
  );
}

// Nhóm con: dòng đóng/mở được (mũi tên, tên, số mục); mục bên trong nằm sau đường kẻ dọc làm trục cây.
function SubSection({
  id,
  label,
  count,
  hasActive,
  children,
}: {
  id: string;
  label: string;
  count: number;
  hasActive: boolean;
  children: ReactNode;
}) {
  const stored = () => readSubs()[id] === true;
  const [open, setOpen] = useOpenByPath(hasActive || stored(), () => hasActive || stored());
  const panelId = `menu-${id.replace(/[^a-z0-9-]+/gi, '-')}`;
  return (
    <>
      <button
        type="button"
        aria-expanded={open}
        aria-controls={panelId}
        aria-current={!open && hasActive ? 'true' : undefined}
        onClick={() => {
          saveSub(id, !open);
          setOpen(!open);
        }}
        className={cn(
          'focus-ring tap flex min-h-8 w-full items-center gap-1.5 rounded-control py-1.5 pr-2.5 pl-[22px] text-left text-body hover:bg-sidebar-hover hover:text-neutral-0',
          !open && hasActive ? 'font-semibold text-neutral-0' : 'text-sidebar-fg',
        )}
      >
        <Icon name={open ? 'chevronDown' : 'chevronRight'} size={16} className="shrink-0" />
        <span className="min-w-0 flex-1 truncate">{label}</span>
        <span className="shrink-0 text-caption text-sidebar-fg-muted">{count}</span>
      </button>
      {open && (
        <ul id={panelId} className="ml-[29px] flex flex-col gap-0.5 border-l border-sidebar-hover">
          {children}
        </ul>
      )}
    </>
  );
}

export function CrmMenuGroup({
  group,
  onNavigate,
}: {
  group: MenuGroup;
  onNavigate?: (() => void) | undefined;
}) {
  const { pathname } = useLocation();
  const active = activeSlug(group, pathname);
  const hasActive = active !== null;
  const [open, setOpen] = useOpenByPath(
    hasActive || group.id === 'tong-quan',
    (was) => hasActive || was,
  );
  const panelId = `menu-${group.id}`;
  // Trang con (bản ghi) không tô mục; tab thì tô dòng của mục cha.
  const highlighted = group.entries.some((e) => crmPath(e.slug) === pathname) ? active : null;
  const link = (entry: MenuEntry, nested?: boolean) => (
    <li key={entry.code}>
      <EntryLink
        entry={entry}
        active={entry.slug === highlighted}
        nested={nested === true}
        onNavigate={onNavigate}
      />
    </li>
  );
  return (
    <li>
      {/* Mục cấp 1 theo .hmt-sb-l1: biểu tượng 20px, chữ đậm vừa, mũi tên ở cuối. */}
      <button
        type="button"
        aria-expanded={open}
        aria-controls={panelId}
        aria-current={!open && hasActive ? 'true' : undefined}
        onClick={() => setOpen(!open)}
        className={cn(
          'focus-ring tap flex min-h-9 w-full items-center gap-2.5 rounded-control px-2.5 py-2 text-left text-body hover:bg-sidebar-hover hover:text-neutral-0',
          open ? 'bg-sidebar-hover font-medium text-neutral-0' : 'font-medium text-sidebar-fg',
          !open &&
            hasActive &&
            'border-l-[3px] border-sidebar-marker pl-[7px] font-bold text-neutral-0',
        )}
      >
        <Icon name={group.icon} className="shrink-0" />
        <span className="min-w-0 flex-1 truncate">{group.label}</span>
        <Icon
          name={open ? 'chevronDown' : 'chevronRight'}
          size={16}
          className="shrink-0 text-sidebar-fg-muted"
        />
      </button>
      {open && (
        <ul id={panelId} className="mt-0.5 flex flex-col gap-0.5">
          {menuTree(group).map((node) =>
            node.kind === 'entry' ? (
              link(node.entry)
            ) : (
              <li key={node.label}>
                <SubSection
                  id={`${group.id}-${node.label}`}
                  label={node.label}
                  count={node.entries.length}
                  hasActive={node.entries.some((e) => e.slug === active)}
                >
                  {node.entries.map((e) => link(e, true))}
                </SubSection>
              </li>
            ),
          )}
        </ul>
      )}
    </li>
  );
}
