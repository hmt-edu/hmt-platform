// Gọi dữ liệu màn «Điểm danh»: một rpc cho mỗi tab (lọc, phân trang ở máy chủ); ghi cột Vận hành từng dòng hoặc nhiều dòng.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { Board, CallList, Quick, RangeFilters } from './attendanceTypes';

export function useBoard(
  filters: RangeFilters & { class_id?: string; quick?: Quick },
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['attendance-board', filters, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<Board>(supabase, 'attendance_board', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useCallList(
  filters: RangeFilters & { start_time?: string; no_reason?: boolean },
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['attendance-calls', filters, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<CallList>(supabase, 'attendance_call_list', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

function useRefreshAttendance() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      [
        'attendance-board',
        'attendance-calls',
        'session-record',
        'session-list',
        'session-pending',
        'session-done-info',
      ].map((key) => client.invalidateQueries({ queryKey: [key] })),
    );
  }, [client]);
}

type OpsEntry = {
  student_id: string;
  status_code?: string;
  contact_reason_code?: string;
  note?: string;
};

/** Ghi một dòng (app.set_attendance_ops): chỉ khoá được gửi mới đổi. */
export function useSaveOpsEntry() {
  const supabase = useDb();
  const refresh = useRefreshAttendance();
  return useMutation({
    mutationFn: (a: { sessionId: string; entry: OpsEntry }) =>
      rpc<number>(supabase, 'set_attendance_ops', {
        p_session_id: a.sessionId,
        p_entries: [a.entry],
      }),
    onSuccess: () => refresh(),
  });
}

/** Gán cùng lúc (app.set_attendance_ops_bulk): một giao dịch, một dòng bị chặn thì không ghi dòng nào. */
export function useBulkOps() {
  const supabase = useDb();
  const refresh = useRefreshAttendance();
  return useMutation({
    mutationFn: (entries: { session_id: string; student_id: string; status_code: string }[]) =>
      rpc<number>(supabase, 'set_attendance_ops_bulk', { p_entries: entries }),
    onSuccess: () => refresh(),
  });
}
