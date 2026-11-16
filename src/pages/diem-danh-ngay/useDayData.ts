// BUOI-15: một lần gọi rpc cho một trang danh sách (lọc, phân trang ở máy chủ: app.session_day_attendance).
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { DayPage } from './dayLogic';

export type DayFilters = { date: string; state: string[] | null; hasNotice: boolean | null };

export function useDayPage(filters: DayFilters, offset: number, limit: number) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['day-attendance', filters, offset, limit],
    retry: false,
    queryFn: () =>
      rpc<DayPage>(supabase, 'session_day_attendance', {
        p_filters: {
          ...(filters.date === '' ? {} : { date: filters.date }),
          state: filters.state,
          has_notice: filters.hasNotice,
        },
        p_limit: limit,
        p_offset: offset,
      }),
  });
}
