// Gọi dữ liệu màn Phiếu nghiệp vụ: danh sách phân trang ở máy chủ (app.list_ticket_tasks), chi tiết một lần gọi (app.get_ticket_task),
// thao tác qua hàm nghiệp vụ (trình, duyệt, từ chối, thực hiện, huỷ). Luật chặn thật ở DB (migration 226).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type {
  DestinationRow,
  DestinationTask,
  TaskFilters,
  TaskPage,
  TaskRecord,
} from './phieuTypes';

export function useTaskPage(filters: TaskFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TaskPage>(supabase, 'list_ticket_tasks', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useTaskRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-record', id],
    enabled: id !== undefined,
    queryFn: () => rpc<TaskRecord>(supabase, 'get_ticket_task', { p_id: id }),
  });
}

/** Phiếu Chuyển cơ sở dưới góc nhìn cơ sở đích; chỉ gọi khi get_ticket_task không cho xem (người ở cơ sở đích). */
export function useDestinationTask(id: string | undefined, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-destination', id],
    enabled: enabled && id !== undefined,
    retry: false,
    queryFn: () => rpc<DestinationTask>(supabase, 'get_task_for_destination', { p_id: id }),
  });
}

/** Phiếu chờ quản lý cơ sở đích chọn lớp và duyệt (hàng việc của người ở cơ sở đích). */
export function useDestinationList(enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-destination-list'],
    enabled,
    retry: false,
    queryFn: () => rpc<DestinationRow[]>(supabase, 'list_tasks_for_destination'),
  });
}

/** Quản lý cơ sở đích chọn lớp mới và buổi bắt đầu (app.set_task_destination_class). */
export function setDestinationClass(
  supabase: SupabaseClient,
  id: string,
  classId: string,
  startDate: string,
) {
  return rpc<null>(supabase, 'set_task_destination_class', {
    p_id: id,
    p_class_id: classId,
    p_start_date: startDate,
  });
}

export function useRefreshTasks() {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['task-list', 'task-record', 'task-destination', 'task-destination-list'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      ),
    [queryClient],
  );
}

export type TaskAction = 'submit' | 'approve' | 'reject' | 'execute' | 'cancel';

/** Một thao tác trên phiếu; `note` là ghi chú khi duyệt, lý do khi từ chối hoặc huỷ. */
export function runTaskAction(
  supabase: SupabaseClient,
  action: TaskAction,
  id: string,
  note?: string,
) {
  switch (action) {
    case 'submit':
      return rpc<null>(supabase, 'submit_ticket_task', { p_id: id });
    case 'approve':
      return rpc<null>(supabase, 'approve_ticket_task', { p_id: id, p_note: note ?? null });
    case 'reject':
      return rpc<null>(supabase, 'reject_ticket_task', { p_id: id, p_reason: note ?? '' });
    case 'execute':
      return rpc<null>(supabase, 'execute_ticket_task', { p_id: id });
    case 'cancel':
      return rpc<null>(supabase, 'cancel_ticket_task', { p_id: id, p_reason: note ?? '' });
  }
}
