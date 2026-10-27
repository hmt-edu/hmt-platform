// Gọi dữ liệu màn Báo giá (BH-01): danh sách phân trang ở máy chủ và Xuất. Giao diện KHÔNG tính tiền, giờ, chiết khấu; chỉ hiện kết quả
// từ hàm cơ sở dữ liệu (app.price_line là nơi duy nhất tính, CLAUDE.md).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { QuoteFilters } from './quoteFilters';
import type { QuotationExportResult, QuotationPage, QuotationRecord } from './quoteTypes';

export function useQuotationPage(
  filters: QuoteFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['quotation-list', filters, sort ?? null, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<QuotationPage>(supabase, 'list_quotations', {
        p_filters: filters,
        p_sort: sort ?? 'created_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Xuất theo cùng bộ lọc (chỉ Trưởng cơ sở, Kế toán, Admin; máy chủ kiểm quyền và ghi nhật ký xuất). */
export async function exportQuotations(
  supabase: SupabaseClient,
  filters: QuoteFilters,
): Promise<QuotationExportResult> {
  return rpc<QuotationExportResult>(supabase, 'export_quotations', { p_filters: filters });
}

/** Làm mới mọi dữ liệu báo giá đang giữ trong bộ nhớ đệm. */
export function useRefreshQuotations() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['quotation-list'] }),
    [queryClient],
  );
}

/** Một báo giá (BH-02). Quyền và phạm vi cơ sở kiểm trong get_quotation. */
export function useQuotation(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['quotation', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<QuotationRecord>(supabase, 'get_quotation', { p_id: id }),
  });
}
