// Gọi dữ liệu CHUNG-15: một lần gọi app.list_my_approvals (phân trang, lọc ở máy chủ).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { ApprovalFilters, ApprovalPage } from './approvalsTypes';

export function useApprovalsPage(filters: ApprovalFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['my-approvals', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ApprovalPage>(supabase, 'list_my_approvals', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshApprovals() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['my-approvals'] }),
    [queryClient],
  );
}
