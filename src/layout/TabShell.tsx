import { NavLink, Outlet } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { portalAccess, type Portal } from '../lib/auth/claims';
import { Alert } from '../ui/Feedback';
import { cn } from '../ui/cn';
import { Icon, type IconName } from '../ui/icons';
import { AccountMenu } from './AccountMenu';
import { useProduct, type Product } from './useProduct';
import { useTodoCount } from '../pages/gv/useTodoCount';
import { todoBadgeText } from '../pages/gv/todoLogic';

export type ShellTab = {
  to: string;
  label: string;
  icon: IconName;
  end?: boolean;
  /** Chấm số đếm nhỏ cạnh nhãn (chuỗi đã định dạng; không có thì không hiện). */
  badge?: string | null;
};

type TabShellProps = {
  portal: Portal;
  product: Product;
  /** Tên cổng hiện trên thanh tiêu đề. */
  title: string;
  tabs: ShellTab[];
  /** Menu trái trên laptop: 'rail' = thu gọn (cổng giáo viên), 'wide' = mở rộng (cổng học tập). */
  sidebar: 'rail' | 'wide';
  /** Giới hạn bề rộng nội dung (cổng học tập: một cột giữa trang). */
  contentClass?: string | undefined;
};

/**
 * Khung cổng Giáo viên (GV-01) và cổng Học tập (HT-09): khuôn K02 trên điện thoại (thanh dưới),
 * khuôn K01 trên laptop (menu trái). Cùng nội dung, cùng thành phần trên hai bố cục.
 */
export function TabShell({ portal, product, title, tabs, sidebar, contentClass }: TabShellProps) {
  useProduct(product);
  const { claims } = useAuth();
  const viewOnly = claims ? portalAccess(claims, portal) === 'view' : false;

  return (
    <div className="flex min-h-dvh bg-canvas">
      <aside
        className={cn(
          'sticky top-0 hidden h-dvh shrink-0 flex-col border-r border-border bg-surface lg:flex',
          sidebar === 'rail' ? 'w-24' : 'w-60',
        )}
      >
        <p className="flex h-14 items-center border-b border-border px-3 font-display text-h3">
          {sidebar === 'rail' ? 'HMT' : 'Hòa Ma Toán'}
        </p>
        <nav aria-label={`Menu ${title}`} className="flex flex-col gap-1 p-2">
          {tabs.map((tab) => (
            <NavLink
              key={tab.to}
              to={tab.to}
              end={tab.end ?? false}
              className={({ isActive }) =>
                cn(
                  'focus-ring relative flex rounded-control text-fg',
                  sidebar === 'rail'
                    ? 'min-h-14 flex-col items-center justify-center gap-1 px-1 text-center text-caption'
                    : 'min-h-11 items-center gap-3 px-3 text-body',
                  isActive ? 'bg-selected font-medium text-on-selected' : 'hover:bg-hover',
                )
              }
            >
              <Icon name={tab.icon} />
              <span>{tab.label}</span>
              <TabBadge text={tab.badge} />
            </NavLink>
          ))}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-10 flex h-14 items-center gap-2 border-b border-border bg-surface px-4">
          <p className="min-w-0 flex-1 truncate font-display text-h3">{title}</p>
          <AccountMenu portal={portal} roleLine={claims?.branchCode ?? ''} />
        </header>
        <main className={cn('w-full min-w-0 flex-1 p-4 pb-24 lg:pb-6', contentClass)}>
          {viewOnly && (
            <Alert tone="info" className="mb-4">
              Chế độ chỉ xem: bạn xem được cổng này nhưng không thao tác.
            </Alert>
          )}
          <Outlet />
        </main>
      </div>

      {/* Thanh dưới trên điện thoại: mỗi mục cao tối thiểu 56px, có chữ kèm biểu tượng. */}
      <nav
        aria-label={`Thanh điều hướng ${title}`}
        className="fixed inset-x-0 bottom-0 z-10 flex border-t border-border bg-surface pb-[env(safe-area-inset-bottom)] lg:hidden"
      >
        {tabs.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            end={tab.end ?? false}
            className={({ isActive }) =>
              cn(
                'focus-ring relative flex min-h-14 min-w-0 flex-1 flex-col items-center justify-center gap-0.5 px-1 text-caption',
                isActive ? 'font-semibold text-on-selected' : 'text-fg-muted',
              )
            }
          >
            <Icon name={tab.icon} />
            <span className="max-w-full truncate">{tab.label}</span>
            <TabBadge text={tab.badge} />
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

function TabBadge({ text }: { text: string | null | undefined }) {
  if (!text) return null;
  return (
    <span
      data-testid="tab-badge"
      className="absolute right-1 top-1 min-w-5 rounded-full bg-danger-solid px-1 text-center text-caption font-semibold text-on-solid"
    >
      {text}
    </span>
  );
}

const TEACHER_TABS: ShellTab[] = [
  { to: '/gv', label: 'Hôm nay', icon: 'home', end: true },
  { to: '/gv/lich-day', label: 'Lịch dạy', icon: 'calendar' },
  { to: '/gv/lop', label: 'Lớp', icon: 'classes' },
  { to: '/gv/viec-can-lam', label: 'Cần làm', icon: 'todo' },
  { to: '/gv/tai-khoan', label: 'Tài khoản', icon: 'user' },
];

const STUDENT_TABS: ShellTab[] = [
  { to: '/hoc', label: 'Trang chủ', icon: 'home', end: true },
  { to: '/hoc/bai-tap', label: 'Bài tập', icon: 'homework' },
  { to: '/hoc/lich', label: 'Lịch', icon: 'calendar' },
  { to: '/hoc/ket-qua', label: 'Kết quả', icon: 'results' },
  { to: '/hoc/tai-khoan', label: 'Tài khoản', icon: 'user' },
];

/** GV-01 · Khung cổng giáo viên: điện thoại có thanh dưới 5 mục, laptop có menu trái thu gọn. */
export function TeacherShell() {
  const count = useTodoCount();
  const tabs = TEACHER_TABS.map((t) =>
    t.to === '/gv/viec-can-lam' ? { ...t, badge: todoBadgeText(count) } : t,
  );
  return (
    <TabShell portal="gv" product="teacher" title="Cổng Giáo viên" tabs={tabs} sidebar="rail" />
  );
}

/** HT-09 · Khung cổng học tập: điện thoại có thanh dưới, laptop menu trái, nội dung một cột giữa trang. */
export function StudentShell() {
  return (
    <TabShell
      portal="hoc"
      product="lms"
      title="Học tập"
      tabs={STUDENT_TABS}
      sidebar="wide"
      contentClass="mx-auto max-w-[45rem]"
    />
  );
}
