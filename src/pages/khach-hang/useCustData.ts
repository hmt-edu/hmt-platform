// Gọi dữ liệu cụm Khách hàng: danh sách phân trang và bản ghi. Lọc, tìm, sắp xếp, phân trang ở máy chủ (CLAUDE.md, Hiệu năng).
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { rpc, useDb } from '../../lib/db';
import type { CustFilters } from './custFilters';
import type { ParentPage, ParentRecord, StudentPage, StudentRecord } from './custTypes';

function usePage<T>(
  fn: string,
  key: string,
  filters: CustFilters,
  sort: string,
  offset: number,
  limit: number | null,
) {
  const supabase = useDb();
  return useQuery({
    queryKey: [key, filters, sort, offset, limit],
    enabled: limit !== null,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<T>(supabase, fn, { p_filters: filters, p_sort: sort, p_limit: limit, p_offset: offset }),
  });
}

export const useParentPage = (f: CustFilters, s: string, o: number, l: number | null) =>
  usePage<ParentPage>('list_parents', 'parent-list', f, s, o, l);
export const useStudentPage = (f: CustFilters, s: string, o: number, l: number | null) =>
  usePage<StudentPage>('list_students', 'student-list', f, s, o, l);

export function useParentRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['parent-record', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<ParentRecord>(supabase, 'get_parent_record', { p_parent_id: id }),
  });
}

export function useStudentRecord(id: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['student-record', id],
    enabled: id !== undefined,
    retry: false,
    queryFn: () => rpc<StudentRecord>(supabase, 'get_student_record', { p_student_id: id }),
  });
}

export function useRefreshCustomers() {
  const client = useQueryClient();
  return useCallback(
    () =>
      Promise.all(
        ['parent-list', 'student-list', 'parent-record', 'student-record'].map((k) =>
          client.invalidateQueries({ queryKey: [k] }),
        ),
      ),
    [client],
  );
}
