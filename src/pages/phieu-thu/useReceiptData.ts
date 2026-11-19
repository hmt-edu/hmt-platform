// Gọi dữ liệu màn Phiếu thu: danh sách phân trang ở máy chủ, bản ghi, và các thao tác ghi (máy chủ kiểm quyền, luật, công tắc Bán hàng).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { GroupCounts } from '../lead/leadTypes';
import type { ReceiptFilters } from './receiptFilters';
import type { OrderPayment, ReceiptInput, ReceiptPage, ReceiptRecord } from './receiptTypes';

/** Đếm nhóm cho Group By (một đến hai cấp), tính ở máy chủ. */
export function useReceiptGroupCounts(filters: ReceiptFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receipt-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'receipt_group_counts', { p_filters: filters, p_fields: fields }),
  });
}

export function useReceiptPage(
  filters: ReceiptFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receipt-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<ReceiptPage>(supabase, 'list_receipts', {
        p_filters: filters,
        p_sort: sort ?? 'created_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useRefreshReceipts() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['receipt-list'] }),
    [queryClient],
  );
}

export function useReceipt(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receipt', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<ReceiptRecord>(supabase, 'get_receipt', { p_id: id }),
  });
}

/** Tóm tắt thanh toán của một đơn (đã thu, còn lại, đủ cọc) cho màn Đơn hàng. */
export function useOrderPayment(orderId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-payment', orderId],
    enabled: orderId !== undefined,
    retry: false,
    queryFn: () => rpc<OrderPayment>(supabase, 'order_payment_summary', { p_order_id: orderId }),
  });
}

export function useRefreshReceipt(id: string, orderId?: string) {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['receipt', id] }),
      queryClient.invalidateQueries({ queryKey: ['receipt-list'] }),
      queryClient.invalidateQueries({ queryKey: ['order-payment'] }),
      ...(orderId ? [queryClient.invalidateQueries({ queryKey: ['order', orderId] })] : []),
    ]);
  }, [queryClient, id, orderId]);
}

export type CreateReceiptResult = { id: string; code: string; warnings: string[] };

export function createReceipt(
  supabase: SupabaseClient,
  orderId: string,
  input: ReceiptInput,
): Promise<CreateReceiptResult> {
  return rpc<CreateReceiptResult>(supabase, 'create_receipt', {
    p_order_id: orderId,
    p_data: input,
  });
}

export function saveReceipt(
  supabase: SupabaseClient,
  id: string,
  input: ReceiptInput,
): Promise<{ id: string; warnings: string[] }> {
  return rpc<{ id: string; warnings: string[] }>(supabase, 'save_receipt', {
    p_id: id,
    p_data: input,
  });
}

export function submitReceipt(
  supabase: SupabaseClient,
  id: string,
): Promise<{ status: string; auto_approved: boolean }> {
  return rpc<{ status: string; auto_approved: boolean }>(supabase, 'submit_receipt', { p_id: id });
}

export function approveReceiptManager(supabase: SupabaseClient, id: string): Promise<void> {
  return rpc<void>(supabase, 'approve_receipt_manager', { p_id: id });
}

export function approveReceiptAccounting(
  supabase: SupabaseClient,
  id: string,
): Promise<{ money_in_code: string }> {
  return rpc<{ money_in_code: string }>(supabase, 'approve_receipt_accounting', { p_id: id });
}

export function rejectReceipt(supabase: SupabaseClient, id: string, reason: string): Promise<void> {
  return rpc<void>(supabase, 'reject_receipt', { p_id: id, p_reason: reason });
}

export function cancelReceipt(
  supabase: SupabaseClient,
  id: string,
  reasonCode: string,
  note: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'cancel_receipt', {
    p_id: id,
    p_reason_code: reasonCode,
    p_note: note,
  });
}

export type ReceiverOption = {
  id: string;
  name: string;
  branch_code: string;
  same_branch: boolean;
};

/** Ô chọn "Người nhận tiền": tìm nhân sự ở máy chủ (cùng cơ sở xếp đầu), số dòng theo tham số trang. */
export function useReceiverOptions(search: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receipt-receivers', search],
    enabled,
    staleTime: 0,
    queryFn: () =>
      rpc<ReceiverOption[]>(supabase, 'receipt_receiver_options', {
        p_search: search === '' ? null : search,
      }),
  });
}

/** Người duyệt dự kiến của phiếu thu Nháp (migration 420): đường duyệt, tên, lý do chặn trình. Chỉ gọi khi phiếu Nháp, không phải nợ đầu kỳ. */
export type ReceiptExpectedApprover = {
  expected_route?: 'QUAN_LY' | 'TU_DUYET' | 'TRUONG_CS' | 'THIEU' | null;
  expected_approver_name?: string | null;
  expected_approver_can_approve?: boolean | null;
  expected_block?: 'KHONG_CO_QUAN_LY' | 'NGUOI_DUYET_BI_KHOA' | 'NGUOI_DUYET_THIEU_QUYEN' | null;
  created_by_name?: string | null;
};

export function useReceiptExpectedApprover(id: string, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['receipt-expected-approver', id],
    enabled,
    queryFn: () =>
      rpc<ReceiptExpectedApprover>(supabase, 'receipt_expected_approver', { p_id: id }),
  });
}
