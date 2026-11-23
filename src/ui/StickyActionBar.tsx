import type { ReactNode } from 'react';

/**
 * Thanh hành động dính đáy màn của cổng giáo viên (điện thoại): nút Lưu nằm trong tầm ngón cái, ngay trên thanh điều hướng dưới.
 * Đặt làm phần tử CUỐI của trang. Trên laptop dính sát đáy cửa sổ.
 */
export function StickyActionBar({ children }: { children: ReactNode }) {
  return (
    <div className="sticky bottom-16 z-[5] -mx-4 flex flex-wrap items-center justify-end gap-3 border-t border-border bg-surface px-4 py-2 lg:bottom-0">
      {children}
    </div>
  );
}
