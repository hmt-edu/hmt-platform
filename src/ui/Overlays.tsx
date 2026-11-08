// Lớp phủ dựng trên Radix: đúng chuẩn bàn phím (Esc, Tab giữ trong hộp, trả focus) và trình đọc màn hình.
// Kích thước và màu theo .hmt-dialog, .hmt-menu, .hmt-tab của gói thiết kế.
import { useRef, type ReactNode } from 'react';
import {
  Dialog as RadixDialog,
  DropdownMenu as RadixMenu,
  Popover as RadixPopover,
  Select as RadixSelect,
  Tabs as RadixTabs,
} from 'radix-ui';
import { Link } from 'react-router';
import { IconButton } from './Button';
import { cn } from './cn';
import { INPUT_BUTTON_CLASS } from './Field';
import { Icon, type IconName } from './icons';
import { useMedia } from './useMedia';

const SCRIM = 'fixed inset-0 z-40 bg-scrim';

/**
 * Trả focus về nút đã mở hộp thoại. Radix chỉ tự trả focus khi hộp mở bằng Radix.Trigger; các hộp của HMT mở
 * bằng trạng thái (open) từ nút bất kỳ nên phải nhớ phần tử đang focus lúc mở rồi trả lại lúc đóng.
 */
function useReturnFocus() {
  const opener = useRef<HTMLElement | null>(null);
  return {
    onOpenAutoFocus: () => {
      opener.current =
        document.activeElement instanceof HTMLElement ? document.activeElement : null;
    },
    onCloseAutoFocus: (event: Event) => {
      event.preventDefault();
      opener.current?.focus();
    },
  };
}

/**
 * Hộp thoại giữa màn hình: đầu (tiêu đề + nút đóng), thân, chân (nút phụ bên trái nút chính, canh phải).
 * `dismissible=false`: bắt buộc chọn một nút (không đóng bằng Esc, bấm ngoài).
 */
export function Dialog({
  open,
  onOpenChange,
  title,
  description,
  children,
  footer,
  dismissible = true,
  wide = false,
}: {
  open: boolean;
  onOpenChange?: (open: boolean) => void;
  title: string;
  description?: ReactNode | undefined;
  children?: ReactNode | undefined;
  footer?: ReactNode | undefined;
  dismissible?: boolean | undefined;
  /** Hộp rộng 720px (nhiều bước, xem trước); mặc định 440px. */
  wide?: boolean | undefined;
}) {
  const block = (event: Event) => {
    if (!dismissible) event.preventDefault();
  };
  const focus = useReturnFocus();
  // Điện thoại (dưới 640px): hộp thoại thành tấm trượt từ dưới lên (K4e), có thanh nắm.
  const sheet = useMedia('(max-width: 639px)');
  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className={SCRIM} />
        <RadixDialog.Content
          onEscapeKeyDown={block}
          onPointerDownOutside={block}
          onInteractOutside={block}
          {...focus}
          className={cn(
            'fixed z-50 flex flex-col overflow-hidden bg-surface shadow-3 focus:outline-none',
            sheet
              ? 'inset-x-0 bottom-0 max-h-[90dvh] w-full rounded-t-box'
              : cn(
                  'top-1/2 left-1/2 max-h-[90dvh] w-[calc(100vw-2rem)] -translate-x-1/2 -translate-y-1/2 rounded-box',
                  wide ? 'max-w-[720px]' : 'max-w-[440px]',
                ),
          )}
        >
          {sheet && (
            <span
              aria-hidden="true"
              className="mx-auto mt-2 h-1 w-10 shrink-0 rounded-full bg-neutral-300"
            />
          )}
          <div className="flex items-center gap-2 px-4 pt-4 pb-2">
            <RadixDialog.Title className="font-display text-h3">{title}</RadixDialog.Title>
            {dismissible && (
              <RadixDialog.Close asChild>
                <IconButton icon="close" label="Đóng" className="ml-auto -mr-2" />
              </RadixDialog.Close>
            )}
          </div>
          <div className="flex min-h-0 flex-col gap-2.5 overflow-y-auto px-4 pt-1 pb-3 text-body-lg">
            {description ? (
              <RadixDialog.Description className="text-fg-muted">
                {description}
              </RadixDialog.Description>
            ) : (
              <RadixDialog.Description className="sr-only">{title}</RadixDialog.Description>
            )}
            {children}
          </div>
          {footer && (
            <div className="flex flex-wrap justify-end gap-2 border-t border-border px-4 py-3">
              {footer}
            </div>
          )}
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}

/**
 * Ngăn kéo từ cạnh trái (menu trên điện thoại) hoặc cạnh phải (biểu mẫu tạo nhanh, K07b).
 */
