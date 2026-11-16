// Gọi dữ liệu QT-05 Ma trận quyền: đọc vai trò, danh mục phân hệ, hành động, phạm vi, ô quyền (vài trăm dòng, một lần gọi; Admin cần xem cả ma trận), phiên bản và thay đổi gần đây;
// ghi qua save_permission_matrix (Admin, kiểm phiên bản hiện hành). Sau khi lưu làm mới cả quyền của khung (menu, nút) vì quyền có hiệu lực ngay.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { Change, ChangeRow, NamedCode, PermissionRow, Role, VersionRow } from './matrixLogic';

function useCatalog(code: string) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-catalog', code],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<NamedCode>(
          supabase
            .schema('app')
            .from('catalog_item')
            .select('code, name')
            .eq('catalog_code', code)
            .order('sort_order'),
        )
      ).rows,
  });
}
export const usePermModules = () => useCatalog('PERM_MODULE');
export const usePermActions = () => useCatalog('PERM_ACTION');
export const usePermScopes = () => useCatalog('PERM_SCOPE');

export function useRoles() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-roles'],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<Role>(
          supabase.schema('app').from('role').select('code, name').order('sort_order'),
        )
      ).rows,
  });
}

export function usePermissionRows() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-rows'],
    queryFn: async () =>
      (
        await fetchRows<PermissionRow>(
          supabase
            .schema('app')
            .from('permission')
            .select('role_code, module_code, action_code, scope_code, is_active')
            .eq('is_active', true),
        )
      ).rows,
  });
}

export function usePermissionVersions() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-versions'],
    queryFn: async () =>
      (
        await fetchRows<VersionRow>(
          supabase
            .schema('app')
            .from('permission_version')
            .select('version_no, saved_at, changed_count, note')
            .order('version_no', { ascending: false })
            .limit(10),
        )
      ).rows,
  });
}

/** Thay đổi của các phiên bản gần đây (tối đa 50 dòng, mới nhất trước). */
export function usePermissionChanges(versionNos: number[]) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-changes', versionNos],
    enabled: versionNos.length > 0,
    queryFn: async () => {
      const { rows } = await fetchRows<ChangeRow & { version: { version_no: number } }>(
        supabase
          .schema('app')
          .from('permission_change')
          .select(
            'role_code, module_code, action_code, from_scope, to_scope, version:permission_version!inner(version_no)',
          )
          .in('permission_version.version_no', versionNos)
          .limit(50),
      );
      return rows.map((r) => ({ ...r, version_no: r.version.version_no }));
    },
  });
}

export function saveMatrix(
  supabase: SupabaseClient,
  baseVersion: number,
  changes: Change[],
  note: string | null,
): Promise<number> {
  return rpc<number>(supabase, 'save_permission_matrix', {
    p_base_version: baseVersion,
    p_changes: changes,
    p_note: note,
  });
}

/** Cờ sửa ma trận (tham số permission_matrix_edit_enabled, mặc định tắt): tắt thì màn chỉ xem, DB cũng chặn lưu. */
export function useMatrixEditEnabled() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['perm-edit-flag'],
    queryFn: async () => {
      const { rows } = await fetchRows<{ value: string }>(
        supabase
          .schema('app')
          .from('setting_def')
          .select('value')
          .eq('key', 'permission_matrix_edit_enabled'),
      );
      return rows[0]?.value === 'true';
    },
  });
}

export function useRefreshMatrix() {
  const client = useQueryClient();
  return useCallback(async () => {
    // Quyền có hiệu lực ngay: đọc lại ma trận, phiên bản và quyền của khung (menu, nút).
    await client.invalidateQueries();
  }, [client]);
}
