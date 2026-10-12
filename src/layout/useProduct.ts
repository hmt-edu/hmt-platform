import { useEffect } from 'react';

export type Product = 'crm' | 'teacher' | 'lms';

const DESKTOP_QUERY = '(min-width: 64rem)';

/**
 * Đặt mật độ theo cổng lên <html> (data-product) để cả hộp thoại, menu thả (vẽ ngoài khung) cũng theo.
 * Cổng giáo viên trên màn từ 1024px đặt thêm data-device="desktop" (nút 40px, hàng 48px: P-12).
 */
export function useProduct(product: Product): void {
  useEffect(() => {
    const root = document.documentElement;
    const previous = root.dataset.product;
    root.dataset.product = product;
    const media = window.matchMedia(DESKTOP_QUERY);
    const apply = () => {
      if (product === 'teacher' && media.matches) root.dataset.device = 'desktop';
      else delete root.dataset.device;
    };
    apply();
    media.addEventListener('change', apply);
    return () => {
      media.removeEventListener('change', apply);
      delete root.dataset.device;
      if (previous) root.dataset.product = previous;
    };
  }, [product]);
}
