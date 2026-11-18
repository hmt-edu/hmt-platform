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
  UpsaleRecord,
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

/** TT-02: bản ghi một phiếu, một lần gọi app.get_upsale_ticket. */
export function useUpsaleRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['upsale-record', id],
    enabled: id !== undefined,
    queryFn: () => rpc<UpsaleRecord>(supabase, 'get_upsale_ticket', { p_id: id }),
  });
}

export function useRefreshUpsaleRecord(id: string) {
  const queryClient = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['upsale-record', 'upsale-list', 'upsale-board'].map((key) =>
          queryClient.invalidateQueries({ queryKey: key === 'upsale-record' ? [key, id] : [key] }),
        ),
      ),
    [queryClient, id],
  );
}

export function changeUpsaleStage(
  supabase: SupabaseClient,
  id: string,
  to: string,
  reasonCode: string | null,
  note: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'change_upsale_stage', {
    p_id: id,
    p_to: to,
    p_reason_code: reasonCode,
    p_note: note,
  });
}

export function saveUpsaleNotes(
  supabase: SupabaseClient,
  id: string,
  goal: string,
  roadmap: string,
): Promise<{ changed: boolean }> {
  return rpc<{ changed: boolean }>(supabase, 'update_upsale_notes', {
    p_id: id,
    p_next_goal: goal,
    p_next_roadmap: roadmap,
  });
}
