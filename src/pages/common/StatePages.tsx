import { useEffect } from 'react';
import { isRouteErrorResponse, useRouteError } from 'react-router';
import { useAuth } from '../../lib/auth/authContext';
import { homePortal } from '../../lib/auth/claims';
import { HmtError } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { StateView } from '../../ui/Feedback';

function homePath(claims: ReturnType<typeof useAuth>['claims']): string {
  const home = claims ? homePortal(claims) : null;
  return home ? `/${home}` : '/dang-nhap';
}

/** CHUNG-16 · Không có quyền truy cập: báo rõ, không lộ dữ liệu. */
export function ForbiddenView({ what }: { what?: string }) {
  const { claims } = useAuth();
  return (
    <StateView
      kind="forbidden"
      title="Bạn không có quyền xem trang này"
      actions={
        <ButtonLink to={homePath(claims)} variant="primary">
          Về trang chủ
        </ButtonLink>
      }
    >
      {what ? `${what} nằm ngoài quyền của tài khoản này. ` : ''}
      Cần dùng thì liên hệ quản trị viên để được cấp quyền.
    </StateView>
  );
}

/** CHUNG-24 · Phân hệ chưa bật ở cơ sở này (công tắc tính năng). */
export function FeatureOffView() {
  const { claims } = useAuth();
  return (
    <StateView
      kind="feature-off"
      title="Phân hệ chưa bật ở cơ sở này"
      actions={
        <ButtonLink to={homePath(claims)} variant="primary">
          Về trang chủ
        </ButtonLink>
      }
    >
      Phân hệ này đang tắt cho cơ sở bạn đang xem. Quản trị viên bật trong Công tắc tính năng khi cơ
      sở sẵn sàng dùng.
    </StateView>
  );
}

/** CHUNG-17 · Không tìm thấy trang. */
export function NotFoundView() {
  const { claims } = useAuth();
  return (
    <StateView
      kind="not-found"
      title="Không tìm thấy trang"
      actions={
        <ButtonLink to={homePath(claims)} variant="primary">
          Về trang chủ
        </ButtonLink>
      }
    >
      Đường dẫn sai hoặc bản ghi không còn. Kiểm tra lại đường dẫn.
    </StateView>
  );
}

const HTTP_NOT_FOUND = 404; // allow-number: mã HTTP "không tìm thấy", không phải số nghiệp vụ

const DETAIL_MAX_LENGTH = 200; // allow-number: cắt câu lỗi kỹ thuật cho gọn khung, không phải số nghiệp vụ

/** Mã lỗi hiện trên khung: câu của HMT, mã HTTP, hoặc tên và câu của lỗi thật để báo lại được. */
function errorDetail(error: unknown): string {
  if (isRouteErrorResponse(error)) return `HTTP ${error.status}`;
  if (error instanceof HmtError) return error.message;
  const text = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  return text.slice(0, DETAIL_MAX_LENGTH);
}

/** CHUNG-17 · Lỗi hệ thống: thông báo dễ hiểu, kèm mã lỗi để báo IT. */
export function RouteErrorPage() {
  const error = useRouteError();
  // Ghi ra Console để người hỗ trợ xem được cả vết lỗi (B-27-05).
  useEffect(() => {
    console.error('[HMT] Trang lỗi:', error);
  }, [error]);
  if (isRouteErrorResponse(error) && error.status === HTTP_NOT_FOUND) return <NotFoundView />;
  const detail = errorDetail(error);
  return (
    <StateView
      kind="error"
      title="Có lỗi xảy ra"
      actions={
        <>
          <Button variant="primary" onClick={() => window.location.reload()}>
            Thử lại
          </Button>
          <ButtonLink to="/">Về trang chủ</ButtonLink>
        </>
      }
    >
      <p>Trang chưa hiển thị được. Bấm Thử lại; nếu vẫn lỗi, gửi mã dưới đây cho quản trị viên.</p>
      <p className="mt-2 font-mono text-caption break-words">Mã lỗi: {detail}</p>
    </StateView>
  );
}

/** Màn chưa dựng: có trong menu để thấy đúng quyền, nội dung làm ở giai đoạn sau. */
export function ComingSoonView({ title, stage }: { title: string; stage?: string }) {
  return (
    <StateView kind="coming-soon" title={title}>
      Sắp có{stage ? `: màn này làm ở ${stage}` : ''}.
    </StateView>
  );
}
