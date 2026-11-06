// Gọi dữ liệu màn Đơn hàng (BH-06): danh sách phân trang ở máy chủ và Xuất. Giao diện KHÔNG tính tiền; chỉ hiện kết quả của hàm cơ sở dữ liệu.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { OrderFilters } from './orderFilters';
import type { OrderExportResult, OrderPage, OrderRecord } from './orderTypes';

export function useOrderPage(
  filters: OrderFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-list', filters, sort ?? null, offset, limit],
    enabled: limit !== null,
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
