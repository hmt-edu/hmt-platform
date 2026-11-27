// Một lần gọi thẻ tóm tắt cho mỗi hồ sơ (app.get_*_summary); đầu hồ sơ và nhãn «Mức gắn bó» dùng chung kết quả.
import { useQuery } from '@tanstack/react-query';
import { rpc, useDb } from '../../lib/db';
import type { ParentSummary, StudentSummary } from './summaryLogic';

export const recordSummaryKey = (entityType: 'PARENT' | 'STUDENT', entityId: string) => [
  'record-summary',
  entityType,
  entityId,
];

export function useRecordSummary(entityType: 'PARENT' | 'STUDENT', entityId: string) {
  const supabase = useDb();
  return useQuery<ParentSummary | StudentSummary>({
    queryKey: recordSummaryKey(entityType, entityId),
    queryFn: () =>
      entityType === 'PARENT'
        ? rpc<ParentSummary>(supabase, 'get_parent_summary', { p_parent_id: entityId })
        : rpc<StudentSummary>(supabase, 'get_student_summary', { p_student_id: entityId }),
  });
}
