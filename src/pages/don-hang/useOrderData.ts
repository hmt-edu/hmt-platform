// Gọi dữ liệu màn Đơn hàng (BH-06): danh sách phân trang ở máy chủ và Xuất. Giao diện KHÔNG tính tiền; chỉ hiện kết quả của hàm cơ sở dữ liệu.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import { readNumberSetting } from '../../lib/auth/api';
import { withFlexibleMax } from './orderEdit';
import type { OrderFilters } from './orderFilters';
import type { GroupCounts } from '../lead/leadTypes';
import type { AddEdit } from './orderEdit';
import type { OrderExportResult, OrderPage, OrderRecord } from './orderTypes';

export function useOrderPage(
  filters: OrderFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<OrderPage>(supabase, 'list_orders', {
        p_filters: filters,
        p_sort: sort ?? 'created_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Đếm nhóm cho Group By (một đến hai cấp), tính ở máy chủ. */
export function useOrderGroupCounts(filters: OrderFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'order_group_counts', { p_filters: filters, p_fields: fields }),
  });
}

/** Xuất theo cùng bộ lọc (chỉ Trưởng cơ sở, Kế toán, Admin; máy chủ kiểm quyền và ghi nhật ký xuất, Đ105). */
export async function exportOrders(
  supabase: SupabaseClient,
  filters: OrderFilters,
): Promise<OrderExportResult> {
  return rpc<OrderExportResult>(supabase, 'export_orders', { p_filters: filters });
}

/** Làm mới mọi danh sách đơn đang giữ trong bộ nhớ đệm. */
export function useRefreshOrders() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['order-list'] }),
    [queryClient],
  );
}

/** Một đơn (BH-05). Quyền và phạm vi cơ sở kiểm trong get_order; đọc không bị chặn khi tắt Bán hàng (Đ181). */
export function useOrder(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<OrderRecord>(supabase, 'get_order', { p_id: id }),
  });
}

/** Làm mới một đơn và các danh sách đơn. */
export function useRefreshOrder(id: string) {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['order', id] }),
      queryClient.invalidateQueries({ queryKey: ['order-list'] }),
      queryClient.invalidateQueries({ queryKey: ['chatter', 'SALES_ORDER', id] }),
    ]);
  }, [queryClient, id]);
}

/** Kết quả Trình duyệt: người duyệt đã chốt và đường duyệt (R-HT-06). */
export type SubmitOrderResult = { id: string; approver_id: string; route: 'QUAN_LY' | 'TU_DUYET' };

/** Trình duyệt đơn Nháp. Máy chủ kiểm quyền Sửa, công tắc Bán hàng (Đ173), em đủ họ tên và năm sinh (R-TIEN-35), điều khoản, người duyệt. */
export function submitOrder(supabase: SupabaseClient, id: string): Promise<SubmitOrderResult> {
  return rpc<SubmitOrderResult>(supabase, 'submit_order', { p_id: id });
}

/** Huỷ đơn (R-TIEN-38): lý do từ danh mục "Lý do huỷ đơn", "Khác" bắt buộc ghi chú; máy chủ kiểm ai được huỷ và chưa có phiếu thu. */
export function cancelOrder(
  supabase: SupabaseClient,
  id: string,
  reasonCode: string,
  note: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'cancel_order', {
    p_id: id,
    p_reason_code: reasonCode,
    p_note: note,
  });
}

/** Duyệt đơn Đã trình (BH-07). Không còn ô tích đồng ý vượt trần (R-V2-11): vượt trần chỉ cảnh báo, nhật ký ghi người duyệt và tổng %. */
export function approveOrder(
  supabase: SupabaseClient,
  id: string,
): Promise<{ on_behalf: boolean }> {
  return rpc<{ on_behalf: boolean }>(supabase, 'approve_order', { p_id: id });
}

/** Từ chối đơn Đã trình: lý do từ danh mục "Lý do từ chối" áp dụng cho đơn, "Khác" bắt buộc ghi chú; đơn về Nháp. */
export function rejectOrder(
  supabase: SupabaseClient,
  id: string,
  reasonCode: string,
  note: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'reject_order', { p_id: id, p_reason_code: reasonCode, p_note: note });
}

/** Một phần tử sửa dòng gửi app.edit_order (xem orderEdit.ts). */
export type OrderLineEdit =
  | {
      line_no: number;
      quantity?: number;
      delivery_mode_code?: string;
      discounts?: { policy_id: string; value: number | null }[];
      remove?: boolean;
    }
  | AddEdit;

/**
 * Sửa đơn Nháp tại chỗ (anh chốt 06/11, B1): số giờ, hình thức, chính sách chiết khấu, bỏ dòng, điều khoản; kể cả đơn chuyển từ báo giá (nhật ký ghi
 * "Đơn đã sửa so với báo giá", Q-31). Máy chủ tính lại thành tiền, kiểm quyền, công tắc Bán hàng, trạng thái Nháp.
 */
