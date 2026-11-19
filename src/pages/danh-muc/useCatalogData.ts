// Gọi dữ liệu QT-06, QT-07 Danh mục. Đọc qua hàm DB list_catalog_summary (cột trái), get_catalog_tree (bảng phải); ghi qua catalog_add_item,
// catalog_rename_item, catalog_set_item_active, catalog_move_item (Admin). Sau khi ghi làm mới cả hai danh sách và danh mục dùng ở ô chọn
// các màn khác (khoá 'lead-catalogs').
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { rpc, useDb } from '../../lib/db';
import type { CatalogSummary, CatalogTree } from './catalogLogic';

export function useCatalogSummary() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['catalog-summary'],
    placeholderData: keepPreviousData,
    queryFn: () => rpc<CatalogSummary[]>(supabase, 'list_catalog_summary'),
  });
}

export function useCatalogTree(rootCode: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['catalog-tree', rootCode],
    enabled: rootCode !== null,
    placeholderData: keepPreviousData,
    queryFn: () => rpc<CatalogTree>(supabase, 'get_catalog_tree', { p_root_code: rootCode }),
  });
}

export function useRefreshCatalogs() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['catalog-summary'] }),
      client.invalidateQueries({ queryKey: ['catalog-tree'] }),
      client.invalidateQueries({ queryKey: ['lead-catalogs'] }),
    ]);
  }, [client]);
}

export function addCatalogItem(
  supabase: SupabaseClient,
  input: {
    catalog_code: string;
    code: string;
    name: string;
    parent_id: string | null;
    sort_order: number | null;
  },
) {
  return rpc<string>(supabase, 'catalog_add_item', {
    p_catalog_code: input.catalog_code,
    p_code: input.code,
    p_name: input.name,
    p_sort_order: input.sort_order,
    p_parent_id: input.parent_id,
  });
}

export function renameCatalogItem(supabase: SupabaseClient, id: string, name: string) {
  return rpc<null>(supabase, 'catalog_rename_item', { p_item_id: id, p_name: name });
}

export function setCatalogItemActive(supabase: SupabaseClient, id: string, active: boolean) {
  return rpc<null>(supabase, 'catalog_set_item_active', { p_item_id: id, p_active: active });
}

export function moveCatalogItem(supabase: SupabaseClient, id: string, direction: 'LEN' | 'XUONG') {
  return rpc<null>(supabase, 'catalog_move_item', { p_item_id: id, p_direction: direction });
}

/** Form nhận xét của từng loại buổi (A25): 9 tiêu chí hoặc form điểm; đọc app.list_session_type_forms, sửa bằng app.set_session_type_form (Admin). */
export type SessionTypeForm = {
  type_code: string;
  name: string;
  form_code: 'TIEU_CHI' | 'DIEM';
  is_active: boolean;
  sort_order: number;
};

export function useSessionTypeForms() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['session-type-forms'],
    queryFn: () => rpc<SessionTypeForm[]>(supabase, 'list_session_type_forms'),
  });
}

export function setSessionTypeForm(supabase: SupabaseClient, typeCode: string, formCode: string) {
  return rpc<null>(supabase, 'set_session_type_form', {
    p_type_code: typeCode,
    p_form_code: formCode,
  });
}
