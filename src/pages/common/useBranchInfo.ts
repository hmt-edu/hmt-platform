import { useQuery } from '@tanstack/react-query';
import { useAuth } from '../../lib/auth/authContext';
import { toHmtError } from '../../lib/db';

export type BranchInfo = { name: string; address: string | null };

/** Tên và địa chỉ cơ sở của báo giá: một lần gọi, đổi rất hiếm. */
export function useBranchInfo(branchId: string | undefined) {
  const { supabase } = useAuth();
  return useQuery({
    queryKey: ['branch-info', branchId],
    enabled: Boolean(supabase) && branchId !== undefined,
    staleTime: 5 * 60_000, // allow-number: tên và địa chỉ cơ sở đổi rất hiếm, giữ năm phút trong bộ nhớ
    queryFn: async (): Promise<BranchInfo | null> => {
      if (!supabase || !branchId) return null;
      const result = await supabase
        .schema('app')
        .from('branch')
        .select('name, address')
        .eq('id', branchId)
        .maybeSingle();
      if (result.error) throw toHmtError(result.error);
      return result.data;
    },
  });
}
