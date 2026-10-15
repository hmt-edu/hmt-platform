// Thanh Stage của bản ghi (.hmt-stage của gói): các bước hình mũi tên; bước đang ở nền cam, chữ đậm.
// Bấm vào một Stage để đổi giai đoạn (không có nút "chuyển giai đoạn"). Bước đã qua mờ, không bấm được
// khi luật chỉ cho đi tới (R-CRM-02); luật chặn nào thì hàm cơ sở dữ liệu trả lý do, hộp thoại chặn hiện ra.
import { cn } from './cn';

export type StageStep = {
  code: string;
  label: string;
  /** Tên đầy đủ cho trình đọc màn hình khi nhãn hiện đã rút gọn. */
  fullLabel?: string | undefined;
};

export function StageBar({
  steps,
  current,
  forwardOnly = true,
  onSelect,
  label = 'Giai đoạn',
}: {
  steps: StageStep[];
  /** Mã bước hiện tại. */
  current: string;
  /** Chỉ đi tới: bước đã qua không bấm được. */
  forwardOnly?: boolean | undefined;
  onSelect?: ((step: StageStep) => void) | undefined;
  label?: string | undefined;
}) {
  const index = steps.findIndex((s) => s.code === current);
  return (
    <nav aria-label={label} className="overflow-x-auto">
      <ol className="flex flex-nowrap">
        {steps.map((step, i) => {
          const isCurrent = i === index;
          const isPast = i < index;
          const blocked = isPast && forwardOnly;
          // Mũi tên: bước đầu phẳng bên trái, các bước sau lõm vào và chồng nhẹ lên bước trước.
          const shape =
            i === 0
              ? '[clip-path:polygon(0_0,calc(100%-12px)_0,100%_50%,calc(100%-12px)_100%,0_100%)] pl-3.5'
              : '[clip-path:polygon(0_0,calc(100%-12px)_0,100%_50%,calc(100%-12px)_100%,0_100%,12px_50%)] -ml-2 pl-6';
          return (
            <li key={step.code} className="flex">
              <button
                type="button"
                aria-current={isCurrent ? 'step' : undefined}
                aria-disabled={blocked || isCurrent || undefined}
                onClick={() => {
                  if (!blocked && !isCurrent) onSelect?.(step);
                }}
                className={cn(
                  'focus-ring inline-flex h-stage shrink-0 items-center gap-1.5 pr-4.5 text-body whitespace-nowrap',
                  shape,
                  isCurrent
                    ? 'cursor-default bg-stage-current font-bold text-fg'
                    : blocked
                      ? 'cursor-not-allowed bg-surface-subtle font-medium text-fg-muted'
                      : 'cursor-pointer bg-surface-subtle font-medium text-fg hover:bg-selected',
                )}
              >
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
