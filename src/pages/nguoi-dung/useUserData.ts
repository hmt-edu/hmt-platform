// Gọi dữ liệu màn Người dùng: danh sách phân trang, bản ghi, xuất, và các thao tác của Admin. Đọc, xuất, thu hồi phiên, đặt lại hai
// bước, đổi quản lý gọi thẳng hàm DB bằng token Admin; đổi vai trò, cơ sở, khoá, mở khoá qua Edge Function admin-users (cần khoá
// secret của Supabase Auth để cấm đăng nhập). Phân trang, lọc, tìm làm ở máy chủ (CLAUDE.md, Hiệu năng).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { callFunction, rpc, useDb } from '../../lib/db';
import type { UserFilters } from './userFilters';
import type { UserExport, UserPage, UserRecord } from './userTypes';

export function useUserPage(
  filters: UserFilters,
  sort: string,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['user-list', filters, sort, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<UserPage>(supabase, 'list_users', {
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useUserRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['user-record', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<UserRecord>(supabase, 'get_user', { p_id: id }),
  });
}

/** Tải lại danh sách và bản ghi sau một thao tác ghi. */
export function useRefreshUsers() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['user-list'] }),
      client.invalidateQueries({ queryKey: ['user-record'] }),
    ]);
  }, [client]);
}

export function exportUsers(supabase: SupabaseClient, filters: UserFilters): Promise<UserExport> {
  return rpc<UserExport>(supabase, 'export_users', { p_filters: filters });
}

// ---- Thao tác ghi của Admin ----

export async function setUserRoles(
  supabase: SupabaseClient,
  userId: string,
  roles: string[],
): Promise<void> {
  await callFunction(supabase, 'admin-users', { action: 'set_roles', userId, roles });
}

export async function setUserBranch(
  supabase: SupabaseClient,
  userId: string,
  branchCode: string,
): Promise<void> {
  await callFunction(supabase, 'admin-users', { action: 'set_branch', userId, branchCode });
}

export async function lockUser(
  supabase: SupabaseClient,
  userId: string,
  reason: string,
): Promise<void> {
  await callFunction(supabase, 'admin-users', { action: 'lock', userId, reason });
}

export async function unlockUser(supabase: SupabaseClient, userId: string): Promise<void> {
  await callFunction(supabase, 'admin-users', { action: 'unlock', userId });
}

/** Đặt lại mật khẩu: máy chủ sinh mật khẩu tạm, trả MỘT lần (hiện ở hộp mật khẩu tạm, không lưu ở đâu); người đó phải đổi ở lần đăng nhập đầu. */
export async function resetUserPassword(supabase: SupabaseClient, userId: string): Promise<string> {
  const result = await callFunction<{ ok: boolean; password?: string }>(supabase, 'admin-users', {
    action: 'reset_password',
    userId,
  });
  if (!result.password) throw new Error('Máy chủ không trả mật khẩu tạm.');
  return result.password;
}

/** Đổi quản lý trực tiếp (R-HT-06): người quản lý trống là bỏ quản lý. */
export async function setUserManager(
  supabase: SupabaseClient,
  userId: string,
  managerId: string | null,
): Promise<void> {
  await rpc<unknown>(supabase, 'set_manager', { p_user_id: userId, p_manager_id: managerId });
}

export async function revokeUserSessions(supabase: SupabaseClient, userId: string): Promise<void> {
  await rpc<unknown>(supabase, 'admin_revoke_sessions', { p_user_id: userId });
}

export async function resetUserMfa(
  supabase: SupabaseClient,
  userId: string,
): Promise<{ removed: number }> {
  return rpc<{ removed: number }>(supabase, 'admin_reset_mfa', { p_user_id: userId });
}

// ---- Tạo người dùng (QT-03), Sửa email ----

export type CreateUserInput = {
  displayName: string;
  username: string;
  email: string;
  branchCode: string;
  staffKind: string;
  roles: string[];
};

/** Tạo tài khoản nhân sự: Edge Function tạo ở Supabase Auth rồi hàm DB; máy chủ sinh mật khẩu tạm, trả MỘT lần cho hộp K4g. */
export async function createUser(
  supabase: SupabaseClient,
  input: CreateUserInput,
): Promise<string> {
  const result = await callFunction<{ userId: string; password?: string }>(
    supabase,
    'admin-users',
    {
      action: 'create',
      displayName: input.displayName,
      username: input.username,
      email: input.email,
      branchCode: input.branchCode,
      staffKind: input.staffKind,
      roles: input.roles,
    },
  );
  if (!result.password) throw new Error('Máy chủ không trả mật khẩu tạm.');
  return result.password;
}

export type FieldCheck = { username: string | null; email: string | null };

/** Kiểm trùng tên đăng nhập, email ngay ở ô (không ghi gì). */
export function checkAccountFields(
  supabase: SupabaseClient,
  username: string,
  email: string,
): Promise<FieldCheck> {
  return rpc<FieldCheck>(supabase, 'check_account_fields', {
    p_username: username,
    p_email: email,
  });
}

export function useAccountFormDefaults(enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['account-form-defaults'],
    enabled,
    staleTime: Infinity,
    queryFn: () => rpc<{ email_domain: string }>(supabase, 'get_account_form_defaults', {}),
  });
}

/** Sửa email của người khác (Admin): máy chủ đổi ở Supabase Auth và DB, thu hồi mọi phiên của người đó, ghi nhật ký. */
export async function setUserEmail(
  supabase: SupabaseClient,
  userId: string,
  email: string,
): Promise<void> {
  await callFunction(supabase, 'admin-users', { action: 'set_email', userId, email });
}
