// Gọi dữ liệu «Chuyển người duyệt» (R-V2-44): trạng thái nút, danh sách người nhận hợp lệ, thao tác chuyển. Máy chủ kiểm mọi điều kiện.
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';

export type ReassignKind = 'DON' | 'PHIEU_THU';

export type ReassignState = {
  can: boolean;
  reason?: 'BI_KHOA' | 'MAT_QUYEN' | 'QUA_HAN' | null;
  approver_name?: string | null;
};

export type ReassignCandidate = { id: string; name: string };

/** Admin mở chứng từ đang chờ quản lý: hỏi máy chủ có hiện nút không. `enabled` do nơi dùng quyết (đúng vai trò, trạng thái, đường duyệt). */
export function useReassignState(kind: ReassignKind, id: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['reassign-state', kind, id],
    enabled,
    queryFn: () => rpc<ReassignState>(supabase, 'get_reassign_state', { p_kind: kind, p_id: id }),
  });
}

export function useReassignCandidates(kind: ReassignKind, id: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['reassign-candidates', kind, id],
    enabled,
    queryFn: () =>
      rpc<ReassignCandidate[]>(supabase, 'list_approver_candidates', { p_kind: kind, p_id: id }),
  });
}
