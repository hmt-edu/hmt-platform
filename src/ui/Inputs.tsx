// Ô nhập chuyên biệt của biểu mẫu (K07): chọn có tìm (Combobox), ngày (DateInput, DateRange), tiền, đính kèm.
import { useEffect, useId, useMemo, useState } from 'react';
import { Command } from 'cmdk';
import { DayPicker, type DateRange as PickerRange } from 'react-day-picker';
import { vi } from 'react-day-picker/locale';
import { formatDmy, maskDmy, parseDmy } from '../lib/dateText';
import { datePresetRange } from '../lib/dateRange';
import { foldText, formatNumber, parseMoney } from '../lib/format';
import { Button } from './Button';
import { cn } from './cn';
import { Field, INPUT_BUTTON_CLASS, INPUT_CLASS } from './Field';
import { Icon } from './icons';
import { Popover } from './Overlays';

export type ComboOption = {
  value: string;
  label: string;
  /** Dòng phụ: mã, cơ sở, sĩ số… */
  hint?: string | undefined;
  /** Chữ để tìm thêm ngoài nhãn (mã, mã cũ). */
  keywords?: string | undefined;
  /** Không chọn được, kèm lý do ("Hết chỗ"). */
  disabledReason?: string | undefined;
};

/**
 * Ô chọn có tìm, không cần gõ dấu. `multiple`: chọn nhiều, mỗi lựa chọn là một thẻ có nút bỏ.
 * Danh sách dài lấy từ máy chủ: truyền `onSearch` và `loading`, khi đó không lọc ở trình duyệt.
 */
export function Combobox({
  label,
  options,
  value,
  onChange,
  multiple = false,
  placeholder = 'Chọn…',
  required,
  error,
  help,
  disabled,
  loading,
  onSearch,
  compact = false,
}: {
  label: string;
  options: ComboOption[];
  value: string[];
  onChange: (value: string[]) => void;
  multiple?: boolean | undefined;
  placeholder?: string | undefined;
  required?: boolean | undefined;
  error?: string | null | undefined;
  help?: string | undefined;
  disabled?: boolean | undefined;
  loading?: boolean | undefined;
  onSearch?: ((query: string) => void) | undefined;
  /** Không hiện nhãn phía trên (đặt trong hàng điều kiện lọc, nhãn đã có ở ô bên cạnh). */
  compact?: boolean | undefined;
}) {
  const [open, setOpen] = useState(false);
  const listId = useId();
  const selected = options.filter((o) => value.includes(o.value));

  const pick = (option: ComboOption) => {
    if (option.disabledReason) return;
    if (multiple) {
      onChange(
        value.includes(option.value)
          ? value.filter((v) => v !== option.value)
          : [...value, option.value],
      );
    } else {
      onChange([option.value]);
      setOpen(false);
    }
  };

  const trigger = (field: Record<string, unknown>) => (
    <Popover
      open={open}
      onOpenChange={setOpen}
      className="w-[var(--radix-popover-trigger-width)] min-w-64 p-0"
      trigger={
        <button
          type="button"
          {...field}
          {...(compact ? { 'aria-label': label } : {})}
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          disabled={disabled}
          className={cn(INPUT_CLASS, 'flex items-center justify-between gap-2 text-left')}
        >
          <span className={cn('min-w-0 truncate', selected.length === 0 && 'text-fg-muted')}>
            {selected.length === 0
              ? placeholder
              : multiple
                ? selected.length === 1
                  ? selected[0]?.label
                  : `Đã chọn ${selected.length}`
                : selected[0]?.label}
          </span>
          <Icon name="chevronDown" size={16} className="shrink-0" />
        </button>
      }
    >
      <Command
        label={label}
        shouldFilter={!onSearch}
        filter={(itemValue, search) => (foldText(itemValue).includes(foldText(search)) ? 1 : 0)}
      >
        <div className="flex items-center gap-2 border-b border-border px-3">
          <Icon name="search" size={16} className="shrink-0 text-fg-muted" />
          <Command.Input
            placeholder="Gõ để tìm (không cần dấu)"
            {...(onSearch ? { onValueChange: onSearch } : {})}
            className="tap h-control w-full bg-transparent text-body outline-none placeholder:text-fg-muted"
          />
        </div>
        <Command.List id={listId} className="max-h-72 overflow-y-auto p-1">
          {loading && <Command.Loading>Đang tìm…</Command.Loading>}
          <Command.Empty className="px-2 py-3 text-fg-muted">Không có kết quả.</Command.Empty>
          {options.map((option) => {
            const isSelected = value.includes(option.value);
            return (
              <Command.Item
                key={option.value}
                value={`${option.label} ${option.keywords ?? ''}`}
                disabled={option.disabledReason !== undefined}
                onSelect={() => pick(option)}
                className="flex min-h-8 cursor-pointer items-center gap-2 rounded-tag px-2 py-1 text-body outline-none data-[disabled=true]:cursor-not-allowed data-[disabled=true]:text-fg-disabled data-[selected=true]:bg-hover max-md:min-h-target"
              >
                <span className="flex size-4 shrink-0 items-center justify-center">
                  {isSelected && <Icon name="checkMark" size={16} />}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate">{option.label}</span>
                  {(option.hint ?? option.disabledReason) && (
                    <span className="block truncate text-caption text-fg-muted">
                      {option.disabledReason ?? option.hint}
                    </span>
                  )}
                </span>
              </Command.Item>
            );
          })}
        </Command.List>
      </Command>
    </Popover>
  );

  const chips = multiple && selected.length > 0 && (
    <ul className="flex flex-wrap gap-1" aria-label={`${label}: đã chọn`}>
      {selected.map((option) => (
        <li
          key={option.value}
          className="inline-flex items-center gap-1 rounded-tag bg-surface-subtle py-0.5 pr-1 pl-2 text-caption"
        >
          {option.label}
          <button
            type="button"
            aria-label={`Bỏ ${option.label}`}
            onClick={() => onChange(value.filter((v) => v !== option.value))}
            className="focus-ring rounded-tag p-0.5 hover:bg-hover"
          >
            <Icon name="close" size={16} />
          </button>
        </li>
      ))}
    </ul>
  );

  if (compact) {
    return (
      <div className="flex flex-col gap-1">
        {trigger({})}
        {chips}
      </div>
    );
  }
  return (
    <Field label={label} required={required} error={error} help={help}>
      {(field) => (
        <div className="flex flex-col gap-1">
          {trigger(field)}
          {chips}
        </div>
      )}
    </Field>
  );
}

