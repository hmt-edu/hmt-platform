// Số đếm cho nút «Ticket mở», «Khiếu nại» của hồ sơ phụ huynh, học sinh. Đếm ở máy chủ, dưới RLS ticket.
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { TicketBoardColumn, TicketPage } from '../ticket/ticketTypes';

export type CustTicketOwner = { key: 'parent_id' | 'student_id'; id: string };

// Trạng thái đã xong, như cột «Hạn» của danh sách ticket: không còn tính là đang mở.
const CLOSED = ['DA_XU_LY', 'DA_DONG', 'DA_HUY'];

export const openTicketTotal = (columns: Pick<TicketBoardColumn, 'status_code' | 'total'>[]) =>
  columns.filter((c) => !CLOSED.includes(c.status_code)).reduce((sum, c) => sum + c.total, 0);

/** Một lần gọi app.ticket_board (số đếm theo từng trạng thái). `undefined` khi đang tải hoặc không được tải. */
export function useOpenTicketCount(owner: CustTicketOwner, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['cust-tickets', 'open', owner.key, owner.id],
    enabled,
    queryFn: async () =>
      openTicketTotal(
        await rpc<TicketBoardColumn[]>(supabase, 'ticket_board', {
          p_filters: { [owner.key]: owner.id },
          p_per_column: 1,
        }),
      ),
  }).data;
}

export function useComplaintCount(studentId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['cust-tickets', 'complaints', studentId],
    enabled,
    queryFn: async () =>
      (
        await rpc<TicketPage>(supabase, 'list_tickets', {
          p_filters: { student_id: studentId, ticket_type: 'KN' },
          p_limit: 1,
          p_offset: 0,
        })
      ).total,
  }).data;
}
