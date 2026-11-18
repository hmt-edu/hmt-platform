// Gọi dữ liệu màn Phiếu tái tục: danh sách phân trang ở máy chủ, Kanban một lần gọi, thao tác tạo, giao (máy chủ kiểm quyền, luật, công tắc).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type {
  UpsaleAssignee,
  UpsaleBoardColumn,
  UpsaleFilters,
  UpsalePage,
  UpsalePreview,
} from './upsaleTypes';

export function useUpsalePage(filters: UpsaleFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['upsale-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<UpsalePage>(supabase, 'list_upsale_tickets', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Kanban L1 đến L8: một lần gọi app.upsale_board; chỉ gọi khi đang xem Kanban. */
export function useUpsaleBoard(filters: UpsaleFilters, perColumn: number | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['upsale-board', filters, perColumn],
    enabled: enabled && perColumn !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<UpsaleBoardColumn[]>(supabase, 'upsale_board', {
        p_filters: filters,
        p_per_column: perColumn,
      }),
  });
}

export function useRefreshUpsale() {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['upsale-list', 'upsale-board'].map((key) =>
          queryClient.invalidateQueries({ queryKey: [key] }),
        ),
      ),
    [queryClient],
  );
}

/** Hộp «Tạo phiếu tái tục thủ công»: xem học sinh, lớp của mã ghi danh đang nhập (gọi khi mã đủ dài). */
export function useUpsalePreview(code: string) {
  const supabase = useDb();
  const trimmed = code.trim();
  return useQuery({
    queryKey: ['upsale-preview', trimmed.toUpperCase()],
    enabled: trimmed.length >= 3, // allow-number: độ dài tối thiểu mã ghi danh để bắt đầu tra, không phải luật nghiệp vụ
    queryFn: () =>
      rpc<UpsalePreview>(supabase, 'preview_upsale_enrollment', { p_enrollment_code: trimmed }),
  });
}

export function createUpsaleFromEnrollment(
  supabase: SupabaseClient,
  code: string,
): Promise<{ id: string; code: string }> {
  return rpc<{ id: string; code: string }>(supabase, 'create_upsale_ticket_from_enrollment', {
    p_enrollment_code: code.trim(),
  });
}

export function useUpsaleAssignees(ticketId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['upsale-assignees', ticketId],
    enabled,
    queryFn: () =>
      rpc<UpsaleAssignee[]>(supabase, 'list_upsale_assignees', { p_ticket_id: ticketId }),
  });
}

export function assignUpsale(supabase: SupabaseClient, id: string, ownerId: string): Promise<void> {
  return rpc<void>(supabase, 'assign_upsale_ticket', { p_id: id, p_owner_id: ownerId });
}
