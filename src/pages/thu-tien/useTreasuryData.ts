// Gọi dữ liệu cụm Thu tiền: danh sách phân trang ở máy chủ (một lần gọi mỗi trang).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { GroupCounts } from '../lead/leadTypes';
import type { TreasuryFilters } from './treasuryFilters';
import type { MoneyInPage, ReceivablePage } from './treasuryTypes';

export function useMoneyInPage(
  filters: TreasuryFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['money-in-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
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
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receivable-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
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

/** Đếm nhóm cho Group By (một đến hai cấp), tính ở máy chủ: khoản tiền vào (TC-08) hoặc công nợ (TC-13). */
export function useTreasuryGroupCounts(
  kind: 'money_in_group_counts' | 'receivable_group_counts',
  filters: TreasuryFilters,
  fields: string[],
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['treasury-groups', kind, filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () => rpc<GroupCounts>(supabase, kind, { p_filters: filters, p_fields: fields }),
  });
}

export function useRefreshTreasury() {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: ['money-in-list'] });
    await queryClient.invalidateQueries({ queryKey: ['receivable-list'] });
  }, [queryClient]);
}

/** TC-09: Kế toán hoàn tác (đảo) một khoản tiền vào, bắt buộc lý do; "Khác" thì bắt ghi chú (máy chủ kiểm). */
export function reverseMoneyIn(
  supabase: SupabaseClient,
  id: string,
  reasonCode: string,
  note: string | null,
): Promise<{
  id: string;
  code: string;
  reversed_code: string;
  amount: number;
  enrollments_negative: number;
}> {
  return rpc(supabase, 'reverse_money_in', {
    p_money_in_id: id,
    p_reason_code: reasonCode,
    p_note: note,
  });
}
