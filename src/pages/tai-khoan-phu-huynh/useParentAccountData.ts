// Gọi dữ liệu màn Tài khoản phụ huynh (QT-17): danh sách phân trang ở máy chủ; cấp tài khoản qua Edge Function admin-users (cần khoá secret
// của Supabase Auth). Đặt lại mật khẩu, khoá dùng lại hàm của màn Người dùng (cùng Edge Function).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { callFunction, rpc, useDb } from '../../lib/db';
import type { ParentAccountFilters } from './parentAccountFilters';
import type { ParentAccountPage } from './parentAccountTypes';

export function useParentAccountPage(
  filters: ParentAccountFilters,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['parent-account-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ParentAccountPage>(supabase, 'list_parent_accounts', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Tải lại danh sách sau một thao tác ghi. */
export function useRefreshParentAccounts() {
  const client = useQueryClient();
  return useCallback(
    () => client.invalidateQueries({ queryKey: ['parent-account-list'] }),
    [client],
  );
}

/** Cấp tài khoản cho một phụ huynh: máy chủ kiểm có thật và chưa có tài khoản, sinh mật khẩu tạm, trả MỘT lần (không lưu, không gửi email). */
export async function issueParentAccount(
  supabase: SupabaseClient,
  parentCode: string,
): Promise<string> {
  const result = await callFunction<{ userId: string; password?: string }>(
    supabase,
    'admin-users',
    {
      action: 'create',
      kind: 'parent',
      parentCode,
    },
  );
  if (!result.password) throw new Error('Máy chủ không trả mật khẩu tạm.');
  return result.password;
}

/** Khoá tài khoản phụ huynh: QT-17 không bắt lý do (Design 23/11); máy chủ đăng xuất mọi thiết bị. */
export async function lockParentAccount(supabase: SupabaseClient, userId: string): Promise<void> {
  await callFunction(supabase, 'admin-users', { action: 'lock', userId });
}
