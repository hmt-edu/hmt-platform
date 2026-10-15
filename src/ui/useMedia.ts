import { useSyncExternalStore } from 'react';

/** Theo dõi một media query (vd bảng thành thẻ dưới 640px, cột phải từ 1280px). */
export function useMedia(query: string): boolean {
  return useSyncExternalStore(
    (onChange) => {
      const list = window.matchMedia(query);
      list.addEventListener('change', onChange);
      return () => list.removeEventListener('change', onChange);
    },
    () => window.matchMedia(query).matches,
    () => false,
  );
}

/** Ngưỡng của hệ thống thiết kế. */
export const NARROW_TABLE = '(max-width: 639px)';
export const WIDE_RECORD = '(min-width: 1280px)';
