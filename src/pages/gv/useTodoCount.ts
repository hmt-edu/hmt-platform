// Số công việc cho chấm đếm ở menu «Cần làm» (R-V2-37): buổi chưa hoàn tất + phiếu test chờ chấm.
// Dùng chung khoá truy vấn với GV-12 nên không gọi lặp. Lỗi hoặc chưa có quyền thì không hiện số.
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { PendingTestsResult } from './testGrading';
import type { MySessionsResult } from './todayLogic';

const LIMIT = 1; // allow-number: chỉ cần tổng (total), không cần dòng
const STALE_MS = 60_000; // allow-number: giữ số đếm 1 phút để khỏi gọi lại mỗi lần đổi tab

export function useTodoCount(): number | null {
  const supabase = useDb();
  const open = useQuery({
    queryKey: ['gv-todo-count-open'],
    queryFn: () =>
      rpc<MySessionsResult>(supabase, 'teacher_my_sessions', { p_mode: 'CAN_LAM', p_limit: LIMIT }),
    retry: false,
    staleTime: STALE_MS,
  });
  const tests = useQuery({
    queryKey: ['gv-todo-count-tests'],
    queryFn: () =>
      rpc<PendingTestsResult>(supabase, 'teacher_my_pending_tests', { p_limit: LIMIT }),
    retry: false,
    staleTime: STALE_MS,
  });
  if (!open.data) return null;
  return open.data.total + (tests.data?.total ?? 0);
}
