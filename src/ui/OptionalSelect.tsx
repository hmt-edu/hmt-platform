import { Select } from './Overlays';

const NONE = '__none';

/** Ô chọn cho phép bỏ chọn ("Chưa chọn"): giá trị rỗng là chưa chọn. */
export function OptionalSelect({
  label,
  value,
  onChange,
  options,
  placeholder,
  disabled,
  invalid,
  requiredEmpty,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  placeholder: string;
  disabled?: boolean;
  invalid?: boolean;
  /** Ô bắt buộc còn trống: viền cam, nền cam nhạt. */
  requiredEmpty?: boolean;
}) {
  return (
    <Select
      label={label}
      value={value === '' ? NONE : value}
      onChange={(v) => onChange(v === NONE ? '' : v)}
      options={[{ value: NONE, label: placeholder }, ...options]}
      disabled={disabled}
      invalid={invalid}
      requiredEmpty={requiredEmpty}
      className="w-full"
    />
  );
}
