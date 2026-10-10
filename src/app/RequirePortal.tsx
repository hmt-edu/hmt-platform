import type { ReactNode } from 'react';
import { Link, Navigate, useLocation } from 'react-router';
import { useAuth } from '../lib/auth/authContext';
import { pendingStep, portalAccess, type Portal } from '../lib/auth/claims';

const PORTAL_NAMES: Record<Portal, string> = { crm: 'CRM', gv: 'Giáo viên', hoc: 'Học tập' };

/** Chặn cổng: chưa đăng nhập → trang đăng nhập; chưa xong bước bắt buộc → làm bước đó; không có quyền → báo rõ. */
export function RequirePortal({ portal, children }: { portal: Portal; children: ReactNode }) {
  const { session, claims } = useAuth();
  const location = useLocation();

  if (session === undefined) return <p className="text-gray-600">Đang tải…</p>;
  if (!claims)
    return <Navigate to={`/dang-nhap?next=${encodeURIComponent(location.pathname)}`} replace />;
  const step = pendingStep(claims);
  if (step === 'change-password') return <Navigate to="/doi-mat-khau" replace />;
  if (step === 'mfa') return <Navigate to="/xac-thuc-hai-buoc" replace />;

  const access = portalAccess(claims, portal);
  if (access === 'none') {
    const allowed = [...claims.portals, ...claims.viewOnlyPortals];
    return (
      <section role="alert">
        <h1 className="text-2xl font-semibold">
          Bạn không có quyền vào cổng {PORTAL_NAMES[portal]}
        </h1>
        <p className="mt-2 text-gray-600">
          {allowed.length > 0
            ? 'Cổng bạn được vào: '
            : 'Tài khoản của bạn chưa được cấp cổng nào. Liên hệ quản trị viên.'}
          {allowed.map((p, i) => (
            <span key={p}>
              {i > 0 && ', '}
              <Link to={`/${p}`} className="underline">
                {PORTAL_NAMES[p]}
              </Link>
            </span>
          ))}
        </p>
      </section>
    );
  }
  return (
    <>
      {access === 'view' && (
        <p className="mb-4 rounded bg-amber-50 px-3 py-2 text-sm text-amber-900">
          Chế độ chỉ xem: bạn xem được cổng này nhưng không thao tác.
        </p>
      )}
      {children}
    </>
  );
}
