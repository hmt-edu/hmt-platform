// Gọi dữ liệu màn Ticket: danh sách phân trang ở máy chủ (app.list_tickets), một lần gọi mỗi trang.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import type { TicketBoardColumn, TicketFilters, TicketPage, TicketRecord } from './ticketTypes';

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

/** CSN-03: chi tiết một ticket và dòng thời gian, một lần gọi app.get_ticket. */
export function useTicketRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-record', id],
    enabled: id !== undefined,
    queryFn: () => rpc<TicketRecord>(supabase, 'get_ticket', { p_id: id }),
  });
}

/** Thêm ghi chú vào dòng thời gian (app.add_ticket_note). */
export function addTicketNote(supabase: SupabaseClient, id: string, note: string) {
  return rpc<null>(supabase, 'add_ticket_note', { p_id: id, p_note: note });
}

/** Đổi trạng thái theo luồng chung (app.change_ticket_status); luật chặn trả lỗi HMT_* tiếng Việt. */
export function changeTicketStatus(
  supabase: SupabaseClient,
  args: { id: string; to: string; note?: string; satisfaction?: number; resolution?: string },
) {
  return rpc<null>(supabase, 'change_ticket_status', {
    p_id: args.id,
    p_to: args.to,
    p_note: args.note ?? null,
    p_satisfaction: args.satisfaction ?? null,
    p_resolution: args.resolution ?? null,
  });
}

/** Nhân viên nhận giao ticket của một cơ sở (app.list_ticket_assignees); chỉ gọi khi mở hộp thoại Giao. */
export function useTicketAssignees(branchId: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-assignees', branchId],
    enabled,
    queryFn: () =>
      rpc<{ id: string; display_name: string; role_names: string[] }[]>(
        supabase,
        'list_ticket_assignees',
        { p_branch_id: branchId },
      ),
  });
}

/** Giao ticket cho đội và người phụ trách (app.assign_ticket); ticket Mới sang Đã giao. */
export function assignTicket(
  supabase: SupabaseClient,
  args: { id: string; team: string; assignee: string },
) {
  return rpc<null>(supabase, 'assign_ticket', {
    p_id: args.id,
    p_team: args.team,
    p_assignee: args.assignee,
  });
}

export type TicketCategory = {
  code: string;
  name: string;
  kind: 'GROUP' | 'SUBGROUP';
  parent_code: string | null;
  ticket_type: 'DN' | 'KN' | 'GV';
  default_priority: string | null;
  requires_student: boolean;
};

/** Nhóm và nhóm con ticket cho ô chọn hai cấp khi tạo (khoảng trăm dòng, đổi hiếm nên giữ suốt phiên). */
export function useTicketCategories() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-categories'],
    staleTime: Infinity,
    queryFn: async () => {
      const { data, error } = await supabase
        .schema('app')
        .from('ticket_category')
        .select('code, name, kind, parent_code, ticket_type, default_priority, requires_student')
        .eq('is_active', true)
        .order('sort_order')
        .returns<TicketCategory[]>();
      if (error) throw errorOf(error);
      return data;
    },
  });
}

/** Tạo ticket (app.create_ticket); trả mã và id. */
export function createTicket(supabase: SupabaseClient, data: Record<string, unknown>) {
  return rpc<{ id: string; code: string }>(supabase, 'create_ticket', { p_data: data });
}