const CALENDAR_CLASS = 'hmt-day-picker';

/**
 * Ô ngày: gõ tay luôn là dd/mm/yyyy (tự chèn dấu "/"), bấm biểu tượng để mở lịch của gói. Không dùng
 * ô ngày của trình duyệt vì cách hiện đổi theo ngôn ngữ máy. Giá trị là Date (giờ địa phương, 00:00) hoặc null.
 */
export function DateInput({
  label,
  value,
  onChange,
  required,
  error,
  help,
  disabled,
  min,
  max,
  compact = false,
}: {
  label: string;
  value: Date | null;
  onChange: (value: Date | null) => void;
  required?: boolean | undefined;
  error?: string | null | undefined;
  help?: string | undefined;
  disabled?: boolean | undefined;
  min?: Date | undefined;
  max?: Date | undefined;
  compact?: boolean | undefined;
}) {
  const [open, setOpen] = useState(false);
  const [text, setText] = useState(formatDmy(value));
  const [shown, setShown] = useState(value);
  // Giá trị đổi từ bên ngoài (chọn trên lịch, đặt lại biểu mẫu) thì cập nhật chữ.
  if (shown?.getTime() !== value?.getTime()) {
    setShown(value);
    setText(formatDmy(value));
  }
  const typedWrong = text.length === 10 && parseDmy(text) === null; // allow-number: độ dài dd/mm/yyyy
  const outOfRange = (d: Date) => (min !== undefined && d < min) || (max !== undefined && d > max);
  const message =
    error ?? (typedWrong ? 'Ngày không đúng. Nhập theo dd/mm/yyyy, ví dụ 05/10/2026.' : null);

  const input = (field: Record<string, unknown>) => (
    <div className="relative">
      <input
        {...field}
        {...(compact ? { 'aria-label': label } : {})}
        inputMode="numeric"
        autoComplete="off"
        placeholder="dd/mm/yyyy"
        disabled={disabled}
        value={text}
        onChange={(e) => {
          const masked = maskDmy(e.target.value);
          setText(masked);
          const parsed = parseDmy(masked);
          if (parsed && !outOfRange(parsed)) {
            setShown(parsed);
            onChange(parsed);
          } else if (masked === '') {
            setShown(null);
            onChange(null);
          }
        }}
        className={cn(INPUT_CLASS, 'tabular pr-10')}
        {...(typedWrong ? { 'aria-invalid': true } : {})}
      />
      <Popover
        open={open}
        onOpenChange={setOpen}
        align="end"
        trigger={
          <button
            type="button"
            aria-label={`Mở lịch: ${label}`}
            disabled={disabled}
            className="focus-ring absolute inset-y-0 right-0 flex w-9 items-center justify-center rounded-r-control text-fg-muted hover:bg-hover max-md:w-11"
          >
            <Icon name="calendar" size={16} />
          </button>
        }
      >
        <div className={CALENDAR_CLASS}>
          <DayPicker
            mode="single"
            locale={vi}
            weekStartsOn={1}
            selected={value ?? undefined}
            defaultMonth={value ?? new Date()}
            disabled={(d) => outOfRange(d)}
            onSelect={(d) => {
              if (d) {
                onChange(d);
                setOpen(false);
              }
            }}
          />
        </div>
      </Popover>
    </div>
  );

  if (compact) return input({});
  return (
    <Field label={label} required={required} error={message} help={help}>
      {(field) => input(field)}
    </Field>
  );
}

