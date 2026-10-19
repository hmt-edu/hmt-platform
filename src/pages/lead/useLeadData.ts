// Gọi dữ liệu màn Lead: danh sách, Kanban, đếm nhóm, dòng của nhóm lá, nhân sự được giao, và các thao tác ghi.
// Mọi lọc, sắp xếp, phân trang, nhóm làm ở cơ sở dữ liệu (CLAUDE.md, Hiệu năng); mỗi màn vài lần gọi.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback, useEffect, useRef, useState } from 'react';
import { rpc, toHmtError, useDb } from '../../lib/db';
import type { LeadFilters } from './leadFilters';
import type { BoardColumn, ExportResult, GroupCounts, LeadPage, LeadRow } from './leadTypes';

export function useLeadPage(
  filters: LeadFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['lead-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<LeadPage>(supabase, 'list_leads', {
        p_filters: filters,
        p_sort: sort ?? 'created_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useLeadBoard(filters: LeadFilters, perColumn: number | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['lead-board', filters, perColumn],
    enabled: enabled && perColumn !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<BoardColumn[]>(supabase, 'lead_board', { p_filters: filters, p_per_column: perColumn }),
  });
}

export function useGroupCounts(filters: LeadFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['lead-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'lead_group_counts', { p_filters: filters, p_fields: fields }),
  });
}

export type Leaf = { rows: LeadRow[]; total: number; loading: boolean };
const LOADING_LEAF: Leaf = { rows: [], total: 0, loading: true };

type LeafStore = { key: string; leaves: Record<string, Leaf> };

/**
 * Dòng của các nhóm lá (Group By ở máy chủ): tải khi người dùng mở nhóm, "Xem thêm" tải trang kế tiếp.
 * `resetKey` đổi (đổi bộ lọc, sắp xếp, làm mới) thì bỏ dữ liệu cũ và tải lại các nhóm đang mở.
 * Nhóm đang mở mà chưa có dữ liệu coi là đang tải. Lỗi báo qua `onError` (hộp thông báo của màn).
 */
export function useLeafRows(
  baseFilters: LeadFilters,
  sort: string | undefined,
  pageSize: number | null,
  resetKey: string,
  onError: (message: string) => void,
) {
  const supabase = useDb();
  const [store, setStore] = useState<LeafStore>({ key: resetKey, leaves: {} });
  const [open, setOpen] = useState<Record<string, LeadFilters>>({});
  const latestKey = useRef(resetKey);
  const inflight = useRef(new Set<string>());
  const loaded = store.key === resetKey ? store.leaves : undefined;

  const fetchPage = useCallback(
    async (key: string, groupFilters: LeadFilters, offset: number): Promise<LeadPage | null> => {
      if (pageSize === null) return null;
      try {
        return await rpc<LeadPage>(supabase, 'list_leads', {
          p_filters: { ...baseFilters, ...groupFilters },
          p_sort: sort ?? 'created_desc',
          p_limit: pageSize,
          p_offset: offset,
        });
      } catch (error) {
        onError(toHmtError(error as { message: string }).message);
        return null;
      } finally {
        inflight.current.delete(`${resetKey}|${key}|${offset}`);
      }
    },
    [supabase, baseFilters, sort, pageSize, resetKey, onError],
  );

  const apply = useCallback(
    (key: string, page: LeadPage | null, append: boolean) => {
      // Trả lời của bộ lọc cũ (đã đổi trong lúc chờ): bỏ.
      if (latestKey.current !== resetKey) return;
      setStore((prev) => {
        const base = prev.key === resetKey ? prev.leaves : {};
        const old = base[key];
        const next: Leaf = page
          ? {
              rows: append ? [...(old?.rows ?? []), ...page.rows] : page.rows,
              total: page.total,
              loading: false,
            }
          : { rows: old?.rows ?? [], total: old?.total ?? 0, loading: false };
        return { key: resetKey, leaves: { ...base, [key]: next } };
      });
    },
    [resetKey],
  );

  useEffect(() => {
    latestKey.current = resetKey;
  }, [resetKey]);

  // Nhóm đang mở chưa có dữ liệu (lần đầu mở, hoặc sau khi đổi bộ lọc): tải trang đầu.
  useEffect(() => {
    for (const [key, groupFilters] of Object.entries(open)) {
      const flight = `${resetKey}|${key}|0`;
      if (loaded?.[key] || inflight.current.has(flight)) continue;
      inflight.current.add(flight);
      void fetchPage(key, groupFilters, 0).then((page) => apply(key, page, false));
    }
  }, [open, loaded, resetKey, fetchPage, apply]);

  const leaves: Record<string, Leaf> = {};
  for (const key of Object.keys(open)) leaves[key] = loaded?.[key] ?? LOADING_LEAF;

  const toggle = (key: string, groupFilters: LeadFilters, isOpen: boolean) =>
    setOpen((current) => {
      const next = { ...current };
      if (isOpen) next[key] = groupFilters;
      else delete next[key];
      return next;
    });

  const more = (key: string, groupFilters: LeadFilters) => {
    const current = loaded?.[key];
    if (!current || current.loading) return;
    setStore({
      key: resetKey,
      leaves: { ...(loaded ?? {}), [key]: { ...current, loading: true } },
    });
    void fetchPage(key, groupFilters, current.rows.length).then((page) => apply(key, page, true));
  };

  return { leaves, toggle, more };
}

/** Đổi giai đoạn lead (kéo thả Kanban, Hoàn tác). Hàm trong cơ sở dữ liệu kiểm quyền và luật C4D. */
export async function changeLeadStage(
  supabase: SupabaseClient,
  id: string,
  stage: string,
  substage: string | null,
): Promise<void> {
  await rpc<null>(supabase, 'change_lead_stage', {
    p_id: id,
    p_stage_code: stage,
    p_substage_code: substage,
  });
}

export async function assignLeads(
  supabase: SupabaseClient,
  ids: string[],
  ownerId: string,
): Promise<number> {
  return rpc<number>(supabase, 'assign_owner', {
    p_entity_type: 'LEAD',
    p_ids: ids,
    p_owner_id: ownerId,
  });
}

export async function exportLeads(
  supabase: SupabaseClient,
  filters: LeadFilters,
): Promise<ExportResult> {
  return rpc<ExportResult>(supabase, 'export_leads', { p_filters: filters });
}

/** Tải lại mọi dữ liệu màn Lead sau một thao tác ghi. */
export function useRefreshLeads() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['lead-list'] }),
      client.invalidateQueries({ queryKey: ['lead-board'] }),
      client.invalidateQueries({ queryKey: ['lead-groups'] }),
    ]);
  }, [client]);
}
