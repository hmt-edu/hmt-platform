// Gọi dữ liệu màn Báo giá (BH-01): danh sách phân trang ở máy chủ và Xuất. Giao diện KHÔNG tính tiền, giờ, chiết khấu; chỉ hiện kết quả
// từ hàm cơ sở dữ liệu (app.price_line là nơi duy nhất tính, CLAUDE.md).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import { withoutFlexible } from './discountPolicyFilter';
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

/** Kết quả Gửi báo giá: tổng sau khi tính lại theo giá ngày Gửi (Đ175) và cảnh báo nếu tổng đổi. */
export type SendQuotationResult = {
  id: string;
  total_amount: number;
  previous_total: number;
  warnings: { code: string; message: string }[];
};

/** Gửi báo giá Nháp: máy chủ tính lại giá theo ngày Gửi, đặt hạn hiệu lực (Đ175). */
export function sendQuotation(supabase: SupabaseClient, id: string): Promise<SendQuotationResult> {
  return rpc<SendQuotationResult>(supabase, 'send_quotation', { p_id: id });
}

/** Từ chối báo giá Đã gửi: lý do từ danh mục "Lý do từ chối"; "Khác" bắt ghi chú (máy chủ kiểm). */
export function rejectQuotation(
  supabase: SupabaseClient,
  id: string,
  reasonCode: string,
  note: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'reject_quotation', {
    p_id: id,
    p_reason_code: reasonCode,
    p_note: note,
  });
}

/** Tải lại một báo giá và các danh sách báo giá sau khi đổi tình trạng. */
export function useRefreshQuotation(id: string) {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['quotation', id] }),
      queryClient.invalidateQueries({ queryKey: ['quotation-list'] }),
    ]);
  }, [queryClient, id]);
}

/** Huỷ báo giá Nháp, Đã gửi hoặc Từ chối; ghi chú không bắt buộc. Có đơn đang xử lý thì máy chủ chặn (R-CRM-19, Đ171). */
export function cancelQuotation(
  supabase: SupabaseClient,
  id: string,
  note: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'cancel_quotation', { p_id: id, p_note: note });
}

/** Em của cơ hội (danh sách em của cơ hội, để chọn trên dòng báo giá). */
export type OppStudent = {
  id: string;
  position: number;
  full_name: string | null;
  birth_year: number | null;
};

/** Danh sách em của cơ hội: lấy từ get_opportunity (đã có trường `students`), dùng chung bộ nhớ đệm với trang cơ hội để không gọi hai lần. */
export function useOpportunityStudents(opportunityId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['opp-record', opportunityId],
    enabled,
    queryFn: () =>
      rpc<{ students: OppStudent[] }>(supabase, 'get_opportunity', { p_id: opportunityId }),
    select: (opp) => opp.students,
  });
}

/** Gói bán cho hộp chọn gói (Hay dùng, Gợi ý theo cơ hội, Tất cả gói; lọc loại gói). */
export type SellablePackage = {
  id: string;
  code: string;
  name: string;
  package_type_code: string;
  unit_code: 'GIO' | 'THANG' | 'BO';
  prices: Record<string, number>;
};
export type SellablePackages = {
  types: { code: string; name: string }[];
  popular: string[];
  suggested: string[];
  total: number;
  packages: SellablePackage[];
};

export function useSellablePackages(opportunityId: string, type: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['quotation-sellable', opportunityId, type],
    enabled,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<SellablePackages>(supabase, 'list_sellable_packages', {
        p_opportunity_id: opportunityId,
        p_type: type,
      }),
  });
}

/** Lưu báo giá Nháp (thay toàn bộ dòng; id rỗng là tạo mới từ cơ hội, cấp mã). Máy chủ tính lại giá và kiểm luật; lỗi nêu đúng dòng. */
export function saveQuotation(
  supabase: SupabaseClient,
  id: string | null,
  opportunityId: string,
  lines: Record<string, unknown>[],
): Promise<{ id: string; code: string; total_amount: number }> {
  return rpc(supabase, 'save_quotation', {
    p_id: id,
    p_opportunity_id: opportunityId,
    p_lines: lines,
  });
}

/** Chính sách chiết khấu áp dụng được hôm nay cho cơ hội (hộp Chọn chính sách chiết khấu). */
export type DiscountPolicy = {
  id: string;
  code: string;
  name: string;
  kind: 'PERCENT' | 'GIFT_HOURS';
  max_value: number;
  /** "Áp đúng mức": nhân viên không nhập, lấy đúng mức tối đa. */
  fixed_value: boolean;
  requires_approval: boolean;
  package_type_codes: string[];
  /** Chính sách hệ thống "Ưu đãi linh hoạt" (R-V2-45); max_value là hạn mức từ Cài đặt. */
  is_flexible?: boolean | undefined;
};

export function useDiscountPolicies(opportunityId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['quotation-discount-policies', opportunityId],
    enabled,
    queryFn: async () =>
      withoutFlexible(
        await rpc<DiscountPolicy[]>(supabase, 'list_applicable_discount_policies', {
          p_opportunity_id: opportunityId,
        }),
      ),
  });
}

/** Chính sách quà tặng áp dụng được hôm nay cho cơ hội (hộp Chọn chính sách quà tặng, R-TIEN-30). */
export type GiftPolicy = {
  id: string;
  code: string;
  name: string;
  max_quantity: number;
  requires_approval: boolean;
  gift_package: {
    id: string;
    code: string;
    name: string;
    package_type_code: string;
    unit_code: 'GIO' | 'THANG' | 'BO';
  };
};

export function useGiftPolicies(opportunityId: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['quotation-gift-policies', opportunityId],
    enabled,
    queryFn: () =>
      rpc<GiftPolicy[]>(supabase, 'list_applicable_gift_policies', {
        p_opportunity_id: opportunityId,
      }),
  });
}
