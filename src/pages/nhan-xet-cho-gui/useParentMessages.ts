// CS-16: đọc danh sách (app.list_parent_messages) và đánh dấu đã gửi (app.mark_parent_message_sent), migration 622. Phân trang ở máy chủ.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { ParentMessageFilters, ParentMessagePage } from './parentMessageTypes';

export function useParentMessagePage(
  filters: ParentMessageFilters,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['parent-messages', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ParentMessagePage>(supabase, 'list_parent_messages', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useMarkParentMessageSent() {
  const supabase = useDb();
  const queryClient = useQueryClient();
  return useCallback(
    async (attendanceId: string) => {
      await rpc<void>(supabase, 'mark_parent_message_sent', { p_attendance_id: attendanceId });
      await queryClient.invalidateQueries({ queryKey: ['parent-messages'] });
    },
    [supabase, queryClient],
  );
}
