import { cn } from './cn';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

const BASE =
  'focus-ring tap inline-flex h-control items-center justify-center gap-2 rounded-md px-[var(--hmt-density-control-px)] text-body font-medium whitespace-nowrap transition-colors duration-150 select-none';

const VARIANTS: Record<ButtonVariant, string> = {
  // Một nút cam mỗi vùng (nguyên tắc "cam có kỷ luật").
  primary: 'bg-action text-on-action hover:bg-action-hover active:bg-action-pressed',
  secondary:
    'border border-border-strong bg-surface text-fg hover:bg-hover-overlay active:bg-pressed-overlay',
  ghost: 'text-fg hover:bg-hover-overlay active:bg-pressed-overlay',
  danger: 'bg-danger-solid text-on-danger-solid hover:opacity-90',
};

const DISABLED =
  'cursor-not-allowed border border-disabled-border bg-disabled text-on-disabled hover:bg-disabled';

/** Lớp CSS của nút (dùng chung cho <button> và liên kết có hình nút). */
export function buttonClass({
  variant = 'secondary',
  disabled,
  fullWidth,
  className,
}: {
  variant?: ButtonVariant | undefined;
  disabled?: boolean | undefined;
  fullWidth?: boolean | undefined;
  className?: string | undefined;
}): string {
  return cn(BASE, disabled ? DISABLED : VARIANTS[variant], fullWidth && 'w-full', className);
}
