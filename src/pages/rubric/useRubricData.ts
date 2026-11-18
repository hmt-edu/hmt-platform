// Gọi dữ liệu CH-07: đọc rubric (một lần gọi get_rubric), danh sách môn và bộ của môn, sửa mô tả, tạo phiên bản (mỗi nút một hàm DB).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { Rubric } from './rubricLogic';

export function useRubric(subjectSet: string, versionId: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['rubric', subjectSet, versionId],
    queryFn: () =>
      rpc<Rubric>(supabase, 'get_rubric', { p_subject_set: subjectSet, p_version_id: versionId }),
  });
}

export type SubjectOption = { code: string; name: string; set: string };

/** Môn trong danh mục và bộ tiêu chí của môn (review_subject_set); vài chục dòng, một lần gọi mỗi bảng. */
export function useRubricSubjects() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['rubric-subjects'],
    queryFn: async (): Promise<SubjectOption[]> => {
      const [subjects, sets] = await Promise.all([
        fetchRows<{ code: string; name: string }>(
          supabase
            .schema('app')
            .from('catalog_item')
            .select('code, name')
            .eq('catalog_code', 'SUBJECT')
            .eq('is_active', true)
            .order('sort_order'),
        ),
        fetchRows<{ subject_code: string; subject_set: string }>(
          supabase.schema('app').from('review_subject_set').select('subject_code, subject_set'),
        ),
      ]);
      const map = new Map(sets.rows.map((s) => [s.subject_code, s.subject_set]));
      return subjects.rows.map((s) => ({
        ...s,
        set: map.get(s.code) === 'TOAN' ? 'TOAN' : 'MON_PHU',
      }));
    },
  });
}

/** Lưu nhiều ô trong MỘT giao dịch (update_review_level_descs). */
export function saveLevelDescs(
  supabase: SupabaseClient,
  versionId: string,
  items: { criterionId: string; level: number; description: string }[],
): Promise<number> {
  return rpc<number>(supabase, 'update_review_level_descs', {
    p_version_id: versionId,
    p_items: items.map((i) => ({
      criterion_id: i.criterionId,
      level: i.level,
      description: i.description,
    })),
  });
}

export function createRubricVersion(
  supabase: SupabaseClient,
  subjectSet: string,
  note: string,
): Promise<string> {
  return rpc<string>(supabase, 'create_rubric_version', {
    p_subject_set: subjectSet,
    p_note: note,
  });
}

export function useRefreshRubric() {
  const client = useQueryClient();
  return useCallback(async () => {
    await client.invalidateQueries({ queryKey: ['rubric'] });
  }, [client]);
}
