// Nối Chatter (CHUNG-22) với cơ sở dữ liệu: ghi chú (app.record_notes), lịch sử (app.record_history),
// gửi ghi chú có nhắc tên (app.add_note_mentioning), gợi ý đồng nghiệp (app.mention_candidates).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState, type ReactNode } from 'react';
import { FORBIDDEN_CODE, HmtError, rpc, useDb } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Chatter, type ChatterEntry, type ChatterFocus, type Person } from '../../ui/Chatter';
import { useToast } from '../../ui/toastContext';
import { LogContactDialog } from '../contacts/LogContactDialog';
import {
  buildEntries,
  type CandidateRow,
  type FieldFormat,
  type HistoryRow,
  type NoteRow,
} from './entries';

/** Hồ sơ có ghi nhận liên hệ (khớp app.log_contact, R-CRM-43). */
const CONTACT_ENTITIES = ['PARENT', 'STUDENT'];

export function RecordChatter({
  entityType,
  entityId,
  format,
  createdText,
  events,
  actions,
  upcoming,
  headerRight,
  canWrite,
  focus,
}: {
  entityType: string;
  entityId: string;
  format: FieldFormat;
  /** Câu cho dòng "đã tạo": "Tạo tài khoản." Không dùng khi màn có `events` (mục Tạo lấy từ sự kiện). */
  createdText: string;
  /** Sự kiện nghiệp vụ của bản ghi (đã đổi sang mục dòng thời gian). Có thì trộn vào dòng thời gian và bỏ dòng "Tạo" của nhật ký thay đổi. */
  events?: ChatterEntry[] | undefined;
  /** Hàng nút nghiệp vụ trên ô ghi chú (Lên lịch hẹn). */
  actions?: ReactNode | undefined;
  /** Khối "Hoạt động sắp tới" do màn truyền vào. */
  upcoming?: ReactNode | undefined;
  /** Góc phải của tiêu đề (nút Theo dõi, khi có hàm). */
  headerRight?: ReactNode | undefined;
  /** Bản ghi chỉ đọc (Đã gộp): tắt ô viết ghi chú. */
  canWrite?: boolean | undefined;
  focus?: ChatterFocus | undefined;
}) {
  const supabase = useDb();
  const queryClient = useQueryClient();
  const queryKey = ['chatter', entityType, entityId];
  const toast = useToast();
  const contacts = CONTACT_ENTITIES.includes(entityType);
  const [logging, setLogging] = useState(false);
  const query = useQuery({
    queryKey,
    queryFn: async () => {
      const args = { p_entity_type: entityType, p_entity_id: entityId };
      const [notes, history] = await Promise.all([
        rpc<NoteRow[]>(supabase, 'record_notes', args),
        rpc<HistoryRow[]>(supabase, 'record_history', args),
      ]);
      return { notes, history };
    },
    retry: false,
  });
  const entries = useMemo(
    () =>
      query.data
        ? buildEntries(
            query.data.notes,
            query.data.history,
            format,
            events ? null : createdText,
            events ?? [],
          )
        : [],
    [query.data, format, events, createdText],
  );

  const forbidden = query.error instanceof HmtError && query.error.code === FORBIDDEN_CODE;
  return (
    <>
      <Chatter
        contacts={contacts}
        focus={focus}
        entries={entries}
        status={
          query.isPending ? 'loading' : forbidden ? 'forbidden' : query.isError ? 'error' : 'ready'
        }
        onRetry={() => void query.refetch()}
        actions={
          contacts && canWrite !== false ? (
            <>
              <Button onClick={() => setLogging(true)}>Ghi nhận liên hệ</Button>
              {actions}
            </>
          ) : (
            actions
          )
        }
        upcoming={upcoming}
        headerRight={headerRight}
        canWrite={canWrite}
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
      {logging && (
        <LogContactDialog
          entityType={entityType}
          entityId={entityId}
          onClose={() => setLogging(false)}
          onSaved={async () => {
            await queryClient.invalidateQueries({ queryKey });
            toast({ title: 'Đã lưu liên hệ.' });
          }}
        />
      )}
    </>
  );
}
