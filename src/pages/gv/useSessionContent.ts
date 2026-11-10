// Gọi dữ liệu màn GV-06: chi tiết buổi (một lần gọi) và lưu nội dung buổi (một lần gọi, cả bộ dòng).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { SessionOverview } from './sessionContent';

export function useSessionOverview(sessionId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-session-overview', sessionId],
    enabled: Boolean(sessionId),
    queryFn: () => rpc<SessionOverview>(supabase, 'session_overview', { p_session_id: sessionId }),
  });
}

export function useSaveSessionContent(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: { lines: string[]; homework: string; version: number }) =>
      rpc<number>(supabase, 'save_session_content', {
        p_session_id: sessionId,
        p_lines: input.lines,
        p_homework: input.homework.trim() === '' ? null : input.homework,
        p_expected_version: input.version,
      }),
    onSuccess: () => client.invalidateQueries({ queryKey: ['gv-session-overview', sessionId] }),
  });
}
