// Hộp thoại thao tác (K4, K4b, K4c, K4d, K07c) và cảnh báo rời trang (CHUNG-26). Thay hẳn alert/confirm/prompt.
// Năm biến thể của khuôn K4: ① xác nhận đơn giản (ConfirmDialog) ② bắt buộc lý do (ReasonDialog) ③ điền vài
// trường, có trường phụ thuộc (FormDialog) ④ chặn hoặc cảnh báo kèm danh sách (BlockingDialog) ⑤ nhiều bước
// (StepDialog); thêm xem trước tác động (ImpactDialog), chọn từ danh sách có kiểm tra (ChoiceDialog) và cảnh báo
// trùng (DuplicateDialog). Dưới 640px mọi hộp thành tấm trượt từ dưới lên (K4e). Nút xác nhận mờ cho tới khi đủ
// điều kiện. Chữ trên nút và câu thông báo do nơi dùng truyền vào, đúng theo gói thiết kế.
import { useEffect, useState, type ReactNode } from 'react';
import { AlertDialog } from 'radix-ui';
import { useBlocker } from 'react-router';
import { Button } from './Button';
import { cn } from './cn';
import { Alert } from './Feedback';
import { TextAreaField } from './Field';
import { Icon, type IconName } from './icons';
import { Dialog, Select } from './Overlays';
import { useMedia } from './useMedia';

const SCRIM = 'fixed inset-0 z-40 bg-scrim';

/** Khung hộp thoại hỏi (role alertdialog): focus mặc định ở nút Huỷ, đang xử lý thì không đóng được. */
function AlertShell({
  open,
  onOpenChange,
  busy = false,
  title,
  icon,
  tone = 'neutral',
  children,
  footer,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  busy?: boolean | undefined;
  title: string;
  icon?: IconName | undefined;
  tone?: 'neutral' | 'danger' | 'warning' | undefined;
  children: ReactNode;
  footer: ReactNode;
}) {
  const sheet = useMedia('(max-width: 639px)');
  return (
    <AlertDialog.Root open={open} onOpenChange={(next) => !busy && onOpenChange(next)}>
      <AlertDialog.Portal>
        <AlertDialog.Overlay className={SCRIM} />
        <AlertDialog.Content
          onEscapeKeyDown={(event) => busy && event.preventDefault()}
          className={cn(
            'fixed z-50 flex flex-col overflow-hidden bg-surface shadow-3 focus:outline-none',
            sheet
              ? 'inset-x-0 bottom-0 max-h-[90dvh] w-full rounded-t-box'
              : 'top-1/2 left-1/2 max-h-[90dvh] w-[calc(100vw-2rem)] max-w-[440px] -translate-x-1/2 -translate-y-1/2 rounded-box',
          )}
        >
          {sheet && (
            <span
              aria-hidden="true"
              className="mx-auto mt-2 h-1 w-10 shrink-0 rounded-full bg-neutral-300"
            />
          )}
          <div className="flex items-center gap-2 px-4 pt-4 pb-2">
            {icon && (
              <span
                className={cn(
                  'flex size-8 shrink-0 items-center justify-center rounded-full',
                  tone === 'danger' && 'bg-danger-subtle text-on-danger-subtle',
                  tone === 'warning' && 'bg-warning-subtle text-on-warning-subtle',
                  tone === 'neutral' && 'bg-surface-subtle text-fg-label',
                )}
              >
                <Icon name={icon} />
              </span>
            )}
            <AlertDialog.Title className="font-display text-h3">{title}</AlertDialog.Title>
          </div>
          <div className="flex min-h-0 flex-col gap-2.5 overflow-y-auto px-4 pt-1 pb-3 text-body-lg">
            {children}
          </div>
          <div className="flex flex-wrap justify-end gap-2 border-t border-border px-4 py-3">
            {footer}
          </div>
        </AlertDialog.Content>
      </AlertDialog.Portal>
    </AlertDialog.Root>
  );
}

