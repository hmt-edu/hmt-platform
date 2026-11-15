// Gọi dữ liệu CH-04 Chính sách chiết khấu, quà tặng: đọc discount_policy và gift_policy kèm gói quà (bảng cấu hình vài chục dòng, mỗi bảng một lần gọi), danh mục nhóm gói,
// gói quà chọn được (DV, TL đang bán). Ghi qua save_discount_policy, save_gift_policy (tạo, sửa) và set_config_active (Ngừng, Dùng lại); quyền Cấu hình bán hàng kiểm ở DB.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { DiscountPolicy, GiftPolicy } from './policyLogic';

export type NamedCode = { code: string; name: string };
export type GiftPackage = { id: string; code: string; name: string; package_type_code: string };

export function useDiscountPolicies() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['discount-policies'],
    queryFn: async () =>
      (
        await fetchRows<DiscountPolicy>(
          supabase
            .schema('app')
            .from('discount_policy')
            .select(
              'id, code, name, kind, max_value, fixed_value, requires_approval, valid_from, valid_to, package_type_codes, branch_ids, is_active, is_flexible',
            )
            .order('is_flexible', { ascending: false })
            .order('name'),
        )
      ).rows,
  });
}

export function useGiftPolicies() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gift-policies'],
    queryFn: async () =>
      (
        await fetchRows<GiftPolicy>(
          supabase
            .schema('app')
            .from('gift_policy')
            .select(
              'id, code, name, gift_package_id, max_quantity, requires_approval, valid_from, valid_to, package_type_codes, branch_ids, is_active, gift_package:sales_package(code, name, package_type_code)',
            )
            .order('name'),
        )
      ).rows,
  });
}

export function usePackageTypes() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['package-types'],
    staleTime: Infinity,
    queryFn: async () =>
      (
        await fetchRows<NamedCode>(
          supabase
            .schema('app')
            .from('catalog_item')
            .select('code, name')
            .eq('catalog_code', 'PACKAGE_TYPE')
            .eq('is_active', true)
            .order('sort_order'),
        )
      ).rows,
  });
}

export function useGiftPackages() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['gift-packages'],
    queryFn: async () =>
      (
        await fetchRows<GiftPackage>(
          supabase
            .schema('app')
            .from('sales_package')
            .select('id, code, name, package_type_code')
            .in('package_type_code', ['DV', 'TL'])
            .eq('is_active', true)
            .order('name'),
        )
      ).rows,
  });
}

export function saveDiscountPolicy(
  supabase: SupabaseClient,
  id: string | null,
  data: Record<string, unknown>,
): Promise<string> {
  return rpc<string>(supabase, 'save_discount_policy', { p_id: id, p_data: data });
}

export function saveGiftPolicy(
  supabase: SupabaseClient,
  id: string | null,
  data: Record<string, unknown>,
): Promise<string> {
  return rpc<string>(supabase, 'save_gift_policy', { p_id: id, p_data: data });
}

export function setPolicyActive(
  supabase: SupabaseClient,
  entity: 'DISCOUNT_POLICY' | 'GIFT_POLICY',
  id: string,
  active: boolean,
): Promise<void> {
  return rpc<void>(supabase, 'set_config_active', {
    p_entity: entity,
    p_id: id,
    p_active: active,
  });
}

export function useRefreshPolicies() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['discount-policies'] }),
      client.invalidateQueries({ queryKey: ['gift-policies'] }),
    ]);
  }, [client]);
}
