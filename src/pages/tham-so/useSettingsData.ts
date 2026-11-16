// Gọi dữ liệu QT-09 Cài đặt tham số: đọc setting_def và setting_branch (Admin; vài chục dòng, một lần gọi mỗi bảng), ghi qua hàm DB set_setting và
// clear_setting_override (kiểm quyền, kiểm khoảng và ghi nhật ký ở DB).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { SettingDef, SettingOverride } from './settingsLogic';

export function useSettingDefs() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['setting-defs'],
    queryFn: async () =>
      (
        await fetchRows<SettingDef>(
          supabase
            .schema('app')
            .from('setting_def')
            .select(
              'key, name, description, value_type, unit, min_value, max_value, value, allow_branch_override, module',
            )
            .order('name'),
        )
      ).rows,
  });
}

export function useSettingOverrides() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['setting-overrides'],
    queryFn: async () =>
      (
        await fetchRows<SettingOverride>(
          supabase
            .schema('app')
            .from('setting_branch')
            .select('setting_key, branch_id, value, is_active')
            .eq('is_active', true),
        )
      ).rows,
  });
}

export function saveSetting(
  supabase: SupabaseClient,
  key: string,
  value: string,
  branchId: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'set_setting', { p_key: key, p_value: value, p_branch_id: branchId });
}

export function clearOverride(
  supabase: SupabaseClient,
  key: string,
  branchId: string,
): Promise<void> {
  return rpc<void>(supabase, 'clear_setting_override', { p_key: key, p_branch_id: branchId });
}

export function useRefreshSettings() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['setting-defs'] }),
      client.invalidateQueries({ queryKey: ['setting-overrides'] }),
      // Tham số số nguyên đang được màn khác đọc (phân trang…): đọc lại sau khi Admin sửa.
      client.invalidateQueries({ queryKey: ['setting-int'] }),
    ]);
  }, [client]);
}
