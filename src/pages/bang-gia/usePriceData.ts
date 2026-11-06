// Gọi dữ liệu màn Bảng giá (CH-03, theo gói): danh sách gói kèm giá hiệu lực tại một ngày (một rpc, phân trang ở máy chủ),
// chọn tất cả theo bộ lọc, thêm nhiều dòng giá một lần (một rpc, một giao dịch).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { PriceCell, PriceItem } from './priceLogic';

export type PriceRow = {
  id: string;
  code: string;
  name: string;
  package_type_code: string;
  subject_code: string | null;
  grade_from_code: string | null;
  grade_to_code: string | null;
  is_active: boolean;
  offline: PriceCell;
  online: PriceCell;
};
export type PricePage = { total: number; rows: PriceRow[] };
export type PriceFilters = {
  q?: string;
  type?: string;
  subject?: string;
  grade?: string;
  status?: string;
};

function clean(filters: PriceFilters): Record<string, string> {
  return Object.fromEntries(Object.entries(filters).filter(([, v]) => v !== undefined && v !== ''));
}

export function usePricePage(
  on: string,
  filters: PriceFilters,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['price-list', on, filters, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<PricePage>(supabase, 'list_package_prices', {
        p_on: on,
        p_filters: clean(filters),
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshPrices() {
  const client = useQueryClient();
  return useCallback(async () => {
    await client.invalidateQueries({ queryKey: ['price-list'] });
  }, [client]);
}

export type FilterSelection = { total: number; items: { id: string; package_type_code: string }[] };

export function packagesForFilter(supabase: SupabaseClient, filters: PriceFilters) {
  return rpc<FilterSelection>(supabase, 'package_ids_for_filter', { p_filters: clean(filters) });
}

export function addPackagePrices(
  supabase: SupabaseClient,
  effectiveFrom: string,
  items: PriceItem[],
): Promise<number> {
  return rpc<number>(supabase, 'add_package_prices', {
    p_effective_from: effectiveFrom,
    p_items: items,
  });
}
