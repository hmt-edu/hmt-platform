// Gọi dữ liệu QT-04 Vai trò: một lần gọi hàm list_roles_summary (12 vai trò kèm số người, số ô quyền) và danh mục phạm vi PERM_SCOPE để hiện tên.
import { useQuery } from '@tanstack/react-query';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { RoleSummary } from './roleLogic';

export function useRoleSummaries() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['role-summaries'],
    queryFn: () => rpc<RoleSummary[]>(supabase, 'list_roles_summary'),
  });
}

export function useScopeNames() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-scope-names'],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<{ code: string; name: string }>(
          supabase
            .schema('app')
            .from('catalog_item')
            .select('code, name')
            .eq('catalog_code', 'PERM_SCOPE'),
        )
      ).rows,
  });
}
