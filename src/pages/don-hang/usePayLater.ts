// BH-09 Cho học trước, đóng tiền sau (R-GD-12): đọc trạng thái bật của đơn (bảng order_pay_later, đọc theo quyền xem đơn của cơ sở) và gọi hàm set_order_pay_later.
import { useQuery } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';

export function useOrderPayLater(orderId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-pay-later', orderId],
    enabled: orderId !== undefined,
    queryFn: async () => {
      const { rows } = await fetchRows<{ enabled: boolean }>(
        supabase
          .schema('app')
          .from('order_pay_later')
          .select('enabled')
          .eq('order_id', orderId ?? ''),
      );
      return rows[0]?.enabled === true;
    },
  });
}

export function setOrderPayLater(
  supabase: SupabaseClient,
  orderId: string,
  enabled: boolean,
  note: string | null,
): Promise<{ order_id: string; enabled: boolean; enrollments: number }> {
  return rpc(supabase, 'set_order_pay_later', {
    p_order_id: orderId,
    p_enabled: enabled,
    p_note: note,
  });
}
