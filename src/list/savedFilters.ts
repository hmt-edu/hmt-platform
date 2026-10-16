// Đọc bộ lọc đã lưu của một màn (bảng app.saved_filter: của mình và bộ lọc dùng chung).
import { useQuery } from '@tanstack/react-query';
import { fetchRows, useDb } from '../lib/db';
import type { ListState } from './types';

export type SavedFilterRow = {
  id: string;
  owner_id: string;
  name: string;
  filters: Partial<ListState>;
  is_shared: boolean;
  is_default: boolean;
};

export const SAVED_FILTERS_KEY = (screenCode: string) => ['saved-filters', screenCode];

export function useSavedFilters(screenCode: string) {
  const supabase = useDb();
  return useQuery({
    queryKey: SAVED_FILTERS_KEY(screenCode),
    queryFn: async () => {
      const { rows } = await fetchRows<SavedFilterRow>(
        supabase
          .schema('app')
          .from('saved_filter')
          .select('id, owner_id, name, filters, is_shared, is_default')
          .eq('screen_code', screenCode)
          .order('name'),
      );
      return rows;
    },
  });
}
