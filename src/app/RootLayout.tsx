import { NavLink, Outlet, useNavigate } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { useIdleLogout } from '../lib/auth/useIdleLogout';
import { portalAccess, type Portal } from '../lib/auth/claims';

const portals: { to: string; key: Portal; label: string }[] = [
  { to: '/crm', key: 'crm', label: 'CRM' },
  { to: '/gv', key: 'gv', label: 'Giáo viên' },
  { to: '/hoc', key: 'hoc', label: 'Học tập' },
];

function navClass({ isActive }: { isActive: boolean }): string {
  return isActive
    ? 'rounded px-3 py-2 text-sm font-medium bg-gray-900 text-white'
    : 'rounded px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200';
}

export function RootLayout() {
  const { claims, signOut } = useAuth();
  const navigate = useNavigate();
  useIdleLogout();

  // Đã đăng nhập: chỉ hiện cổng được vào (quyền thật vẫn do cơ sở dữ liệu chặn).
  const visible = claims ? portals.filter((p) => portalAccess(claims, p.key) !== 'none') : portals;

  return (
    <div className="min-h-dvh bg-gray-50 text-gray-900">
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-2 px-4 py-3">
          <NavLink to="/" className="text-base font-semibold">
            HMT Platform
          </NavLink>
          <nav aria-label="Các cổng" className="flex flex-wrap items-center gap-1">
            {visible.map((portal) => (
              <NavLink key={portal.to} to={portal.to} className={navClass}>
                {portal.label}
              </NavLink>
            ))}
            {claims ? (
              <>
                <span className="px-2 text-sm text-gray-600" data-testid="ten-nguoi-dung">
                  {claims.name}
                  {claims.branchCode ? ` · ${claims.branchCode}` : ''}
                </span>
                <button
                  type="button"
                  onClick={() => void signOut().then(() => navigate('/dang-nhap'))}
                  className="rounded px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200"
                >
                  Đăng xuất
                </button>
              </>
            ) : (
              <NavLink to="/dang-nhap" className={navClass}>
                Đăng nhập
              </NavLink>
            )}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