function Describe({ children }: { children: ReactNode }) {
  return (
    <AlertDialog.Description asChild>
      <div className="flex flex-col gap-2.5">{children}</div>
    </AlertDialog.Description>
  );
}

function ErrorLine({ error }: { error?: string | null | undefined }) {
  return error ? <Alert tone="danger">{error}</Alert> : null;
}

export type SummaryRow = { label: string; value: ReactNode };

/** Bảng tóm tắt việc sắp làm (Phụ huynh, Học sinh, Gói, Số giờ, Thành tiền…). */
function Summary({ rows }: { rows: SummaryRow[] }) {
  return (
    <dl className="flex flex-col gap-1 rounded-control bg-canvas px-3 py-2.5 text-body">
      {rows.map((row) => (
        <div key={row.label} className="flex justify-between gap-3">
          <dt className="text-fg-muted">{row.label}</dt>
          <dd className="text-right font-semibold">{row.value}</dd>
        </div>
      ))}
    </dl>
  );
}

/** ① Xác nhận đơn giản: duyệt, trình, hoàn tất buổi. Có thể kèm tóm tắt và một dòng ghi chú. */
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  summary,
  description,
  note,
  confirmLabel,
  confirmIcon,
  cancelLabel = 'Huỷ',
  tone = 'primary',
  busy = false,
  error,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  summary?: SummaryRow[] | undefined;
  description?: ReactNode | undefined;
  /** Dòng chú nhỏ dưới tóm tắt ("Duyệt xong đơn tự khoá, không sửa được."). */
  note?: string | undefined;
  confirmLabel: string;
  confirmIcon?: IconName | undefined;
  cancelLabel?: string | undefined;
  /** `danger`: nút xác nhận viền đỏ, có biểu tượng (không dùng nền đỏ đặc cạnh nút cam). */
  tone?: 'primary' | 'danger' | undefined;
  busy?: boolean | undefined;
  error?: string | null | undefined;
  onConfirm: () => void;
}) {
  return (
    <AlertShell
      open={open}
      onOpenChange={onOpenChange}
      busy={busy}
      title={title}
      footer={
        <>
          <AlertDialog.Cancel asChild>
            <Button disabled={busy}>{cancelLabel}</Button>
          </AlertDialog.Cancel>
          <Button
            variant={tone === 'danger' ? 'danger' : 'primary'}
            icon={confirmIcon}
            loading={busy}
            onClick={onConfirm}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      <Describe>
        {summary && <Summary rows={summary} />}
        {description && <div>{description}</div>}
        {note && <p className="text-body text-fg-muted">{note}</p>}
        <ErrorLine error={error} />
      </Describe>
    </AlertShell>
  );
}

export type ReasonOption = { value: string; label: string; needsNote?: boolean };
export type ReasonResult = { option: string; note: string };

function ReasonBody({
  title,
  description,
  options,
  reasonLabel,
  noteLabel,
  notePlaceholder,
  confirmLabel,
  confirmIcon,
  cancelLabel,
  busy,
  error,
  onOpenChange,
  onConfirm,
}: {
  title: string;
  description?: ReactNode | undefined;
  options: ReasonOption[];
  reasonLabel: string;
  noteLabel: string;
  notePlaceholder: string;
  confirmLabel: string;
  confirmIcon: IconName;
  cancelLabel: string;
  busy: boolean;
  error?: string | null | undefined;
  onOpenChange: (open: boolean) => void;
  onConfirm: (result: ReasonResult) => void;
}) {
  const [option, setOption] = useState('');
  const [note, setNote] = useState('');
  const chosen = options.find((o) => o.value === option);
  // Luật: chưa chọn lý do thì chưa xác nhận được; lý do "Khác" (needsNote) thì bắt buộc ghi chú.
  const ready = chosen !== undefined && (!chosen.needsNote || note.trim() !== '');
  return (
    <AlertShell
      open
      onOpenChange={onOpenChange}
      busy={busy}
      title={title}
      footer={
        <>
          <AlertDialog.Cancel asChild>
            <Button disabled={busy}>{cancelLabel}</Button>
          </AlertDialog.Cancel>
          <Button
            variant="danger"
            icon={confirmIcon}
            loading={busy}
            disabled={!ready}
            onClick={() => onConfirm({ option, note: note.trim() })}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      <Describe>
        {description && <div>{description}</div>}
        <div className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label after:text-on-danger-subtle after:content-['_*']">
            {reasonLabel}
          </span>
          <Select
            label={reasonLabel}
            value={option}
            onChange={setOption}
            placeholder="Chọn lý do…"
            options={options.map((o) => ({ value: o.value, label: o.label }))}
            className="w-full"
          />
        </div>
        <TextAreaField
          label={noteLabel}
          placeholder={notePlaceholder}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
        <ErrorLine error={error} />
      </Describe>
    </AlertShell>
  );
}

/**
 * ② Bắt buộc lý do: huỷ, từ chối, đảo khoản, điều chỉnh giờ. Lý do chọn từ danh mục (đọc từ cơ sở dữ liệu);
 * mục có `needsNote` ("Khác") thì bắt buộc ghi chú. Nút xác nhận mờ cho tới khi đủ.
 */
export function ReasonDialog({
  open,
  onOpenChange,
  title,
  description,
  options,
  reasonLabel = 'Lý do',
  noteLabel = 'Ghi chú',
  notePlaceholder = 'Bắt buộc khi chọn “Khác”',
  confirmLabel,
  confirmIcon = 'cancelled',
  cancelLabel = 'Giữ lại',
  busy = false,
  error,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: ReactNode | undefined;
  options: ReasonOption[];
  reasonLabel?: string | undefined;
  noteLabel?: string | undefined;
  notePlaceholder?: string | undefined;
  confirmLabel: string;
  confirmIcon?: IconName | undefined;
  cancelLabel?: string | undefined;
  busy?: boolean | undefined;
  error?: string | null | undefined;
  onConfirm: (result: ReasonResult) => void;
}) {
  // Thân chỉ dựng khi mở: mỗi lần mở là ô lý do trống.
  if (!open) return null;
  return (
    <ReasonBody
      title={title}
      description={description}
      options={options}
      reasonLabel={reasonLabel}
      noteLabel={noteLabel}
      notePlaceholder={notePlaceholder}
      confirmLabel={confirmLabel}
      confirmIcon={confirmIcon}
      cancelLabel={cancelLabel}
      busy={busy}
      error={error}
      onOpenChange={onOpenChange}
      onConfirm={onConfirm}
    />
  );
}

/**
 * ③ Điền vài trường (giao sale, dời lịch, Assign…), kể cả trường phụ thuộc (chọn cơ sở rồi mới chọn nhân sự
 * thuộc cơ sở đó): nơi dùng dựng các ô trong `children`, truyền `canSubmit` để nút chính mờ cho tới khi đủ.
 */
export function FormDialog({
  open,
  onOpenChange,
  title,
  subtitle,
  children,
  confirmLabel,
  cancelLabel = 'Huỷ',
  canSubmit,
  busy = false,
  error,
  onSubmit,
  wide = false,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  /** Dòng phụ dưới tiêu đề (đối tượng đang thao tác). */
  subtitle?: ReactNode | undefined;
  children: ReactNode;
  confirmLabel: string;
  cancelLabel?: string | undefined;
  canSubmit: boolean;
  busy?: boolean | undefined;
  error?: string | null | undefined;
  onSubmit: () => void;
  wide?: boolean | undefined;
}) {
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => !busy && onOpenChange(next)}
      title={title}
      description={subtitle}
      wide={wide}
      dismissible={!busy}
      footer={
        <>
          <Button onClick={() => onOpenChange(false)} disabled={busy}>
            {cancelLabel}
          </Button>
          <Button variant="primary" loading={busy} disabled={!canSubmit} onClick={onSubmit}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      {children}
      <ErrorLine error={error} />
    </Dialog>
  );
}

export type BlockItem = { left: ReactNode; right?: ReactNode };
export type BlockReason = {
  text: string;
  goLabel?: string | undefined;
  onGo?: (() => void) | undefined;
};

/**
 * ④ Chặn hoặc cảnh báo kèm danh sách. `mode="block"`: chỉ có "Đã hiểu" (không làm được). `mode="warn"`:
 * "Huỷ" và nút tiếp (cảnh báo, không chặn). `reasons`: danh sách chỗ còn thiếu, mỗi dòng có thể có nút đi tới ô
 * cần điền (chuyển giai đoạn "cần đủ điều kiện").
 */
export function BlockingDialog({
  open,
  onOpenChange,
  mode = 'block',
  title,
  code,
  message,
  items,
  reasons,
  acknowledgeLabel = 'Đã hiểu',
  continueLabel = 'Tiếp',
  onContinue,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  mode?: 'block' | 'warn' | undefined;
  title: string;
  /** Mã bản ghi hiện dưới tiêu đề (CS1-2627-TOAN-K09-CB-A-001). */
  code?: string | undefined;
  message?: ReactNode | undefined;
  items?: BlockItem[] | undefined;
  reasons?: BlockReason[] | undefined;
  acknowledgeLabel?: string | undefined;
  continueLabel?: string | undefined;
  onContinue?: (() => void) | undefined;
}) {
  const warn = mode === 'warn';
  return (
    <AlertShell
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      icon={warn ? 'warning' : 'forbidden'}
      tone={warn ? 'warning' : 'danger'}
      footer={
        warn ? (
          <>
            <AlertDialog.Cancel asChild>
              <Button>Huỷ</Button>
            </AlertDialog.Cancel>
            <Button
              variant="primary"
              onClick={() => {
                onOpenChange(false);
                onContinue?.();
              }}
            >
              {continueLabel}
            </Button>
          </>
        ) : (
          <AlertDialog.Cancel asChild>
            <Button variant="primary">{acknowledgeLabel}</Button>
          </AlertDialog.Cancel>
        )
      }
    >
      <Describe>
        {code && <p className="tabular font-mono text-caption text-fg-muted">{code}</p>}
        {message && (
          <div
            className={cn(
              'flex items-start gap-2 rounded-control px-3 py-2.5 text-body',
              warn
                ? 'bg-warning-subtle text-on-warning-subtle'
                : 'bg-danger-subtle text-on-danger-subtle',
            )}
          >
            <Icon name={warn ? 'warning' : 'alert'} className="mt-px shrink-0" />
            <p>{message}</p>
          </div>
        )}
        {items && (
          <ul className="divide-y divide-surface-subtle text-body">
            {items.map((item, i) => (
              <li key={i} className="flex justify-between gap-3 py-1.5">
                <span>{item.left}</span>
                {item.right && <span className="tabular text-fg-muted">{item.right}</span>}
              </li>
            ))}
          </ul>
        )}
        {reasons && (
          <ul className="flex flex-col divide-y divide-border rounded-control border border-border">
            {reasons.map((reason) => (
              <li key={reason.text} className="flex items-center justify-between gap-3 px-3 py-2">
                <span>{reason.text}</span>
                {reason.onGo && (
                  <Button
                    variant="text"
                    onClick={() => {
                      onOpenChange(false);
                      reason.onGo?.();
                    }}
                  >
                    {reason.goLabel ?? 'Đến ô này'}
                  </Button>
                )}
              </li>
            ))}
          </ul>
        )}
      </Describe>
    </AlertShell>
  );
}

/** ⑤ Nhiều bước (nhập từ file: Tải file, Ghép cột, Xem trước). Nút "Tiếp" mờ cho tới khi bước đủ điều kiện. */
export function StepDialog({
  open,
  onOpenChange,
  title,
  steps,
  step,
  onStepChange,
  canNext,
  onFinish,
  finishLabel,
  busy = false,
  nextLabel = 'Tiếp',
  backLabel = 'Quay lại',
  hideBack = false,
  hideCancel = false,
  locked = false,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  steps: string[];
  /** Bước hiện tại, tính từ 0. */
  step: number;
  onStepChange: (step: number) => void;
  canNext: boolean;
  onFinish: () => void;
  /** Nút chính ở bước cuối ("Nhập"). */
  finishLabel: string;
  busy?: boolean | undefined;
  /** Nhãn nút «Tiếp» ở các bước giữa (ví dụ «Nạp thật» ở bước xem trước của QT-18). */
  nextLabel?: string | undefined;
  /** Nhãn nút quay lại (ví dụ «Đổi file»). */
  backLabel?: string | undefined;
  /** Ẩn nút quay lại (bước kết quả không quay lại được). */
  hideBack?: boolean | undefined;
  /** Ẩn nút Huỷ (bước kết quả chỉ còn nút chính). */
  hideCancel?: boolean | undefined;
  /** Khoá đóng hộp (Huỷ, Esc, bấm nền) cho tới khi người dùng làm xong việc bắt buộc (tải mật khẩu tạm). */
  locked?: boolean | undefined;
  children: ReactNode;
}) {
  const last = step === steps.length - 1;
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => !busy && !locked && onOpenChange(next)}
      title={title}
      wide
      dismissible={!busy && !locked}
      footer={
        <>
          {!hideCancel && (
            <Button onClick={() => onOpenChange(false)} disabled={busy || locked}>
              Huỷ
            </Button>
          )}
          {step > 0 && !hideBack && (
            <Button onClick={() => onStepChange(step - 1)} disabled={busy}>
              {backLabel}
            </Button>
          )}
          <Button
            variant="primary"
            loading={busy}
            disabled={!canNext}
            onClick={() => (last ? onFinish() : onStepChange(step + 1))}
          >
            {last ? finishLabel : nextLabel}
          </Button>
        </>
      }
    >
      <ol
        className="flex flex-wrap items-center gap-3 text-caption text-fg-muted"
        aria-label="Các bước"
      >
        {steps.map((name, i) => {
          const done = i < step;
          const on = i === step;
          return (
            <li
              key={name}
              aria-current={on ? 'step' : undefined}
              className="flex items-center gap-1.5"
            >
              <span
                className={cn(
                  'tabular inline-flex size-[22px] items-center justify-center rounded-full text-caption font-semibold',
                  done && 'bg-success-solid text-on-solid',
                  on && 'bg-stage-current text-fg',
                  !done && !on && 'bg-surface-subtle text-fg-label',
                )}
              >
                {done ? <Icon name="checkMark" size={16} /> : i + 1}
              </span>
              <span className={cn(on && 'font-semibold text-fg')}>{name}</span>
              {done && <span className="sr-only">(đã xong)</span>}
            </li>
          );
        })}
      </ol>
      {children}
    </Dialog>
  );
}

