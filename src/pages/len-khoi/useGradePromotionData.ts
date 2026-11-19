// Gọi dữ liệu màn Lên khối đầu năm (KH-08): xem trước phân trang ở máy chủ, chạy đợt, hoàn tác, liệt kê đợt. Mọi luật ở hàm DB (migration 566).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { PromotionBatches, PromotionPreview, RunResult } from './gradePromotionTypes';

export function usePromotionPreview(
  filters: Record<string, unknown>,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['grade-promotion-preview', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<PromotionPreview>(supabase, 'preview_grade_promotion', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function usePromotionBatches() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['grade-promotion-batches'],
    queryFn: () => rpc<PromotionBatches>(supabase, 'list_grade_promotion_batches', {}),
  });
}

export function useRefreshPromotion() {
  const client = useQueryClient();
  return useCallback(
    () =>
      Promise.all([
        client.invalidateQueries({ queryKey: ['grade-promotion-preview'] }),
        client.invalidateQueries({ queryKey: ['grade-promotion-batches'] }),
      ]),
    [client],
  );
}

export function runPromotion(
  supabase: SupabaseClient,
  filters: Record<string, unknown>,
  excluded: string[],
): Promise<RunResult> {
  return rpc<RunResult>(supabase, 'run_grade_promotion', {
    p_filters: filters,
    p_excluded: excluded,
  });
}

export function undoPromotion(
  supabase: SupabaseClient,
  batchId: string,
): Promise<{ restored: number; kept: number }> {
  return rpc<{ restored: number; kept: number }>(supabase, 'undo_grade_promotion', {
    p_batch_id: batchId,
  });
}
