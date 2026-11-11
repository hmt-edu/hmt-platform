// Gọi dữ liệu màn GV-07K: màn chấm kiểm tra (một lần gọi) và lưu cả màn (một lần gọi, một giao dịch).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { ExamSave, ExamSheet } from './exam';

export function useExamSheet(sessionId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-exam-sheet', sessionId],
    enabled: Boolean(sessionId),
    queryFn: () => rpc<ExamSheet>(supabase, 'exam_grading_sheet', { p_session_id: sessionId }),
  });
}

export function useSaveExam(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: ExamSave) =>
      rpc<number>(supabase, 'save_exam_grading', {
        p_session_id: sessionId,
        p_scores: input.scores,
        p_notes: input.notes,
      }),
    onSuccess: () => {
      void client.invalidateQueries({ queryKey: ['gv-exam-sheet', sessionId] });
      void client.invalidateQueries({ queryKey: ['gv-session-overview', sessionId] });
    },
  });
}
