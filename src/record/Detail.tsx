// Khuôn K3 Chi tiết (bản ghi): thanh trên (tên loại bản ghi, Sửa / Lưu / Huỷ, hành động, phân trang), thanh
// giai đoạn, hàng nút nghiệp vụ + Sub-stage, nút liên kết (smart button) có số đếm, thân bản ghi, cột phải
// "Ghi chú & hoạt động". Ba chế độ: xem, sửa, tạo mới. Theo quyết định 13/10: mọi nút "Tạo" mở thẳng khuôn
// này ở trạng thái trống; giai đoạn, nút liên kết, ghi chú mờ cho đến khi lưu (khác gói v4: không có ngăn
// kéo "Tạo nhanh").
import type { ReactNode } from 'react';
import { Button, IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Icon, type IconName } from '../ui/icons';
import { DropdownMenu, type MenuItem } from '../ui/Overlays';
import { UnsavedGuard } from '../ui/Dialogs';
import { StageBar, type StageStep } from '../ui/Stage';
import { smartTarget, type SmartTarget, type SmartZeroBehavior } from './smartButton';

export type DetailMode = 'view' | 'edit' | 'create';

export type SmartItem = {
  key: string;
  label: string;
  icon: IconName;
  count: number;
  /** Gọi khi bấm: `target` cho biết mở danh sách (nhiều), mở thẳng bản ghi (một) hay danh sách rỗng (không có). */
  onOpen: (target: Exclude<SmartTarget, 'none'>) => void;
};

