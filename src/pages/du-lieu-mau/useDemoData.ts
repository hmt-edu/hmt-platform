// Dữ liệu mẫu staging: hỏi nút có hiện không (app.demo_data_available), liệt kê/tạo/xoá bộ (app.list_demo_data_sets, create_demo_data_set, delete_demo_data_set).
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '../../lib/auth/authContext';
import { rpc, useDb } from '../../lib/db';

export type DemoSet = {
  id: string;
  branch_id: string;
  branch_name: string;
  status_code: string;
  created_at: string;
  created_by: string;
  creator_name: string | null;
  total: number;
};

/** Nút chỉ hiện khi máy chủ báo bật (môi trường thử nghiệm và công tắc bật). Lỗi thì coi như tắt. */
export function useDemoAvailable() {
  const { supabase } = useAuth();
  return useQuery({
    queryKey: ['demo-available'],
    enabled: Boolean(supabase),
    staleTime: 5 * 60_000, // allow-number: hỏi lại sau 5 phút, không phải số nghiệp vụ
    retry: false,
    queryFn: () => {
      if (!supabase) throw new Error('Chưa cấu hình kết nối.');
      return rpc<boolean>(supabase, 'demo_data_available');
    },
  });
}

export function useDemoSets() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['demo-sets'],
    retry: false,
    queryFn: () => rpc<DemoSet[]>(supabase, 'list_demo_data_sets', { p_offset: 0 }),
  });
}

export function useCreateDemoSet() {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => rpc<string>(supabase, 'create_demo_data_set'),
    onSettled: () => client.invalidateQueries({ queryKey: ['demo-sets'] }),
  });
}

export function useDeleteDemoSet() {
  const supabase = useDb();
  const client = useQueryClient();
  return useMutation({
    mutationFn: (setId: string) => rpc<void>(supabase, 'delete_demo_data_set', { p_set_id: setId }),
    onSettled: () => client.invalidateQueries({ queryKey: ['demo-sets'] }),
  });
}

/** Mã lỗi hàm tạo bộ khi cơ sở đã đủ số bộ tối đa (người bấm có thể chưa có bộ nào để xoá). */
export const DEMO_BRANCH_FULL_CODE = 'HMT_DEMO_QUA_HAN_MUC_CO_SO';

/**
 * Câu báo khi tạo bộ lỗi. Cơ sở đủ bộ thì nói rõ nhờ Admin xoá bớt (người bấm không thấy bộ của người khác);
 * lỗi khác giữ nguyên câu của máy chủ.
 */
export function demoCreateErrorText(code: string, message: string): string {
  if (code === DEMO_BRANCH_FULL_CODE) {
    return 'Cơ sở đã đủ số bộ mẫu, nhờ Admin xoá bớt.';
  }
  return message;
}
