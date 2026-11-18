// Gọi dữ liệu GV-15: đọc phiếu (một lần gọi), Lưu nháp, Trả về sale.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { TestSheet } from './testGrading';

export function useTestSheet(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gv-test-sheet', id],
    enabled: Boolean(id),
    queryFn: () => rpc<TestSheet>(supabase, 'teacher_test_sheet', { p_id: id }),
  });
}

export type TestResultInput = {
  score: number | null;
  note: string;
  level: string | null;
  framework: string | null;
};

/** Lưu nháp (enter_test_result) hoặc nộp (thêm complete_student_test, Trả về sale): mỗi nút một hàm DB. */
export function useSaveTest(id: string) {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async (input: TestResultInput & { submit: boolean }) => {
      await rpc<null>(supabase, 'enter_test_result', {
        p_id: id,
        p_score: input.score,
        p_note: input.note,
        p_level_code: input.level,
        p_framework_code: input.framework,
      });
      if (input.submit) await rpc<null>(supabase, 'complete_student_test', { p_id: id });
    },
    onSettled: () => {
      void client.invalidateQueries({ queryKey: ['gv-test-sheet', id] });
      void client.invalidateQueries({ queryKey: ['gv-todo-tests'] });
    },
  });
}
