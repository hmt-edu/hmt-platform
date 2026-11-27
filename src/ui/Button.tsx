import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { Link, type LinkProps } from 'react-router';
import { buttonClass, type ButtonSize, type ButtonVariant } from './buttonClass';
import { cn } from './cn';
import { Icon, type IconName } from './icons';

type CommonProps = {
  variant?: ButtonVariant | undefined;
  size?: ButtonSize | undefined;
  icon?: IconName | undefined;
  /** Đang xử lý: khoá nút, hiện vòng quay, giữ nguyên chữ để không nhảy bố cục. */
  loading?: boolean | undefined;
  fullWidth?: boolean | undefined;
  /** Canh chữ trong nút (nút trong danh sách dọc thì canh trái). */
  align?: 'center' | 'start' | undefined;
  children: ReactNode;
};

export function Button({
  variant = 'secondary',
  size,
  icon,
  loading = false,
  fullWidth,
  align,
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
      className={buttonClass({ variant, size, disabled: inactive, fullWidth, align, className })}
    >
      {loading ? (
        <Icon name="loading" size={16} className="animate-spin motion-reduce:animate-none" />
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
  size,
  icon,
  fullWidth,
  align,
  className,
  children,
  ...rest
}: Omit<CommonProps, 'loading'> & LinkProps) {
  return (
    <Link {...rest} className={buttonClass({ variant, size, fullWidth, align, className })}>
      {icon && <Icon name={icon} size={16} />}
      {children}
    </Link>
  );
}

/** Nút chỉ có biểu tượng: bắt buộc có nhãn cho trình đọc màn hình; 32px, trên điện thoại 44px. */
export function IconButton({
  icon,
  label,
  bordered = false,
  className,
  loading = false,
  disabled,
  ...rest
}: {
  icon: IconName;
  label: string;
  /** Đang xử lý: khoá nút, biểu tượng quay. */
  loading?: boolean | undefined;
  /** Có viền (kiểu .hmt-iconbtn-b) khi đứng riêng trên thanh công cụ. */
  bordered?: boolean | undefined;
} & Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'>) {
  return (
    <button
      type="button"
      {...rest}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      aria-label={label}
      title={label}
      className={cn(
        'focus-ring relative inline-flex size-control shrink-0 items-center justify-center rounded-control text-fg-label hover:bg-hover disabled:cursor-not-allowed disabled:text-fg-disabled disabled:hover:bg-transparent max-md:size-target',
        bordered && 'border border-border-strong bg-surface',
        className,
      )}
    >
      <Icon
        name={loading ? 'loading' : icon}
        className={loading ? 'animate-spin motion-reduce:animate-none' : undefined}
      />
    </button>
  );
}
