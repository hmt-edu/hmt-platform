// Dữ liệu dùng chung của cổng Học tập (/hoc) và cổng Phụ huynh (/ph): danh sách con và lịch học (migration 637, 638).
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';

export type PortalChild = { id: string; code: string; full_name: string };

export type PortalSession = {
  session_id: string;
  session_date: string;
  start_time: string;
  end_time: string;
  class_code: string;
  subject_name: string | null;
  room_name: string | null;
  teacher_name: string | null;
  type_code: string;
  type_name: string | null;
  status_code: string;
  is_makeup: boolean;
};

/** Học sinh người đăng nhập thấy (học sinh: chính mình; phụ huynh: các con). Rỗng khi cơ sở chưa bật Học tập. */
export function useChildren() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['portal-children'],
    queryFn: () => rpc<PortalChild[]>(supabase, 'portal_children'),
    staleTime: Infinity,
  });
}

/** Lịch học một học sinh trong khoảng ngày [from, to] (HT-06, PH-05). */
export function usePortalSchedule(studentId: string | undefined, from: string, to: string) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['portal-schedule', studentId, from, to],
    enabled: studentId !== undefined,
    queryFn: () =>
      rpc<{ rows: PortalSession[] }>(supabase, 'portal_schedule', {
        p_student_id: studentId,
        p_from: from,
        p_to: to,
      }),
    refetchOnWindowFocus: true,
  });
}

/** Gom buổi theo ngày (khoá yyyy-mm-dd), giữ thứ tự máy chủ đã sắp. */
export function groupSessionsByDay(
  rows: PortalSession[],
  days: string[],
): Record<string, PortalSession[]> {
  const out: Record<string, PortalSession[]> = Object.fromEntries(days.map((d) => [d, []]));
  for (const r of rows) out[r.session_date]?.push(r);
  return out;
}

/** «18:00 – 19:30» từ giờ máy chủ trả (hh:mm:ss). */
export function timeRange(s: Pick<PortalSession, 'start_time' | 'end_time'>): string {
  return `${s.start_time.slice(0, 5)} – ${s.end_time.slice(0, 5)}`;
}

export type AssignmentGroup = 'CAN_LAM' | 'DA_NOP' | 'DA_CHAM';

export type PortalAssignmentRow = {
  assignment_id: string;
  title: string;
  due_at: string;
  class_code: string;
  subject_name: string | null;
  is_overdue: boolean;
  allow_late: boolean;
  submitted_at: string | null;
  is_late: boolean;
  grade_status_code: string | null;
  grade_status_name: string | null;
  score: number | null;
};

export type PortalAssignmentPage = {
  total: number;
  counts: Record<AssignmentGroup, number>;
  rows: PortalAssignmentRow[];
};

export type WindowState = 'CON_HAN' | 'QUA_HAN_NHAN_MUON' | 'QUA_HAN_KHONG_NHAN';

export type PortalAssignmentDetail = {
  assignment: {
    id: string;
    title: string;
    description: string;
    due_at: string;
    class_code: string;
    subject_name: string | null;
    allow_resubmit: boolean;
    allow_late: boolean;
  };
  window_state: WindowState;
  can_submit: boolean;
  submission: {
    submitted_at: string | null;
    is_late: boolean;
    attempt_count: number;
    graded_at: string | null;
  } | null;
  result: {
    status_code: string;
    status_name: string | null;
    score: number | null;
    note: string | null;
  } | null;
  files: { file_name: string; byte_size: number; mime_type: string }[];
};

/** HT-02: bài tập theo nhóm, phân trang ở máy chủ. */
export function usePortalAssignments(
  studentId: string | undefined,
  group: AssignmentGroup,
  offset: number,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['portal-assignments', studentId, group, offset],
    enabled: studentId !== undefined,
    queryFn: () =>
      rpc<PortalAssignmentPage>(supabase, 'portal_assignments', {
        p_student_id: studentId,
        p_group: group,
        p_offset: offset,
      }),
  });
}

/** HT-03, HT-05: chi tiết một bài và kết quả chấm. */
export function usePortalAssignment(
  studentId: string | undefined,
  assignmentId: string | undefined,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['portal-assignment', studentId, assignmentId],
    enabled: studentId !== undefined && assignmentId !== undefined,
    queryFn: () =>
      rpc<PortalAssignmentDetail>(supabase, 'portal_assignment', {
        p_student_id: studentId,
        p_assignment_id: assignmentId,
      }),
  });
}

/** Nhãn một dòng bài ở HT-02: «Quá hạn» (còn nộp muộn được thì thêm gợi ý) hoặc hạn nộp. */
export function dueNote(r: Pick<PortalAssignmentRow, 'is_overdue' | 'allow_late'>): string {
  if (!r.is_overdue) return 'Hạn nộp';
  return r.allow_late ? 'Quá hạn, vẫn nhận bài muộn' : 'Quá hạn, không nhận bài muộn';
}
