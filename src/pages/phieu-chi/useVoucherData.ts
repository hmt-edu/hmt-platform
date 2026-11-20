// Gọi dữ liệu màn Phiếu chi: danh sách phân trang ở máy chủ, bản ghi, và thao tác ghi nhận đã chi (máy chủ kiểm quyền và luật).
import type { GroupCounts } from '../lead/leadTypes';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { VoucherFilters } from './voucherFilters';
import type { VoucherPage, VoucherRecord } from './voucherTypes';

export function useVoucherPage(
  filters: VoucherFilters,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['voucher-list', filters, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<VoucherPage>(supabase, 'list_payment_vouchers', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Đếm nhóm cho Group By (một đến hai cấp), tính ở máy chủ. */
export function useVoucherGroupCounts(filters: VoucherFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['voucher-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'voucher_group_counts', { p_filters: filters, p_fields: fields }),
  });
}

export function useRefreshVouchers() {
  const queryClient = useQueryClient();
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: ['voucher-list'] }),
    [queryClient],
  );
}

export function useVoucher(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['voucher', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<VoucherRecord>(supabase, 'get_payment_voucher', { p_id: id }),
  });
}

export function useRefreshVoucher(id: string) {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['voucher', id] }),
      queryClient.invalidateQueries({ queryKey: ['voucher-list'] }),
    ]);
  }, [queryClient, id]);
}

/** Ghi nhận đã chi tiền (Chờ chi → Đã chi). Chỉ Kế toán; máy chủ kiểm lại quyền. */
export function payVoucher(
  supabase: SupabaseClient,
  id: string,
  note: string | null,
  methodCode: string | null,
) {
  return rpc<null>(supabase, 'pay_payment_voucher', {
    p_voucher_id: id,
    p_note: note,
    p_method_code: methodCode,
  });
}

/** Ghi trước khi chi: hình thức chi, tài khoản nhận (chữ tự do), ngày chi dự kiến (migration 581). Chỉ Kế toán, phiếu Chờ chi. */
export function setVoucherPlan(
  supabase: SupabaseClient,
  id: string,
  plan: { methodCode: string | null; accountNote: string | null; plannedOn: string | null },
) {
  return rpc<null>(supabase, 'set_payment_voucher_plan', {
    p_voucher_id: id,
    p_method_code: plan.methodCode,
    p_account_note: plan.accountNote,
    p_planned_on: plan.plannedOn,
  });
}
