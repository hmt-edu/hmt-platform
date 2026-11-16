// Gọi dữ liệu yêu cầu buổi: một lần gọi cho danh sách (phân trang ở máy chủ), mỗi thao tác một hàm (R-BUOI-04). Luật do máy chủ quyết.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { RequestPage } from './requestLogic';

export function useRequestPage(status: string[] | null, offset: number, limit: number) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-requests', status, offset, limit],
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<RequestPage>(supabase, 'list_session_requests', {
        p_filters: status === null ? {} : { status },
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

function useRefreshRequests() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['session-requests'] }),
    [queryClient],
  );
}

export type SaveArgs = {
  id: string | null;
  classId: string;
  date: string;
  start: string;
  end: string;
  roomId: string | null;
  note: string | null;
};

/** Lưu yêu cầu buổi củng cố ở Nháp rồi (tuỳ chọn) gửi duyệt; trả mã yêu cầu. */
export function useSaveRequest() {
  const supabase = useDb();
  const refresh = useRefreshRequests();
  return useMutation({
    mutationFn: async (a: SaveArgs & { submit: boolean }) => {
      const saved = await rpc<{ id: string; code: string }>(supabase, 'save_session_request', {
        p_id: a.id,
        p_class_id: a.classId,
        p_date: a.date,
        p_start: a.start,
        p_end: a.end,
        p_room_id: a.roomId,
        p_note: a.note,
      });
      if (a.submit) await rpc<null>(supabase, 'submit_session_request', { p_id: saved.id });
      return saved;
    },
    onSuccess: () => refresh(),
  });
}

export function useApproveRequest() {
  const supabase = useDb();
  const refresh = useRefreshRequests();
  return useMutation({
    mutationFn: (id: string) =>
      rpc<{ session_id: string; warnings: string[] }>(supabase, 'approve_session_request', {
        p_id: id,
      }),
    onSuccess: () => refresh(),
  });
}

export function useRejectRequest() {
  const supabase = useDb();
  const refresh = useRefreshRequests();
  return useMutation({
    mutationFn: (a: { id: string; reason: string; note: string | null }) =>
      rpc<null>(supabase, 'reject_session_request', {
        p_id: a.id,
        p_reason_code: a.reason,
        p_note: a.note,
      }),
    onSuccess: () => refresh(),
  });
}

export function useCancelRequest() {
  const supabase = useDb();
  const refresh = useRefreshRequests();
  return useMutation({
    mutationFn: (id: string) => rpc<null>(supabase, 'cancel_session_request', { p_id: id }),
    onSuccess: () => refresh(),
  });
}
