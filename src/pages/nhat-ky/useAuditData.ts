// Gọi dữ liệu QT-11: một trang nhật ký (rpc list_audit_log) và danh sách tên bảng có nhật ký (app.audited_table, chỉ Admin đọc).
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { AuditPage } from './auditTypes';

export function useAuditPage(
  filters: Record<string, unknown>,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['audit-log', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<AuditPage>(supabase, 'list_audit_log', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useAuditedTables() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['audited-tables'],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<{ table_name: string }>(
          supabase.schema('app').from('audited_table').select('table_name').order('table_name'),
        )
      ).rows.map((r) => r.table_name),
  });
}
