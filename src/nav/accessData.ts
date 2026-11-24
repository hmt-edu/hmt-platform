// Dữ liệu khung đọc từ cơ sở dữ liệu: ma trận quyền, vai trò, cơ sở, công tắc tính năng.
// Chỉ để giao diện ẩn/hiện cho gọn; quyền thật do RLS và hàm trong cơ sở dữ liệu chặn.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useAuth } from '../lib/auth/authContext';
import { intSettingQuery, toHmtError } from '../lib/db';

export type PermissionRow = {
  role_code: string;
  module_code: string;
  action_code: string;
  scope_code: string;
};
export type RoleRow = { code: string; name: string; default_scope: string; portals: string[] };
export type BranchRow = { id: string; code: string; name: string; is_office: boolean };
export type FeatureRow = { module_code: string; branch_id: string; enabled: boolean };

export type AccessData = {
  permissions: PermissionRow[];
  roles: RoleRow[];
  branches: BranchRow[];
  features: FeatureRow[];
};

/** Phạm vi rộng nhất: thấy mọi cơ sở (danh mục PERM_SCOPE). */
export const SCOPE_ALL = 'TOAN_HE_THONG';

async function rows<T>(
  query: PromiseLike<{ data: unknown; error: { message: string } | null }>,
): Promise<T[]> {
  const { data, error } = await query;
  if (error) throw toHmtError(error);
  return (data ?? []) as T[];
}

export async function loadAccessData(
  supabase: SupabaseClient,
  roleCodes: string[],
): Promise<AccessData> {
  const app = supabase.schema('app');
  const [permissions, roles, branches, features] = await Promise.all([
    rows<PermissionRow>(
      app
        .from('permission')
        .select('role_code, module_code, action_code, scope_code')
        .eq('is_active', true)
        .in('role_code', roleCodes),
    ),
    rows<RoleRow>(
      app.from('role').select('code, name, default_scope, portals').order('sort_order'),
    ),
    rows<BranchRow>(
      app
        .from('branch')
        .select('id, code, name, is_office')
        .eq('is_active', true)
        .order('sort_order'),
    ),
    rows<FeatureRow>(app.from('feature_flag').select('module_code, branch_id, enabled')),
  ]);
  return { permissions, roles, branches, features };
}

// Tham số mà màn đầu của cổng dùng ngay (cỡ trang danh sách): tải CÙNG LÚC với dữ liệu quyền, không đợi màn mở rồi mới gọi (đo 18/11: gọi nối tiếp mất thêm ~0,3 s).
const PREFETCH_INT_SETTINGS = ['list_page_size_default'];

export function useAccessData() {
  const { supabase, claims } = useAuth();
  const client = useQueryClient();
  const roleKey = claims?.roles.join(',') ?? '';
  const userId = claims?.userId;
  useEffect(() => {
    if (!supabase || !userId) return;
    for (const key of PREFETCH_INT_SETTINGS)
      void client.prefetchQuery(intSettingQuery(supabase, key));
  }, [client, supabase, userId]);
  return useQuery({
    queryKey: ['access-data', claims?.userId, roleKey],
    enabled: Boolean(supabase && claims),
    queryFn: () => {
      if (!supabase || !claims) throw new Error('Chưa đăng nhập.');
      return loadAccessData(supabase, claims.roles);
    },
  });
}
