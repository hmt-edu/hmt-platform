// QT-16: một lần gọi rpc cho một trang danh sách hồ sơ dạy (lọc, phân trang ở máy chủ), danh sách người dùng chưa có hồ sơ, ghi hồ sơ, Ngừng/Dùng lại.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { TeachingCandidate, TeachingFilters, TeachingPage } from './teachingLogic';

export function useTeachingPage(filters: TeachingFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['teaching-profiles', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TeachingPage>(supabase, 'list_teaching_profiles', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Người dùng có vai Giáo viên, Trợ giảng chưa có hồ sơ (ô chọn khi tạo hồ sơ); chỉ gọi khi hộp thoại tạo mở. */
export function useTeachingCandidates(enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['teaching-candidates'],
    enabled,
    staleTime: 0,
    queryFn: () => rpc<TeachingCandidate[]>(supabase, 'list_teaching_candidates'),
  });
}

export function useRefreshTeaching() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['teaching-profiles'] }),
      client.invalidateQueries({ queryKey: ['teaching-candidates'] }),
    ]);
  }, [client]);
}

export function saveTeachingProfile(supabase: SupabaseClient, data: Record<string, unknown>) {
  return rpc<{ id: string }>(supabase, 'save_teaching_profile', { p_data: data });
}

export function setTeachingActive(supabase: SupabaseClient, id: string, active: boolean) {
  return rpc<null>(supabase, 'set_teaching_profile_active', { p_id: id, p_active: active });
}
