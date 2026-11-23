// Lịch hẹn trên trang bản ghi (TS-08 Cơ hội): khối "Hoạt động sắp tới" và các hộp Tạo, Dời, Huỷ (R-CRM-04, R-CRM-38).
// Một chỗ gom trạng thái và hộp thoại để trang bản ghi chỉ nhận khối hiển thị và nút mở hộp Tạo.
import { useCallback, useState, type ReactNode } from 'react';
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
  useRefreshAppointmentData,
  useTestUpcoming,
  type UpcomingAppointment,
} from './appointmentApi';
import { AppointmentDialog } from './AppointmentDialog';
import { CompleteAppointmentDialog, type CompleteArgs } from './CompleteAppointmentDialog';
import { formatDateTime } from '../../lib/format';
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
  // Ghi lịch hẹn ở trang bản ghi cũng làm mới màn Lịch hẹn và các bản ghi khác (lead, cơ hội, phiếu), không chỉ trang này.
  const refreshRelated = useRefreshAppointmentData();
  const refreshAll = useCallback(async () => {
    await Promise.all([refresh(), refreshRelated()]);
  }, [refresh, refreshRelated]);
  const undo = useUndoAppointment(refreshAll);
  const ofOpportunity = useOpportunityUpcoming(upcomingOfTest === undefined ? opportunityId : null);
  const ofTest = useTestUpcoming(upcomingOfTest ?? null);
  const query = upcomingOfTest === undefined ? ofOpportunity : ofTest;
  const [createOpen, setCreateOpen] = useState(false);
  const [moving, setMoving] = useState<Row | null>(null);
  const [canceling, setCanceling] = useState<UpcomingAppointment | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [completing, setCompleting] = useState<UpcomingAppointment | null>(null);

  const activityName = (code: string) => catalogs.name('ACTIVITY_TYPE', code) ?? code;
  const target = { label, branchId };

  /** Gọi từ hộp «Hoàn thành lịch hẹn» (TS-11): lỗi ném lại để hộp hiện câu lỗi, giữ nội dung đã nhập. */
  async function complete(id: string, args: CompleteArgs) {
    await completeAppointment(supabase, id, args);
    await refreshAll();
    toast({ title: 'Đã hoàn thành lịch hẹn.', action: undo(id) });
  }

  const upcoming = (
    <UpcomingActivities
      rows={query.data?.rows ?? []}
      activityName={activityName}
      canEdit={canEdit}
      canCancel={canCancel}
      busyId={null}
      onComplete={(row) => setCompleting(row)}
      onReschedule={(row) => setMoving({ ...row, branchId })}
      onCancel={(row) => {
        setCancelError(null);
        setCanceling(row);
      }}
    />
  );

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
                context: `${label} · ${formatDateTime(completing.scheduled_at)}`,
              }
            : null
        }
        resultOptions={catalogs.options('APPOINTMENT_RESULT')}
        onComplete={complete}
      />
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
          await refreshAll();
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
            await refreshAll();
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
            .then(refreshAll)
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
