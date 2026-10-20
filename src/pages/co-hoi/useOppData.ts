// Gọi dữ liệu màn Cơ hội: danh sách, Kanban L1–L8, đếm nhóm, bản ghi, và các thao tác ghi (đổi giai đoạn, Xuất).
// Mọi lọc, sắp xếp, phân trang, nhóm làm ở cơ sở dữ liệu (CLAUDE.md, Hiệu năng); mỗi màn vài lần gọi.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { LeadFilters } from '../lead/leadFilters';
import type { ExportResult, GroupCounts } from '../lead/leadTypes';
import type { OppBoardColumn, OppRecord, OpportunityPage } from './oppTypes';

export function useOppPage(
  filters: LeadFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['opp-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<OpportunityPage>(supabase, 'list_opportunities', {
        p_filters: filters,
        p_sort: sort ?? 'created_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useOppBoard(filters: LeadFilters, perColumn: number | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['opp-board', filters, perColumn],
    enabled: enabled && perColumn !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<OppBoardColumn[]>(supabase, 'opportunity_board', {
        p_filters: filters,
        p_per_column: perColumn,
      }),
  });
}

export function useOppGroupCounts(filters: LeadFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['opp-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'opportunity_group_counts', {
        p_filters: filters,
        p_fields: fields,
      }),
  });
}

export function useOpportunity(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['opp-record', id],
    enabled: id !== undefined,
    queryFn: () => rpc<OppRecord>(supabase, 'get_opportunity', { p_id: id }),
    retry: false,
  });
}

/** Đổi giai đoạn, nhóm con (TS-09). Hàm trong cơ sở dữ liệu kiểm quyền và mọi luật (R-CRM-02, 03, 12 đến 16). */
export async function changeOpportunityStage(
  supabase: SupabaseClient,
  args: {
    id: string;
    stage: string;
    substage: string | null;
    skipReason?: string | null;
    skipNote?: string | null;
    confirmL8?: boolean;
  },
): Promise<void> {
  await rpc<null>(supabase, 'change_opportunity_stage', {
    p_id: args.id,
    p_stage_code: args.stage,
    p_substage_code: args.substage,
    p_skip_reason_code: args.skipReason ?? null,
    p_skip_note: args.skipNote ?? null,
    p_confirm_l8: args.confirmL8 ?? false,
  });
}

export async function exportOpportunities(
  supabase: SupabaseClient,
  filters: LeadFilters,
): Promise<ExportResult> {
  return rpc<ExportResult>(supabase, 'export_opportunities', { p_filters: filters });
}

export async function assignOpportunities(
  supabase: SupabaseClient,
  ids: string[],
  ownerId: string,
): Promise<number> {
  return rpc<number>(supabase, 'assign_owner', {
    p_entity_type: 'OPPORTUNITY',
    p_ids: ids,
    p_owner_id: ownerId,
  });
}

/** Tải lại mọi dữ liệu màn Cơ hội sau một thao tác ghi. */
export function useRefreshOpps() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      ['opp-list', 'opp-board', 'opp-groups'].map((key) =>
        client.invalidateQueries({ queryKey: [key] }),
      ),
    );
  }, [client]);
}

/** Tải lại bản ghi cơ hội, ghi chú và hoạt động, lịch hẹn sau một thao tác ghi. */
export function useRefreshOppRecord(oppId: string) {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['opp-record', oppId] }),
      client.invalidateQueries({ queryKey: ['chatter', 'OPPORTUNITY', oppId] }),
      client.invalidateQueries({ queryKey: ['opp-upcoming', oppId] }),
      client.invalidateQueries({ queryKey: ['opp-list'] }),
      client.invalidateQueries({ queryKey: ['opp-board'] }),
      client.invalidateQueries({ queryKey: ['opp-groups'] }),
    ]);
  }, [client, oppId]);
}
