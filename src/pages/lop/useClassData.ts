// Gọi dữ liệu màn Lớp: danh sách phân trang (LOP-01), hồ sơ (LOP-02), lịch tuần (LOP-08), danh mục cho bộ lọc.
// Lọc, tìm, sắp xếp, phân trang ở máy chủ (CLAUDE.md, Hiệu năng).
import { keepPreviousData, useQueries, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { ClassFilters } from './classFilters';
import type { ClassPage, ClassRecord, WeekSession } from './classTypes';

export function useClassPage(
  filters: ClassFilters,
  sort: string,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['class-list', filters, sort, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ClassPage>(supabase, 'list_classes', {
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useClassRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['class-record', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<ClassRecord>(supabase, 'get_class_record', { p_class_id: id }),
  });
}

export function useWeekSessions(branchId: string | undefined, from: string, to: string) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['class-week', branchId, from, to],
    enabled: Boolean(branchId),
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<WeekSession[]>(supabase, 'week_sessions', {
        p_branch_id: branchId,
        p_from: from,
        p_to: to,
      }),
  });
}

type CatalogRow = { catalog_code: string; code: string; name: string; is_active: boolean };

/** Danh mục dùng cho bộ lọc và nhãn của màn Lớp (môn, khối, phân loại, trình độ, tình trạng duyệt). Đổi hiếm nên giữ suốt phiên. */
export function useClassCatalogs() {
  const supabase = useDb();
  const query = useQuery({
    queryKey: ['class-catalogs'],
    staleTime: Infinity,
    queryFn: async (): Promise<CatalogRow[]> => {
      const { data, error } = await supabase
        .schema('app')
        .from('catalog_item')
        .select('catalog_code, code, name, is_active, sort_order')
        .in('catalog_code', ['SUBJECT', 'GRADE', 'CLASS_TYPE', 'LEVEL', 'CLASS_STATUS'])
        .order('sort_order');
      if (error) throw error;
      return data;
    },
  });
  const items = query.data ?? [];
  return {
    ready: !query.isPending,
    options: (catalog: string) =>
      items
        .filter((i) => i.catalog_code === catalog && i.is_active)
        .map((i) => ({ value: i.code, label: i.name })),
    name: (catalog: string, code: string | null | undefined) =>
      items.find((i) => i.catalog_code === catalog && i.code === code)?.name,
  };
}

export function useRefreshClasses() {
  const client = useQueryClient();
  return useCallback(
    () =>
      Promise.all([
        client.invalidateQueries({ queryKey: ['class-list'] }),
        client.invalidateQueries({ queryKey: ['class-board'] }),
        client.invalidateQueries({ queryKey: ['class-record'] }),
        client.invalidateQueries({ queryKey: ['class-week'] }),
      ]),
    [client],
  );
}

export type TransitionResult = { to: string; sessions_created?: number; warnings?: unknown[] };

/** Đổi tình trạng duyệt của lớp (LOP-05, LOP-06): một lần gọi app.transition_class; bị chặn thì ném lỗi có mã và câu tiếng Việt. */
export function transitionClass(
  supabase: SupabaseClient,
  id: string,
  to: string,
  note: string | null,
): Promise<TransitionResult> {
  return rpc<TransitionResult>(supabase, 'transition_class', { p_id: id, p_to: to, p_note: note });
}

export type FormOptions = {
  teachers: { id: string; name: string; staff_code: string | null }[];
  assistants: { id: string; name: string; staff_code: string | null }[];
  cskh: { id: string; name: string; staff_code: string | null }[];
  rooms: { id: string; name: string; capacity: number | null }[];
  groups: { id: string; grade_code: string; name: string | null }[];
};

/** Lựa chọn của biểu mẫu LOP-03 theo cơ sở: giáo viên, trợ giảng, CSKH, phòng, nhóm lớp (một lần gọi). */
export function useClassFormOptions(branchId: string) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['class-form-options', branchId],
    enabled: branchId !== '',
    queryFn: () => rpc<FormOptions>(supabase, 'list_class_form_options', { p_branch_id: branchId }),
  });
}

/** Năm cột Kanban của LOP-01 theo bước duyệt (khung LOP01_kanban); Đã đóng và Huỷ không có cột, xem ở danh sách. */
export const KANBAN_STATUSES = ['NHAP', 'DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET', 'TU_CHOI'] as const;

/** Mỗi cột một lần gọi list_classes, chỉ vài thẻ đầu (phân trang ở máy chủ); cột đã là một tình trạng nên bỏ bộ lọc tình trạng duyệt của người dùng. */
export function useClassBoard(filters: ClassFilters, perColumn: number | null, enabled: boolean) {
  const supabase = useDb();
  return useQueries({
    queries: KANBAN_STATUSES.map((status) => {
      const chosen = (filters.status as string[] | undefined) ?? [];
      const hidden = chosen.length > 0 && !chosen.includes(status);
      return {
        queryKey: ['class-board', filters, status, perColumn],
        enabled: enabled && perColumn !== null,
        placeholderData: keepPreviousData,
        queryFn: (): Promise<ClassPage> =>
          hidden
            ? Promise.resolve({ total: 0, rows: [] })
            : rpc<ClassPage>(supabase, 'list_classes', {
                p_filters: { ...filters, status: [status] },
                p_sort: 'code_asc',
                p_limit: perColumn,
                p_offset: 0,
              }),
      };
    }),
  });
}
