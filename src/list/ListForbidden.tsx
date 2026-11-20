// Khung «Không có quyền» của danh sách K03 (canvas 9933: TC01, TC04, TC08, TC10, TC13, BH01, BH06 `*_khong_quyen`):
// tiêu đề «Bạn không có quyền xem <đối tượng>», câu nêu vai trò và phân hệ, nút «Về trang chủ». Chỉ dùng khi máy chủ trả HMT_KHONG_CO_QUYEN.
import { useAuth } from '../lib/auth/authContext';
import { homePortal } from '../lib/auth/claims';
import { useAccess } from '../nav/AccessContext';
import { ButtonLink } from '../ui/Button';
import { StateView } from '../ui/Feedback';
import { forbiddenBody, type ListForbiddenSpec } from './forbiddenSpec';

export function ListForbidden({ subject, module }: ListForbiddenSpec) {
  const { claims } = useAuth();
  const access = useAccess();
  const home = claims ? homePortal(claims) : null;
  return (
    <StateView
      kind="forbidden"
      title={`Bạn không có quyền xem ${subject}`}
      headingLevel={2}
      actions={
        <ButtonLink to={home ? `/${home}` : '/dang-nhap'} variant="primary">
          Về trang chủ
        </ButtonLink>
      }
    >
      {forbiddenBody(access.roleNames, module)}
    </StateView>
  );
}
