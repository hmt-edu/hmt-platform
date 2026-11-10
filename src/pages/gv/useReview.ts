// Gọi dữ liệu màn GV-07: màn chấm (một lần gọi), mở nhận xét của buổi, lưu cả màn (một lần gọi, một giao dịch), xem trước lời nhắn phụ huynh.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { ReviewSheet, SaveReview } from './review';

export function useReviewSheet(sessionId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-review-sheet', sessionId],
    enabled: Boolean(sessionId),
    queryFn: () => rpc<ReviewSheet>(supabase, 'review_grading_sheet', { p_session_id: sessionId }),
  });
}

export function useOpenReview(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => rpc<number>(supabase, 'open_session_review', { p_session_id: sessionId }),
    onSuccess: () => client.invalidateQueries({ queryKey: ['gv-review-sheet', sessionId] }),
  });
}

export function useSaveReview(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: SaveReview) =>
      rpc<number>(supabase, 'save_review_grading', {
        p_session_id: sessionId,
        p_criteria: input.criteria,
        p_scores: input.scores,
        p_notes: input.notes,
      }),
    onSuccess: () => {
      void client.invalidateQueries({ queryKey: ['gv-review-sheet', sessionId] });
      void client.invalidateQueries({ queryKey: ['gv-session-overview', sessionId] });
    },
  });
}

export type ParentHint = { kind: string; level: number | null; phrases: string[] };

export function useParentHint(sessionId: string, studentId: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-parent-hint', sessionId, studentId],
    enabled: enabled && studentId !== null,
    queryFn: () =>
      rpc<ParentHint>(supabase, 'parent_message_hint', {
        p_session_id: sessionId,
        p_student_id: studentId,
      }),
  });
}
