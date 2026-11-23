// Màn lỗi tải dữ liệu dùng chung: không quyền, không thấy, lỗi (có nút Thử lại; chỉ lỗi mạng mới thử lại có ích).
import { Button } from './Button';
import { StateView } from './Feedback';
import { queryErrorSpec } from './queryError';

export function QueryErrorView({
  error,
  subject,
  onRetry,
}: {
  error: unknown;
  subject: string;
  onRetry: () => void;
}) {
  const spec = queryErrorSpec(error, subject);
  return (
    <StateView
      kind={spec.kind}
      title={spec.title}
      actions={spec.canRetry ? <Button onClick={onRetry}>Thử lại</Button> : undefined}
    >
      {spec.canRetry ? 'Kiểm tra mạng rồi bấm Thử lại.' : spec.detail}
    </StateView>
  );
}