export type DateRangeValue = { from: Date; to: Date; preset?: string | undefined } | null;

const PRESETS = [
  { key: 'today', label: 'Hôm nay' },
  { key: 'week', label: 'Tuần này' },
  { key: 'last-week', label: 'Tuần trước' },
  { key: 'month', label: 'Tháng này' },
  { key: 'last-month', label: 'Tháng trước' },
] as const;

/** Ô chọn khoảng ngày: mốc nhanh hoặc chọn hai ngày trên lịch; chữ luôn là dd/mm/yyyy. */
export function DateRange({
  label,
  value,
  onChange,
  today = new Date(),
  defaultOpen = false,
  onClose,
}: {
  label: string;
  value: DateRangeValue;
  onChange: (value: DateRangeValue) => void;
  today?: Date | undefined;
  /** Mở lịch ngay khi hiện ra (người dùng vừa chọn "Tuỳ chọn khoảng ngày…"). */
  defaultOpen?: boolean | undefined;
  /** Người dùng đóng lịch mà không chọn gì. */
  onClose?: (() => void) | undefined;
}) {
  const [open, setOpen] = useState(false);
  // Mở sau một nhịp: ô chọn vừa đóng còn lấy lại tiêu điểm, mở ngay thì lịch bị đóng liền.
  useEffect(() => {
    if (!defaultOpen) return;
    const timer = window.setTimeout(() => setOpen(true), 50); // allow-number: chờ giao diện đóng ô chọn, không phải số nghiệp vụ
    return () => window.clearTimeout(timer);
  }, [defaultOpen]);
  const [draft, setDraft] = useState<PickerRange | undefined>(undefined);
  const presetLabel = PRESETS.find((p) => p.key === value?.preset)?.label;
  const text = value
    ? `${presetLabel ? `${presetLabel} · ` : ''}${formatDmy(value.from)} – ${formatDmy(value.to)}`
    : 'Mọi thời gian';
  const ranges = useMemo(
    () => PRESETS.map((p) => ({ ...p, range: datePresetRange(p.key, today) })),
    [today],
  );

  return (
    <Popover
      open={open}
      onOpenChange={(next) => {
        setOpen(next);
        if (next) setDraft(value ? { from: value.from, to: value.to } : undefined);
        else onClose?.();
      }}
      trigger={
        <button type="button" aria-label={`${label}: ${text}`} className={INPUT_BUTTON_CLASS}>
          <Icon name="calendar" size={16} className="shrink-0 text-fg-muted" />
          <span className="tabular">{text}</span>
        </button>
      }
    >
      <div className="flex flex-col gap-3 sm:flex-row">
        <div
          className="flex flex-row flex-wrap gap-1 sm:w-32 sm:flex-col"
          role="group"
          aria-label="Mốc nhanh"
        >
          {ranges.map(({ key, label: presetLabel, range }) =>
            range ? (
              <Button
                key={key}
                variant={value?.preset === key ? 'secondary' : 'ghost'}
                align="start"
                onClick={() => {
                  onChange({ from: range.from, to: range.to, preset: key });
                  setOpen(false);
                }}
              >
                {presetLabel}
              </Button>
            ) : null,
          )}
          <Button
            variant="ghost"
            align="start"
            onClick={() => {
              onChange(null);
              setOpen(false);
            }}
          >
            Mọi thời gian
          </Button>
        </div>
        <div className={CALENDAR_CLASS}>
          <DayPicker
            mode="range"
            locale={vi}
            weekStartsOn={1}
            selected={draft}
            defaultMonth={value?.from ?? today}
            onSelect={(range) => {
              setDraft(range);
              if (range?.from && range.to && range.from.getTime() !== range.to.getTime()) {
                onChange({ from: range.from, to: range.to });
                setOpen(false);
              }
            }}
          />
        </div>
      </div>
    </Popover>
  );
}

