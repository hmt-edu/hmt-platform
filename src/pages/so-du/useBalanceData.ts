// Gọi dữ liệu màn Số dư khách hàng: danh sách phân trang ở máy chủ và lịch sử sổ của một phụ huynh (máy chủ kiểm quyền, phạm vi).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { BalanceFilters } from './balanceFilters';
import type { BalanceHistory, BalancePage } from './balanceTypes';

export function useBalancePage(filters: BalanceFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['balance-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<BalancePage>(supabase, 'list_customer_balances', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshBalances() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['balance-list'] }),
    [queryClient],
  );
}

export function useBalanceHistory(parentId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['balance-history', parentId],
    enabled: parentId !== undefined,
    retry: false,
    queryFn: () =>
      rpc<BalanceHistory>(supabase, 'get_customer_balance_history', { p_parent_id: parentId }),
  });
}
