import { PORTALS, pendingStep, portalAccess, type HmtClaims, type Portal } from './claims';

function portalOf(path: string): Portal | null {
  const first = path.split(/[/?#]/)[1] ?? '';
  return (PORTALS as readonly string[]).includes(first) ? (first as Portal) : null;
}

/**
 * Sau khi đăng nhập thì đi đâu:
 * 1. Còn bước bắt buộc (đổi mật khẩu lần đầu, hai bước) thì làm bước đó.
 * 2. Địa chỉ đang mở dở (`next`) chỉ dùng khi thuộc cổng người này vào được; không thì bỏ.
 * 3. Người dùng đầy đủ từ hai cổng trở lên (vừa nhân viên vừa giáo viên) thì chọn cổng (CHUNG-25).
 * 4. Còn lại vào cổng của mình; không có cổng nào thì báo không có quyền (CHUNG-16).
 */
export function afterLoginPath(claims: HmtClaims, next: string | null): string {
  const step = pendingStep(claims);
  if (step === 'change-password') return '/doi-mat-khau';
  if (step === 'mfa') return '/xac-thuc-hai-buoc';

  if (next && next.startsWith('/') && !next.startsWith('//')) {
    const portal = portalOf(next);
    if (portal && portalAccess(claims, portal) !== 'none') return next;
  }
  if (claims.portals.length > 1) return '/chon-cong';
  const home = claims.portals[0] ?? claims.viewOnlyPortals[0];
  return home ? `/${home}` : '/khong-co-quyen';
}
