import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';

export type StaffRow = {
  id: string;
  display_name: string;
  branch_code: string;
  role_names: string[];
};

/** Nhân sự có thể được giao một loại bản ghi (hàm list_assignable_staff kiểm quyền Giao việc và cơ sở). */
export function useAssignableStaff(entityType: string, branchId: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['assignable-staff', entityType, branchId],
    enabled,
    queryFn: () =>
      rpc<StaffRow[]>(supabase, 'list_assignable_staff', {
        p_entity_type: entityType,
        p_branch_id: branchId,
      }),
  });
}
