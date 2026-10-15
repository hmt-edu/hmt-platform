import { createContext, useContext } from 'react';

export type ToastTone = 'success' | 'info' | 'warning' | 'danger';
export type ToastInput = {
  tone?: ToastTone;
  title: string;
  /** Thao tác kèm theo (Hoàn tác, Thử lại). */
  action?: { label: string; onClick: () => void };
};

export const ToastContext = createContext<((toast: ToastInput) => void) | null>(null);

/** Hiện thông báo ngắn sau một thao tác: const toast = useToast(); toast({ title: 'Đã lưu' }). */
export function useToast(): (toast: ToastInput) => void {
  const show = useContext(ToastContext);
  if (!show) throw new Error('useToast phải nằm trong ToastProvider.');
  return show;
}