/** Hàng nút liên kết có số đếm. Mờ cho đến khi bản ghi được lưu (`disabled`). */
export function SmartButtons({
  items,
  disabled = false,
  zero = 'empty-list',
}: {
  items: SmartItem[];
  disabled?: boolean | undefined;
  zero?: SmartZeroBehavior | undefined;
}) {
  return (
    <ul
      aria-label="Bản ghi liên quan"
      className={cn(
        'grid grid-cols-2 overflow-hidden rounded-box border border-border bg-surface md:grid-cols-3 xl:grid-cols-6',
        disabled && 'opacity-50',
      )}
    >
      {items.map((item) => {
        const target = smartTarget(item.count, zero);
        return (
          <li
            key={item.key}
            className="border-r border-b border-border last:border-r-0 xl:border-b-0"
          >
            <button
              type="button"
              disabled={disabled || target === 'none'}
              aria-label={`${item.label}: ${item.count}`}
              onClick={() => target !== 'none' && item.onOpen(target)}
              className="focus-ring flex min-h-14 w-full items-center gap-2.5 px-3 py-2 text-left hover:bg-hover disabled:cursor-not-allowed disabled:hover:bg-transparent"
            >
              <Icon name={item.icon} className="shrink-0 text-fg-label" />
              <span className="min-w-0">
                <b className="tabular block text-h3 font-semibold">{item.count}</b>
                <span className="block truncate text-caption text-fg-muted">{item.label}</span>
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

/** Tên trường và giá trị trong thân bản ghi. */
export function DetailField({
  label,
  hint,
  required,
  mode,
  value,
  editor,
  error,
}: {
  label: string;
  /** Chú nhỏ cạnh nhãn ("bắt buộc từ L5"). */
  hint?: string | undefined;
  required?: boolean | undefined;
  mode: DetailMode;
  /** Giá trị khi xem. */
  value: ReactNode;
  /** Ô nhập khi sửa hoặc tạo mới. */
  editor?: ReactNode | undefined;
  error?: string | null | undefined;
}) {
  const editing = mode !== 'view' && editor !== undefined;
  return (
    <div className="grid min-h-8 grid-cols-1 items-center gap-1 py-1 sm:grid-cols-[150px_minmax(0,1fr)] sm:gap-2">
      <dt className="text-body font-semibold">
        {label}
        {required && editing && <span className="text-on-danger-subtle"> *</span>}
        {hint && <span className="ml-1.5 text-caption font-normal text-fg-muted">{hint}</span>}
      </dt>
      <dd className="min-w-0">
        {editing ? (
          <div className="flex flex-col gap-1">
            {editor}
            {error && (
              <p className="flex items-start gap-1 text-caption text-on-danger-subtle">
                <Icon name="alert" size={16} className="mt-px shrink-0" />
                {error}
              </p>
            )}
          </div>
        ) : (
          <span className="break-words">{value === '' || value === null ? '—' : value}</span>
        )}
      </dd>
    </div>
  );
}

/** Nhóm trường có tiêu đề nhỏ viết hoa (THÔNG TIN PHỤ HUYNH). */
export function DetailSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex min-w-0 flex-col">
      <h3 className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase">
        {title}
      </h3>
      <dl className="flex flex-col">{children}</dl>
    </section>
  );
}

export type DetailPager = {
  index: number;
  total: number;
  onPrev?: (() => void) | undefined;
  onNext?: (() => void) | undefined;
};

export function RecordDetail({
  kind,
  title,
  mode,
  dirty = false,
  saving = false,
  onEdit,
  onSave,
  onCancel,
  headerActions,
  attachments,
  menu,
  pager,
  onRefresh,
  stage,
  businessActions,
  subStage,
  smart,
  smartZero,
  children,
  aside,
}: {
  /** Tên loại bản ghi ở thanh trên ("Cơ hội"). */
  kind: string;
  /** Tên bản ghi to ở đầu thân (rỗng khi Tạo mới). */
  title: string;
  mode: DetailMode;
  /** Có thay đổi chưa lưu: rời trang thì hỏi (CHUNG-26). */
  dirty?: boolean | undefined;
  saving?: boolean | undefined;
  onEdit: () => void;
  onSave: () => void;
  onCancel: () => void;
  /** Nút cạnh Sửa (Tạo, Assign…). */
  headerActions?: ReactNode | undefined;
  attachments?: { count: number } | undefined;
  menu?: { label: string; items: MenuItem[] } | undefined;
  pager?: DetailPager | undefined;
  onRefresh?: (() => void) | undefined;
  stage?:
    | {
        steps: StageStep[];
        current: string;
        forwardOnly?: boolean | undefined;
        onSelect: (step: StageStep) => void;
        onLockedClick?: ((step: StageStep, reason: string) => void) | undefined;
      }
    | undefined;
  businessActions?: ReactNode | undefined;
  subStage?: ReactNode | undefined;
  smart?: SmartItem[] | undefined;
  smartZero?: SmartZeroBehavior | undefined;
  children: ReactNode;
  aside: ReactNode;
}) {
  const creating = mode === 'create';
  const editing = mode !== 'view';
  return (
    <div className="flex flex-col gap-3.5">
      <UnsavedGuard when={editing && dirty} />
      <header className="flex flex-wrap items-center gap-2 rounded-box border border-border bg-surface px-3 py-2.5">
        <h1 className="mr-1 font-display text-h2">{kind}</h1>
        {editing ? (
          <>
            <Button variant="primary" icon="checkMark" loading={saving} onClick={onSave}>
              Lưu
            </Button>
            <Button onClick={onCancel} disabled={saving}>
              Huỷ
            </Button>
          </>
        ) : (
          <>
            <Button variant="primary" icon="edit" onClick={onEdit}>
              Sửa
            </Button>
            {headerActions}
          </>
        )}
        <div className="ml-auto flex flex-wrap items-center gap-2">
          {attachments && !editing && (
            <Button variant="text" icon="attach" disabled title="Đính kèm có từ giai đoạn 4">
              Đính kèm ({attachments.count})
            </Button>
          )}
          {menu && !editing && (
            <DropdownMenu
              trigger={
                <Button variant="text" icon="chevronDown">
                  {menu.label}
                </Button>
              }
              items={menu.items}
            />
          )}
          {pager && !editing && (
            <div
              className="tabular flex items-center gap-1 text-body text-fg-label"
              aria-live="polite"
            >
              <span>
                {pager.index} / {pager.total}
              </span>
              <IconButton
                icon="chevronLeft"
                label="Bản ghi trước"
                disabled={!pager.onPrev}
                onClick={pager.onPrev}
              />
              <IconButton
                icon="chevronRight"
                label="Bản ghi sau"
                disabled={!pager.onNext}
                onClick={pager.onNext}
              />
            </div>
          )}
          {onRefresh && !creating && (
            <IconButton icon="refresh" label="Làm mới" bordered onClick={onRefresh} />
          )}
        </div>
      </header>

      <div className="flex flex-col gap-3.5 xl:flex-row xl:items-start">
        <div className="flex min-w-0 flex-1 flex-col gap-3.5">
          {stage && (
            <div className="rounded-box border border-border bg-surface p-2">
              <StageBar
                steps={stage.steps}
                current={stage.current}
                forwardOnly={stage.forwardOnly}
                onSelect={stage.onSelect}
                onLockedClick={stage.onLockedClick}
                disabled={creating}
              />
            </div>
          )}
          {(businessActions || subStage) && (
            <div
              className={cn(
                'flex flex-wrap items-center gap-2 rounded-box border border-border bg-surface p-3',
                creating && 'opacity-50',
              )}
              {...(creating ? { inert: true } : {})}
            >
              {businessActions}
              {subStage && <div className="ml-auto flex items-center gap-2">{subStage}</div>}
            </div>
          )}
          {smart && <SmartButtons items={smart} disabled={creating} zero={smartZero} />}
          <article className="rounded-box border border-border bg-surface px-6 pt-5 pb-6">
            <h2 className="mb-4 font-display text-h1">
              {title || (creating ? `${kind} mới` : kind)}
            </h2>
            {children}
          </article>
        </div>
        <aside aria-label="Ghi chú và hoạt động" className="w-full shrink-0 xl:w-[380px]">
          {aside}
        </aside>
      </div>
    </div>
  );
}
