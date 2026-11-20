// Gọi hàm gộp trùng lead, cơ hội (TS-10): gợi ý bản trùng, xem trước, gộp. Luật và quyền do hàm trong cơ sở dữ liệu kiểm
// (R-CRM-22, 37); ở đây chỉ gọi và nhận kết quả.
import type { SupabaseClient } from '@supabase/supabase-js';
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';

export type MergeEntity = 'LEAD' | 'OPPORTUNITY' | 'PARENT' | 'STUDENT';

/** Lead, cơ hội dùng hộp TS-10; phụ huynh, học sinh dùng hộp KH-07 (gợi ý, gộp ở hàm riêng). */
export const isPeopleEntity = (entity: MergeEntity): boolean =>
  entity === 'PARENT' || entity === 'STUDENT';

export type MergeCandidate = {
  id: string;
  code: string;
  label: string;
  branch_code: string;
  stage_code: string;
  created_at: string;
  can_merge: boolean;
  blocker_code: string | null;
  blocker_message: string | null;
};

/** Một bên của hộp so sánh. Khoá `opportunities` chỉ có ở lead, `tests` và `stage_code` chỉ có ở cơ hội, `source` chỉ có ở lead. */
export type MergeSide = {
  code: string;
  parent_name: string;
  phone: string;
  student_name: string | null;
  source?: string | null;
  stage_code?: string;
  owner: string | null;
  branch_code: string;
  created_at: string;
  opportunities?: number;
  tests?: number;
  appointments: number;
  notes: number;
  /** Phụ huynh, học sinh: SĐT 2, năm sinh, khối và số dòng theo nhóm dữ liệu sẽ chuyển. */
  phone_2?: string | null;
  birth_year?: number | null;
  grade?: number | null;
  counts?: Record<string, number>;
};

export type MergeNotice = { code: string; message: string };

export type MergePreview = {
  keep_code: string;
  merge_code: string;
  move: Record<string, number>;
  /** Phụ huynh, học sinh: số dư của bản bị gộp, cộng vào bản giữ lại. */
  money?: { balance: number };
  blockers: MergeNotice[];
  warnings: MergeNotice[];
  sides: { keep: MergeSide; merge: MergeSide };
  items: {
    appointments: { title: string; scheduled_at: string; status: string }[];
    notes: { author: string | null; created_at: string; body: string }[];
  };
};

export type MergeResult = { keep_code: string; merge_code: string };

export function useMergeCandidates(entity: MergeEntity, id: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['merge-candidates', entity, id],
    enabled,
    staleTime: 0,
    gcTime: 0,
    retry: false,
    queryFn: () =>
      rpc<MergeCandidate[]>(
        supabase,
        isPeopleEntity(entity) ? 'merge_candidates_people' : 'merge_candidates',
        { p_entity: entity, p_id: id },
      ),
  });
}

export function useMergePreview(
  entity: MergeEntity,
  keepId: string | null,
  mergeId: string | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['merge-preview', entity, keepId, mergeId],
    enabled: keepId !== null && mergeId !== null,
    staleTime: 0,
    gcTime: 0,
    retry: false,
    queryFn: () =>
      rpc<MergePreview>(supabase, 'merge_preview', {
        p_entity: entity,
        p_keep: keepId,
        p_merge: mergeId,
      }),
  });
}

const MERGE_FUNCTION: Record<MergeEntity, string> = {
  LEAD: 'merge_leads',
  OPPORTUNITY: 'merge_opportunities',
  PARENT: 'merge_parents',
  STUDENT: 'merge_students',
};

/** Gộp thật (không hoàn tác). Hàm DB bắt buộc p_confirm = true. */
export function mergeRecords(
  supabase: SupabaseClient,
  entity: MergeEntity,
  keepId: string,
  mergeId: string,
): Promise<MergeResult> {
  return rpc<MergeResult>(supabase, MERGE_FUNCTION[entity], {
    p_keep: keepId,
    p_merge: mergeId,
    p_confirm: true,
  });
}
