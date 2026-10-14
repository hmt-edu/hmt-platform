// Lớp phủ dựng trên Radix: đúng chuẩn bàn phím (Esc, Tab giữ trong hộp, trả focus) và trình đọc màn hình.
import type { ReactNode } from 'react';
import { Dialog as RadixDialog, DropdownMenu as RadixMenu, Select as RadixSelect } from 'radix-ui';
import { Link } from 'react-router';
import { IconButton } from './Button';
import { cn } from './cn';
import { Icon, type IconName } from './icons';

const SCRIM = 'fixed inset-0 z-40 bg-scrim';

/** Hộp thoại giữa màn hình. `dismissible=false`: bắt buộc chọn một nút (không đóng bằng Esc, bấm ngoài). */
export function Dialog({
  open,
  onOpenChange,
  title,
  description,
  children,
  footer,
  dismissible = true,
}: {
  open: boolean;
  onOpenChange?: (open: boolean) => void;
  title: string;
  description?: ReactNode | undefined;
  children?: ReactNode | undefined;
  footer?: ReactNode | undefined;
  dismissible?: boolean | undefined;
}) {
  const block = (event: Event) => {
    if (!dismissible) event.preventDefault();
  };
  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className={SCRIM} />
        <RadixDialog.Content
          onEscapeKeyDown={block}
          onPointerDownOutside={block}
          onInteractOutside={block}
          className="fixed top-1/2 left-1/2 z-50 flex max-h-[90dvh] w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 flex-col gap-4 overflow-y-auto rounded-box bg-surface-overlay p-6 shadow-3 focus:outline-none"
        >
          <div className="flex items-start justify-between gap-4">
            <RadixDialog.Title className="text-h2">{title}</RadixDialog.Title>
            {dismissible && (
              <RadixDialog.Close asChild>
                <IconButton icon="close" label="Đóng" className="-mt-2 -mr-2" />
              </RadixDialog.Close>
            )}
          </div>
          {description ? (
            <RadixDialog.Description className="text-fg-muted">
              {description}
            </RadixDialog.Description>
          ) : (
            <RadixDialog.Description className="sr-only">{title}</RadixDialog.Description>
          )}
          {children}
          {footer && <div className="flex flex-wrap justify-end gap-2">{footer}</div>}
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}

/** Ngăn kéo từ cạnh trái (menu trên điện thoại). */
export function Drawer({
  open,
  onOpenChange,
  title,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  children: ReactNode;
}) {
  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className={SCRIM} />
        <RadixDialog.Content className="fixed inset-y-0 left-0 z-50 flex w-72 max-w-[85vw] flex-col bg-surface shadow-3 focus:outline-none">
          <div className="flex items-center justify-between border-b border-border px-4 py-2">
            <RadixDialog.Title className="text-h3">{title}</RadixDialog.Title>
            <RadixDialog.Close asChild>
              <IconButton icon="close" label="Đóng menu" />
            </RadixDialog.Close>
          </div>
          <RadixDialog.Description className="sr-only">{title}</RadixDialog.Description>
          <div className="min-h-0 flex-1 overflow-y-auto">{children}</div>
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}

export type MenuItem =
  | { kind: 'link'; label: string; to: string; icon?: IconName }
  | { kind: 'action'; label: string; onSelect: () => void; icon?: IconName };

const MENU_ITEM =
  'flex min-h-9 cursor-pointer items-center gap-2 rounded-tag px-2 text-body text-fg outline-none data-[highlighted]:bg-hover-overlay max-md:min-h-11';

/** Menu thả xuống (menu tài khoản). */
export function DropdownMenu({ trigger, items }: { trigger: ReactNode; items: MenuItem[] }) {
  return (
    <RadixMenu.Root>
      <RadixMenu.Trigger asChild>{trigger}</RadixMenu.Trigger>
      <RadixMenu.Portal>
        <RadixMenu.Content
          align="end"
          sideOffset={4}
          className="z-30 min-w-52 rounded-box border border-border bg-surface-raised p-1 shadow-2"
        >
          {items.map((item) =>
            item.kind === 'link' ? (
              <RadixMenu.Item key={item.label} asChild>
                <Link to={item.to} className={MENU_ITEM}>
                  {item.icon && <Icon name={item.icon} size={16} />}
                  {item.label}
                </Link>
              </RadixMenu.Item>
            ) : (
              <RadixMenu.Item key={item.label} onSelect={item.onSelect} className={MENU_ITEM}>
                {item.icon && <Icon name={item.icon} size={16} />}
                {item.label}
              </RadixMenu.Item>
            ),
          )}
        </RadixMenu.Content>
      </RadixMenu.Portal>
    </RadixMenu.Root>
  );
}

/** Ô chọn một giá trị trong danh sách ngắn (ô chọn cơ sở). */
export function Select({
  label,
  value,
  onChange,
  options,
  icon,
  className,
}: {
  /** Nhãn cho trình đọc màn hình (ô không có nhãn hiện). */
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  icon?: IconName | undefined;
  className?: string | undefined;
}) {
  return (
    <RadixSelect.Root value={value} onValueChange={onChange}>
      <RadixSelect.Trigger
        aria-label={label}
        className={cn(
          'focus-ring tap inline-flex h-control items-center gap-2 rounded-control border border-border-strong bg-surface px-3 text-body text-fg',
          className,
        )}
      >
        {icon && <Icon name={icon} size={16} className="shrink-0 text-fg-muted" />}
        <span className="min-w-0 flex-1 truncate text-left">
          <RadixSelect.Value />
        </span>
        <RadixSelect.Icon>
          <Icon name="chevronDown" size={16} />
        </RadixSelect.Icon>
      </RadixSelect.Trigger>
      <RadixSelect.Portal>
        <RadixSelect.Content
          position="popper"
          sideOffset={4}
          className="z-30 max-h-72 min-w-[var(--radix-select-trigger-width)] overflow-y-auto rounded-box border border-border bg-surface-raised p-1 shadow-2"
        >
          <RadixSelect.Viewport>
            {options.map((option) => (
              <RadixSelect.Item
                key={option.value}
                value={option.value}
                className="flex min-h-9 cursor-pointer items-center rounded-tag px-2 text-body text-fg outline-none data-[highlighted]:bg-hover-overlay data-[state=checked]:bg-selected data-[state=checked]:text-on-selected max-md:min-h-11"
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
