// Thao tác lịch hẹn dùng chung (màn Lịch hẹn và Lịch tuần của «Việc của tôi»): Hoàn thành, Dời, Huỷ, Mở lại, Tạo.
// Mỗi thao tác một hộp thoại, gọi hàm máy chủ rồi tải lại (R-CRM-04). Trả `dialogs` để màn đặt vào cuối trang.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import type { RowActions } from '../../pages/lich-hen/AppointmentParts';
import { STATUS_LABEL, type AppointmentRow } from '../../pages/lich-hen/appointmentTypes';
import type { useLeadCatalogs } from '../../pages/lead/useCatalogs';
import { ConfirmDialog, ReasonDialog } from '../../ui/Dialogs';
import { useToast } from '../../ui/toastContext';
import {
  cancelAppointment,
  completeAppointment,
  createLeadAppointment,
  createOpportunityAppointment,
  reopenAppointment,
  rescheduleAppointment,
  useRefreshAppointmentData,
} from './appointmentApi';
import { AppointmentDialog } from './AppointmentDialog';
import { CompleteAppointmentDialog, type CompleteArgs } from './CompleteAppointmentDialog';
import { RecordPicker, type PickedRecord } from './RecordPicker';
import { useUndoAppointment } from './useUndoAppointment';

export function useAppointmentActions(catalogs: ReturnType<typeof useLeadCatalogs>) {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refreshData = useRefreshAppointmentData();
  const undoAppointment = useUndoAppointment(refreshData);

  const [creating, setCreating] = useState(false);
  const [picked, setPicked] = useState<PickedRecord | null>(null);
  const [moving, setMoving] = useState<AppointmentRow | null>(null);
  const [canceling, setCanceling] = useState<AppointmentRow | null>(null);
  const [completing, setCompleting] = useState<AppointmentRow | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [reopening, setReopening] = useState<AppointmentRow | null>(null);
  const [reopenBusy, setReopenBusy] = useState(false);
  const [reopenError, setReopenError] = useState<string | null>(null);

  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;
  const branchIdOf = (code: string) =>
    access.teachingBranches.find((b) => b.code === code)?.id ?? '';

  /** Hộp «Hoàn thành lịch hẹn» (TS-11): lỗi ném lại để hộp hiện câu lỗi. */
  async function completeWith(id: string, args: CompleteArgs) {
    await completeAppointment(supabase, id, args);
    await refreshData();
    toast({ title: 'Đã hoàn thành lịch hẹn.', action: undoAppointment(id) });
  }

  const actions: RowActions = {
    canEdit: access.can('APPOINTMENT', 'SUA'),
    canCancel: access.can('APPOINTMENT', 'HUY'),
    busyId: null,
    onComplete: (row) => setCompleting(row),
    onReschedule: setMoving,
    onCancel: (row) => {
      setCancelError(null);
      setCanceling(row);
    },
    onReopen: (row) => {
      setReopenError(null);
      setReopening(row);
    },
  };

  const openCreate = () => {
    setPicked(null);
    setCreating(true);
  };

  const dialogs = (
    <>
      <CompleteAppointmentDialog
        open={completing !== null}
        onOpenChange={(o) => !o && setCompleting(null)}
        target={
          completing
            ? {
                id: completing.id,
                activityCode: completing.activity_code,
                isAutoReminder: completing.is_auto_reminder,
                label: `${activityName(completing.activity_code)} · ${completing.title}`,
                context: [
                  completing.record_code,
                  completing.record_label,
                  formatDateTime(completing.scheduled_at),
                ]
                  .filter(Boolean)
                  .join(' · '),
              }
            : null
        }
        resultOptions={catalogs.options('APPOINTMENT_RESULT')}
        onComplete={completeWith}
      />
      <AppointmentDialog
        open={creating}
        onOpenChange={setCreating}
        target={picked}
        targetPicker={<RecordPicker value={picked} onChange={setPicked} />}
        activityOptions={catalogs.options('ACTIVITY_TYPE')}
        onCreate={async (args) => {
          if (!picked) return;
          const noteText = args.note.trim();
          const args2 = {
            activityCode: args.activityCode,
            scheduledAt: args.scheduledAt,
            title: noteText === '' ? activityName(args.activityCode) : noteText,
            ownerId: args.ownerId,
          };
          if (picked.kind === 'OPPORTUNITY') {
            await createOpportunityAppointment(supabase, {
              ...args2,
              opportunityId: picked.recordId,
            });
          } else {
            await createLeadAppointment(supabase, { ...args2, leadId: picked.recordId });
          }
          await refreshData();
          toast({ title: 'Đã tạo lịch hẹn.' });
        }}
        onReschedule={() => Promise.resolve()}
      />
      {moving && (
        <AppointmentDialog
          open
          onOpenChange={(open) => !open && setMoving(null)}
          target={{ label: moving.record_label ?? '', branchId: branchIdOf(moving.branch_code) }}
          activityOptions={[]}
          reschedule={{
            id: moving.id,
            label:
              moving.title === activityName(moving.activity_code)
                ? moving.title
                : `${activityName(moving.activity_code)} · ${moving.title}`,
            scheduledAt: moving.scheduled_at,
            ownerId: moving.owner_id,
            ownerName: moving.owner_name,
            branchId: branchIdOf(moving.branch_code),
          }}
          onCreate={() => Promise.resolve()}
          onReschedule={async (args) => {
            await rescheduleAppointment(supabase, args);
            await refreshData();
            toast({ title: 'Đã dời lịch hẹn.' });
          }}
        />
      )}
      <ReasonDialog
        open={canceling !== null}
        onOpenChange={(open) => !open && setCanceling(null)}
        title="Huỷ lịch hẹn"
        description={
          canceling ? `${activityName(canceling.activity_code)} · ${canceling.title}` : undefined
        }
        options={catalogs.options('APPOINTMENT_CANCEL_REASON').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('APPOINTMENT_CANCEL_REASON', o.value),
        }))}
        confirmLabel="Huỷ lịch hẹn"
        busy={cancelBusy}
        error={cancelError}
        onConfirm={(result) => {
          if (!canceling) return;
          setCancelBusy(true);
          setCancelError(null);
          void cancelAppointment(supabase, canceling.id, result.option, result.note)
            .then(refreshData)
            .then(() => {
              setCanceling(null);
              toast({ title: 'Đã huỷ lịch hẹn.', action: undoAppointment(canceling.id) });
            })
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />
      <ConfirmDialog
        open={reopening !== null}
        onOpenChange={(open) => !open && setReopening(null)}
        title="Mở lại lịch hẹn?"
        description={
          reopening
            ? `${activityName(reopening.activity_code)} · ${reopening.title} đang ${STATUS_LABEL[reopening.status].toLowerCase()}. Mở lại sẽ đưa về Chưa làm, không đổi giai đoạn, không tạo việc, không gửi thông báo. Lịch sử có ghi lần mở lại.`
            : undefined
        }
        confirmLabel="Mở lại"
        busy={reopenBusy}
        error={reopenError}
        onConfirm={() => {
          if (!reopening) return;
          setReopenBusy(true);
          setReopenError(null);
          void reopenAppointment(supabase, reopening.id)
            .then(refreshData)
            .then(() => {
              setReopening(null);
              toast({ title: 'Đã mở lại lịch hẹn.' });
            })
            .catch((e: unknown) => setReopenError(errorOf(e).message))
            .finally(() => setReopenBusy(false));
        }}
      />
    </>
  );

  return { actions, activityName, openCreate, dialogs };
}
