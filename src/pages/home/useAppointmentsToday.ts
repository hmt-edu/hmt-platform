import { useQuery } from '@tanstack/react-query';
import { useAuth } from '../../lib/auth/authContext';
import { rpc } from '../../lib/db';
import { vnDayBounds } from '../../lib/vnDay';

export type TodayAppointment = {
  id: string;
  scheduled_at: string;
  title: string;
  lead_code: string | null;
  lead_label: string | null;
  branch_code: string;
};

export type AppointmentsToday = {
  todayTotal: number;
  rows: TodayAppointment[];
  overdue: number;
};

/** Số dòng xem nhanh trên Trang chủ (bản vẽ K09b: bốn đến năm dòng); số tổng vẫn đủ. */
const PREVIEW_ROWS = 5; // allow-number: số dòng xem nhanh trên giao diện, không phải ngưỡng nghiệp vụ

/**
 * Lịch hẹn Chưa làm của tôi hôm nay (theo giờ Việt Nam) và số lịch Quá hạn (hẹn trước đầu ngày hôm nay).
 * Hai lần gọi, chạy song song: `list_appointments` (trả tổng và dòng cùng lúc) và `appointment_overdue_count`.
 * `branchId`: ô chọn cơ sở của Admin, Kế toán; người một cơ sở thì cơ sở do RLS quyết, không truyền.
 */
export function useAppointmentsToday(branchId: string | null) {
  const { supabase, claims } = useAuth();
  const { start, end, dateKey } = vnDayBounds();
  return useQuery({
    queryKey: ['home-appointments', claims?.userId, branchId, dateKey],
    enabled: Boolean(supabase && claims),
    queryFn: async (): Promise<AppointmentsToday> => {
      if (!supabase) throw new Error('Chưa đăng nhập.');
      const [list, overdue] = await Promise.all([
        rpc<{ total: number; rows: TodayAppointment[] }>(supabase, 'list_appointments', {
          p_filters: {
            mine: true,
            status: ['CHUA_LAM'],
            from: start.toISOString(),
            to: end.toISOString(),
            ...(branchId ? { branch_id: branchId } : {}),
          },
          p_sort: 'time_asc',
          p_limit: PREVIEW_ROWS,
          p_offset: 0,
        }),
        rpc<number>(supabase, 'appointment_overdue_count', {
          p_before: start.toISOString(),
          p_mine: true,
        }),
      ]);
      return { todayTotal: list.total, rows: list.rows, overdue };
    },
  });
}