export type ImpactRow = { id: string; cells: ReactNode[]; warning?: string | undefined };

/**
 * Xem trước tác động trước khi xác nhận (đổi giáo viên 12 buổi): bảng các dòng bị đổi, dòng có vấn đề tô đỏ
 * kèm lý do. Chỉ cảnh báo, vẫn bấm Xác nhận được (K4c).
 */
export function ImpactDialog({
  open,
  onOpenChange,
  title,
  headline,
  totalLabel,
  warning,
  columns,
  rows,
  confirmLabel = 'Xác nhận',
  busy = false,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  /** Dòng mô tả việc sắp làm. */
  headline: ReactNode;
  /** Nhãn tổng ("Tổng 12 buổi bị đổi"). */
  totalLabel: string;
  warning?: ReactNode | undefined;
  columns: string[];
  rows: ImpactRow[];
  confirmLabel?: string | undefined;
  busy?: boolean | undefined;
  onConfirm: () => void;
}) {
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => !busy && onOpenChange(next)}
      title={title}
      wide
      dismissible={!busy}
      footer={
        <>
          <Button onClick={() => onOpenChange(false)} disabled={busy}>
            Huỷ
          </Button>
          <Button variant="primary" loading={busy} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <div className="flex flex-wrap items-center justify-between gap-2 text-body">
        <p>{headline}</p>
        <span className="rounded-tag bg-info-subtle px-2 py-0.5 text-caption font-medium text-on-info-subtle">
          {totalLabel}
        </span>
      </div>
      {warning && (
        <div className="flex items-start gap-2 rounded-control bg-warning-subtle px-3 py-2.5 text-body text-on-warning-subtle">
          <Icon name="warning" className="mt-px shrink-0" />
          <p>{warning}</p>
        </div>
      )}
      <div className="max-h-[320px] overflow-auto rounded-box border border-border">
        <table className="w-full border-collapse text-body">
          <thead className="sticky top-0 bg-surface-subtle text-caption font-semibold text-fg-label">
            <tr className="h-table-head">
              <th scope="col" className="w-10 px-2.5 text-left">
                #
              </th>
              {columns.map((c) => (
                <th key={c} scope="col" className="px-2.5 text-left whitespace-nowrap">
                  {c}
                </th>
              ))}
              <th scope="col" className="px-2.5 text-left">
                Kiểm tra
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr
                key={row.id}
                className={cn(
                  'h-row border-b border-surface-subtle',
                  row.warning && 'bg-danger-subtle',
                )}
              >
                <td className="tabular px-2.5 text-fg-muted">{index + 1}</td>
                {row.cells.map((cell, i) => (
                  <td key={i} className="px-2.5 whitespace-nowrap">
                    {cell}
                  </td>
                ))}
                <td className="px-2.5">
                  {row.warning ? (
                    <span className="flex items-center gap-1.5 text-on-danger-subtle">
                      <Icon name="warning" size={16} />
                      <span className="font-medium">Trùng lịch</span>
                      <span className="text-caption">{row.warning}</span>
                    </span>
                  ) : (
                    <>
                      <Icon name="checkMark" size={16} className="text-success-solid" />
                      <span className="sr-only">Hợp lệ</span>
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Dialog>
  );
}

export type ChoiceOption = {
  id: string;
  cells: ReactNode[];
  /** Lý do không chọn được; hiện tối đa 2, còn lại gộp "+N lý do". Rỗng hoặc không có = chọn được. */
  reasons?: string[] | undefined;
};

const MAX_REASONS_SHOWN = 2; // allow-number: tối đa hai lý do mỗi dòng rồi "+N lý do" (thiết kế K4d)

/**
 * Chọn từ danh sách có kiểm tra điều kiện (chọn lớp cho dòng đơn): mỗi dòng là một lựa chọn; dòng sai điều kiện
 * mờ đi, ghi tối đa hai lý do rồi "+N lý do". `children` là phần điền thêm (ngày vào lớp) dưới bảng; nút
 * "Chọn" mờ cho tới khi chọn một dòng hợp lệ và `canSubmit`.
 */
export function ChoiceDialog({
  open,
  onOpenChange,
  title,
  info,
  columns,
  options,
  value,
  onValueChange,
  canSubmit,
  confirmLabel = 'Chọn',
  children,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  info?: ReactNode | undefined;
  columns: string[];
  options: ChoiceOption[];
  value: string | null;
  onValueChange: (id: string) => void;
  canSubmit: boolean;
  confirmLabel?: string | undefined;
  children?: ReactNode | undefined;
  onConfirm: () => void;
}) {
  const chosen = options.find((o) => o.id === value);
  const valid = chosen !== undefined && (chosen.reasons?.length ?? 0) === 0;
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      wide
      footer={
        <>
          <Button onClick={() => onOpenChange(false)}>Huỷ</Button>
          <Button variant="primary" disabled={!valid || !canSubmit} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      {info && (
        <div className="flex items-start gap-2 rounded-control bg-info-subtle px-3 py-2.5 text-body text-on-info-subtle">
          <Icon name="info" className="mt-px shrink-0" />
          <p>{info}</p>
        </div>
      )}
      <div className="max-h-[300px] overflow-auto rounded-box border border-border">
        <table className="w-full border-collapse text-body" role="radiogroup" aria-label={title}>
          <thead className="sticky top-0 bg-surface-subtle text-caption font-semibold text-fg-label">
            <tr className="h-table-head">
              <th scope="col" className="w-10" />
              {columns.map((c) => (
                <th key={c} scope="col" className="px-2.5 text-left whitespace-nowrap">
                  {c}
                </th>
              ))}
              <th scope="col" className="px-2.5 text-left whitespace-nowrap">
                Không chọn được
              </th>
            </tr>
          </thead>
          <tbody>
            {options.map((option) => {
              const blocked = (option.reasons?.length ?? 0) > 0;
              const shown = option.reasons?.slice(0, MAX_REASONS_SHOWN) ?? [];
              const more = (option.reasons?.length ?? 0) - shown.length;
              return (
                <tr
                  key={option.id}
                  className={cn(
                    'border-b border-surface-subtle',
                    blocked && 'text-fg-muted',
                    value === option.id && 'bg-selected',
                  )}
                >
                  <td className="px-2.5 py-2">
                    <input
                      type="radio"
                      name="choice"
                      checked={value === option.id}
                      disabled={blocked}
                      onChange={() => onValueChange(option.id)}
                      aria-label={`Chọn ${option.id}`}
                      className="focus-ring size-4 accent-[var(--action-primary-bg)]"
                    />
                  </td>
                  {option.cells.map((cell, i) => (
                    <td key={i} className="px-2.5 py-2 align-top">
                      {cell}
                    </td>
                  ))}
                  <td className="px-2.5 py-2 align-top">
                    <ul className="flex flex-col gap-0.5">
                      {shown.map((reason) => (
                        <li
                          key={reason}
                          className="inline-flex items-start gap-1 rounded-tag bg-danger-subtle px-1.5 py-0.5 text-caption text-on-danger-subtle"
                        >
                          <Icon name="forbidden" size={16} className="shrink-0" />
                          {reason}
                        </li>
                      ))}
                      {more > 0 && <li className="text-caption text-fg-muted">+{more} lý do</li>}
                    </ul>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      {children}
    </Dialog>
  );
}

/**
 * Cảnh báo trùng (K07c, TS-14): hiện khi bấm Lưu mà số điện thoại đã có hồ sơ. Không có nút Huỷ: đóng bằng dấu
 * X ở góc (đóng là quay lại biểu mẫu, chưa lưu). Hai lựa chọn: gắn vào hồ sơ có sẵn, hoặc vẫn tạo mới.
 */
/** Nhóm hồ sơ trùng trong hộp cảnh báo (TS-14): "Lead đã có", "Phụ huynh đã có" kèm các dòng mã · tên. */
export type DuplicateGroup = { title: string; lines: ReactNode[] };

export function DuplicateDialog({
  open,
  onOpenChange,
  title = 'Số điện thoại này đã có hồ sơ',
  existingCode,
  existingName,
  groups,
  phone,
  canAttach = true,
  onAttach,
  onCreateNew,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title?: string | undefined;
  /** Một hồ sơ trùng (bản gọn). Có `groups` thì dùng danh sách nhóm, bỏ hai ô này. */
  existingCode?: string | undefined;
  existingName?: string | undefined;
  /** Danh sách hồ sơ trùng theo nhóm (lead, phụ huynh): dùng cho TS-14. */
  groups?: DuplicateGroup[] | undefined;
  /** Số điện thoại đã định dạng, nêu trong câu giải thích khi dùng `groups`. */
  phone?: string | undefined;
  /** Không có hồ sơ phụ huynh để gắn vào thì ẩn nút "Gắn vào hồ sơ có sẵn". */
  canAttach?: boolean | undefined;
  onAttach: () => void;
  onCreateNew: () => void;
}) {
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      footer={
        <>
          <Button
            onClick={() => {
              onOpenChange(false);
              onCreateNew();
            }}
          >
            Vẫn tạo mới
          </Button>
          {canAttach && (
            <Button
              variant="primary"
              onClick={() => {
                onOpenChange(false);
                onAttach();
              }}
            >
              Gắn vào hồ sơ có sẵn
            </Button>
          )}
        </>
      }
    >
      {groups ? (
        <div className="flex flex-col gap-3">
          {groups.map((group) => (
            <section key={group.title} aria-label={group.title}>
              <h3 className="mb-1 text-caption font-semibold text-fg-muted">{group.title}</h3>
              <ul className="flex flex-col gap-1 rounded-control bg-warning-subtle px-3 py-2.5 text-body text-on-warning-subtle">
                {group.lines.map((line, i) => (
                  <li key={i}>{line}</li>
                ))}
              </ul>
            </section>
          ))}
          <p className="text-fg-muted">
            {phone ? `Số ${phone} trùng với hồ sơ trên. ` : ''}
            {canAttach
              ? 'Gắn vào hồ sơ có sẵn nếu là cùng một khách, hoặc vẫn tạo mới nếu là khách khác.'
              : 'Vẫn tạo mới nếu là khách khác.'}
          </p>
        </div>
      ) : (
        <div className="flex items-start gap-2 rounded-control bg-warning-subtle px-3 py-2.5 text-body text-on-warning-subtle">
          <Icon name="warning" className="mt-px shrink-0" />
          <p>
            Số này đã có <b>{existingCode}</b> ({existingName}). Không chặn: bạn gắn vào hồ sơ có
            sẵn hoặc vẫn tạo hồ sơ mới.
          </p>
        </div>
      )}
    </Dialog>
  );
}

/**
 * CHUNG-26 · Cảnh báo rời trang khi còn thay đổi chưa lưu (bản ghi đang Sửa). Đóng tab, tải lại trang thì
 * trình duyệt tự hỏi (không thay được hộp thoại đó).
 */
export function UnsavedGuard({
  when,
  title = 'Rời trang khi chưa lưu?',
  description = 'Các thay đổi bạn vừa nhập chưa được lưu. Rời trang thì các thay đổi này sẽ mất.',
  stayLabel = 'Ở lại',
  leaveLabel = 'Rời trang',
}: {
  when: boolean;
  /** Chữ riêng của từng màn (ví dụ GV-05 theo khung); mặc định là chữ khuôn CHUNG-26. */
  title?: string;
  description?: string;
  stayLabel?: string;
  leaveLabel?: string;
}) {
  const blocker = useBlocker(when);

  useEffect(() => {
    if (!when) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [when]);

  return (
    <AlertShell
      open={blocker.state === 'blocked'}
      onOpenChange={(open) => !open && blocker.reset?.()}
      title={title}
      footer={
        <>
          <AlertDialog.Cancel asChild>
            <Button variant="primary">{stayLabel}</Button>
          </AlertDialog.Cancel>
          <Button variant="danger" icon="logout" onClick={() => blocker.proceed?.()}>
            {leaveLabel}
          </Button>
        </>
      }
    >
      <Describe>
        <p className="text-fg-muted">{description}</p>
      </Describe>
    </AlertShell>
  );
}
