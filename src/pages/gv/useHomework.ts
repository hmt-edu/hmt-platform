// Gọi dữ liệu màn GV-08: màn chấm (một lần gọi), lưu lô chấm (một lần gọi), cập nhật bài Nộp sau.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { GradingSheet, HomeworkStatus, SaveItem } from './homework';

export function useGradingSheet(sessionId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-homework-sheet', sessionId],
    enabled: Boolean(sessionId),
    queryFn: () =>
      rpc<GradingSheet>(supabase, 'homework_grading_sheet', { p_session_id: sessionId }),
  });
}

export function useSaveGrading(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: (items: SaveItem[]) =>
      rpc<number>(supabase, 'save_homework_grading', { p_session_id: sessionId, p_items: items }),
    onSuccess: () => {
      void client.invalidateQueries({ queryKey: ['gv-homework-sheet', sessionId] });
      void client.invalidateQueries({ queryKey: ['gv-session-overview', sessionId] });
    },
  });
}

export function useUpdateLate(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      assignedSessionId: string;
      studentId: string;
      status: HomeworkStatus;
      score: number | null;
      version: number;
    }) =>
      rpc<null>(supabase, 'update_late_homework', {
        p_assigned_session_id: input.assignedSessionId,
        p_student_id: input.studentId,
        p_status_code: input.status,
        p_score: input.score,
        p_note: null,
        p_expected_version: input.version,
      }),
    onSuccess: () => client.invalidateQueries({ queryKey: ['gv-homework-sheet', sessionId] }),
  });
}
