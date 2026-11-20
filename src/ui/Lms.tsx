// Thành phần dùng chung cho GV-17 (Giao bài trên LMS) và GV-18 (Chấm bài nộp online), theo khung canvas bổ sung 20/11/2026
// (GHI_CHU_CHO_CODE mục 3): công tắc, thanh tiến độ, hàng tệp có tiến độ, thẻ chọn một trong các trạng thái, khung xem bài nộp.
// Luật: R-LMS-01 (hai công tắc), R-LMS-04 (tệp tối đa 10 MB), R-GV-11 (năm trạng thái BTVN).
import { useId, useState, type ReactNode } from 'react';
import { Button } from './Button';
import { cn } from './cn';
import { Icon } from './icons';
import { formatFileSize } from './lmsFiles';

/** Công tắc bật tắt (.hmt-sw: 36×20, role=switch). Nhãn đi kèm luôn là chữ; trạng thái không chỉ dựa vào màu. */
export function Switch({
  label,
  description,
  checked,
  onChange,
  disabled = false,
}: {
  label: string;
  description?: string | undefined;
  checked: boolean;
  onChange?: ((checked: boolean) => void) | undefined;
  disabled?: boolean | undefined;
}) {
  const labelId = useId();
  const descId = useId();
  return (
    <div className="flex items-start justify-between gap-3 py-2.5">
      <div className="min-w-0">
        <p id={labelId} className="font-medium text-fg">
          {label}
        </p>
        {description && (
          <p id={descId} className="text-caption text-fg-muted">
            {description}
          </p>
        )}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-labelledby={labelId}
        aria-describedby={description ? descId : undefined}
        disabled={disabled}
        onClick={() => onChange?.(!checked)}
        className={cn(
          'relative h-5 w-9 shrink-0 rounded-full transition-colors',
          checked ? 'bg-action' : 'bg-border-strong',
          disabled && 'cursor-not-allowed opacity-50',
        )}
      >
        <span
          aria-hidden="true"
          className={cn(
            'absolute left-0.5 top-0.5 h-4 w-4 rounded-full bg-surface transition-transform',
            checked && 'translate-x-4',
          )}
        />
      </button>
    </div>
  );
}

/** Thanh tiến độ 4px (tải tệp, «đã chấm x/y»). `value` từ 0 tới 100; luôn kèm `label` để đọc được bằng chữ. */
export function ProgressBar({
  value,
  label,
  className,
}: {
  value: number;
  label: string;
  className?: string | undefined;
}) {
  const percent = Math.min(100, Math.max(0, Math.round(value))); // allow-number: phần trăm 0–100
  return (
    <div
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100} // allow-number: phần trăm
      aria-valuenow={percent}
      className={cn('h-1 overflow-hidden rounded-sm bg-surface-subtle', className)}
    >
      <div className="h-full bg-brand-500" style={{ width: `${percent}%` }} />
    </div>
  );
}

/**
 * Hàng một tệp đính kèm: tên, dung lượng, nút Xoá; đang tải thì có thanh tiến độ; tệp quá hạn mức hiện viền đỏ kèm lý do bằng chữ.
 * `locked` (bài đã có em nộp): tệp cũ khoá, không có nút Xoá.
 */
