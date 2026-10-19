import {
  useId,
  useState,
  type InputHTMLAttributes,
  type ReactNode,
  type TextareaHTMLAttributes,
} from 'react';
import { cn } from './cn';
import { Icon } from './icons';

// Theo .hmt-input của gói: cao 32px, viền #8A8076 1px, bo 6px, lề 10px; lỗi: viền đỏ 2px; chỉ đọc: nền xám nhạt.
// cn() chỉ nối chuỗi, không gỡ lớp trùng thuộc tính: ô cần cao hay rộng khác thì dùng hằng riêng, không ghi đè.
const INPUT_FRAME =
  'focus-ring tap rounded-control border border-border-strong bg-surface px-2.5 text-fg placeholder:text-fg-muted focus-visible:border-focus [&[readonly]]:border-border [&[readonly]]:bg-surface-subtle disabled:cursor-not-allowed disabled:border-border disabled:bg-surface-subtle disabled:text-fg-disabled aria-[invalid=true]:border-2 aria-[invalid=true]:border-danger-solid data-[required-empty=true]:border-brand-500 data-[required-empty=true]:bg-brand-50';

/** Ô nhập một dòng. */
export const INPUT_CLASS = `${INPUT_FRAME} h-control w-full text-body`;
/** Ô nhập nhiều dòng (cao tối thiểu 72px). */
export const TEXTAREA_CLASS = `${INPUT_FRAME} min-h-[72px] w-full py-2 text-body`;
/** Nút có hình ô nhập, rộng theo nội dung (ô chọn khoảng ngày, chọn một giá trị). */
export const INPUT_BUTTON_CLASS = `${INPUT_FRAME} inline-flex h-control items-center gap-2 text-body whitespace-nowrap`;

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
  invalid,
  children,
  className,
}: {
  label: string;
  required?: boolean | undefined;
  help?: ReactNode | undefined;
  error?: string | null | undefined;
  /** Tô viền đỏ mà không hiện câu lỗi riêng (lỗi đã nói ở khối cảnh báo của trang). */
  invalid?: boolean | undefined;
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
          'text-caption font-semibold text-fg-label',
          required && "after:text-on-danger-subtle after:content-['_*']",
        )}
      >
        {label}
      </label>
      {children({
        id,
        'aria-describedby': [errorId, helpId].filter(Boolean).join(' ') || undefined,
        'aria-invalid': error || invalid ? true : undefined,
        'aria-required': required ? true : undefined,
      })}
      {error && (
        <p id={errorId} className="flex items-start gap-1 text-caption text-on-danger-subtle">
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
  invalid?: boolean | undefined;
} & Omit<InputHTMLAttributes<HTMLInputElement>, 'id' | 'className'>;

export function TextField({ label, help, error, invalid, required, ...input }: TextFieldProps) {
  return (
    <Field label={label} help={help} error={error} invalid={invalid} required={required}>
      {(field) => <input {...input} {...field} className={INPUT_CLASS} />}
    </Field>
  );
}

/** Ô mật khẩu có nút Hiện/Ẩn (nút là chữ, không chỉ biểu tượng). */
export function PasswordInput({ label, help, error, invalid, required, ...input }: TextFieldProps) {
  const [shown, setShown] = useState(false);
  return (
    <Field label={label} help={help} error={error} invalid={invalid} required={required}>
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
            className="focus-ring absolute inset-y-1 right-1 rounded-tag px-2 text-caption font-semibold text-link hover:bg-hover"
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
 * Ô nhập mã 6 số (TOTP) vẽ thành sáu ô rời như bản vẽ P1, nhưng bên dưới vẫn là **một** ô nhập thật (trong suốt,
 * phủ kín sáu ô): điện thoại tự điền mã (autocomplete one-time-code), dán mã, bàn phím và trình đọc màn hình
 * chạy đúng như một ô. `invalid` tô viền đỏ; câu lỗi do trang hiện ở khối cảnh báo.
 */
export function OtpInput({
  label,
  value,
  onChange,
  invalid,
  autoFocus,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  invalid?: boolean | undefined;
  autoFocus?: boolean | undefined;
}) {
  const id = useId();
  const [focused, setFocused] = useState(false);
  const active = Math.min(value.length, OTP_LENGTH - 1);
  return (
    <div className="flex flex-col items-center">
      <label htmlFor={id} className="sr-only">
        {label}
      </label>
      <div className="relative flex gap-2">
        {Array.from({ length: OTP_LENGTH }, (_, i) => (
          <span
            key={i}
            aria-hidden="true"
            className={cn(
              'flex h-14 w-12 items-center justify-center rounded-control border bg-surface text-h2 tabular text-fg',
              invalid ? 'border-danger-solid' : 'border-border-strong',
              focused && i === active && 'border-focus ring-2 ring-focus/40',
            )}
          >
            {value[i] ?? ''}
          </span>
        ))}
        <input
          id={id}
          name="totp"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern={`[0-9]{${OTP_LENGTH}}`}
          maxLength={OTP_LENGTH}
          autoFocus={autoFocus}
          aria-required="true"
          aria-invalid={invalid ? true : undefined}
          value={value}
          onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, OTP_LENGTH))}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          className="absolute inset-0 h-full w-full cursor-text opacity-0"
        />
      </div>
    </div>
  );
}

/** Ô nhập nhiều dòng (ghi chú, lý do). */
export function TextAreaField({
  label,
  help,
  error,
  required,
  ...input
}: {
  label: string;
  help?: ReactNode | undefined;
  error?: string | null | undefined;
} & Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, 'id' | 'className'>) {
  return (
    <Field label={label} help={help} error={error} required={required}>
      {(field) => <textarea {...input} {...field} className={TEXTAREA_CLASS} />}
    </Field>
  );
}

/** Ô tick. Nhãn đi kèm là chữ, bấm vào nhãn cũng bật tắt; trên điện thoại cao 44px. */
export function Checkbox({
  label,
  className,
  ...input
}: { label: ReactNode } & Omit<InputHTMLAttributes<HTMLInputElement>, 'type' | 'className'> & {
    className?: string | undefined;
  }) {
  return (
    <label
      className={cn(
        'flex min-h-control cursor-pointer items-center gap-2 text-body max-md:min-h-target',
        input.disabled && 'cursor-not-allowed text-fg-disabled',
        className,
      )}
    >
      <input
        {...input}
        type="checkbox"
        className="focus-ring size-4 shrink-0 accent-[var(--action-primary-bg)]"
      />
      {label}
    </label>
  );
}
