import { useEffect, useState } from 'react';

const DEFAULT_DELAY_MS = 300; // allow-number: chờ người dùng gõ xong rồi mới gọi tìm kiếm, không phải số nghiệp vụ

/** Giá trị trễ một nhịp: ô tìm kiếm gõ tới đâu cũng không gọi máy chủ mỗi phím. */
export function useDebounced<T>(value: T, delayMs: number = DEFAULT_DELAY_MS): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);
  return debounced;
}
