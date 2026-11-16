// Gọi dữ liệu QT-14 Ngày nghỉ lễ: đọc bảng holiday theo năm (lọc ở máy chủ, vài chục dòng mỗi năm), xem buổi bị ảnh hưởng qua list_holiday_sessions,
// ghi qua save_holiday và set_holiday_active (kiểm quyền và luật ở DB).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { fetchRows, rpc, useDb } from '../../lib/db';
import { yearRange, type Holiday, type HolidaySessions } from './holidayLogic';

export function useHolidays(year: number) {
  const supabase = useDb();
  const { from, to } = yearRange(year);
  return useQuery({
    queryKey: ['holidays', year],
    queryFn: async () =>
      (
        await fetchRows<Holiday>(
          supabase
            .schema('app')
            .from('holiday')
            .select('id, holiday_date, name, branch_id, is_active')
            .gte('holiday_date', from)
            .lte('holiday_date', to)
            .order('holiday_date'),
        )
      ).rows,
  });
}

export function useHolidaySessions(id: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['holiday-sessions', id],
    enabled: id !== null,
    queryFn: () => rpc<HolidaySessions>(supabase, 'list_holiday_sessions', { p_id: id }),
  });
}

export type SaveResult = { id: string; is_new: boolean; affected_sessions: number };

export function saveHoliday(
  supabase: SupabaseClient,
  input: { id: string | null; date: string; name: string; branchId: string | null },
): Promise<SaveResult> {
  return rpc<SaveResult>(supabase, 'save_holiday', {
    p_id: input.id,
    p_date: input.date,
    p_name: input.name,
    p_branch_id: input.branchId,
  });
}

export function setHolidayActive(
  supabase: SupabaseClient,
  id: string,
  active: boolean,
): Promise<{ id: string; is_active: boolean; affected_sessions: number }> {
  return rpc(supabase, 'set_holiday_active', { p_id: id, p_active: active });
}

export function useRefreshHolidays() {
  const client = useQueryClient();
  return useCallback(async () => {
    await client.invalidateQueries({ queryKey: ['holidays'] });
    await client.invalidateQueries({ queryKey: ['holiday-sessions'] });
  }, [client]);
}
