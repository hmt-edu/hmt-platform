// Gọi dữ liệu QT-12: hai danh sách phân trang (rpc), danh mục phân hệ để hiện tên, và mở khoá tạm.
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { ExportRow, LoginRow, Paged } from './loginLogTypes';

function usePaged<T>(
  fn: string,
  filters: Record<string, unknown>,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: [fn, filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<Paged<T>>(supabase, fn, { p_filters: filters, p_limit: limit, p_offset: offset }),
  });
}

export const useLoginPage = (f: Record<string, unknown>, o: number, l: number | null) =>
  usePaged<LoginRow>('list_login_events', f, o, l);
export const useExportPage = (f: Record<string, unknown>, o: number, l: number | null) =>
  usePaged<ExportRow>('list_export_log', f, o, l);

export function useModuleNames() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['module-names'],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<{ code: string; name: string }>(
          supabase
            .schema('app')
            .from('catalog_item')
            .select('code, name')
            .eq('catalog_code', 'MODULE')
            .order('sort_order'),
        )
      ).rows,
  });
}

export async function unlockTempLogin(supabase: SupabaseClient, userId: string): Promise<void> {
  await rpc<unknown>(supabase, 'unlock_temp_login', { p_user_id: userId });
}
