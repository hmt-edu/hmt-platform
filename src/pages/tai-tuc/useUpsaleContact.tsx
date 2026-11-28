// Luồng liên hệ ngay trên phiếu tái tục (TT-02): «Thêm lịch hẹn», «Ghi nhận liên hệ» và lịch sử liên hệ. Dùng lại hộp thoại và
// hàm của hồ sơ phụ huynh, học sinh (R-CRM-42, R-CRM-43): ghi vào hồ sơ phụ huynh, phiếu không có phụ huynh thì vào học sinh.
// Quyền thật kiểm ở create_appointment và log_contact; ẩn nút theo quyền. Hiện ở mọi giai đoạn; điện thoại chỉ đọc (Đ248).
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import { AppointmentDialog } from '../../features/appointments/AppointmentDialog';
import { useRefreshAppointmentData } from '../../features/appointments/appointmentApi';
import type { NoteRow } from '../../features/chatter/entries';
import { LogContactDialog } from '../../features/contacts/LogContactDialog';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Spinner } from '../../ui/Feedback';
import { LineTable } from '../../ui/LineTable';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { contactHistory } from './upsaleContactHistory';
import type { UpsaleRecord } from './upsaleTypes';

export function useUpsaleContact(
  record: UpsaleRecord,
  readOnly: boolean,
  refreshRecord: () => Promise<unknown>,
): { buttons: ReactNode; history: ReactNode; dialogs: ReactNode } {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const queryClient = useQueryClient();
  const refreshAppointments = useRefreshAppointmentData();
  const [dialog, setDialog] = useState<'appointment' | 'contact' | null>(null);

  const { parent, student } = record;
  const owners = [
    ...(parent && access.can('PARENT', 'XEM') ? [{ type: 'PARENT' as const, ...parent }] : []),
    ...(student && access.can('STUDENT', 'XEM') ? [{ type: 'STUDENT' as const, ...student }] : []),
  ];
  const target = owners[0];
  const queryKey = ['upsale-contacts', owners.map((o) => o.id)];
  const query = useQuery({
    queryKey,
    enabled: target !== undefined,
    retry: false,
    queryFn: async () => {
      const lists = await Promise.all(
        owners.map((o) =>
          rpc<NoteRow[]>(supabase, 'record_notes', { p_entity_type: o.type, p_entity_id: o.id }),
        ),
      );
      return contactHistory(lists.flat());
    },
  });

  const refresh = async () => {
    await Promise.all([
      refreshRecord(),
      refreshAppointments(),
      queryClient.invalidateQueries({ queryKey }),
      ...owners.map((o) => queryClient.invalidateQueries({ queryKey: ['chatter', o.type, o.id] })),
    ]);
  };
  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;

  const canBook = !readOnly && target !== undefined && access.can('APPOINTMENT', 'TAO');
  const canLog = !readOnly && target !== undefined;

  const buttons =
    canBook || canLog ? (
      <>
        {canBook && <Button onClick={() => setDialog('appointment')}>Thêm lịch hẹn</Button>}
        {canLog && <Button onClick={() => setDialog('contact')}>Ghi nhận liên hệ</Button>}
      </>
    ) : null;

  const history =
    target === undefined ? null : query.isPending ? (
      <Spinner label="Đang tải lịch sử liên hệ…" />
    ) : query.isError ? (
      <p role="alert" className="flex flex-wrap items-center gap-2 text-fg-muted">
        {errorOf(query.error).message}
        <Button size="sm" onClick={() => void query.refetch()}>
          Thử lại
        </Button>
      </p>
    ) : (
      <LineTable
        caption="Lịch sử liên hệ"
        scrollFocusable
        rows={query.data}
        rowKey={(r) => r.id}
        empty={<p className="p-3 text-fg-muted">Chưa ghi nhận lần liên hệ nào.</p>}
        columns={[
          { key: 'at', header: 'Ngày', cell: (r) => formatDateTime(r.at) },
          { key: 'channel', header: 'Kênh', cell: (r) => r.channel },
          { key: 'result', header: 'Kết quả', cell: (r) => r.result },
        ]}
      />
    );

  const dialogs = target ? (
    <>
      {dialog === 'contact' && (
        <LogContactDialog
          entityType={target.type}
          entityId={target.id}
          onClose={() => setDialog(null)}
          onSaved={async () => {
            await refresh();
            toast({ title: 'Đã lưu liên hệ.' });
          }}
        />
      )}
      {dialog === 'appointment' && (
        <AppointmentDialog
          open
          onOpenChange={(o) => !o && setDialog(null)}
          target={{ label: `${target.code} · ${target.name}`, branchId: record.ticket.branch_id }}
          activityOptions={catalogs.options('ACTIVITY_TYPE')}
          onCreate={async (args) => {
            const note = args.note.trim();
            await rpc<string>(supabase, 'create_appointment', {
              p_lead_id: null,
              p_activity_code: args.activityCode,
              p_scheduled_at: args.scheduledAt.toISOString(),
              p_title: note === '' ? activityName(args.activityCode) : note,
              p_owner_id: args.ownerId,
              ...(target.type === 'PARENT'
                ? { p_parent_id: target.id }
                : { p_student_id: target.id }),
            });
            await refresh();
            toast({ title: 'Đã tạo lịch hẹn.' });
          }}
          onReschedule={() => Promise.resolve()}
        />
      )}
    </>
  ) : null;

  return { buttons, history, dialogs };
}
