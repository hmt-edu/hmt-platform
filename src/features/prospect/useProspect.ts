// Gọi dữ liệu danh sách em: ba hàm DB (thêm, sửa, bỏ em) và con có sẵn của phụ huynh (chọn trong hộp «Thêm em» của cơ hội).
import { useQuery } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { rpc, useDb } from '../../lib/db';
import type { ProspectStudent } from './prospectLogic';

export type Entity = 'LEAD' | 'OPPORTUNITY';

export function addProspectStudent(
  supabase: SupabaseClient,
  entity: Entity,
  id: string,
  data: Record<string, unknown>,
) {
  return rpc<ProspectStudent[]>(supabase, 'add_prospect_student', {
    p_entity: entity,
    p_id: id,
    p_data: data,
  });
}

export function updateProspectStudent(
  supabase: SupabaseClient,
  lineId: string,
  data: Record<string, unknown>,
) {
  return rpc<ProspectStudent[]>(supabase, 'update_prospect_student', {
    p_id: lineId,
    p_data: data,
  });
}

export function removeProspectStudent(supabase: SupabaseClient, lineId: string) {
  return rpc<ProspectStudent[]>(supabase, 'remove_prospect_student', { p_id: lineId });
}

/** «Thêm em vào cơ hội cũ» (TS-06): chép em của chính lead sang cơ hội đã có. */
export function addLeadStudentsToOpportunity(
  supabase: SupabaseClient,
  opportunityId: string,
  studentIds: string[],
) {
  return rpc<ProspectStudent[]>(supabase, 'add_lead_students_to_opportunity', {
    p_opportunity_id: opportunityId,
    p_student_ids: studentIds,
  });
}

export type ParentChild = {
  id: string;
  code: string;
  full_name: string;
  grade: string | null;
};

/** Các con của phụ huynh (một lần gọi get_parent_record), chỉ tải khi hộp «Chọn con có sẵn» mở. */
export function useParentChildren(parentId: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['prospect-parent-children', parentId],
    enabled: enabled && parentId !== null,
    queryFn: async () => {
      const rec = await rpc<{ children: ParentChild[] }>(supabase, 'get_parent_record', {
        p_parent_id: parentId,
      });
      return rec.children;
    },
  });
}
