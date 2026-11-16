// Gọi dữ liệu QT-08: đọc cơ sở và phòng (bảng nhỏ: vài cơ sở, vài chục phòng), ghi qua update_branch_info, save_room, set_room_active (migration 225).
import type { SupabaseClient } from '@supabase/supabase-js';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { Branch, Room } from './branchLogic';

export function useBranchesAndRooms() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['branches-rooms'],
    queryFn: async () => {
      const [branches, rooms] = await Promise.all([
        fetchRows<Branch>(
          supabase
            .schema('app')
            .from('branch')
            .select('id, code, name, address, is_active')
            .order('sort_order')
            .order('code'),
        ),
        fetchRows<Room>(
          supabase
            .schema('app')
            .from('room')
            .select('id, branch_id, code, name, capacity, is_active')
            .order('sort_order')
            .order('code'),
        ),
      ]);
      return { branches: branches.rows, rooms: rooms.rows };
    },
  });
}

export function useRefreshBranches() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['branches-rooms'] }),
    [queryClient],
  );
}

export const updateBranchInfo = (
  supabase: SupabaseClient,
  id: string,
  name: string,
  address: string,
) => rpc<null>(supabase, 'update_branch_info', { p_id: id, p_name: name, p_address: address });

export const saveRoom = (supabase: SupabaseClient, data: Record<string, unknown>) =>
  rpc<{ id: string; created: boolean }>(supabase, 'save_room', { p_data: data });

export const setRoomActive = (supabase: SupabaseClient, id: string, active: boolean) =>
  rpc<null>(supabase, 'set_room_active', { p_id: id, p_active: active });
