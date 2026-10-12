import { Navigate } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import { PORTAL_NAMES } from '../../layout/portalNames';
import { useAuth } from '../../lib/auth/authContext';
import { PORTALS, pendingStep, portalAccess, type Portal } from '../../lib/auth/claims';
import { ButtonLink } from '../../ui/Button';

const PORTAL_HINT: Record<Portal, string> = {
  crm: 'Tuyển sinh, bán hàng, vận hành lớp, chăm sóc khách hàng',
  gv: 'Lịch dạy, điểm danh, chấm bài, nhận xét',
  hoc: 'Bài tập, lịch học, kết quả',
};

/** CHUNG-25 · Chọn cổng: người vừa là nhân viên vừa là giáo viên chọn vào CRM hoặc cổng Giáo viên. */
export function ChoosePortalPage() {
  const { claims } = useAuth();
  if (!claims) return <Navigate to="/dang-nhap" replace />;
  if (pendingStep(claims)) return <Navigate to="/dang-nhap" replace />;
  const allowed = PORTALS.filter((p) => portalAccess(claims, p) !== 'none');
  if (allowed.length === 0) return <Navigate to="/khong-co-quyen" replace />;

  return (
    <AuthLayout
      title="Chọn cổng làm việc"
      subtitle={`Xin chào ${claims.name}. Bạn dùng được các cổng sau:`}
    >
      <ul className="flex flex-col gap-3">
        {allowed.map((portal) => (
          <li key={portal}>
            <ButtonLink
              to={`/${portal}`}
              fullWidth
              className="h-auto min-h-16 flex-col items-start gap-0 py-2 whitespace-normal"
            >
              <span className="font-semibold">
                Cổng {PORTAL_NAMES[portal]}
                {portalAccess(claims, portal) === 'view' ? ' (chỉ xem)' : ''}
              </span>
              <span className="text-caption font-normal text-fg-muted">{PORTAL_HINT[portal]}</span>
            </ButtonLink>
          </li>
        ))}
      </ul>
      <p className="text-caption text-fg-muted">
        Đổi cổng bất cứ lúc nào từ menu tài khoản ở góc trên.
      </p>
    </AuthLayout>
  );
}
