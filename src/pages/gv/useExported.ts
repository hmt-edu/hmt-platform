// GV-07X: danh sách em đã xuất nhận xét của buổi (app.review_exported_students) và đặt dấu Đã xuất (app.set_review_exported, R-V2-38: chỉ để nhìn).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';

export function useExportedStudents(sessionId: string) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-exported', sessionId],
    retry: false,
    queryFn: () => rpc<string[]>(supabase, 'review_exported_students', { p_session_id: sessionId }),
  });
}

export function useMarkExported(sessionId: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async (studentIds: string[]) => {
      for (const id of studentIds) {
        await rpc<void>(supabase, 'set_review_exported', {
          p_session_id: sessionId,
          p_student_id: id,
          p_exported: true,
        });
      }
    },
    onSettled: () => client.invalidateQueries({ queryKey: ['gv-exported', sessionId] }),
  });
}
