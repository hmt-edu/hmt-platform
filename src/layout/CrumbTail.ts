import { createContext, useContext, useEffect } from 'react';

/** Đặt chữ cuối của đường dẫn trên thanh trên (tên bản ghi đang mở, "Tạo mới"); rời trang thì bỏ. */
export const CrumbTailContext = createContext<(label: string | null) => void>(() => undefined);

export function useCrumbTail(label: string | null): void {
  const set = useContext(CrumbTailContext);
  useEffect(() => {
    set(label);
    return () => set(null);
  }, [label, set]);
}
