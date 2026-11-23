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
