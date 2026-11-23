// Dữ liệu cổng Học tập, Phụ huynh: kết quả học tập (HT-07, PH-02) và nhận xét các buổi (HT-08), migration 640, 641.
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';

export type ResultSession = {
  session_id: string;
  session_no: number;
  session_date: string;
  thai_do: number | null;
  tiep_thu: number | null;
  van_dung: number | null;
};

export type ResultClass = {
  class_id: string;
  class_code: string;
  subject_name: string | null;
  attendance: { present: number; total: number };
  /** `has` = false khi lớp không giao BTVN: ẩn cả phần BTVN (R-V2-35). */
  homework: { has: boolean; done: number; total: number; avg_score: number | null };
  sessions: ResultSession[];
};

export type ReviewRow = {
  session_id: string;
  session_no: number;
  session_date: string;
  class_code: string;
  subject_name: string | null;
  comment: string;
};

/** Kết quả học tập một học sinh theo từng lớp (một lần gọi). */
export function usePortalResults(studentId: string | undefined) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['portal-results', studentId],
    enabled: studentId !== undefined,
    queryFn: () =>
      rpc<{ classes: ResultClass[] }>(supabase, 'portal_results', { p_student_id: studentId }),
    refetchOnWindowFocus: true,
  });
}

/** Nhận xét của giáo viên theo buổi, phân trang ở máy chủ. */
export function usePortalReviews(studentId: string | undefined, limit: number, offset: number) {
  const supabase = useDb();
  return useQuery({
    queryKey: ['portal-reviews', studentId, limit, offset],
    enabled: studentId !== undefined,
    placeholderData: keepPreviousData,
    queryFn: () =>
      rpc<{ total: number; rows: ReviewRow[] }>(supabase, 'portal_reviews', {
        p_student_id: studentId,
        p_limit: limit,
        p_offset: offset,
      }),
  });
}

/** «4,2» (dấu phẩy thập phân); null thì «–». */
export function formatScore(value: number | null): string {
  return value === null ? '–' : value.toLocaleString('vi-VN', { minimumFractionDigits: 1 });
}

/** Tỉ lệ làm BTVN theo phần trăm làm tròn; 0 buổi thì null. */
export function homeworkRate(hw: ResultClass['homework']): number | null {
  return hw.total === 0 ? null : Math.round((hw.done / hw.total) * 100); // allow-number: đổi sang phần trăm
}

/** «19/11» từ ngày yyyy-mm-dd. */
export function shortDate(iso: string): string {
  const [, m = '', d = ''] = iso.split('-');
  return `${d}/${m}`;
}
