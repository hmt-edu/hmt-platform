// GD-07: một lần gọi rpc cho một trang danh sách (lọc, phân trang ở máy chủ: app.list_expiring_enrollments).
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { GroupCounts } from '../lead/leadTypes';
import type { ExpiringPage } from './expiringLogic';

export function useExpiringPage(
  status: string[] | null,
  search: string,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['expiring-enrollments', status, search, offset, limit],
    retry: false,
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ExpiringPage>(supabase, 'list_expiring_enrollments', {
        p_filters: { status, search },
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Số dòng theo trường nhóm (Group By ở máy chủ, tối đa hai cấp): app.expiring_group_counts, bộ lọc giống list_expiring_enrollments. */
export function useExpiringGroupCounts(
  filters: { status: string[] | null; search: string },
  fields: string[],
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['expiring-groups', filters, fields],
    retry: false,
    enabled: fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'expiring_group_counts', { p_filters: filters, p_fields: fields }),
  });
}
