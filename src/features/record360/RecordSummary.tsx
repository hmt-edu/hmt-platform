// Đầu hồ sơ 360° (canvas a8d7): hàng «Làm nhanh», thẻ tóm tắt, cờ cảnh báo. Một lần gọi cho mỗi hồ sơ (app.get_*_summary).
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { useLeadCatalogs } from '../../pages/lead/useCatalogs';
import { Button } from '../../ui/Button';
import { cn } from '../../ui/cn';
import { useToast } from '../../ui/toastContext';
import { AppointmentDialog } from '../appointments/AppointmentDialog';
import { useRefreshAppointmentData } from '../appointments/appointmentApi';
import { LogContactDialog } from '../contacts/LogContactDialog';
import {
  hasHiddenMoney,
  parentCards,
  parentFlags,
  studentCards,
  studentFlags,
  type FlagTarget,
  type ParentSummary,
  type StudentSummary,
  type SummaryCard,
  type SummaryFlag,
} from './summaryLogic';
import { recordSummaryKey, useRecordSummary } from './useRecordSummary';

type Props = {
  entityType: 'PARENT' | 'STUDENT';
  entityId: string;
  /** "PH000045 · Trần Thị Hà": ô «Gắn với» của hộp lịch hẹn. */
  label: string;
  /** Hồ sơ đã gộp chỉ xem: tắt các nút làm nhanh. */
  readOnly: boolean;
  /** Đường dẫn tạo ticket; không có thì nút mờ. */
  ticketPath: string | null;
  onFlag: (target: Exclude<FlagTarget, 'contacts'>) => void;
  onChatter: (target: 'note' | 'contacts') => void;
};

export function RecordSummary(props: Props) {
  const { entityType, entityId, readOnly } = props;
  const supabase = useDb();
  const access = useAccess();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();
  const refreshAppointments = useRefreshAppointmentData();
  const [calling, setCalling] = useState(false);
  const [booking, setBooking] = useState(false);
  const queryKey = recordSummaryKey(entityType, entityId);
  const query = useRecordSummary(entityType, entityId);
  const data = query.data;
  const view = data ? toView(data) : null;
  const refresh = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey }),
      queryClient.invalidateQueries({ queryKey: ['chatter', entityType, entityId] }),
      queryClient.invalidateQueries({ queryKey: ['parent-record', 'tab'] }),
      refreshAppointments(),
    ]);
  };
  const upsalePath =
    data?.upsale_id && access.can('UPSALE', 'XEM') ? `/crm/tai-tuc/${data.upsale_id}` : null;
  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;

  const flag = (target: FlagTarget) => {
    if (target === 'contacts') props.onChatter('contacts');
    else props.onFlag(target);
  };

  const writable = !readOnly && data?.contact_visible === true;
  return (
    <div className="flex flex-col gap-3">
      {!readOnly && (
        <div role="group" aria-label="Làm nhanh" className="flex flex-wrap items-center gap-2">
          <span className="text-caption font-semibold text-fg-muted">Làm nhanh</span>
          <Button size="sm" disabled={!writable} onClick={() => setCalling(true)}>
            Gọi
          </Button>
          <Button
            size="sm"
            disabled={!data || !access.can('APPOINTMENT', 'TAO')}
            onClick={() => setBooking(true)}
          >
            Hẹn
          </Button>
          <Button size="sm" disabled={!writable} onClick={() => props.onChatter('note')}>
            Ghi chú
          </Button>
          <Button
            size="sm"
            disabled={!props.ticketPath || !access.can('TICKET', 'TAO')}
            onClick={() => props.ticketPath && void navigate(props.ticketPath)}
          >
            Tạo ticket
          </Button>
          <Button
            size="sm"
            disabled={!upsalePath}
            title={upsalePath ? undefined : 'Chưa có phiếu tái tục'}
            onClick={() => upsalePath && void navigate(upsalePath)}
          >
            Báo giá tái tục
          </Button>
        </div>
      )}
      {query.isError && (
        <p role="alert" className="flex flex-wrap items-center gap-2 text-fg-muted">
          Không tải được phần tóm tắt.
          <Button size="sm" onClick={() => void query.refetch()}>
            Thử lại
          </Button>
        </p>
      )}
      {view && (
        <>
          <Cards cards={view.cards} />
          {view.hidden && (
            <p className="text-caption text-fg-muted">
              Bạn không có quyền xem tiền nên các ô tiền được ẩn.
            </p>
          )}
          <Flags flags={view.flags} onOpen={flag} />
        </>
      )}
      {calling && (
        <LogContactDialog
          entityType={entityType}
          entityId={entityId}
          initialChannel="GOI_DIEN"
          onClose={() => setCalling(false)}
          onSaved={async () => {
            await refresh();
            toast({ title: 'Đã lưu liên hệ.' });
          }}
        />
      )}
      {booking && data && (
        <AppointmentDialog
          open
          onOpenChange={setBooking}
          target={{ label: props.label, branchId: data.branch_id }}
          activityOptions={catalogs.options('ACTIVITY_TYPE')}
          onCreate={async (args) => {
            const note = args.note.trim();
            await rpc<string>(supabase, 'create_appointment', {
              p_lead_id: null,
              p_activity_code: args.activityCode,
              p_scheduled_at: args.scheduledAt.toISOString(),
              p_title: note === '' ? activityName(args.activityCode) : note,
              p_owner_id: args.ownerId,
              ...(entityType === 'PARENT' ? { p_parent_id: entityId } : { p_student_id: entityId }),
            });
            await refresh();
            toast({ title: 'Đã tạo lịch hẹn.' });
          }}
          onReschedule={() => Promise.resolve()}
        />
      )}
    </div>
  );
}

function toView(data: ParentSummary | StudentSummary) {
  return 'money' in data
    ? { cards: parentCards(data), flags: parentFlags(data), hidden: hasHiddenMoney(data) }
    : { cards: studentCards(data), flags: studentFlags(data), hidden: false };
}

function Cards({ cards }: { cards: SummaryCard[] }) {
  return (
    <dl aria-label="Tóm tắt" className="grid grid-cols-2 gap-2 md:grid-cols-3">
      {cards.map((c) => (
        <div key={c.key} className="rounded-box border border-border bg-surface px-3 py-2">
          <dt className="text-caption text-fg-muted">{c.label}</dt>
          <dd className="tabular font-semibold">{c.value}</dd>
          {c.note && (
            <dd className={cn('text-caption', c.danger ? 'text-danger' : 'text-fg-muted')}>
              {c.note}
            </dd>
          )}
        </div>
      ))}
    </dl>
  );
}

function Flags({ flags, onOpen }: { flags: SummaryFlag[]; onOpen: (t: FlagTarget) => void }) {
  if (flags.length === 0)
    return <p className="text-fg-muted">Không có cảnh báo nào. Hồ sơ đang ổn.</p>;
  return (
    <div role="group" aria-label="Cần chú ý" className="flex flex-wrap items-center gap-2">
      <span className="text-caption font-semibold text-fg-muted">Cần chú ý</span>
      {flags.map((f) => (
        <Button key={f.target} size="sm" onClick={() => onOpen(f.target)}>
          {f.label} ›
        </Button>
      ))}
    </div>
  );
}