export function editOrder(
  supabase: SupabaseClient,
  id: string,
  edits: OrderLineEdit[],
  paymentTermId: string | null,
): Promise<{ id: string; total_amount: number; changed: boolean }> {
  return rpc<{ id: string; total_amount: number; changed: boolean }>(supabase, 'edit_order', {
    p_id: id,
    p_edits: edits.length > 0 ? edits : null,
    p_payment_term_id: paymentTermId,
  });
}

export type PolicyOption = {
  id: string;
  code: string;
  name: string;
  kind: 'PERCENT' | 'GIFT_HOURS';
  max_value: number;
  fixed_value: boolean;
  valid_from: string;
  valid_to: string | null;
  package_type_codes: string[];
  branch_ids: string[];
  /** Chính sách hệ thống "Ưu đãi linh hoạt" (R-V2-45). */
  is_flexible?: boolean | undefined;
};
export type TermOption = { id: string; name: string };

/** Chính sách chiết khấu đang dùng và điều khoản thanh toán đang dùng, cho chế độ sửa đơn (ít dòng, đọc một lần khi mở sửa). */
export function useOrderEditOptions(enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-edit-options'],
    enabled,
    staleTime: 60_000, // allow-number: chính sách, điều khoản đổi hiếm, giữ một phút
    queryFn: async (): Promise<{ policies: PolicyOption[]; terms: TermOption[] }> => {
      const [policies, terms, flexMax] = await Promise.all([
        supabase
          .schema('app')
          .from('discount_policy')
          .select(
            'id, code, name, kind, max_value, fixed_value, valid_from, valid_to, package_type_codes, branch_ids, is_flexible',
          )
          .eq('is_active', true)
          .order('name'),
        supabase
          .schema('app')
          .from('payment_term')
          .select('id, name')
          .eq('is_active', true)
          .order('name'),
        // Hạn mức Ưu đãi linh hoạt mỗi dòng (R-V2-45): đọc từ Cài đặt, không viết cứng.
        readNumberSetting(supabase, 'flexible_discount_max_percent'),
      ]);
      if (policies.error) throw new Error(policies.error.message);
      if (terms.error) throw new Error(terms.error.message);
      // Chính sách linh hoạt: hạn mức lấy từ Cài đặt (cột max_value của chính sách không phải nguồn hạn mức).
      const policyRows: PolicyOption[] = withFlexibleMax(policies.data ?? [], flexMax);
      const termRows: TermOption[] = terms.data ?? [];
      return { policies: policyRows, terms: termRows };
    },
  });
}

/** Tên điều khoản theo mã (id), kể cả điều khoản đã ngừng: để dòng thời gian đơn hiện tên thay vì mã nội bộ. */
export function usePaymentTermNames() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['payment-term-names'],
    staleTime: 5 * 60_000, // allow-number: tên điều khoản đổi hiếm
    queryFn: async (): Promise<Map<string, string>> => {
      const { data, error } = await supabase.schema('app').from('payment_term').select('id, name');
      if (error) throw new Error(error.message);
      const rows: TermOption[] = data ?? [];
      return new Map(rows.map((t) => [t.id, t.name]));
    },
  });
}

export type CreatedOrder = { id: string; code: string; total_amount: number };

/** Tạo đơn Nháp thẳng từ cơ hội L8 (UI-O4, R-CRM-16, R-CRM-19, R-TIEN-39): giá tính ở máy chủ (R-TIEN-13); cơ hội đã có đơn Nháp thì máy chủ từ chối HMT_CO_DON_NHAP cho tới khi gửi lại với confirmExistingDraft. */
export function createOrderFromOpportunity(
  supabase: SupabaseClient,
  opportunityId: string,
  lines: Record<string, unknown>[],
  confirmExistingDraft: boolean,
  paymentTermId: string,
): Promise<CreatedOrder> {
  return rpc<CreatedOrder>(supabase, 'create_order_from_opportunity', {
    p_opportunity_id: opportunityId,
    p_lines: lines,
    p_payment_term_id: paymentTermId,
    p_confirm_existing_draft: confirmExistingDraft,
  });
}

/** Chuyển báo giá Đã gửi thành đơn Nháp (UI-O4, R-TIEN-14, Đ259): chỉ các dòng giữ lại; giá chép y báo giá. */
export function createOrderFromQuotation(
  supabase: SupabaseClient,
  quotationId: string,
  lineNos: number[],
  paymentTermId: string,
): Promise<CreatedOrder> {
  return rpc<CreatedOrder>(supabase, 'create_order_from_quotation', {
    p_quotation_id: quotationId,
    p_line_nos: lineNos,
    p_payment_term_id: paymentTermId,
  });
}

/** Đơn Nháp mới nhất của cơ hội (hộp BH-11 "Mở đơn cũ"), hoặc null. */
export function getOpportunityDraftOrder(
  supabase: SupabaseClient,
  opportunityId: string,
): Promise<{ id: string; code: string } | null> {
  return rpc<{ id: string; code: string } | null>(supabase, 'get_opportunity_draft_order', {
    p_opportunity_id: opportunityId,
  });
}