export function Drawer({
  open,
  onOpenChange,
  title,
  children,
  footer,
  side = 'left',
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode | undefined;
  side?: 'left' | 'right' | 'bottom' | undefined;
}) {
  const focus = useReturnFocus();
  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className={SCRIM} />
        <RadixDialog.Content
          {...focus}
          className={cn(
            'fixed z-50 flex flex-col bg-surface shadow-3 focus:outline-none',
            side === 'left' && 'inset-y-0 left-0 w-72 max-w-[85vw]',
            side === 'right' && 'inset-y-0 right-0 w-[480px] max-w-[100vw]',
            // Tấm trượt từ dưới lên (điện thoại): bộ lọc, nhóm, cột, yêu thích.
            side === 'bottom' && 'inset-x-0 bottom-0 max-h-[85dvh] w-full rounded-t-box',
          )}
        >
          <div className="flex items-center gap-2 border-b border-border px-4 py-2">
            <RadixDialog.Title className="font-display text-h3">{title}</RadixDialog.Title>
            <RadixDialog.Close asChild>
              <IconButton icon="close" label="Đóng" className="ml-auto" />
            </RadixDialog.Close>
          </div>
          <RadixDialog.Description className="sr-only">{title}</RadixDialog.Description>
          <div className="min-h-0 flex-1 overflow-y-auto">{children}</div>
          {footer && (
            <div className="flex flex-wrap justify-end gap-2 border-t border-border px-4 py-3">
              {footer}
            </div>
          )}
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}

export type MenuItem =
  | { kind: 'link'; label: string; to: string; icon?: IconName }
  | {
      kind: 'action';
      label: string;
      onSelect: () => void;
      icon?: IconName;
      /** Mục chưa dùng được: hiện mờ kèm lý do ("Có khi làm BH-03"), không chọn được. */
      unavailable?: string;
    };

// .hmt-opt: dòng 13px, lề 8px, bo 4px, hover nền cam nhạt.
const MENU_ITEM =
  'flex min-h-8 cursor-pointer items-center gap-2 rounded-tag px-2 py-1.5 text-body text-fg outline-none data-[highlighted]:bg-hover max-md:min-h-target';
const MENU_PANEL = 'z-[70] min-w-60 rounded-box border border-border bg-surface p-1.5 shadow-2';

/** Menu thả xuống (menu tài khoản, thêm thao tác). */
export function DropdownMenu({
  trigger,
  items,
  align = 'end',
}: {
  trigger: ReactNode;
  items: MenuItem[];
  align?: 'start' | 'end' | undefined;
}) {
  return (
    <RadixMenu.Root>
      <RadixMenu.Trigger asChild>{trigger}</RadixMenu.Trigger>
      <RadixMenu.Portal>
        <RadixMenu.Content align={align} sideOffset={4} className={MENU_PANEL}>
          {items.map((item) =>
            item.kind === 'link' ? (
              <RadixMenu.Item key={item.label} asChild>
                <Link to={item.to} className={MENU_ITEM}>
                  {item.icon && <Icon name={item.icon} size={16} />}
                  {item.label}
                </Link>
              </RadixMenu.Item>
            ) : (
              <RadixMenu.Item
                key={item.label}
                onSelect={item.onSelect}
                disabled={item.unavailable !== undefined}
                className={cn(
                  MENU_ITEM,
                  item.unavailable !== undefined && 'cursor-default text-fg-muted',
                )}
              >
                {item.icon && <Icon name={item.icon} size={16} />}
                {item.label}
                {item.unavailable !== undefined && (
                  <span className="ml-auto text-caption">{item.unavailable}</span>
                )}
              </RadixMenu.Item>
            ),
          )}
        </RadixMenu.Content>
      </RadixMenu.Portal>
    </RadixMenu.Root>
  );
}

