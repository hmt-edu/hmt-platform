// Nối Chatter (CHUNG-22) với cơ sở dữ liệu: ghi chú (app.record_notes), lịch sử (app.record_history),
// gửi ghi chú có nhắc tên (app.add_note_mentioning), gợi ý đồng nghiệp (app.mention_candidates).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { FORBIDDEN_CODE, HmtError, rpc, useDb } from '../../lib/db';
import { Chatter, type Person } from '../../ui/Chatter';
import {
  buildEntries,
  type CandidateRow,
  type FieldFormat,
  type HistoryRow,
  type NoteRow,
} from './entries';

export function RecordChatter({
  entityType,
  entityId,
  format,
  createdText,
}: {
  entityType: string;
  entityId: string;
  format: FieldFormat;
  /** Câu cho dòng "đã tạo": "Tạo tài khoản." */
  createdText: string;
}) {
  const supabase = useDb();
  const queryClient = useQueryClient();
  const queryKey = ['chatter', entityType, entityId];
  const query = useQuery({
    queryKey,
    queryFn: async () => {
      const args = { p_entity_type: entityType, p_entity_id: entityId };
      const [notes, history] = await Promise.all([
        rpc<NoteRow[]>(supabase, 'record_notes', args),
        rpc<HistoryRow[]>(supabase, 'record_history', args),
      ]);
      return buildEntries(notes, history, format, createdText);
    },
    retry: false,
  });

  const forbidden = query.error instanceof HmtError && query.error.code === FORBIDDEN_CODE;
  return (
    <Chatter
      entries={query.data ?? []}
      status={
        query.isPending ? 'loading' : forbidden ? 'forbidden' : query.isError ? 'error' : 'ready'
      }
      onRetry={() => void query.refetch()}
      onSend={async (body, mentionIds) => {
        await rpc(supabase, 'add_note_mentioning', {
          p_entity_type: entityType,
          p_entity_id: entityId,
          p_body: body,
          p_mention_ids: mentionIds,
        });
        await queryClient.invalidateQueries({ queryKey });
      }}
      searchPeople={async (text): Promise<Person[]> => {
        const rows = await rpc<CandidateRow[]>(supabase, 'mention_candidates', { p_query: text });
        return rows.map((r) => ({
          id: r.id,
          name: r.display_name,
          hint: [r.role_names, r.branch_code].filter(Boolean).join(' · '),
        }));
      }}
    />
  );
}
