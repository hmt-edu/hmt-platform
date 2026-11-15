// Gọi dữ liệu màn Ticket: danh sách phân trang ở máy chủ (app.list_tickets), một lần gọi mỗi trang.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { TicketFilters, TicketPage } from './ticketTypes';

export function useTicketPage(filters: TicketFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TicketPage>(supabase, 'list_tickets', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshTickets() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['ticket-list'] }),
    [queryClient],
  );
}
