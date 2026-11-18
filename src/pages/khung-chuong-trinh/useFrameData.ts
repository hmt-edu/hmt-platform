// Gọi dữ liệu CH-05 Khung chương trình: danh sách qua app.list_curriculum_frames (lọc, phân trang ở máy chủ), tạo khung, tạo bản mới, ngừng (kiểm quyền và luật ở DB).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { FrameFilters, FramePage } from './frameLogic';

export const FRAME_PAGE_SIZE = 50; // allow-number: mặc định phân trang danh sách (quy ước hiệu năng, tối đa 100)

export function useFrames(filters: FrameFilters, page: number, enabled = true) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['curriculum-frames', filters, page],
    enabled,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<FramePage>(supabase, 'list_curriculum_frames', {
        p_filters: filters,
        p_limit: FRAME_PAGE_SIZE,
        p_offset: page * FRAME_PAGE_SIZE,
      }),
  });
}

export function useRefreshFrames() {
  const client = useQueryClient();
  return useCallback(() => client.invalidateQueries({ queryKey: ['curriculum-frames'] }), [client]);
}

export type CreatedFrame = { id: string; code: string };

export function createFrame(
  supabase: SupabaseClient,
  input: { subject: string; grade: string; level: string; year: string },
): Promise<CreatedFrame> {
  return rpc<CreatedFrame>(supabase, 'create_curriculum_frame', {
    p_subject: input.subject,
    p_grade: input.grade,
    p_level: input.level,
    p_year: input.year,
  });
}

export function createVersion(supabase: SupabaseClient, fromId: string): Promise<CreatedFrame> {
  return rpc<CreatedFrame>(supabase, 'create_curriculum_version', { p_from_id: fromId });
}

export function setFrameActive(
  supabase: SupabaseClient,
  id: string,
  active: boolean,
): Promise<void> {
  return rpc<void>(supabase, 'set_curriculum_frame_active', { p_id: id, p_active: active });
}
