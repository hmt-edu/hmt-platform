import { useId, useState, type InputHTMLAttributes, type ReactNode } from 'react';
import { cn } from './cn';
import { Icon } from './icons';

export const INPUT_CLASS =
  'focus-ring tap h-control w-full rounded-control border border-border-strong bg-surface px-3 text-body text-fg placeholder:text-fg-muted disabled:cursor-not-allowed disabled:border-disabled-border disabled:bg-disabled disabled:text-on-disabled aria-[invalid=true]:border-danger-border';

type FieldRenderProps = {
  id: string;
  'aria-describedby': string | undefined;
  'aria-invalid': true | undefined;
  'aria-required': true | undefined;
};

/** Bọc mọi ô nhập: nhãn, dấu bắt buộc, gợi ý, lỗi tại chỗ (nối bằng aria). */
export function Field({
  label,
  required,
  help,
  error,
  children,
  className,
}: {
  label: string;
  required?: boolean | undefined;
  help?: ReactNode | undefined;
  error?: string | null | undefined;
  children: (props: FieldRenderProps) => ReactNode;
  className?: string | undefined;
}) {
  const id = useId();
  const helpId = help ? `${id}-help` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  return (
    <div className={cn('flex flex-col gap-1', className)}>
      {/* Dấu sao bắt buộc vẽ bằng CSS để không lẫn vào tên nhãn; trình đọc màn hình nghe qua aria-required. */}
      <label
        htmlFor={id}
        className={cn(
          'text-caption font-semibold text-fg',
          required && "after:text-danger after:content-['_*']",
        )}
      >
        {label}
      </label>
      {children({
        id,
        'aria-describedby': [errorId, helpId].filter(Boolean).join(' ') || undefined,
        'aria-invalid': error ? true : undefined,
        'aria-required': required ? true : undefined,
      })}
      {error && (
        <p id={errorId} className="flex items-start gap-1 text-caption font-semibold text-danger">
          <Icon name="alert" size={16} className="mt-px shrink-0" />
          {error}
        </p>
      )}
      {help && (
        <p id={helpId} className="text-caption text-fg-muted">
          {help}
        </p>
      )}
    </div>
  );
}

type TextFieldProps = {
  label: string;
  help?: ReactNode | undefined;
  error?: string | null | undefined;
} & Omit<InputHTMLAttributes<HTMLInputElement>, 'id' | 'className'>;

export function TextField({ label, help, error, required, ...input }: TextFieldProps) {
  return (
    <Field label={label} help={help} error={error} required={required}>
      {(field) => <input {...input} {...field} className={INPUT_CLASS} />}
    </Field>
  );
}

/** Ô mật khẩu có nút Hiện/Ẩn (nút là chữ, không chỉ biểu tượng). */
export function PasswordInput({ label, help, error, required, ...input }: TextFieldProps) {
  const [shown, setShown] = useState(false);
  return (
    <Field label={label} help={help} error={error} required={required}>
      {(field) => (
        <div className="relative">
          <input
            {...input}
            {...field}
            type={shown ? 'text' : 'password'}
            className={cn(INPUT_CLASS, 'pr-16')}
          />
          <button
            type="button"
            onClick={() => setShown((v) => !v)}
            aria-pressed={shown}
            aria-label={shown ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
            className="focus-ring absolute inset-y-1 right-1 rounded-tag px-2 text-caption font-semibold text-link hover:bg-hover-overlay"
          >
            {shown ? 'Ẩn' : 'Hiện'}
          </button>
        </div>
      )}
    </Field>
  );
}

const OTP_LENGTH = 6;

/**
 * Ô nhập mã 6 số (TOTP). Một ô duy nhất thay cho 6 ô rời như bản vẽ: để điện thoại tự điền mã
 * (autocomplete one-time-code), dán mã và trình đọc màn hình đều chạy đúng.
 */
export function OtpInput({
  label,
  value,
  onChange,
  error,
  autoFocus,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  error?: string | null | undefined;
  autoFocus?: boolean | undefined;
}) {
  return (
    <Field label={label} error={error} required help={`Mã gồm ${OTP_LENGTH} chữ số.`}>
      {(field) => (
        <input
          {...field}
          name="totp"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern={`[0-9]{${OTP_LENGTH}}`}
          maxLength={OTP_LENGTH}
          autoFocus={autoFocus}
          value={value}
          onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, OTP_LENGTH))}
          className={cn(INPUT_CLASS, 'tabular text-center text-h2 tracking-[0.5em]')}
        />
      )}
    </Field>
  );
}
