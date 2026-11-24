// Gọi dữ liệu màn Gói bán (CH-01). Đọc bảng app.sales_package qua RLS (quyền Cấu hình bán hàng · Xem), lọc, tìm, phân trang ở máy chủ.
// Ghi qua hàm DB save_sales_package, set_config_active (Admin).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { fetchRows, rpc, useDb } from '../../lib/db';
import { sanitizeSearchTerm } from './packageLogic';

export type PackageRow = {
  id: string;
  code: string;
  name: string;
  package_type_code: string;
  subject_code: string | null;
  grade_from_code: string | null;
  grade_to_code: string | null;
  is_active: boolean;
  legacy_ref: string | null;
};

export type PackageFilters = { q: string; status: '' | 'active' | 'inactive'; type: string };

const COLUMNS =
  'id, code, name, package_type_code, subject_code, grade_from_code, grade_to_code, is_active, legacy_ref';

export function usePackagePage(filters: PackageFilters, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['package-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let query = supabase
        .schema('app')
        .from('sales_package')
        .select(COLUMNS, { count: 'exact' })
        .order('is_active', { ascending: false })
        .order('code');
      const q = sanitizeSearchTerm(filters.q);
      if (q !== '') query = query.or(`code.ilike.%${q}%,name.ilike.%${q}%,legacy_ref.ilike.%${q}%`);
      if (filters.status !== '') query = query.eq('is_active', filters.status === 'active');
      if (filters.type !== '') query = query.eq('package_type_code', filters.type);
      return fetchRows<PackageRow>(query.range(offset, offset + (limit ?? 1) - 1));
    },
  });
}

export function useRefreshPackages() {
  const client = useQueryClient();
  return useCallback(async () => {
    await client.invalidateQueries({ queryKey: ['package-list'] });
  }, [client]);
}

export type PackageInput = {
  code: string;
  name: string;
  package_type_code: string;
  subject_code: string;
  grade_from_code: string;
  grade_to_code: string;
  legacy_ref: string;
};

export function createPackage(supabase: SupabaseClient, input: PackageInput): Promise<string> {
  return rpc<string>(supabase, 'save_sales_package', { p_id: null, p_data: input });
}

/** Sửa gói: chỉ tên và mã cũ (mã, loại, môn, khối không đổi). */
export async function editPackage(
  supabase: SupabaseClient,
  id: string,
  data: { name: string; legacy_ref: string },
): Promise<void> {
  await rpc<unknown>(supabase, 'save_sales_package', { p_id: id, p_data: data });
}

/** Ngừng bán hoặc Dùng lại (không xoá gói; đơn đã tạo giữ nguyên). */
export async function setPackageActive(
  supabase: SupabaseClient,
  id: string,
  active: boolean,
): Promise<void> {
  await rpc<unknown>(supabase, 'set_config_active', {
    p_entity: 'PACKAGE',
    p_id: id,
    p_active: active,
  });
}
