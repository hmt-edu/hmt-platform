// Lịch hẹn trên trang bản ghi (TS-08 Cơ hội): khối "Hoạt động sắp tới" và các hộp Tạo, Dời, Huỷ (R-CRM-04, R-CRM-38).
// Một chỗ gom trạng thái và hộp thoại để trang bản ghi chỉ nhận khối hiển thị và nút mở hộp Tạo.
import { useState, type ReactNode } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { ReasonDialog } from '../../ui/Dialogs';
import { useToast } from '../../ui/toastContext';
import type { LeadCatalogs } from '../../pages/lead/useCatalogs';
import {
  cancelAppointment,
  completeAppointment,
  createOpportunityAppointment,
  rescheduleAppointment,
  useOpportunityUpcoming,
  useTestUpcoming,
  type UpcomingAppointment,
} from './appointmentApi';
import { AppointmentDialog } from './AppointmentDialog';
import { UpcomingActivities } from './UpcomingActivities';
import { useUndoAppointment } from './useUndoAppointment';

type Row = UpcomingAppointment & { branchId: string };

export function useOpportunityAppointments({
  opportunityId,
  branchId,
  label,
  catalogs,
  canEdit,
  canCancel,
  refresh,
  upcomingOfTest,
}: {
  opportunityId: string;
  branchId: string;
  /** "CO000124 · Anh Phạm Văn Tú · Phạm Minh Khôi" (ô Gắn với, chỉ đọc). */
  label: string;
  catalogs: LeadCatalogs;
  canEdit: boolean;
  canCancel: boolean;
  refresh: () => Promise<void>;
  /** Trang phiếu kiểm tra: khối "Hoạt động sắp tới" là lịch nhắc của phiếu này; Tạo vẫn gắn với cơ hội của phiếu. */
  upcomingOfTest?: string | undefined;
}): { upcoming: ReactNode; dialogs: ReactNode; openCreate: () => void } {
  const supabase = useDb();
  const toast = useToast();
  const undo = useUndoAppointment(refresh);
  const ofOpportunity = useOpportunityUpcoming(upcomingOfTest === undefined ? opportunityId : null);
  const ofTest = useTestUpcoming(upcomingOfTest ?? null);
  const query = upcomingOfTest === undefined ? ofOpportunity : ofTest;
  const [createOpen, setCreateOpen] = useState(false);
  const [moving, setMoving] = useState<Row | null>(null);
  const [canceling, setCanceling] = useState<UpcomingAppointment | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;
  const target = { label, branchId };

  async function complete(row: UpcomingAppointment) {
    setBusyId(row.id);
    try {
      await completeAppointment(supabase, row.id);
      await refresh();
      toast({ title: 'Đã hoàn thành lịch hẹn.', action: undo(row.id) });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setBusyId(null);
    }
  }

  const upcoming = (
    <UpcomingActivities
      rows={query.data?.rows ?? []}
      activityName={activityName}
      canEdit={canEdit}
      canCancel={canCancel}
      busyId={busyId}
      onComplete={(row) => void complete(row)}
      onReschedule={(row) => setMoving({ ...row, branchId })}
      onCancel={(row) => {
        setCancelError(null);
        setCanceling(row);
      }}
    />
  );

  const dialogs = (
    <>
      <AppointmentDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        target={target}
        activityOptions={catalogs.options('ACTIVITY_TYPE')}
        onCreate={async (args) => {
          const noteText = args.note.trim();
          await createOpportunityAppointment(supabase, {
            opportunityId,
            activityCode: args.activityCode,
            scheduledAt: args.scheduledAt,
            // Bản vẽ không có ô "Nội dung": ghi chú là nội dung hiện ở danh sách; để trống thì lấy tên loại hoạt động.
            title: noteText === '' ? activityName(args.activityCode) : noteText,
            ownerId: args.ownerId,
          });
          await refresh();
          toast({ title: 'Đã tạo lịch hẹn.' });
        }}
        onReschedule={() => Promise.resolve()}
      />
      {moving && (
        <AppointmentDialog
          open
          onOpenChange={(open) => !open && setMoving(null)}
          target={target}
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
            branchId: moving.branchId,
          }}
          onCreate={() => Promise.resolve()}
          onReschedule={async (args) => {
            await rescheduleAppointment(supabase, args);
            await refresh();
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
            .then(refresh)
            .then(() => {
              setCanceling(null);
              toast({ title: 'Đã huỷ lịch hẹn.', action: undo(canceling.id) });
            })
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />
    </>
  );

  return { upcoming, dialogs, openCreate: () => setCreateOpen(true) };
}