/** Ô chọn một giá trị trong danh sách ngắn (ô chọn cơ sở, vai trò). */
export function Select({
  label,
  value,
  onChange,
  options,
  icon,
  className,
  placeholder,
  id,
  disabled,
  requiredEmpty,
  invalid,
}: {
  /** Nhãn cho trình đọc màn hình (ô không có nhãn hiện). */
  label: string;
  /** Mã của nút (để nhãn hiện `htmlFor` trỏ tới). */
  id?: string | undefined;
  disabled?: boolean | undefined;
  /** Ô bắt buộc còn trống (chưa báo lỗi): viền cam, nền cam nhạt như bản vẽ. */
  requiredEmpty?: boolean | undefined;
  /** Ô đang báo lỗi: viền đỏ. */
  invalid?: boolean | undefined;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  icon?: IconName | undefined;
  className?: string | undefined;
  /** Chữ hiện khi chưa chọn (value rỗng). */
  placeholder?: string | undefined;
}) {
  return (
    <RadixSelect.Root value={value} onValueChange={onChange} disabled={disabled}>
      <RadixSelect.Trigger
        id={id}
        data-required-empty={requiredEmpty && !invalid ? 'true' : undefined}
        aria-invalid={invalid ? true : undefined}
        aria-label={label}
        className={cn(INPUT_BUTTON_CLASS, 'justify-between', className)}
      >
        {icon && <Icon name={icon} size={16} className="shrink-0 text-fg-muted" />}
        <span className="min-w-0 flex-1 truncate text-left">
          <RadixSelect.Value placeholder={placeholder} />
        </span>
        <RadixSelect.Icon>
          <Icon name="chevronDown" size={16} />
        </RadixSelect.Icon>
      </RadixSelect.Trigger>
      <RadixSelect.Portal>
        <RadixSelect.Content
          position="popper"
          sideOffset={4}
          className={cn(
            MENU_PANEL,
            'max-h-72 min-w-[var(--radix-select-trigger-width)] overflow-y-auto',
          )}
        >
          <RadixSelect.Viewport>
            {options.map((option) => (
              <RadixSelect.Item
                key={option.value}
                value={option.value}
                className={cn(
                  MENU_ITEM,
                  'data-[state=checked]:bg-selected data-[state=checked]:font-semibold data-[state=checked]:text-on-selected',
                )}
              >
                <RadixSelect.ItemText>{option.label}</RadixSelect.ItemText>
              </RadixSelect.Item>
            ))}
          </RadixSelect.Viewport>
        </RadixSelect.Content>
      </RadixSelect.Portal>
    </RadixSelect.Root>
  );
}

/** Khung nổi neo dưới một nút (Filters, Group By, Cột, Favorites: PR danh sách). */
export function Popover({
  trigger,
  children,
  align = 'start',
  open,
  onOpenChange,
  className,
}: {
  trigger: ReactNode;
  children: ReactNode;
  align?: 'start' | 'end' | undefined;
  open?: boolean | undefined;
  onOpenChange?: ((open: boolean) => void) | undefined;
  className?: string | undefined;
}) {
  return (
    <RadixPopover.Root
      {...(open === undefined ? {} : { open })}
      {...(onOpenChange ? { onOpenChange } : {})}
    >
      <RadixPopover.Trigger asChild>{trigger}</RadixPopover.Trigger>
      <RadixPopover.Portal>
        <RadixPopover.Content
          align={align}
          sideOffset={4}
          className={cn(
            'z-[70] max-w-[calc(100vw-2rem)] rounded-box border border-border bg-surface p-3 shadow-2 focus:outline-none',
            className,
          )}
        >
          {children}
        </RadixPopover.Content>
      </RadixPopover.Portal>
    </RadixPopover.Root>
  );
}

export type TabItem = {
  value: string;
  label: string;
  count?: number | undefined;
  content: ReactNode;
};

/** Tab nội dung (.hmt-tab): gạch chân cam đậm ở tab đang chọn. Mũi tên trái/phải đổi tab. */
export function Tabs({
  label,
  items,
  value,
  onChange,
}: {
  label: string;
  items: TabItem[];
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <RadixTabs.Root value={value} onValueChange={onChange} className="flex flex-col gap-3">
      {/* overflow-y-hidden: overflow-x-auto làm trục dọc thành auto, mà tab có -mb-px nên tràn 1px dọc và hiện thanh cuộn dọc nhỏ khi máy bật "luôn hiện thanh cuộn" (Q-89). */}
      <RadixTabs.List
        aria-label={label}
        className="flex gap-0.5 overflow-x-auto overflow-y-hidden border-b border-border"
      >
        {items.map((item) => (
          <RadixTabs.Trigger
            key={item.value}
            value={item.value}
            className="focus-ring tap -mb-px inline-flex h-control items-center gap-2 border-b-2 border-transparent px-3 text-body font-medium whitespace-nowrap text-fg-label data-[state=active]:border-brand-500 data-[state=active]:font-semibold data-[state=active]:text-brand-800"
          >
            {item.label}
            {item.count !== undefined && (
              <span className="tabular rounded-full bg-surface-subtle px-1.5 text-caption text-fg">
                {item.count}
              </span>
            )}
          </RadixTabs.Trigger>
        ))}
      </RadixTabs.List>
      {items.map((item) => (
        <RadixTabs.Content key={item.value} value={item.value} className="focus:outline-none">
          {item.content}
        </RadixTabs.Content>
      ))}
    </RadixTabs.Root>
  );
}
