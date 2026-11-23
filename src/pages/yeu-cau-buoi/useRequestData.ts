// Gọi dữ liệu yêu cầu buổi: một lần gọi cho danh sách (phân trang ở máy chủ), mỗi thao tác một hàm (R-BUOI-04). Luật do máy chủ quyết.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { examRpcArgs, type ExamInput } from './examFields';
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
    mutationFn: async (a: SaveArgs & { submit: boolean; exam?: ExamInput | null }) => {
      const saved = await rpc<{ id: string; code: string }>(supabase, 'save_session_request', {
        p_id: a.id,
        p_class_id: a.classId,
        p_date: a.date,
        p_start: a.start,
        p_end: a.end,
        p_room_id: a.roomId,
        p_note: a.note,
      });
      // A25: loại Kiểm tra kèm cấu hình điểm, đặt khi yêu cầu còn Nháp (trước khi gửi duyệt).
      if (a.exam)
        await rpc<null>(supabase, 'set_request_exam', {
          p_request_id: saved.id,
          p_enabled: true,
          ...examRpcArgs(a.exam),
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

/** Kết quả kiểm trùng giờ trước khi duyệt (G21): chỉ cảnh báo, không chặn. */
export type RequestClash = { teacher_clash: string[]; room_clash: string[] };

export function useRequestClashCheck() {
  const supabase = useDb();
  return useMutation({
    mutationFn: (id: string) =>
      rpc<RequestClash>(supabase, 'session_request_clash_check', { p_id: id }),
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

export type SupportArgs = {
  classId: string;
  studentIds: string[];
  date: string;
  start: string;
  end: string;
  teacherId: string;
  roomId: string | null;
  note: string | null;
};

/** Lưu yêu cầu học bổ trợ ở Nháp rồi (tuỳ chọn) gửi duyệt (app.save_support_request, R-BUOI-05); trả mã yêu cầu. */
export function useSaveSupport() {
  const supabase = useDb();
  const refresh = useRefreshRequests();
  return useMutation({
    mutationFn: async (a: SupportArgs & { submit: boolean; exam?: ExamInput | null }) => {
      const saved = await rpc<{ id: string; code: string }>(supabase, 'save_support_request', {
        p_id: null,
        p_class_id: a.classId,
        p_student_ids: a.studentIds,
        p_date: a.date,
        p_start: a.start,
        p_end: a.end,
        p_teacher_id: a.teacherId,
        p_room_id: a.roomId,
        p_note: a.note,
      });
      // A25: loại Kiểm tra kèm cấu hình điểm, đặt khi yêu cầu còn Nháp (trước khi gửi duyệt).
      if (a.exam)
        await rpc<null>(supabase, 'set_request_exam', {
          p_request_id: saved.id,
          p_enabled: true,
          ...examRpcArgs(a.exam),
        });
      if (a.submit) await rpc<null>(supabase, 'submit_session_request', { p_id: saved.id });
      return saved;
    },
    onSuccess: () => refresh(),
  });
}

export type MakeupArgs = {
  classId: string;
  studentIds: string[];
  date: string;
  start: string;
  end: string;
  teacherId: string | null;
  roomId: string | null;
  reason: string;
};

/** Lưu yêu cầu học bù ở Nháp rồi (tuỳ chọn) gửi duyệt (app.save_makeup_request, R-BUOI-03); trả mã yêu cầu. */
export function useSaveMakeup() {
  const supabase = useDb();
  const refresh = useRefreshRequests();
  return useMutation({
    mutationFn: async (a: MakeupArgs & { submit: boolean; exam?: ExamInput | null }) => {
      const saved = await rpc<{ id: string; code: string }>(supabase, 'save_makeup_request', {
        p_id: null,
        p_class_id: a.classId,
        p_student_ids: a.studentIds,
        p_date: a.date,
        p_start: a.start,
        p_end: a.end,
        p_teacher_id: a.teacherId,
        p_room_id: a.roomId,
        p_reason: a.reason,
      });
      // A25: loại Kiểm tra kèm cấu hình điểm, đặt khi yêu cầu còn Nháp (trước khi gửi duyệt).
      if (a.exam)
        await rpc<null>(supabase, 'set_request_exam', {
          p_request_id: saved.id,
          p_enabled: true,
          ...examRpcArgs(a.exam),
        });
      if (a.submit) await rpc<null>(supabase, 'submit_session_request', { p_id: saved.id });
      return saved;
    },
    onSuccess: () => refresh(),
  });
}