export function FileRow({
  name,
  size,
  progress,
  error,
  locked = false,
  onRemove,
}: {
  name: string;
  size: number;
  /** 0–100 khi đang tải lên; bỏ trống khi đã tải xong. */
  progress?: number | undefined;
  /** Lý do lỗi (ví dụ «Tệp quá 10 MB»). */
  error?: string | undefined;
  locked?: boolean | undefined;
  onRemove?: (() => void) | undefined;
}) {
  const uploading = progress !== undefined && progress < 100; // allow-number: phần trăm
  return (
    <li
      className={cn(
        'flex flex-col gap-1.5 rounded-control bg-surface px-2.5 py-2',
        error ? 'border-2 border-danger-solid' : 'border border-border',
      )}
    >
      <div className="flex items-center gap-2.5">
        <Icon name={locked ? 'lock' : 'file'} className="shrink-0 text-fg-muted" />
        <div className="min-w-0 flex-1">
          <p className="truncate font-medium text-fg">{name}</p>
          <p className="text-caption text-fg-muted">
            {formatFileSize(size)}
            {uploading && ` · đang tải ${Math.round(progress)}%`}
            {locked && ' · đã khoá vì có em nộp bài'}
          </p>
        </div>
        {!locked && onRemove && (
          <Button variant="ghost" size="sm" onClick={onRemove} aria-label={`Xoá tệp ${name}`}>
            <Icon name="trash" />
            Xoá
          </Button>
        )}
      </div>
      {uploading && <ProgressBar value={progress} label={`Đang tải ${name}`} />}
      {error && (
        <p role="alert" className="text-caption text-danger">
          {error}
        </p>
      )}
    </li>
  );
}

export type ChoiceCardOption<T extends string> = {
  value: T;
  label: string;
  description?: string | undefined;
  disabled?: boolean | undefined;
  /** Vì sao thẻ bị khoá (ví dụ em chưa nộp thì chỉ chọn được Nộp sau, Không làm). */
  disabledReason?: string | undefined;
};

/**
 * Thẻ chọn MỘT trong nhiều (bước 3 GV-18 điện thoại, năm trạng thái BTVN): vòng tròn chọn, chữ và dòng giải thích.
 * radiogroup: mũi tên đổi lựa chọn, đọc được bằng trình đọc màn hình.
 */
export function ChoiceCards<T extends string>({
  legend,
  options,
  value,
  onChange,
}: {
  legend: string;
  options: ChoiceCardOption<T>[];
  value: T | null;
  onChange: (value: T) => void;
}) {
  const name = useId();
  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="mb-1 font-semibold text-fg">{legend}</legend>
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <label
            key={o.value}
            className={cn(
              'flex items-start gap-3 rounded-control border px-3 py-2.5',
              selected ? 'border-border-selected bg-selected' : 'border-border bg-surface',
              o.disabled ? 'cursor-not-allowed opacity-60' : 'cursor-pointer hover:bg-hover',
            )}
          >
            <input
              type="radio"
              name={name}
              value={o.value}
              checked={selected}
              disabled={o.disabled}
              onChange={() => onChange(o.value)}
              className="mt-1 h-4 w-4 shrink-0 accent-brand-600"
            />
            <span className="min-w-0">
              <span className="block font-medium text-fg">{o.label}</span>
              {o.description && (
                <span className="block text-caption text-fg-muted">{o.description}</span>
              )}
              {o.disabled && o.disabledReason && (
                <span className="block text-caption text-fg-muted">{o.disabledReason}</span>
              )}
            </span>
          </label>
        );
      })}
    </fieldset>
  );
}

export type SubmissionPage = { id: string; src: string; alt: string };

/** Mức phóng to: bước 25%, từ 100% tới 300%. */
const ZOOM_STEP = 0.25; // allow-number: bước phóng to giao diện
const ZOOM_MIN = 1; // allow-number: không thu nhỏ hơn khung
const ZOOM_MAX = 3; // allow-number: tối đa 300%
const QUARTER_TURN = 90; // allow-number: góc xoay mỗi lần bấm

/**
 * Khung xem bài nộp (GV-18 bước 1): ảnh nhiều trang (dải ảnh nhỏ, phóng to, xoay) hoặc một tệp PDF.
 * `loading` hiện trạng thái đang tải; `error` hiện lỗi kèm nút Thử lại. Không tự tải ảnh: trang cha đưa địa chỉ vào.
 */