/**
 * Ô nhập tiền (đồng): canh phải, tự chấm ngăn nghìn, đuôi "đ". `readOnly` dùng cho số hệ thống tính:
 * nền nhạt, viền nét đứt, ghi rõ "Hệ thống tính". Chỉ để nhập; tính tiền nằm ở cơ sở dữ liệu.
 */
export function MoneyInput({
  label,
  value,
  onChange,
  required,
  error,
  help,
  readOnly,
  disabled,
}: {
  label: string;
  value: number | null;
  onChange?: ((value: number | null) => void) | undefined;
  required?: boolean | undefined;
  error?: string | null | undefined;
  help?: string | undefined;
  readOnly?: boolean | undefined;
  disabled?: boolean | undefined;
}) {
  return (
    <Field
      label={label}
      required={required}
      error={error}
      help={readOnly ? (help ?? 'Hệ thống tính, không sửa tay.') : help}
    >
      {(field) => (
        <div className="relative">
          <input
            {...field}
            inputMode="numeric"
            autoComplete="off"
            readOnly={readOnly}
            disabled={disabled}
            value={value === null ? '' : formatNumber(value)}
            onChange={(e) => onChange?.(parseMoney(e.target.value))}
            className={cn(INPUT_CLASS, 'tabular pr-8 text-right', readOnly && 'border-dashed')}
          />
          <span
            aria-hidden="true"
            className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-fg-muted"
          >
            đ
          </span>
        </div>
      )}
    </Field>
  );
}

/**
 * Đính kèm tệp (CHUNG-21). Giai đoạn 0 chưa có nơi lưu tệp (Cloudflare R2 bật ở giai đoạn 4):
 * `available=false` thì nút tải lên tắt và nói rõ lý do, không âm thầm bỏ qua.
 */
export function FileUpload({
  label,
  available,
  onFiles,
}: {
  label: string;
  available: boolean;
  onFiles?: ((files: File[]) => void) | undefined;
}) {
  const inputId = useId();
  const noteId = useId();
  return (
    <div className="flex flex-col gap-1">
      <label
        htmlFor={inputId}
        aria-disabled={!available}
        className={cn(
          'flex flex-col items-center gap-1 rounded-control border border-dashed border-border-strong bg-canvas px-3 py-4 text-center',
          available ? 'cursor-pointer hover:bg-hover' : 'cursor-not-allowed text-fg-disabled',
        )}
      >
        <Icon name="upload" />
        <span className="font-medium">{label}</span>
        <span className="text-caption">Ảnh hoặc PDF</span>
      </label>
      <input
        id={inputId}
        type="file"
        multiple
        accept="image/*,application/pdf"
        disabled={!available}
        aria-describedby={available ? undefined : noteId}
        onChange={(e) => onFiles?.(Array.from(e.target.files ?? []))}
        className="sr-only"
      />
      {!available && (
        <p id={noteId} className="text-caption text-fg-muted">
          Chưa bật lưu tệp đính kèm.
        </p>
      )}
    </div>
  );
}
