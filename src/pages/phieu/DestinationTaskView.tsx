// CS-07 Chuyển cơ sở, màn của quản lý cơ sở ĐÍCH (khi tới lượt, migration 568): xem phiếu tối thiểu, chọn lớp mới và buổi bắt đầu, rồi Duyệt.
// Luật chặn thật ở DB (set_task_destination_class, approve_ticket_task); màn chỉ gợi ý. Giữ giờ (R-GD-10): lớp mới nhận học sinh với số giờ còn lại.
import { useState } from 'react';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import type { DestinationTask } from './phieuTypes';
import { runTaskAction, setDestinationClass, useRefreshTasks } from './usePhieuData';

export function DestinationTaskView({ data }: { data: DestinationTask }) {
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refresh = useRefreshTasks();
  const { task, classes } = data;
  useCrumbTail(task.code);
  const [classId, setClassId] = useState(task.to_class_id ?? '');
  const [startDate, setStartDate] = useState(task.start_date ?? '');
  const [approving, setApproving] = useState(false);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const chosen = classes.find((c) => c.id === classId);
  const saved =
    task.to_class_id !== null && task.to_class_id === classId && task.start_date === startDate;

  const run = async (work: () => Promise<unknown>, done: string) => {
    setBusy(true);
    setError(null);
    try {
      await work();
      setApproving(false);
      setNote('');
      toast({ tone: 'success', title: done });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <RecordDetail
        kind="Phiếu"
        title={`Chuyển cơ sở · ${task.code}`}
        mode="view"
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => void refresh()}
        aside={null}
        headerActions={
          <Button variant="primary" disabled={!saved} onClick={() => setApproving(true)}>
            Duyệt
          </Button>
        }
      >
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phiếu">
            <DetailField label="Học sinh" mode="view" value={task.student_name ?? ''} />
            <DetailField
              label="Cơ sở đi"
              mode="view"
              value={access.branchName(task.from_branch_code) ?? task.from_branch_code}
            />
            <DetailField
              label="Cơ sở đích"
              mode="view"
              value={access.branchName(task.dest_branch_code) ?? task.dest_branch_code}
            />
            <DetailField label="Giờ còn lại" mode="view" value={`${task.hours_left} giờ`} />
            <DetailField label="Lý do" mode="view" value={task.reason} />
            <DetailField
              label="Quản lý cơ sở đi đã duyệt"
              mode="view"
              value={task.approved_by_source ?? ''}
            />
          </DetailSection>
          <DetailSection title="Chọn lớp mới">
            <OptionalSelect
              label="Lớp mới"
              value={classId}
              onChange={(v) => {
                setClassId(v);
                setStartDate('');
              }}
              options={classes.map((c) => ({
                value: c.id,
                label: `${c.code}${c.seats_left !== null ? ` · còn ${c.seats_left} chỗ` : ''}`,
              }))}
              placeholder="Chọn lớp"
            />
            <OptionalSelect
              label="Hiệu lực từ buổi"
              value={startDate}
              onChange={setStartDate}
              options={(chosen?.upcoming ?? []).map((u) => ({
                value: u.date,
                label: `Buổi ${u.session_no} · ${formatDate(u.date)}`,
              }))}
              placeholder="Chọn buổi"
              disabled={chosen === undefined}
            />
            {classes.length === 0 && (
              <p className="text-caption text-fg-muted">
                Cơ sở đích chưa có lớp đã duyệt còn chỗ cùng môn của học sinh.
              </p>
            )}
            {error && !approving && <p className="text-caption text-on-danger-subtle">{error}</p>}
            <div className="mt-3">
              <Button
                loading={busy}
                disabled={classId === '' || startDate === '' || saved}
                onClick={() =>
                  void run(
                    () => setDestinationClass(supabase, task.id, classId, startDate),
                    'Đã lưu lớp mới.',
                  )
                }
              >
                Lưu lớp mới
              </Button>
            </div>
            <p className="mt-2 text-caption text-fg-muted">
              Lưu lớp mới xong mới Duyệt được. Duyệt xong phiếu chuyển sang bước thực hiện.
            </p>
          </DetailSection>
        </div>
      </RecordDetail>
      <FormDialog
        open={approving}
        onOpenChange={(o) => !o && setApproving(false)}
        title="Duyệt phiếu"
        subtitle={task.code}
        confirmLabel="Duyệt"
        canSubmit
        busy={busy}
        error={error}
        onSubmit={() =>
          void run(() => runTaskAction(supabase, 'approve', task.id, note), 'Đã duyệt phiếu.')
        }
      >
        <TextAreaField label="Ghi chú" value={note} onChange={(e) => setNote(e.target.value)} />
      </FormDialog>
    </>
  );
}
