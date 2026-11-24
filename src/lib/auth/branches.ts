import { useQuery } from '@tanstack/react-query';
import { useAuth } from './authContext';
import { toHmtError } from '../db';

export type BranchName = { code: string; name: string };

/**
 * Tên các cơ sở dạy học cho cột giới thiệu của trang đăng nhập. Hàm công khai `login_branch_names`
 * (người chưa đăng nhập gọi được) chỉ trả mã và tên, không trả Hội sở hay dữ liệu nào khác.
 * Đổi rất hiếm nên giữ trong bộ nhớ suốt phiên; lỗi thì cột giới thiệu bỏ danh sách, không chặn đăng nhập.
 */
export function useBranchNames() {
  const { supabase } = useAuth();
  return useQuery({
    queryKey: ['login-branch-names'],
    enabled: Boolean(supabase),
    staleTime: Infinity,
    retry: false,
    queryFn: async (): Promise<BranchName[]> => {
      if (!supabase) return [];
      const result = await supabase.rpc('login_branch_names');
      if (result.error) throw toHmtError(result.error);
      return (result.data ?? []) as BranchName[];
    },
  });
}
