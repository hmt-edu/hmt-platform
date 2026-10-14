import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { Link, type LinkProps } from 'react-router';
import { buttonClass, type ButtonVariant } from './buttonClass';
import { cn } from './cn';
import { Icon, type IconName } from './icons';

type CommonProps = {
  variant?: ButtonVariant | undefined;
  icon?: IconName | undefined;
  /** Đang xử lý: khoá nút, hiện vòng quay, giữ nguyên chữ để không nhảy bố cục. */
  loading?: boolean | undefined;
  fullWidth?: boolean | undefined;
  children: ReactNode;
};

export function Button({
  variant = 'secondary',
  icon,
  loading = false,
  fullWidth,
  className,
  disabled,
  type = 'button',
  children,
  ...rest
}: CommonProps & ButtonHTMLAttributes<HTMLButtonElement>) {
  const inactive = disabled || loading;
  return (
    <button
      {...rest}
      type={type}
      disabled={inactive}
      aria-busy={loading || undefined}
      className={buttonClass({ variant, disabled: inactive, fullWidth, className })}
    >
      {loading ? (
        <Icon name="loading" size={16} className="animate-spin" />
      ) : (
        icon && <Icon name={icon} size={16} />
      )}
      {children}
    </button>
  );
}

/** Liên kết có hình nút (điều hướng, không phải hành động). */
export function ButtonLink({
  variant = 'secondary',
  icon,
  fullWidth,
  className,
  children,
  ...rest
}: Omit<CommonProps, 'loading'> & LinkProps) {
  return (
    <Link {...rest} className={buttonClass({ variant, fullWidth, className })}>
      {icon && <Icon name={icon} size={16} />}
      {children}
    </Link>
  );
}

/** Nút chỉ có biểu tượng: bắt buộc có nhãn cho trình đọc màn hình; vùng chạm 44px. */
export function IconButton({
  icon,
  label,
  className,
  ...rest
}: { icon: IconName; label: string } & Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'>) {
  return (
    <button
      type="button"
      {...rest}
      aria-label={label}
      title={label}
      className={cn(
        'focus-ring touch-target inline-flex items-center justify-center rounded-control text-fg hover:bg-hover-overlay active:bg-pressed-overlay',
        className,
      )}
    >
      <Icon name={icon} />
    </button>
  );
}