export function SubmissionViewer({
  pages,
  pdfSrc,
  pdfTitle = 'Bài nộp (PDF)',
  loading = false,
  error,
  onRetry,
  footer,
}: {
  pages?: SubmissionPage[] | undefined;
  pdfSrc?: string | undefined;
  pdfTitle?: string | undefined;
  loading?: boolean | undefined;
  error?: string | undefined;
  onRetry?: (() => void) | undefined;
  footer?: ReactNode;
}) {
  const [index, setIndex] = useState(0);
  const [zoom, setZoom] = useState(ZOOM_MIN);
  const [turn, setTurn] = useState(0);
  const list = pages ?? [];
  const current = list[Math.min(index, Math.max(0, list.length - 1))];

  if (loading) {
    return (
      <div
        role="status"
        className="flex h-64 items-center justify-center gap-2 rounded-control border border-border bg-surface-subtle text-fg-muted"
      >
        <Icon name="loading" className="animate-spin" />
        Đang tải bài nộp…
      </div>
    );
  }
  if (error) {
    return (
      <div
        role="alert"
        className="flex flex-col items-center gap-2 rounded-control border border-border bg-surface-subtle px-4 py-8 text-center"
      >
        <p className="font-medium text-fg">{error}</p>
        {onRetry && (
          <Button variant="secondary" onClick={onRetry}>
            <Icon name="refresh" />
            Thử lại
          </Button>
        )}
      </div>
    );
  }
  if (pdfSrc) {
    return (
      <div className="flex flex-col gap-2">
        <iframe
          title={pdfTitle}
          src={pdfSrc}
          className="h-96 w-full rounded-control border border-border bg-surface"
        />
        {footer}
      </div>
    );
  }
  if (!current) return null;

  const go = (next: number) => {
    setIndex(next);
    setZoom(ZOOM_MIN);
    setTurn(0);
  };
  return (
    <div className="flex flex-col gap-2">
      <div className="overflow-auto rounded-control border border-border bg-surface-subtle p-2">
        <img
          src={current.src}
          alt={current.alt}
          style={{
            transform: `rotate(${turn}deg)`,
            width: `${zoom * 100}%`, // allow-number: phần trăm khung
          }}
          className="mx-auto block max-w-none origin-center transition-transform"
        />
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <Button
          variant="secondary"
          size="sm"
          disabled={zoom <= ZOOM_MIN}
          onClick={() => setZoom((z) => Math.max(ZOOM_MIN, z - ZOOM_STEP))}
        >
          <Icon name="zoomOut" />
          Thu nhỏ
        </Button>
        <Button
          variant="secondary"
          size="sm"
          disabled={zoom >= ZOOM_MAX}
          onClick={() => setZoom((z) => Math.min(ZOOM_MAX, z + ZOOM_STEP))}
        >
          <Icon name="zoomIn" />
          Phóng to
        </Button>
        <Button variant="secondary" size="sm" onClick={() => setTurn((t) => t + QUARTER_TURN)}>
          <Icon name="rotate" />
          Xoay
        </Button>
        <span className="ml-auto text-caption text-fg-muted">
          Trang {Math.min(index, list.length - 1) + 1}/{list.length}
        </span>
      </div>
      {list.length > 1 && (
        <ul className="flex gap-2 overflow-x-auto" aria-label="Các trang của bài nộp">
          {list.map((p, i) => (
            <li key={p.id}>
              <button
                type="button"
                aria-label={`Trang ${i + 1}`}
                aria-current={i === index ? 'true' : undefined}
                onClick={() => go(i)}
                className={cn(
                  'h-[72px] w-14 overflow-hidden rounded-sm bg-white', // allow-number: cỡ ảnh nhỏ theo khung canvas
                  i === index ? 'border-2 border-brand-600' : 'border border-border',
                )}
              >
                <img src={p.src} alt="" className="h-full w-full object-cover" />
              </button>
            </li>
          ))}
        </ul>
      )}
      {footer}
    </div>
  );
}
