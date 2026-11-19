// Gọi dữ liệu màn Tài khoản học sinh (QT-13): danh sách phân trang ở máy chủ; cấp tài khoản qua Edge Function admin-users (cần khoá secret
// của Supabase Auth). Đặt lại mật khẩu, khoá, mở khoá dùng lại hàm của màn Người dùng (cùng Edge Function).
import type { SupabaseClient } from '@supabase/supabase-js';
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { callFunction, errorOf, rpc, useDb } from '../../lib/db';
import type { StudentAccountFilters } from './studentAccountFilters';
import type { IssueResult, StudentAccountPage, StudentAccountRow } from './studentAccountTypes';

export function useStudentAccountPage(
  filters: StudentAccountFilters,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['student-account-list', filters, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<StudentAccountPage>(supabase, 'list_student_accounts', {
        p_filters: filters,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** Tải lại danh sách sau một thao tác ghi. */
export function useRefreshStudentAccounts() {
  const client = useQueryClient();
  return useCallback(
    () => client.invalidateQueries({ queryKey: ['student-account-list'] }),
    [client],
  );
}

/** Cấp tài khoản cho một em: máy chủ kiểm em có thật và chưa có tài khoản, sinh mật khẩu tạm, trả MỘT lần. */
export async function issueStudentAccount(
  supabase: SupabaseClient,
  studentCode: string,
): Promise<string> {
  const result = await callFunction<{ userId: string; password?: string }>(
    supabase,
    'admin-users',
    {
      action: 'create',
      kind: 'student',
      studentCode,
    },
  );
  if (!result.password) throw new Error('Máy chủ không trả mật khẩu tạm.');
  return result.password;
}

/** Cấp lần lượt từng em (mỗi em một giao dịch; em lỗi thì ghi lỗi, chạy tiếp em sau). Trả kết quả từng em, không ghi mật khẩu ở đâu. */
export async function issueStudentAccounts(
  supabase: SupabaseClient,
  rows: StudentAccountRow[],
  onProgress?: (done: number) => void,
): Promise<IssueResult[]> {
  const results: IssueResult[] = [];
  for (const r of rows) {
    try {
      const password = await issueStudentAccount(supabase, r.student_code);
      results.push({ student_code: r.student_code, full_name: r.full_name, password, error: null });
    } catch (e) {
      results.push({
        student_code: r.student_code,
        full_name: r.full_name,
        password: null,
        error: errorOf(e).message,
      });
    }
    onProgress?.(results.length);
  }
  return results;
}
