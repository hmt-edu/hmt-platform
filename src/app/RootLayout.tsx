import { NavLink, Outlet } from 'react-router';

const portals = [
  { to: '/crm', label: 'CRM' },
  { to: '/gv', label: 'Giáo viên' },
  { to: '/hoc', label: 'Học tập' },
] as const;

function navClass({ isActive }: { isActive: boolean }): string {
  return isActive
    ? 'rounded px-3 py-2 text-sm font-medium bg-gray-900 text-white'
    : 'rounded px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200';
}

export function RootLayout() {
  return (
    <div className="min-h-dvh bg-gray-50 text-gray-900">
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-2 px-4 py-3">
          <NavLink to="/" className="text-base font-semibold">
            HMT Platform
          </NavLink>
          <nav aria-label="Các cổng" className="flex flex-wrap gap-1">
            {portals.map((portal) => (
              <NavLink key={portal.to} to={portal.to} className={navClass}>
                {portal.label}
              </NavLink>
            ))}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
