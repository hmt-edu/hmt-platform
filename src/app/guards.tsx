import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router';
import { AuthLayout } from '../layout/AuthLayout';
import { SignOutButton } from '../layout/SignOutButton';
import { PORTAL_NAMES } from '../layout/portalNames';
import { useAuth } from '../lib/auth/authContext';
import { pendingStep, portalAccess, type Portal } from '../lib/auth/claims';
import { afterLoginPath } from '../lib/auth/redirect';
import { useIdleLogout } from '../lib/auth/useIdleLogout';
import { useSessionGuard } from '../lib/auth/useSessionGuard';
import { AccessProvider } from '../nav/AccessContext';
import { ButtonLink } from '../ui/Button';
import { Spinner, StateView } from '../ui/Feedback';

/** Trang đăng nhập theo cổng: học sinh bằng mã HS, phụ huynh bằng mã PH, còn lại bằng email. */
const LOGIN_PATH: Record<Portal, string> = {
  crm: '/dang-nhap',
  gv: '/dang-nhap',
  hoc: '/dang-nhap/hoc-sinh',
  ph: '/dang-nhap/phu-huynh',
};

function SessionWatch({ children }: { children: ReactNode }) {
  useIdleLogout();
  useSessionGuard();
  return <>{children}</>;
}

/** CHUNG-16 ở mức cổng: người không được vào cổng này (hoặc chưa được cấp cổng nào). */
export function NoPortalPage({ portal }: { portal?: Portal }) {
  const { claims } = useAuth();
  const home = claims ? afterLoginPath(claims, null) : '/dang-nhap';
  return (
    <AuthLayout title="Không có quyền truy cập">
      <StateView
        kind="forbidden"
        headingLevel={2}
        title={
          portal === 'gv'
            ? 'Tài khoản chưa liên kết hồ sơ giáo viên' // GV-01 (khung GV01_quyen)
            : portal
              ? `Bạn không có quyền vào cổng ${PORTAL_NAMES[portal]}`
              : 'Tài khoản chưa được cấp cổng nào'
        }
        actions={
          <>
            {home !== '/khong-co-quyen' && (
              <ButtonLink to={home} variant="primary">
                Về cổng của tôi
              </ButtonLink>
            )}
            <SignOutButton variant={home !== '/khong-co-quyen' ? 'secondary' : 'primary'} />
          </>
        }
      >
        {portal === 'gv'
          ? 'Cổng giáo viên chỉ mở cho giáo viên và trợ giảng được phân công. Hãy liên hệ quản trị viên.'
          : 'Cần dùng thì liên hệ quản trị viên để được cấp quyền.'}
      </StateView>
    </AuthLayout>
  );
}

/**
 * Chặn cổng: chưa đăng nhập thì về trang đăng nhập (nhớ địa chỉ đang mở); còn bước bắt buộc thì làm
 * bước đó; không có quyền vào cổng thì CHUNG-16. Vào được thì tải quyền và canh phiên.
 */
export function RequirePortal({ portal, children }: { portal: Portal; children: ReactNode }) {
  const { session, claims } = useAuth();
  const location = useLocation();

  if (session === undefined) return <Spinner />;
  if (!claims) {
    const next = encodeURIComponent(location.pathname + location.search);
    return <Navigate to={`${LOGIN_PATH[portal]}?next=${next}`} replace />;
  }
  if (pendingStep(claims)) return <Navigate to={afterLoginPath(claims, null)} replace />;
  if (portalAccess(claims, portal) === 'none') return <NoPortalPage portal={portal} />;

  return (
    <SessionWatch>
      <AccessProvider>{children}</AccessProvider>
    </SessionWatch>
  );
}

/** Đường dẫn gốc: đã đăng nhập thì về cổng của mình, chưa thì về trang đăng nhập. */
export function RootRedirect() {
  const { session, claims } = useAuth();
  if (session === undefined) return <Spinner />;
  return <Navigate to={claims ? afterLoginPath(claims, null) : '/dang-nhap'} replace />;
}
