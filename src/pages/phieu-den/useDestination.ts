// CS-07 màn cơ sở đích: gọi app.list_tasks_for_destination, get_task_for_destination, set_task_destination_class (migration 568). Duyệt, từ chối dùng hàm chung của phiếu.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { DestinationRecord, DestinationRow } from './destinationTypes';

export function useDestinationList() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-destination-list'],
    queryFn: () => rpc<DestinationRow[]>(supabase, 'list_tasks_for_destination'),
  });
}

export function useDestinationRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-destination', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<DestinationRecord>(supabase, 'get_task_for_destination', { p_id: id }),
  });
}

export function useRefreshDestination() {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['task-destination-list', 'task-destination', 'task-list', 'task-record'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      ),
    [queryClient],
  );
}

export function setDestinationClass(
  supabase: ReturnType<typeof useDb>,
  args: { id: string; classId: string; startDate: string },
) {
  return rpc<null>(supabase, 'set_task_destination_class', {
    p_id: args.id,
    p_class_id: args.classId,
    p_start_date: args.startDate,
  });
}
