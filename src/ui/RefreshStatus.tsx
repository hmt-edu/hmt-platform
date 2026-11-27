import { formatTime } from '../lib/format';
import { cn } from './cn';
import type { RefreshState } from './useRefreshAction';

/**
 * Chữ cạnh nút «Làm mới» (K1): lỗi, hoặc giờ cập nhật gần nhất (chỉ ở danh sách).
 * «Đang làm mới…» dành cho trình đọc màn hình, và hiện chữ khi người dùng tắt chuyển động (nút không quay).
 */
export function RefreshStatus({
  state,
  showTime = false,
}: {
  state: RefreshState;
  showTime?: boolean | undefined;
}) {
  const { busy, failed, updatedAt } = state;
  const time = showTime && updatedAt ? `Cập nhật ${formatTime(updatedAt)}` : '';
  return (
    <span
      role="status"
      className={cn(
        'text-caption whitespace-nowrap',
        busy && 'sr-only motion-reduce:not-sr-only',
        failed && !busy ? 'text-danger' : 'text-fg-muted',
      )}
    >
      {busy ? 'Đang làm mới…' : failed ? 'Không làm mới được, bấm thử lại' : time}
    </span>
  );
}
