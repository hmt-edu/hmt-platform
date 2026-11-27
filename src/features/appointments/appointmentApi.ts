// Gọi dữ liệu lịch hẹn của một hồ sơ (lead): danh sách sắp tới và các thao tác (tạo, dời, hoàn thành, huỷ, mở lại).
// Luật nằm ở hàm cơ sở dữ liệu (R-CRM-04, R-CRM-38); giao diện chỉ gọi và hiện lỗi.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { IconName } from '../../ui/icons';

export type UpcomingAppointment = {
  id: string;
  activity_code: string;
  scheduled_at: string;
  title: string;
  status: 'CHUA_LAM' | 'HOAN_THANH' | 'HUY';
  owner_id: string;
  owner_name: string | null;
  /** Lịch tự nhắc do hệ thống tạo (list_appointments trả sẵn). */
  is_auto_reminder: boolean;
};

const ACTIVITY_ICON: Record<string, IconName> = {
  GOI_DIEN: 'phone2',
  ZALO: 'chat',
  EMAIL: 'mail',
  GAP_TRUC_TIEP: 'meet',
  SMS: 'chat',
  NHAC_THU_TIEN: 'payment',
};
export const activityIcon = (code: string): IconName => ACTIVITY_ICON[code] ?? 'calendar';

/** Lịch hẹn Chưa làm của một lead, gần nhất trước (khối "Hoạt động sắp tới"). Một lần gọi, tối đa một trang. */
export function useLeadUpcoming(leadId: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['lead-upcoming', leadId],
    enabled: leadId !== null,
    queryFn: () =>
      rpc<{ total: number; rows: UpcomingAppointment[] }>(supabase, 'list_appointments', {
        p_filters: { lead_id: leadId, status: ['CHUA_LAM'] },
        p_sort: 'time_asc',
        p_limit: null,
        p_offset: 0,
      }),
  });
}

/** Lịch hẹn Chưa làm của một cơ hội, gần nhất trước (khối "Hoạt động sắp tới" của trang Cơ hội). */
export function useOpportunityUpcoming(opportunityId: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['opp-upcoming', opportunityId],
    enabled: opportunityId !== null,
    queryFn: () =>
      rpc<{ total: number; rows: UpcomingAppointment[] }>(supabase, 'list_appointments', {
        p_filters: { opportunity_id: opportunityId, status: ['CHUA_LAM'] },
        p_sort: 'time_asc',
        p_limit: null,
        p_offset: 0,
      }),
  });
}

/** Lịch hẹn Chưa làm gắn với một phiếu kiểm tra (lịch nhắc tự sinh, R-CRM-05), gần nhất trước (khối "Hoạt động sắp tới" của trang phiếu). */
export function useTestUpcoming(testId: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-upcoming', testId],
    enabled: testId !== null,
    queryFn: () =>
      rpc<{ total: number; rows: UpcomingAppointment[] }>(supabase, 'list_appointments', {
        p_filters: { student_test_id: testId, status: ['CHUA_LAM'] },
        p_sort: 'time_asc',
        p_limit: null,
        p_offset: 0,
      }),
  });
}

/** Lịch Chưa làm liên quan hồ sơ phụ huynh, học sinh (khối "Hoạt động sắp tới"), gần nhất trước. */
export function useCustomerUpcoming(owner: CustomerOwner | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['record-upcoming', owner?.key ?? null, owner?.id ?? null],
    enabled: owner !== null,
    queryFn: () =>
      rpc<{ total: number; rows: (UpcomingAppointment & { branch_id: string })[] }>(
        supabase,
        'list_record_appointments',
        {
          p_filters: { [owner?.key ?? 'parent_id']: owner?.id, status: ['CHUA_LAM'] },
          p_sort: 'time_asc',
          p_limit: null,
          p_offset: 0,
        },
      ),
  });
}

export type CustomerOwner = { key: 'parent_id' | 'student_id'; id: string };

export async function createOpportunityAppointment(
  supabase: SupabaseClient,
  args: {
    opportunityId: string;
    activityCode: string;
    scheduledAt: Date;
    title: string;
    ownerId: string | null;
  },
): Promise<void> {
  await rpc<string>(supabase, 'create_appointment', {
    p_lead_id: null,
    p_activity_code: args.activityCode,
    p_scheduled_at: args.scheduledAt.toISOString(),
    p_title: args.title,
    p_note: null,
    p_owner_id: args.ownerId,
    p_opportunity_id: args.opportunityId,
  });
}

