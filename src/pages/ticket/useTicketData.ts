// Gọi dữ liệu màn Ticket: danh sách phân trang ở máy chủ (app.list_tickets), một lần gọi mỗi trang.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { TicketBoardColumn, TicketFilters, TicketPage } from './ticketTypes';

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
    () =>
      Promise.all(
        ['ticket-list', 'ticket-board'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      ),
    [queryClient],
  );
}

/** Kanban CSN-02: một lần gọi app.ticket_board cho cả bảy cột trạng thái; chỉ gọi khi đang xem Kanban. */
export function useTicketBoard(filters: TicketFilters, perColumn: number | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-board', filters, perColumn],
    enabled: enabled && perColumn !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TicketBoardColumn[]>(supabase, 'ticket_board', {
        p_filters: filters,
        p_per_column: perColumn,
      }),
  });
}
