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

export const FilteredListContext = createContext<(filtered: boolean) => void>(() => undefined);

/** Danh sách đang lọc theo bản ghi cha báo cho khung ứng dụng: mở một dòng thì bỏ tầng danh sách khỏi đường dẫn. */
export function useFilteredListCrumb(filtered: boolean): void {
  const set = useContext(FilteredListContext);
  useEffect(() => {
    set(filtered);
    return () => set(false);
  }, [filtered, set]);
}
