import type { ReactNode } from 'react';
import { cn } from './cn';
import { Icon, type IconName } from './icons';

export type AlertTone = 'info' | 'success' | 'warning' | 'danger';

// Theo .hmt-alert của gói: nền nhạt theo tông, chữ đậm, bo 6px, không viền; luôn có biểu tượng.
const TONES: Record<AlertTone, { box: string; icon: IconName }> = {
  info: { box: 'bg-info-subtle text-on-info-subtle', icon: 'info' },
  success: { box: 'bg-success-subtle text-on-success-subtle', icon: 'check' },
  warning: { box: 'bg-warning-subtle text-on-warning-subtle', icon: 'warning' },
  danger: { box: 'bg-danger-subtle text-on-danger-subtle', icon: 'alert' },
};

/** Thông báo tại chỗ: luôn có biểu tượng + chữ (không chỉ dùng màu). Lỗi thì đọc ngay (role=alert). */
export function Alert({
  tone = 'info',
  title,
  icon,
  children,
  className,
}: {
  tone?: AlertTone | undefined;
  /** Biểu tượng riêng thay cho biểu tượng mặc định của tông. */
  icon?: IconName | undefined;
  title?: string | undefined;
  children: ReactNode;
  className?: string | undefined;
}) {
  const style = TONES[tone];
  return (
    <div
      role={tone === 'danger' ? 'alert' : 'status'}
      className={cn(
        'flex items-start gap-2.5 rounded-control px-3 py-2.5 text-body',
        style.box,
        className,
      )}
    >
      <Icon name={icon ?? style.icon} className="mt-px shrink-0" />
      <div className="min-w-0">
        {title && <p className="font-semibold">{title}</p>}
        <div>{children}</div>
      </div>
    </div>
  );
}

export function Spinner({ label = 'Đang tải…' }: { label?: string }) {
  return (
    <p role="status" className="flex items-center justify-center gap-2 py-8 text-fg-muted">
      <Icon name="loading" className="animate-spin" />
      {label}
    </p>
  );
}

export type StateKind =
  'empty' | 'error' | 'forbidden' | 'not-found' | 'feature-off' | 'coming-soon';

const STATE_ICON: Record<StateKind, IconName> = {
  empty: 'info',
  error: 'warning',
  forbidden: 'forbidden',
  'not-found': 'search',
  'feature-off': 'config',
  'coming-soon': 'comingSoon',
};

/** Trạng thái thay cho nội dung: trống, lỗi, không có quyền, không tìm thấy, phân hệ chưa bật, sắp có. */
export function StateView({
  kind,
  title,
  children,
  actions,
  headingLevel = 1,
}: {
  kind: StateKind;
  title: string;
  children?: ReactNode | undefined;
  actions?: ReactNode | undefined;
  headingLevel?: 1 | 2 | undefined;
}) {
  const Heading = headingLevel === 1 ? 'h1' : 'h2';
  return (
    <section
      role={kind === 'error' || kind === 'forbidden' ? 'alert' : undefined}
      className="mx-auto flex max-w-lg flex-col items-center gap-2 px-4 py-12 text-center"
    >
      <span className="flex size-10 items-center justify-center text-fg-muted">
        <Icon name={STATE_ICON[kind]} size={24} />
      </span>
      <Heading className="text-h4">{title}</Heading>
      {children && <div className="text-fg-muted">{children}</div>}
      {actions && <div className="mt-2 flex flex-wrap justify-center gap-2">{actions}</div>}
    </section>
  );
}

/** Ảnh đại diện bằng chữ cái đầu của hai từ cuối trong tên. */
export function Avatar({ name, large = false }: { name: string; large?: boolean }) {
  const words = name
    .replace(/\(.*?\)/g, '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  const initials = words
    .slice(-2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
  return (
    <span
      aria-hidden="true"
      className={cn(
        'flex shrink-0 items-center justify-center rounded-full bg-brand-100 text-caption font-semibold text-brand-800',
        large ? 'size-[30px]' : 'size-6',
      )}
    >
      {initials || '?'}
    </span>
  );
}

/** Số đếm trên menu, chuông (ẩn khi bằng 0). */
export function CountBadge({ count, label }: { count: number; label: string }) {
  if (count <= 0) return null;
  return (
    <span className="tabular inline-flex min-w-5 items-center justify-center rounded-full bg-danger-solid px-1 text-caption font-semibold text-on-solid">
      <span aria-hidden="true">{count}</span>
      <span className="sr-only">
        {count} {label}
      </span>
    </span>
  );
}
