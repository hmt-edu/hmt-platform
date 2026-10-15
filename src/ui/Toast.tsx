// Thông báo nổi sau một thao tác (.hmt-toast của gói): nền tối, chữ trắng, có thể kèm nút (Hoàn tác, Thử lại).
// 5 giây, 8 giây khi có nút, lỗi không tự ẩn; tối đa ba cái, cái mới đẩy cái cũ.
import { useCallback, useState, type ReactNode } from 'react';
import { Toast as RadixToast } from 'radix-ui';
import { Icon, type IconName } from './icons';
import { ToastContext, type ToastInput, type ToastTone } from './toastContext';

const DURATION_MS = 5_000; // allow-number: thời gian hiện thông báo theo hệ thống thiết kế, không phải số nghiệp vụ
const DURATION_WITH_ACTION_MS = 8_000; // allow-number: như trên, khi có nút thao tác
const STAY_OPEN_MS = 600_000; // allow-number: lỗi không tự ẩn (để rất lâu, người dùng tự đóng)
const MAX_VISIBLE = 3; // allow-number: tối đa ba thông báo cùng lúc theo hệ thống thiết kế

const TONE_ICON: Record<ToastTone, { icon: IconName; className: string }> = {
  success: { icon: 'check', className: 'text-success-subtle' },
  info: { icon: 'info', className: 'text-info-subtle' },
  warning: { icon: 'warning', className: 'text-warning-solid' },
  danger: { icon: 'alert', className: 'text-danger-subtle' },
};

type ToastItem = ToastInput & { id: number };

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const show = useCallback((toast: ToastInput) => {
    setItems((current) =>
      [...current, { ...toast, id: Date.now() + Math.random() }].slice(-MAX_VISIBLE),
    );
  }, []);
  const remove = (id: number) => setItems((current) => current.filter((t) => t.id !== id));

  return (
    <ToastContext.Provider value={show}>
      <RadixToast.Provider label="Thông báo" swipeDirection="right">
        {children}
        {items.map((item) => {
          const tone = item.tone ?? 'success';
          return (
            <RadixToast.Root
              key={item.id}
              type={tone === 'danger' ? 'foreground' : 'background'}
              duration={
                tone === 'danger'
                  ? STAY_OPEN_MS
                  : item.action
                    ? DURATION_WITH_ACTION_MS
                    : DURATION_MS
              }
              onOpenChange={(open) => !open && remove(item.id)}
              className="flex max-w-[560px] items-center gap-3 rounded-box bg-neutral-900 py-2.5 pr-2.5 pl-4 text-body-lg text-neutral-0 shadow-2"
            >
              <Icon
                name={TONE_ICON[tone].icon}
                className={`shrink-0 ${TONE_ICON[tone].className}`}
              />
              <RadixToast.Title className="min-w-0 flex-1">{item.title}</RadixToast.Title>
              {item.action && (
                <RadixToast.Action altText={item.action.label} asChild>
                  <button
                    type="button"
                    onClick={item.action.onClick}
                    className="focus-ring h-7 shrink-0 rounded-control border border-neutral-700 bg-transparent px-2.5 text-body font-semibold text-brand-200 hover:bg-neutral-800"
                  >
                    {item.action.label}
                  </button>
                </RadixToast.Action>
              )}
              <RadixToast.Close
                aria-label="Đóng thông báo"
                className="focus-ring inline-flex size-7 shrink-0 items-center justify-center rounded-control text-sidebar-fg-muted hover:bg-neutral-800"
              >
                <Icon name="close" size={16} />
              </RadixToast.Close>
            </RadixToast.Root>
          );
        })}
        <RadixToast.Viewport className="fixed right-4 bottom-4 z-[60] flex w-[min(560px,calc(100vw-2rem))] flex-col gap-2 outline-none max-md:right-1/2 max-md:bottom-20 max-md:translate-x-1/2" />
      </RadixToast.Provider>
    </ToastContext.Provider>
  );
}
