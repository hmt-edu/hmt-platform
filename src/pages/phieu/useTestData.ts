// Gọi dữ liệu màn Phiếu kiểm tra: danh sách, Kanban, Lịch, đếm nhóm, bản ghi, danh sách chọn (giáo viên, phòng) và các thao tác ghi.
// Mọi lọc, sắp xếp, phân trang, nhóm làm ở cơ sở dữ liệu (CLAUDE.md, Hiệu năng); luật nằm ở hàm DB (R-CRM-05, 06, 10, 11, 15, 21).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { ExportResult, GroupCounts } from '../lead/leadTypes';
import type { TestFilters } from './testFilters';
import type { TestBoardColumn, TestPage, TestRecord } from './testTypes';

export function useTestPage(
  filters: TestFilters,
  sort: string,
  offset: number,
  limit: number | null,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-list', filters, sort, offset, limit],
    enabled: enabled && limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TestPage>(supabase, 'list_student_tests', {
        p_filters: filters,
        p_sort: sort,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

export function useTestBoard(filters: TestFilters, perColumn: number | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-board', filters, perColumn],
    enabled: enabled && perColumn !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<TestBoardColumn[]>(supabase, 'student_test_board', {
        p_filters: filters,
        p_per_column: perColumn,
      }),
  });
}

/** Phiếu trong cửa sổ đang xem của kiểu Lịch: tải từng trang tới khi đủ (tối đa `maxPages` trang) rồi dừng. */
export function useTestCalendar(
  filters: TestFilters,
  pageSize: number | null,
  maxPages: number,
  enabled: boolean,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-calendar', filters, pageSize],
    enabled: enabled && pageSize !== null,
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const rows: TestPage['rows'] = [];
      let total = 0;
      for (let page = 0; page < maxPages; page += 1) {
        const result = await rpc<TestPage>(supabase, 'list_student_tests', {
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

export function useTestGroupCounts(filters: TestFilters, fields: string[], enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-groups', filters, fields],
    enabled: enabled && fields.length > 0,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<GroupCounts>(supabase, 'student_test_group_counts', {
        p_filters: filters,
        p_fields: fields,
      }),
  });
}

export function useTestRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-record', id],
    enabled: id !== undefined,
    queryFn: () => rpc<TestRecord>(supabase, 'get_student_test', { p_id: id }),
    retry: false,
  });
}

export type PickRow = { id: string; name: string; branch_code: string; capacity?: number | null };

/** Giáo viên đang hoạt động của một cơ sở (chọn giáo viên chấm). */
export function useTestGraders(branchId: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-graders', branchId],
    enabled: enabled && branchId !== null,
    queryFn: async () => {
      const rows = await rpc<{ id: string; display_name: string; branch_code: string }[]>(
        supabase,
        'list_test_graders',
        { p_branch_id: branchId },
      );
      return rows.map((r): PickRow => ({
        id: r.id,
        name: r.display_name,
        branch_code: r.branch_code,
      }));
    },
  });
}

/** Phòng đang dùng của một cơ sở test (chọn phòng). */
export function useTestRooms(branchId: string | null, enabled: boolean) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['test-rooms', branchId],
    enabled: enabled && branchId !== null,
    queryFn: () =>
      rpc<{ id: string; name: string; capacity: number | null; branch_code: string }[]>(
        supabase,
        'list_test_rooms',
        { p_branch_id: branchId },
      ),
  });
}

export async function exportTests(
  supabase: SupabaseClient,
  filters: TestFilters,
): Promise<ExportResult> {
  return rpc<ExportResult>(supabase, 'export_student_tests', { p_filters: filters });
}

// ---- Thao tác ghi (mỗi thao tác một hàm DB, một giao dịch) ----

export async function createTest(
  supabase: SupabaseClient,
  args: {
    opportunityId: string;
    data: Record<string, unknown>;
    reminderAt: Date | null;
    reminderActivity: string | null;
  },
): Promise<{ id: string; code: string }> {
  return rpc<{ id: string; code: string }>(supabase, 'create_student_test', {
    p_opportunity_id: args.opportunityId,
    p_data: args.data,
    p_reminder_at: args.reminderAt ? args.reminderAt.toISOString() : null,
    p_reminder_activity: args.reminderActivity,
  });
}

export const startTest = (supabase: SupabaseClient, id: string) =>
  rpc<null>(supabase, 'start_student_test', { p_id: id });
export const submitTest = (supabase: SupabaseClient, id: string) =>
  rpc<null>(supabase, 'submit_student_test', { p_id: id });
export const completeTest = (supabase: SupabaseClient, id: string) =>
  rpc<null>(supabase, 'complete_student_test', { p_id: id });
export const stepBackTest = (supabase: SupabaseClient, id: string, reason: string | null) =>
  rpc<null>(supabase, 'step_back_student_test', { p_id: id, p_reason: reason });
export const cancelTest = (
  supabase: SupabaseClient,
  id: string,
  reasonCode: string,
  note: string | null,
) =>
  rpc<null>(supabase, 'cancel_student_test', { p_id: id, p_reason_code: reasonCode, p_note: note });
export const reopenTest = (supabase: SupabaseClient, id: string, reason: string) =>
  rpc<null>(supabase, 'reopen_student_test', { p_id: id, p_reason: reason });
export const rescheduleTest = (
  supabase: SupabaseClient,
  id: string,
  at: Date,
  reminderAt: Date | null,
) =>
  rpc<null>(supabase, 'reschedule_student_test', {
    p_id: id,
    p_scheduled_at: at.toISOString(),
    p_reminder_at: reminderAt ? reminderAt.toISOString() : null,
  });
export const updateTest = (supabase: SupabaseClient, id: string, data: Record<string, unknown>) =>
  rpc<null>(supabase, 'update_student_test', { p_id: id, p_data: data });
export const enterTestResult = (
  supabase: SupabaseClient,
  args: {
    id: string;
    score: number;
    note: string;
    levelCode: string | null;
    frameworkCode: string | null;
    graderId: string | null;
  },
) =>
  rpc<null>(supabase, 'enter_test_result', {
    p_id: args.id,
    p_score: args.score,
    p_note: args.note,
    p_level_code: args.levelCode,
    p_framework_code: args.frameworkCode,
    p_grader_id: args.graderId,
  });

/** Tải lại mọi dữ liệu danh sách phiếu sau một thao tác ghi. */
export function useRefreshTests() {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      ['test-list', 'test-board', 'test-calendar', 'test-groups'].map((key) =>
        client.invalidateQueries({ queryKey: [key] }),
      ),
    );
  }, [client]);
}

/** Tải lại bản ghi phiếu, ghi chú và hoạt động, lịch hẹn nhắc, và cơ hội gắn (nhóm con L5 đổi theo phiếu). */
export function useRefreshTestRecord(testId: string) {
  const client = useQueryClient();
  return useCallback(async () => {
    await Promise.all(
      [
        ['test-record', testId],
        ['chatter', 'STUDENT_TEST', testId],
        ['test-upcoming', testId],
        ['test-list'],
        ['test-board'],
        ['test-calendar'],
        ['test-groups'],
        ['opp-record'],
        ['opp-list'],
        ['opp-board'],
      ].map((queryKey) => client.invalidateQueries({ queryKey })),
    );
  }, [client, testId]);
}
