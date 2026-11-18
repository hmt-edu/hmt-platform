// Khối lỗi tải dữ liệu của cổng Giáo viên (CLAUDE.md «Trải nghiệm»): không có quyền thì hiện trạng thái «Không có quyền» (R-GV-08, R-GV-13: giáo viên
// chỉ thấy việc, lớp, học sinh của mình; máy chủ trả HMT_KHONG_CO_QUYEN), lỗi khác hiện câu lỗi của máy chủ kèm nút Thử lại (lỗi mạng).
import type { ReactNode } from 'react';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { Button, ButtonLink } from '../../ui/Button';
import { Alert, StateView } from '../../ui/Feedback';

export function QueryErrorBlock({
  error,
  onRetry,
  extra,
}: {
  error: unknown;
  onRetry: () => void;
  /** Nút phụ cạnh Thử lại (ví dụ «Về lớp»). */
  extra?: ReactNode;
}) {
  const e = errorOf(error);
  if (e.code === FORBIDDEN_CODE) {
    return (
      <StateView
        kind="forbidden"
        title="Bạn không xem được mục này"
        actions={
          <>
            <ButtonLink to="/gv" variant="primary">
              Về trang Hôm nay
            </ButtonLink>
            {extra}
          </>
        }
      >
        Giáo viên và trợ giảng chỉ thấy lớp, buổi, học sinh được phân công cho mình.
      </StateView>
    );
  }
  return (
    <>
      <Alert tone="danger">{e.message}</Alert>
      <div className="flex gap-3">
        <Button onClick={onRetry}>Thử lại</Button>
        {extra}
      </div>
    </>
  );
}
