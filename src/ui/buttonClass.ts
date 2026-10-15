import { cn } from './cn';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'text';
export type ButtonSize = 'sm' | 'md' | 'lg';

// Theo .hmt-btn của gói thiết kế: cao 32px, bo 6px, viền #8A8076, chữ 13px/500. Mỗi màn một nút chính.
const BASE =
  'focus-ring tap inline-flex items-center gap-1.5 rounded-control border px-3 text-body font-medium whitespace-nowrap transition-colors duration-150 select-none';

const SIZES: Record<ButtonSize, string> = {
  sm: 'h-control-sm px-2 text-caption',
  md: 'h-control',
  lg: 'h-control-lg px-4 text-body-lg',
};

const VARIANTS: Record<ButtonVariant, string> = {
  primary:
    'border-action bg-action font-semibold text-on-action hover:border-action-hover hover:bg-action-hover',
  secondary: 'border-border-strong bg-surface text-fg hover:bg-hover',
  // Nút nguy hiểm: nền trắng, viền và chữ đỏ, luôn có biểu tượng đi kèm.
  danger: 'border-danger-action bg-surface text-danger-action hover:bg-danger-subtle',
  text: 'border-transparent bg-transparent px-2 text-link hover:bg-hover hover:text-brand-800',
  ghost: 'border-transparent bg-transparent text-fg hover:bg-hover',
};

const DISABLED =
  'cursor-not-allowed border-border bg-surface-subtle text-fg-disabled hover:bg-surface-subtle hover:border-border';

/** Lớp CSS của nút (dùng chung cho <button> và liên kết có hình nút). */
export function buttonClass({
  variant = 'secondary',
  size = 'md',
  disabled,
  fullWidth,
  align = 'center',
  className,
}: {
  variant?: ButtonVariant | undefined;
  size?: ButtonSize | undefined;
  disabled?: boolean | undefined;
  fullWidth?: boolean | undefined;
  /** Canh chữ trong nút (nút trong danh sách dọc thì canh trái). */
  align?: 'center' | 'start' | undefined;
  className?: string | undefined;
}): string {
  return cn(
    BASE,
    SIZES[size],
    align === 'start' ? 'justify-start' : 'justify-center',
    disabled ? DISABLED : VARIANTS[variant],
    fullWidth && 'w-full',
    className,
  );
}
