// Gọi dữ liệu CH-02 Gói bán (bản ghi): đọc một gói và các dòng giá theo hiệu lực qua RLS (quyền Cấu hình bán hàng · Xem); thêm giá qua add_package_price.
import type { SupabaseClient } from '@supabase/supabase-js';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { PackageRow } from './usePackageData';
import type { PriceRow } from './packageRecordLogic';

const COLUMNS =
  'id, code, name, package_type_code, subject_code, grade_from_code, grade_to_code, is_active, legacy_ref';
/** Trần dòng giá của một gói (2 hình thức, ít ngày hiệu lực): an toàn, không phân trang. */
const PRICE_CAP = 200; // allow-number: trần an toàn cho danh sách giá của một gói (hiển thị, không phải luật)

export function usePackageRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['package-record', id],
    enabled: id !== undefined,
    queryFn: async () => {
      const pkg = await fetchRows<PackageRow>(
        supabase
          .schema('app')
          .from('sales_package')
          .select(COLUMNS)
          .eq('id', id ?? ''),
      );
      const prices = await fetchRows<PriceRow>(
        supabase
          .schema('app')
          .from('package_price')
          .select('id, delivery_mode_code, unit_price, effective_from')
          .eq('package_id', id ?? '')
          .order('effective_from', { ascending: false })
          .order('delivery_mode_code')
          .limit(PRICE_CAP),
      );
      return { pkg: pkg.rows[0] ?? null, prices: prices.rows };
    },
  });
}

export function useRefreshPackageRecord() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      ['package-record', 'package-list'].map((k) => client.invalidateQueries({ queryKey: [k] })),
    );
  }, [client]);
}

export function addPackagePrice(
  supabase: SupabaseClient,
  input: { packageId: string; mode: string; price: number | null; effectiveFrom: string },
): Promise<string> {
  return rpc<string>(supabase, 'add_package_price', {
    p_package_id: input.packageId,
    p_delivery_mode_code: input.mode,
    p_unit_price: input.price,
    p_effective_from: input.effectiveFrom,
  });
}