export async function createLeadAppointment(
  supabase: SupabaseClient,
  args: {
    leadId: string;
    activityCode: string;
    scheduledAt: Date;
    title: string;
    ownerId: string | null;
  },
): Promise<void> {
  await rpc<string>(supabase, 'create_appointment', {
    p_lead_id: args.leadId,
    p_activity_code: args.activityCode,
    p_scheduled_at: args.scheduledAt.toISOString(),
    p_title: args.title,
    p_note: null,
    p_owner_id: args.ownerId,
  });
}

export async function rescheduleAppointment(
  supabase: SupabaseClient,
  args: { id: string; scheduledAt: Date; ownerId: string | null; note: string },
): Promise<void> {
  await rpc<null>(supabase, 'reschedule_appointment', {
    p_id: args.id,
    p_scheduled_at: args.scheduledAt.toISOString(),
    p_owner_id: args.ownerId,
    p_note: args.note.trim() === '' ? null : args.note.trim(),
  });
}

/** Hoàn thành lịch hẹn (R-CRM-04) kèm kết quả cuộc gọi, ghi chú và hẹn lần sau (migration 628); bỏ trống thì như cách gọi cũ. */
export async function completeAppointment(
  supabase: SupabaseClient,
  id: string,
  extra?: { resultCode: string | null; note: string; nextAt: Date | null },
): Promise<void> {
  await rpc<null>(supabase, 'complete_appointment', {
    p_id: id,
    ...(extra
      ? {
          p_result_code: extra.resultCode,
          p_result_note: extra.note.trim() === '' ? null : extra.note.trim(),
          p_next_at: extra.nextAt ? extra.nextAt.toISOString() : null,
        }
      : {}),
  });
}

export async function cancelAppointment(
  supabase: SupabaseClient,
  id: string,
  reason: string,
  note: string,
): Promise<void> {
  await rpc<null>(supabase, 'cancel_appointment', {
    p_id: id,
    p_reason_code: reason,
    p_note: note.trim() === '' ? null : note.trim(),
  });
}

/** Mở lại lịch hẹn Hoàn thành hoặc Huỷ về Chưa làm (R-CRM-04): không đổi giai đoạn, không tạo việc, không báo ai. */
export async function reopenAppointment(supabase: SupabaseClient, id: string): Promise<void> {
  await rpc<null>(supabase, 'reopen_appointment', { p_id: id });
}

/**
 * Mọi dữ liệu đã tải mà một thao tác ghi lịch hẹn (tạo, dời, hoàn thành, mở lại, huỷ) có thể làm cũ: màn Lịch hẹn (danh sách, bảng,
 * lịch, nhóm, quá hạn), khối "Hoạt động sắp tới", bản ghi, danh sách, bảng của lead, cơ hội, phiếu kiểm tra, và dòng thời gian
 * (ghi chú hệ thống). Làm mới theo tiền tố khoá nên mọi mã bản ghi cùng được làm mới; một chỗ duy nhất để màn nào ghi cũng đồng bộ
 * các màn khác (trước đây màn Lịch hẹn chỉ làm mới lead, trang Cơ hội không làm mới Lịch hẹn).
 */
export const APPOINTMENT_RELATED_KEYS = [
  'appointment-list',
  'appointment-board',
  'appointment-calendar',
  'appointment-groups',
  'appointment-overdue',
  'lead-upcoming',
  'lead-record',
  'lead-list',
  'lead-board',
  'opp-upcoming',
  'record-upcoming',
  'opp-record',
  'opp-list',
  'opp-board',
  'opp-groups',
  'test-upcoming',
  'test-record',
  'test-list',
  'test-board',
  'test-calendar',
  'test-groups',
  'chatter',
] as const;

export function useRefreshAppointmentData() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      APPOINTMENT_RELATED_KEYS.map((key) => client.invalidateQueries({ queryKey: [key] })),
    );
  }, [client]);
}

/** Tải lại khối lịch hẹn, ghi chú và hoạt động, số đếm của lead sau một thao tác ghi. */
export function useRefreshLeadRecord(leadId: string) {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey: ['lead-upcoming', leadId] }),
      client.invalidateQueries({ queryKey: ['lead-record', leadId] }),
      client.invalidateQueries({ queryKey: ['chatter', 'LEAD', leadId] }),
      client.invalidateQueries({ queryKey: ['lead-list'] }),
      client.invalidateQueries({ queryKey: ['lead-board'] }),
    ]);
  }, [client, leadId]);
}
