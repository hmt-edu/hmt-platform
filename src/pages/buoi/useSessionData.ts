// Gọi dữ liệu cụm Buổi A: danh sách buổi, bản ghi buổi, bảng điểm danh vận hành, em vắng/chưa đến hôm nay (đọc, phân trang ở máy chủ) và các thao tác ghi dùng hàm D1c.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { GroupCounts } from '../lead/leadTypes';
import { rpc, useDb } from '../../lib/db';
import type {
  AbsentPage,
  CancelPreview,
  MoveCheck,
  MoveOptions,
  OpsSheet,
  PendingPage,
  SessionPage,
  SessionRecord,
} from './sessionTypes';

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
      [
        'session-list',
        'session-record',
        'session-absent',
        'session-ops-sheet',
        'session-pending',
      ].map((key) => client.invalidateQueries({ queryKey: [key] })),
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

export function usePendingPage(filters: SessionFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-pending', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<PendingPage>(supabase, 'session_pending_list', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** "Nhắc GV": ghi thông báo cho giáo viên của buổi (app.remind_teacher_session). */
export function useRemindTeacher() {
  const supabase = useDb();
  return useMutation({
    mutationFn: (sessionId: string) =>
      rpc<boolean>(supabase, 'remind_teacher_session', { p_session_id: sessionId }),
  });
}

export function useCancelPreview(sessionId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-cancel-preview', sessionId],
    enabled,
    retry: false,
    queryFn: () =>
      rpc<CancelPreview>(supabase, 'session_cancel_preview', { p_session_id: sessionId }),
  });
}

export type CancelArgs = { kind: string | null; reason: string; note: string | null };
/** Huỷ buổi (app.cancel_session, R-BUOI-06, R-BUOI-07, R-BUOI-09). Luật do máy chủ quyết. */
export function useCancelSession(sessionId: string) {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (a: CancelArgs) =>
      rpc<{ status: string; added_session_id: string | null }>(supabase, 'cancel_session', {
        p_session_id: sessionId,
        p_kind: a.kind,
        p_reason_code: a.reason,
        p_note: a.note,
      }),
    onSuccess: () => refresh(),
  });
}

export type CorrectArgs = {
  studentId: string;
  status: string;
  reason: string;
  note: string | null;
};
/** Sửa điểm danh sau Done (app.correct_attendance_after_done, BUOI-14, R-GIO-07): chỉ Điểm danh · Duyệt, bắt buộc lý do. */
export function useCorrectAttendance(sessionId: string) {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (a: CorrectArgs) =>
      rpc<null>(supabase, 'correct_attendance_after_done', {
        p_session_id: sessionId,
        p_student_id: a.studentId,
        p_status_code: a.status,
        p_reason_code: a.reason,
        p_note: a.note,
      }),
    onSuccess: () => refresh(),
  });
}

export type StaffArgs = { teacherId: string | null; assistantId: string | null };
/** Đổi giáo viên, trợ giảng một buổi chưa Done (app.change_session_staff, BUOI-13, R-LOP-10, R-LOP-11): trùng giờ chỉ cảnh báo. */
export function useChangeSessionStaff(sessionId: string) {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (a: StaffArgs) =>
      rpc<{ warnings: string[] }>(supabase, 'change_session_staff', {
        p_session_id: sessionId,
        p_teacher_id: a.teacherId,
        p_assistant_id: a.assistantId,
      }),
    onSuccess: () => refresh(),
  });
}

export function useAddTrialStudent(sessionId: string) {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (prospectStudentId: string) =>
      rpc<{ attendance_id: string; student_id: string; warnings: string[] }>(
        supabase,
        'add_trial_student',
        {
          p_session_id: sessionId,
          p_prospect_student_id: prospectStudentId,
        },
      ),
    onSuccess: () => refresh(),
  });
}

export function useMoveOptions(sessionId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-move-options', sessionId],
    enabled,
    retry: false,
    queryFn: () => rpc<MoveOptions>(supabase, 'session_move_options', { p_session_id: sessionId }),
  });
}

export type MoveArgs = { date: string; start: string; end: string; roomId: string | null };

/** Kiểm trùng phòng, giáo viên trước khi lưu (chỉ cảnh báo, R-LOP-08). */
export function useMoveCheck(sessionId: string, a: MoveArgs | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-move-check', sessionId, a],
    enabled: a !== null,
    retry: false,
    queryFn: () =>
      rpc<MoveCheck>(supabase, 'session_move_check', {
        p_session_id: sessionId,
        p_date: a?.date,
        p_start: a?.start,
        p_end: a?.end,
        p_room_id: a?.roomId,
      }),
  });
}

/** Dời một buổi (app.move_session, R-LOP-08: trùng chỉ cảnh báo). */
export function useMoveSession(sessionId: string) {
  const supabase = useDb();
  const refresh = useRefreshSessions();
  return useMutation({
    mutationFn: (a: MoveArgs) =>
      rpc<{ warnings: string[] }>(supabase, 'move_session', {
        p_session_id: sessionId,
        p_date: a.date,
        p_start: a.start,
        p_end: a.end,
        p_room_id: a.roomId,
      }),
    onSuccess: () => refresh(),
  });
}

/** Số buổi theo trường nhóm (Group By ở máy chủ, tối đa hai cấp): app.session_group_counts, bộ lọc giống session_list. */
export function useSessionGroupCounts(filters: SessionFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'session_group_counts', { p_filters: filters, p_fields: fields }),
  });
}
