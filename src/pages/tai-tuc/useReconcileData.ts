// Gọi dữ liệu màn TT-04: bảng phân trang ở máy chủ, thẻ tổng một lần gọi, tạo phiếu sớm (máy chủ kiểm quyền, luật, công tắc).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import { monthStart } from './reconcileLogic';
import type { ReconcilePage, ReconcileQuery, ReconcileSummary } from './reconcileTypes';

export function useReconcilePage(query: ReconcileQuery, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['upsale-reconcile', query, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ReconcilePage>(supabase, 'list_upsale_reconcile', {
        p_month: monthStart(query.month),
        p_filters: query.filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useReconcileSummary(query: ReconcileQuery) {
  const supabase = useDb();
  const branch = typeof query.filters.branch_id === 'string' ? query.filters.branch_id : null;
  return useQuery({
    queryKey: ['upsale-reconcile-summary', query.month, branch],
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ReconcileSummary>(supabase, 'upsale_reconcile_summary', {
        p_month: monthStart(query.month),
        p_branch_id: branch,
      }),
  });
}

export function useRefreshReconcile() {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['upsale-reconcile', 'upsale-reconcile-summary'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      ),
    [queryClient],
  );
}

/** Tạo phiếu tái tục sớm cho (học sinh, lớp): dùng hàm tạo tay của TT-03. */
export function createEarlyUpsale(
  supabase: SupabaseClient,
  studentId: string,
  classId: string,
): Promise<{ id: string; code: string }> {
  return rpc<{ id: string; code: string }>(supabase, 'create_upsale_ticket', {
    p_student_id: studentId,
    p_class_id: classId,
    p_note: 'Tạo sớm từ màn Đối chiếu tái tục',
  });
}
