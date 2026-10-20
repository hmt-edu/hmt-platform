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

export async function completeAppointment(supabase: SupabaseClient, id: string): Promise<void> {
  await rpc<null>(supabase, 'complete_appointment', { p_id: id });
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
