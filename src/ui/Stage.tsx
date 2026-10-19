// Thanh Stage của bản ghi (.hmt-stage của gói): các bước hình mũi tên; bước đang ở nền cam, chữ đậm.
// Bấm vào một Stage để đổi giai đoạn (không có nút "chuyển giai đoạn"). Bước đã qua mờ, không bấm được
// khi luật chỉ cho đi tới (R-CRM-02); luật chặn nào thì hàm cơ sở dữ liệu trả lý do, hộp thoại chặn hiện ra.
import { cn } from './cn';
import { Icon } from './icons';

export type StageStep = {
  code: string;
  label: string;
  /** Tên đầy đủ cho trình đọc màn hình khi nhãn hiện đã rút gọn. */
  fullLabel?: string | undefined;
  /** Giai đoạn hệ thống tự chuyển: hiện ổ khoá, bấm không đổi được mà báo lý do (không có nút "chuyển"). */
  lockedReason?: string | undefined;
};

export function StageBar({
  steps,
  current,
  forwardOnly = true,
  onSelect,
  onLockedClick,
  label = 'Giai đoạn',
  disabled = false,
}: {
  steps: StageStep[];
  /** Mã bước hiện tại. */
  current: string;
  /** Chỉ đi tới: bước đã qua không bấm được. */
  forwardOnly?: boolean | undefined;
  onSelect?: ((step: StageStep) => void) | undefined;
  /** Bấm vào giai đoạn do hệ thống tự chuyển: nơi dùng hiện lý do (thông báo hoặc hộp thoại). */
  onLockedClick?: ((step: StageStep, reason: string) => void) | undefined;
  label?: string | undefined;
  /** Bản ghi chưa lưu (đang Tạo): cả thanh mờ, chưa đổi giai đoạn được. */
  disabled?: boolean | undefined;
}) {
  const index = steps.findIndex((s) => s.code === current);
  return (
    <nav aria-label={label} className={cn('overflow-x-auto', disabled && 'opacity-50')}>
      <ol className="flex w-full flex-nowrap">
        {steps.map((step, i) => {
          const isCurrent = i === index;
          const isPast = i < index;
          const blocked = isPast && forwardOnly;
          const locked = step.lockedReason !== undefined && !isCurrent;
          // Mũi tên: bước đầu phẳng bên trái, các bước sau lõm vào và chồng nhẹ lên bước trước.
          const shape =
            i === 0
              ? '[clip-path:polygon(0_0,calc(100%-12px)_0,100%_50%,calc(100%-12px)_100%,0_100%)] pl-3.5'
              : '[clip-path:polygon(0_0,calc(100%-12px)_0,100%_50%,calc(100%-12px)_100%,0_100%,12px_50%)] -ml-2 pl-6';
          return (
            <li key={step.code} className="flex min-w-max flex-1">
              <button
                type="button"
                aria-current={isCurrent ? 'step' : undefined}
                aria-disabled={blocked || isCurrent || locked || disabled || undefined}
                title={step.lockedReason}
                onClick={() => {
                  if (disabled || isCurrent) return;
                  if (locked) onLockedClick?.(step, step.lockedReason ?? '');
                  else if (!blocked) onSelect?.(step);
                }}
                className={cn(
                  'focus-ring inline-flex h-stage w-full shrink-0 items-center gap-1.5 pr-4.5 text-body whitespace-nowrap',
                  shape,
                  isCurrent
                    ? 'cursor-default bg-stage-current font-bold text-fg'
                    : blocked || locked
                      ? 'cursor-not-allowed bg-surface-subtle font-medium text-fg-muted'
                      : 'cursor-pointer bg-surface-subtle font-medium text-fg hover:bg-selected',
                )}
              >
                {locked && <Icon name="forbidden" size={16} />}
                <span className="tabular font-semibold">{step.code}</span>
                <span>{step.label}</span>
                {step.fullLabel && <span className="sr-only">{step.fullLabel}</span>}
              </button>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
