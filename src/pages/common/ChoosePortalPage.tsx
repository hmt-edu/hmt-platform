import { Link, Navigate } from 'react-router';
import { AuthLayout } from '../../layout/AuthLayout';
import { PORTAL_NAMES } from '../../layout/portalNames';
import { useAuth } from '../../lib/auth/authContext';
import { PORTALS, pendingStep, portalAccess, type Portal } from '../../lib/auth/claims';
import { AuthNote, SignOutLink } from '../auth/authParts';
import { Icon, type IconName } from '../../ui/icons';

const PORTAL_CARD: Record<Portal, { icon: IconName; hint: string }> = {
  crm: {
    icon: 'sidebar',
    hint: 'Tuyển sinh, khách hàng, bán hàng, lớp, buổi học, chăm sóc khách hàng.',
  },
  gv: { icon: 'training', hint: 'Lịch dạy, điểm danh, chấm nhận xét, bài tập về nhà.' },
  hoc: { icon: 'homework', hint: 'Bài tập, lịch học, kết quả.' },
  ph: { icon: 'user', hint: 'Theo dõi việc học của con.' },
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
      title={`Chào ${claims.name}`}
      subtitle={`Tài khoản của bạn vào được ${allowed.length === 2 ? 'hai' : allowed.length} cổng. Chọn cổng để bắt đầu.`}
      wide
    >
      <ul className="grid gap-3 sm:grid-cols-2">
        {allowed.map((portal) => (
          <li key={portal}>
            <Link
              to={`/${portal}`}
              className="focus-ring flex h-full min-h-11 flex-col gap-2 rounded-box border border-border bg-surface p-5 text-left text-[13px] leading-[1.5] text-fg-muted hover:border-action hover:bg-brand-50"
            >
              <span className="flex size-11 items-center justify-center rounded-control bg-selected text-on-selected">
                <Icon name={PORTAL_CARD[portal].icon} size={20} />
              </span>
              <b className="font-display text-[17px] font-semibold text-fg">
                {PORTAL_NAMES[portal]}
                {portalAccess(claims, portal) === 'view' ? ' (chỉ xem)' : ''}
              </b>
              <span>{PORTAL_CARD[portal].hint}</span>
            </Link>
          </li>
        ))}
      </ul>
      <AuthNote center>Đổi cổng bất cứ lúc nào ở menu tài khoản (ảnh đại diện góc trên).</AuthNote>
      <SignOutLink label="Đăng xuất" />
    </AuthLayout>
  );
}
