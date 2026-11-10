// Gọi dữ liệu cụm Buổi A: danh sách buổi, bản ghi buổi, bảng điểm danh vận hành, em vắng/chưa đến hôm nay (đọc, phân trang ở máy chủ) và các thao tác ghi dùng hàm D1c.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { AbsentPage, OpsSheet, SessionPage, SessionRecord } from './sessionTypes';

export type SessionFilters = Record<string, unknown>;

export function useSessionPage(
  filters: SessionFilters,
  sort: string,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-list', filters, sort, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<SessionPage>(supabase, 'session_list', {
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useAbsentPage(filters: SessionFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-absent', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<AbsentPage>(supabase, 'absent_today_list', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useSessionRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-record', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<SessionRecord>(supabase, 'session_record', { p_id: id }),
  });
}

export function useOpsSheet(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-ops-sheet', id],
    enabled: id !== undefined,
    retry: false,
    refetchOnWindowFocus: false,
    queryFn: () => rpc<OpsSheet>(supabase, 'session_ops_sheet', { p_session_id: id }),
  });
}

/** Làm mới mọi dữ liệu buổi học đang giữ (danh sách, bản ghi, hàng gọi nhắc). */
export function useRefreshSessions() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      ['session-list', 'session-record', 'session-absent', 'session-ops-sheet'].map((key) =>
        client.invalidateQueries({ queryKey: [key] }),
      ),
    );
  }, [client]);
}

export type OpsEntry = {
  student_id: string;
  status_code: string | null;
  contact_reason_code: string | null;
  note: string | null;
};

/** Ghi điểm danh phía vận hành, lý do liên hệ (app.set_attendance_ops, D1c). Luật do máy chủ quyết. */
export function useSaveOps(sessionId: string) {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (entries: OpsEntry[]) =>
      rpc<number>(supabase, 'set_attendance_ops', { p_session_id: sessionId, p_entries: entries }),
    onSuccess: () => refresh(),
  });
}

/** Chốt danh sách ngay (app.close_session, R-GIO-02). */
export function useCloseSession() {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (sessionId: string) =>
      rpc<unknown>(supabase, 'close_session', { p_session_id: sessionId }),
    onSuccess: () => refresh(),
  });
}
