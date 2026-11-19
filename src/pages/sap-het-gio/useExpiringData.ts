// GD-07: một lần gọi rpc cho một trang danh sách (lọc, phân trang ở máy chủ: app.list_expiring_enrollments).
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { ExpiringPage } from './expiringLogic';

export function useExpiringPage(
  status: string[] | null,
  search: string,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['expiring-enrollments', status, search, offset, limit],
    retry: false,
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ExpiringPage>(supabase, 'list_expiring_enrollments', {
        p_filters: { status, search },
        p_limit: limit,
        p_offset: offset,
      }),
  });
}
