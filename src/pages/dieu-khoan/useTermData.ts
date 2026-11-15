// Gọi dữ liệu CH-09 Điều khoản thanh toán: đọc payment_term kèm các đợt (một lần gọi, vài chục dòng), ghi qua create_payment_term (bản mới) và set_config_active
// (Ngừng, Dùng lại). Quyền Cấu hình bán hàng, luật chia đợt do DB kiểm.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import type { PaymentTerm } from './termLogic';

export function useTerms() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['payment-terms'],
    queryFn: async () =>
      (
        await fetchRows<PaymentTerm>(
          supabase
            .schema('app')
            .from('payment_term')
            .select(
              'id, code, version, name, valid_from, is_active, installments:payment_term_installment(seq, share_percent, fixed_amount, due_days)',
            )
            .order('name')
            .order('version', { ascending: false }),
        )
      ).rows,
  });
}

export function createTerm(
  supabase: SupabaseClient,
  input: { code: string; name: string; validFrom: string; installments: unknown[] },
): Promise<string> {
  return rpc<string>(supabase, 'create_payment_term', {
    p_code: input.code,
    p_name: input.name,
    p_valid_from: input.validFrom,
    p_installments: input.installments,
  });
}

export function setTermActive(
  supabase: SupabaseClient,
  id: string,
  active: boolean,
): Promise<void> {
  return rpc<void>(supabase, 'set_config_active', {
    p_entity: 'PAYMENT_TERM',
    p_id: id,
    p_active: active,
  });
}

export function useRefreshTerms() {
  const client = useQueryClient();
  return useCallback(async () => {
    await client.invalidateQueries({ queryKey: ['payment-terms'] });
  }, [client]);
}
