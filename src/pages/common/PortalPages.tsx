import { useLocation } from 'react-router';
import { useAccess } from '../../nav/AccessContext';
import { CRM_MENU, checkRoute } from '../../nav/crmMenu';
import { ComingSoonView, FeatureOffView, ForbiddenView, NotFoundView } from './StatePages';

/**
 * Mọi đường dẫn khác dưới /crm: có trong menu và có quyền thì hiện "Sắp có"; không có quyền thì
 * CHUNG-16; phân hệ tắt ở cơ sở thì CHUNG-24; không có trong menu thì CHUNG-17.
 */
export function CrmSectionPage() {
  const access = useAccess();
  const location = useLocation();
  const slug = location.pathname.replace(/^\/crm\/?/, '').replace(/\/$/, '');
  const result = checkRoute(CRM_MENU, slug, access);
  switch (result.status) {
    case 'ok':
      return <ComingSoonView title={result.entry.label} stage={result.entry.stage} />;
    case 'forbidden':
      return <ForbiddenView />;
    case 'feature-off':
      return <FeatureOffView />;
    case 'not-found':
      return <NotFoundView />;
  }
}

/** Trang trống của cổng Giáo viên, Học tập: khung và quyền đã đúng, nội dung làm ở giai đoạn 3, 4. */
export function PortalTabPage({ title, stage }: { title: string; stage: string }) {
  return <ComingSoonView title={title} stage={stage} />;
}
