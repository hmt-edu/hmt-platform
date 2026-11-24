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
