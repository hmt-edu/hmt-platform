// Gọi dữ liệu màn Lịch hẹn: danh sách phân trang, ba cột Kanban, các lịch trong cửa sổ của kiểu xem Lịch, số lịch quá hạn.
// Lọc, sắp xếp, phân trang, tìm kiếm làm ở cơ sở dữ liệu (CLAUDE.md, Hiệu năng); mỗi màn vài lần gọi, không gọi theo từng dòng.
import { keepPreviousData, useQueries, useQuery } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useRefreshAppointmentData } from '../../features/appointments/appointmentApi';
import { rpc, useDb } from '../../lib/db';
import type { GroupCounts } from '../lead/leadTypes';
import type { AppointmentFilters } from './appointmentFilters';
import type {
  AppointmentExport,
  AppointmentPage,
  AppointmentStatus,
  AssignAppointmentsResult,
} from './appointmentTypes';

export function useAppointmentPage(
  filters: AppointmentFilters,
  sort: string,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['appointment-list', filters, sort, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<AppointmentPage>(supabase, 'list_appointments', {
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export const KANBAN_STATUSES: AppointmentStatus[] = ['CHUA_LAM', 'HOAN_THANH', 'HUY'];

/** Ba cột Kanban: mỗi cột một lần gọi (lọc theo trạng thái của cột), mỗi cột tối đa `perColumn` thẻ. */
export function useAppointmentColumns(
  filters: AppointmentFilters,
  perColumn: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQueries({
    queries: KANBAN_STATUSES.map((status) => {
      // Cột đã là một trạng thái nên bỏ bộ lọc trạng thái của người dùng (lọc "Chưa làm" thì hai cột kia rỗng).
      const chosen = (filters.status as string[] | undefined) ?? [];
      const hidden = chosen.length > 0 && !chosen.includes(status);
      return {
        queryKey: ['appointment-board', filters, status, perColumn],
        enabled: enabled && perColumn !== null,
        placeholderData: keepPreviousData,
        queryFn: (): Promise<AppointmentPage> =>
          hidden
            ? Promise.resolve({ total: 0, rows: [] })
            : rpc<AppointmentPage>(supabase, 'list_appointments', {
                p_filters: { ...filters, status: [status] },
                p_sort: 'time_asc',
                p_limit: perColumn,
                p_offset: 0,
              }),
      };
    }),
  });
}

/** Lịch hẹn trong cửa sổ đang xem của kiểu Lịch: tải từng trang tới khi đủ (tối đa `maxPages` trang) rồi dừng. */
export function useCalendarAppointments(
  filters: AppointmentFilters,
  pageSize: number | null,
  maxPages: number,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['appointment-calendar', filters, pageSize],
    enabled: enabled && pageSize !== null,
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const rows: AppointmentPage['rows'] = [];
      let total = 0;
      for (let page = 0; page < maxPages; page += 1) {
        const result = await rpc<AppointmentPage>(supabase, 'list_appointments', {
          p_filters: filters,
          p_sort: 'time_asc',
          p_limit: pageSize,
          p_offset: page * (pageSize ?? 0),
        });
        total = result.total;
        rows.push(...result.rows);
        if (rows.length >= total || result.rows.length === 0) break;
      }
      return { total, rows, truncated: rows.length < total };
    },
  });
}

/** Số lịch Chưa làm trước một mốc (dải "Còn N lịch quá hạn đang bị ẩn"). */
export function useOverdueBefore(before: Date | null, mine: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['appointment-overdue', before?.toISOString() ?? null, mine],
    enabled: before !== null,
    queryFn: () =>
      rpc<number>(supabase, 'appointment_overdue_count', {
        p_before: before?.toISOString(),
        p_mine: mine,
      }),
  });
}

/** Tải lại mọi dữ liệu liên quan lịch hẹn sau một thao tác ghi (cả bản ghi lead, cơ hội, phiếu đang mở ở nơi khác). */
export function useRefreshAppointments() {
  return useRefreshAppointmentData();
}

/** Đếm nhóm cho Group By (một đến hai cấp), tính ở máy chủ. */
export function useAppointmentGroupCounts(
  filters: AppointmentFilters,
  fields: string[],
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['appointment-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'appointment_group_counts', {
        p_filters: filters,
        p_fields: fields,
      }),
  });
}

/** Xuất danh sách theo bộ lọc đang xem (hàm kiểm quyền Xuất, ghi nhật ký xuất, cắt ở mức tối đa). */
export function exportAppointments(
  supabase: SupabaseClient,
  filters: AppointmentFilters,
): Promise<AppointmentExport> {
  return rpc<AppointmentExport>(supabase, 'export_appointments', { p_filters: filters });
}

/** Giao nhiều lịch hẹn cho một người; hàm giao phần hợp lệ và trả lý do từng nhóm bị bỏ. */
export function assignAppointments(
  supabase: SupabaseClient,
  ids: string[],
  ownerId: string,
): Promise<AssignAppointmentsResult> {
  return rpc<AssignAppointmentsResult>(supabase, 'assign_appointments', {
    p_ids: ids,
    p_owner_id: ownerId,
  });
}
