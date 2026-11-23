// Thanh bốn bước của buổi dạy ở cổng giáo viên: 1 Điểm danh, 2 Nội dung, 3 Nhận xét, 4 BTVN (khung GV05_buoc_tiep, GV06_buoc_tiep).
// Chỉ hiển thị vị trí: bước hiện tại tô đậm, bước đã xong có dấu ✓. Không điều hướng (nút «Bước tiếp» làm việc đó).
import { cn } from '../../ui/cn';

const STEPS = ['Điểm danh', 'Nội dung', 'Nhận xét', 'BTVN'] as const;

export type SessionStepNo = 1 | 2 | 3 | 4;

export function SessionStepBar({
  current,
  done = [],
}: {
  /** Bước đang mở (1 đến 4). */
  current: SessionStepNo;
  /** Các bước đã xong (số bước), hiện dấu ✓. */
  done?: SessionStepNo[];
}) {
  return (
    <ol aria-label="Các bước của buổi" className="flex items-center gap-1 text-caption">
      {STEPS.map((title, i) => {
        const no = (i + 1) as SessionStepNo;
        const isDone = done.includes(no);
        const isCurrent = no === current;
        return (
          <li
            key={title}
            aria-current={isCurrent ? 'step' : undefined}
            className={cn(
              'flex min-w-0 flex-1 items-center justify-center gap-1 rounded-control border px-1 py-1',
              isCurrent
                ? 'border-action bg-selected font-semibold text-fg'
                : 'border-border text-fg-muted',
            )}
          >
            <span aria-hidden="true">{isDone ? '✓' : no}</span>
            <span className="truncate">
              {title}
              {isDone && <span className="sr-only"> (xong)</span>}
            </span>
          </li>
        );
      })}
    </ol>
  );
}
