// Gọi dữ liệu cụm Thu tiền: danh sách phân trang ở máy chủ (một lần gọi mỗi trang).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { TreasuryFilters } from './treasuryFilters';
import type { MoneyInPage, ReceivablePage } from './treasuryTypes';

export function useMoneyInPage(
  filters: TreasuryFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['money-in-list', filters, sort ?? null, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<MoneyInPage>(supabase, 'list_money_in', {
        p_filters: filters,
        p_sort: sort ?? 'date_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useReceivablePage(
  filters: TreasuryFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receivable-list', filters, sort ?? null, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ReceivablePage>(supabase, 'list_receivables', {
        p_filters: filters,
        p_sort: sort ?? 'due_asc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshTreasury() {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: ['money-in-list'] });
    await queryClient.invalidateQueries({ queryKey: ['receivable-list'] });
  }, [queryClient]);
}
