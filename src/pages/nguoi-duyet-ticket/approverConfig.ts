// QT-15 Cấu hình người duyệt ticket (phiếu nghiệp vụ) theo nhóm con, có ngày hiệu lực: kiểu dữ liệu, chữ hiển thị, kiểm biểu mẫu. Hàm thuần có kiểm thử.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import type { SupabaseClient } from '@supabase/supabase-js';
import { rpc, useDb } from '../../lib/db';

export type LevelCode = 'QUAN_LY_CO_SO' | 'KE_TOAN';
export type ApproverVersion = {
  levels: LevelCode[];
  valid_from: string;
  created_at?: string;
  created_by_name?: string | null;
};
export type ApproverRule = {
  task_type: string;
  categories: { code: string; name: string }[];
  current_levels: LevelCode[];
  upcoming: ApproverVersion[];
  history: ApproverVersion[];
};

export const LEVEL_LABEL: Record<LevelCode, string> = {
  QUAN_LY_CO_SO: 'Quản lý cơ sở',
  KE_TOAN: 'Kế toán',
};

/** «Quản lý cơ sở, rồi Kế toán» theo thứ tự duyệt. */
export function levelsText(levels: LevelCode[]): string {
  return levels.map((l) => LEVEL_LABEL[l] ?? l).join(', rồi ');
}

/** Cấp được chọn theo thứ tự cố định Quản lý cơ sở, Kế toán (luật R-CS-07 chỉ có hai cấp). */
export function orderedLevels(picked: Set<LevelCode>): LevelCode[] {
  return (['QUAN_LY_CO_SO', 'KE_TOAN'] as const).filter((l) => picked.has(l));
}

/** Lỗi biểu mẫu: phải có ít nhất một cấp và ngày hiệu lực từ hôm nay trở đi (ngày dạng yyyy-mm-dd). */
export function formError(levels: LevelCode[], validFrom: string, today: string): string | null {
  if (levels.length === 0) return 'Chọn ít nhất một cấp duyệt.';
  if (validFrom === '') return 'Chọn ngày hiệu lực.';
  if (validFrom < today) return 'Ngày hiệu lực phải từ hôm nay trở đi.';
  return null;
}

export function useApproverConfig() {
  const supabase = useDb();
  return useQuery({
    queryKey: ['ticket-approver-config'],
    queryFn: () => rpc<ApproverRule[]>(supabase, 'list_ticket_approver_config'),
  });
}

export function useRefreshApproverConfig() {
  const client = useQueryClient();
  return () => client.invalidateQueries({ queryKey: ['ticket-approver-config'] });
}

export function saveApproverRule(
  supabase: SupabaseClient,
  taskType: string,
  levels: LevelCode[],
  validFrom: string,
): Promise<string> {
  return rpc<string>(supabase, 'save_ticket_task_rule', {
    p_type: taskType,
    p_levels: levels,
    p_valid_from: validFrom,
  });
}
