// Gọi dữ liệu màn Phiếu nghiệp vụ: danh sách phân trang ở máy chủ (app.list_ticket_tasks), chi tiết một lần gọi (app.get_ticket_task),
// thao tác qua hàm nghiệp vụ (trình, duyệt, từ chối, thực hiện, huỷ). Luật chặn thật ở DB (migration 226).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import type { TaskFilters, TaskPage, TaskRecord } from './phieuTypes';

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

/** Mã ghi danh của phiếu (một dòng theo id, cột `code`); phiếu không có ghi danh thì không gọi. */
export function useTaskEnrollmentCode(enrollmentId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['task-enrollment-code', enrollmentId],
    enabled: enrollmentId !== undefined && enrollmentId !== '',
    staleTime: Infinity,
    queryFn: async () => {
      const { data, error } = await supabase
        .schema('app')
        .from('enrollment')
        .select('code')
        .eq('id', enrollmentId ?? '')
        .maybeSingle<{ code: string }>();
      if (error) throw errorOf(error);
      return data?.code ?? null;
    },
  });
}

export function useRefreshTasks() {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['task-list', 'task-record'].map((key) =>
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
