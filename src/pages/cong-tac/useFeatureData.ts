// Gọi dữ liệu QT-10 Công tắc tính năng: đọc danh mục phân hệ (MODULE) và app.feature_flag (vài chục dòng), ghi qua app.set_feature (Admin; kiểm quyền và ghi nhật ký ở DB).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { FeatureFlag, FeatureModule } from './featureLogic';

export function useFeatureModules() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['feature-modules'],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<FeatureModule>(
          supabase
            .schema('app')
            .from('catalog_item')
            .select('code, name')
            .eq('catalog_code', 'MODULE')
            .eq('is_active', true)
            .order('sort_order'),
        )
      ).rows,
  });
}

export function useFeatureFlags() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['feature-flags'],
    queryFn: async () =>
      (
        await fetchRows<FeatureFlag>(
          supabase.schema('app').from('feature_flag').select('module_code, branch_id, enabled'),
        )
      ).rows,
  });
}

export function setFeature(
  supabase: SupabaseClient,
  moduleCode: string,
  branchId: string,
  enabled: boolean,
): Promise<void> {
  return rpc<void>(supabase, 'set_feature', {
    p_module_code: moduleCode,
    p_branch_id: branchId,
    p_enabled: enabled,
  });
}

export function useRefreshFeatures() {
  const client = useQueryClient();
  return useCallback(async () => {
    // Công tắc ảnh hưởng menu và quyền truy cập: đọc lại cả dữ liệu quyền của khung.
    await client.invalidateQueries({ queryKey: ['feature-flags'] });
    await client.invalidateQueries();
  }, [client]);
}
