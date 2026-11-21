// Gọi dữ liệu cụm Ghi danh: danh sách, hàng chờ, bản ghi, sổ giờ (đọc, phân trang ở máy chủ), tuỳ chọn xếp lớp, xếp lớp.
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { GroupCounts } from '../lead/leadTypes';
import type {
  AssignOptions,
  EnrollmentPage,
  EnrollmentRecord,
  LedgerPage,
  MatchingClass,
  OrderLineClass,
  QueuePage,
} from './enrollTypes';

export type EnrollFilters = Record<string, unknown>;

export function useEnrollmentPage(
  filters: EnrollFilters,
  sort: string | undefined,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-list', filters, sort ?? null, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<EnrollmentPage>(supabase, 'enrollment_list', {
        p_filters: filters,
        p_sort: sort ?? 'code_desc',
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useEnrollmentQueue(
  filters: EnrollFilters,
  offset: number,
  limit: number | null,
  enabled = true,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-queue', filters, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<QueuePage>(supabase, 'enrollment_queue', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useEnrollmentRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-record', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<EnrollmentRecord>(supabase, 'enrollment_record', { p_id: id }),
  });
}

export function useEnrollmentLedger(id: string | undefined, offset: number, limit: number | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-ledger', id, offset, limit],
    enabled: id !== undefined && limit !== null,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<LedgerPage>(supabase, 'enrollment_ledger', {
        p_id: id,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Tuỳ chọn xếp lớp (GD-03): chỉ gọi khi hộp thoại mở. */
export function useAssignOptions(enrollmentId: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-assign-options', enrollmentId],
    enabled: enrollmentId !== null,
    retry: false,
    staleTime: 0,
    gcTime: 0,
    queryFn: () =>
      rpc<AssignOptions>(supabase, 'enrollment_assign_options', { p_enrollment_id: enrollmentId }),
  });
}

export function assignEnrollments(
  supabase: SupabaseClient,
  entries: { enrollment_id: string; class_id: string; start_date: string }[],
): Promise<number> {
  return rpc<number>(supabase, 'assign_enrollments_to_classes', { p_entries: entries });
}

/** Lớp phù hợp cho một dòng đơn (BH-08): theo gói và cơ sở của đơn. Chỉ gọi khi hộp thoại mở. */
export function useMatchingClasses(packageId: string | null, branchId: string | null) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['matching-classes', packageId, branchId],
    enabled: packageId !== null,
    retry: false,
    staleTime: 0,
    gcTime: 0,
    queryFn: () =>
      rpc<MatchingClass[]>(supabase, 'enrollment_matching_classes', {
        p_package_id: packageId,
        p_branch_id: branchId,
        p_student_id: null,
      }),
  });
}

export function useOrderLineClasses(orderId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['order-line-classes', orderId],
    enabled: orderId !== undefined,
    retry: false,
    queryFn: () => rpc<OrderLineClass[]>(supabase, 'order_line_classes', { p_order_id: orderId }),
  });
}

export function setOrderLineClass(
  supabase: SupabaseClient,
  orderId: string,
  lineNo: number,
  classId: string | null,
  start: string | null,
): Promise<void> {
  return rpc<void>(supabase, 'set_order_line_class', {
    p_order_id: orderId,
    p_line_no: lineNo,
    p_class_id: classId,
    p_start: start,
  });
}

/** Làm mới mọi dữ liệu ghi danh đang giữ trong bộ nhớ đệm (sau khi xếp lớp). */
export function useRefreshEnrollments() {
  const queryClient = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      [
        'enrollment-list',
        'enrollment-queue',
        'enrollment-queue-groups',
        'enrollment-record',
        'enrollment-ledger',
      ].map((key) => queryClient.invalidateQueries({ queryKey: [key] })),
    );
  }, [queryClient]);
}

export type AdjustArgs = { hours: number; reason: string; note: string | null };
/** Điều chỉnh giờ: thêm dòng ngược dấu vào sổ giờ (app.adjust_enrollment_hours, GD-05, R-GD-04). Trả số dư mới. Luật do máy chủ quyết (R-GD-18). */
export function useAdjustHours(enrollmentId: string) {
  const supabase = useDb();
  const refresh = useRefreshEnrollments();
  return useMutation({
    mutationFn: (a: AdjustArgs) =>
      rpc<number>(supabase, 'adjust_enrollment_hours', {
        p_enrollment_id: enrollmentId,
        p_hours: a.hours,
        p_reason_code: a.reason,
        p_note: a.note,
      }),
    onSuccess: () => refresh(),
  });
}

/** Khối «Em có N ghi danh ở lớp này» (GD-02): các ghi danh khác của cùng học sinh ở cùng lớp, kèm tổng giờ còn của lớp. */
export type SameClassPeers = {
  class_id: string | null;
  class_code: string | null;
  total_remaining: number | null;
  peers: { id: string; code: string; remaining: number }[];
};

export function useSameClassPeers(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-peers', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<SameClassPeers>(supabase, 'enrollment_same_class_peers', { p_id: id }),
  });
}

/** Đếm nhóm cho Group By (một đến hai cấp), tính ở máy chủ. */
/** Số ghi danh chờ xếp lớp theo trường nhóm (Group By ở máy chủ, tối đa hai cấp): app.enrollment_queue_group_counts. */
export function useQueueGroupCounts(filters: EnrollFilters, fields: string[]) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-queue-groups', filters, fields],
    enabled: fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'enrollment_queue_group_counts', {
        p_filters: filters,
        p_fields: fields,
      }),
  });
}

export function useEnrollmentGroupCounts(filters: EnrollFilters, fields: string[]) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['enrollment-groups', filters, fields],
    enabled: fields.length > 0,
    placeholderData: keepPreviousData,
    retry: false,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'enrollment_group_counts', {
        p_filters: filters,
        p_fields: fields,
      }),
  });
}
