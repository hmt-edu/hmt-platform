// CS-07 màn cơ sở ĐÍCH (R-GD-10, R-CS-07; anh chốt 21/11 23:17): quản lý cơ sở mới thấy phiếu chuyển cơ sở khi cơ sở đi đã duyệt, chọn lớp mới và buổi bắt đầu, rồi Duyệt hoặc Từ chối.
// Chưa có khung riêng cho màn này: dựng từ khuôn trang phiếu (TaskRecordPage, CSN06a_chuyen_co_so), chờ Design xác nhận. Luật chặn thật ở hàm DB.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { useToast } from '../../ui/toastContext';
import { runTaskAction } from '../phieu/usePhieuData';
import { hasSavedDestinationClass, validateDestinationChoice } from './destinationTypes';
import { setDestinationClass, useDestinationRecord, useRefreshDestination } from './useDestination';

export function TaskDestinationPage() {
  const { id } = useParams();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshDestination();
  const record = useDestinationRecord(id);
  const task = record.data?.task;
  useCrumbTail(task?.code ?? '');
  const [classId, setClassId] = useState('');
  const [startDate, setStartDate] = useState('');
  const [show, setShow] = useState(false);
  const [asking, setAsking] = useState<'approve' | 'reject' | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (record.isPending) return <Spinner label="Đang tải phiếu…" />;
  if (record.isError || !task || !record.data)
    return (
      <QueryErrorView error={record.error} subject="phiếu" onRetry={() => void record.refetch()} />
    );
  const classes = record.data.classes;
  const chosen = classes.find((c) => c.id === classId);
  const errors = show ? validateDestinationChoice(classId, startDate) : {};
  const saved = hasSavedDestinationClass(task);
  const savedClass = classes.find((c) => c.id === task.to_class_id);

  const run = async (fn: () => Promise<unknown>, done: string) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
      setAsking(null);
      setNote('');
      toast({ tone: 'success', title: done });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };
  const saveClass = () => {
    setShow(true);
    if (Object.keys(validateDestinationChoice(classId, startDate)).length > 0) return;
    void run(
      () => setDestinationClass(supabase, { id: task.id, classId, startDate }),
      'Đã lưu lớp mới.',
    );
  };

  return (
    <>
      <RecordDetail
        kind="Phiếu"
        title={`Chuyển cơ sở · ${task.student_name ?? task.code}`}
        mode="view"
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => void record.refetch()}
        headerActions={
          <>
            <Button
              variant="primary"
              disabled={!saved}
              onClick={() => {
                setError(null);
                setAsking('approve');
              }}
            >
              Duyệt
            </Button>
            <Button
              onClick={() => {
                setError(null);
                setAsking('reject');
              }}
            >
              Từ chối
            </Button>
          </>
        }
        stageShowCode={false}
        aside={undefined}
      >
        {error && asking === null && (
          <div className="mb-4">
            <Alert tone="danger">
              <b>Chưa lưu được.</b> {error}
            </Alert>
          </div>
        )}
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phiếu">
            <DetailField label="Mã phiếu" mode="view" value={task.code} />
            <DetailField label="Học sinh" mode="view" value={task.student_name ?? ''} />
            <DetailField label="Cơ sở hiện tại" mode="view" value={task.from_branch_code} />
            <DetailField label="Cơ sở mới" mode="view" value={task.dest_branch_code} />
            <DetailField label="Giờ còn lại" mode="view" value={`${task.hours_left} giờ`} />
            <DetailField label="Lý do" mode="view" value={task.reason} />
            <DetailField
              label="Quản lý cơ sở đi đã duyệt"
              mode="view"
              value={task.approved_by_source ?? ''}
            />
          </DetailSection>
          <DetailSection title="Lớp ở cơ sở mới">
            {saved && (
              <p className="text-caption text-fg-muted">
                Đã chọn: {savedClass?.code ?? 'lớp đã lưu'} từ ngày{' '}
                {formatDate(task.start_date ?? '')}. Chọn lại bên dưới nếu muốn đổi.
              </p>
            )}
            <OptionalSelect
              label="Lớp ở cơ sở mới"
              value={classId}
              onChange={(v) => {
                setClassId(v);
                setStartDate('');
              }}
              options={classes.map((c) => ({ value: c.id, label: c.code }))}
              placeholder="Chọn lớp"
              invalid={errors.classId !== undefined}
            />
            {errors.classId && (
              <p className="text-caption text-on-danger-subtle">{errors.classId}</p>
            )}
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
              invalid={errors.startDate !== undefined}
            />
            {errors.startDate && (
              <p className="text-caption text-on-danger-subtle">{errors.startDate}</p>
            )}
            <div>
              <Button loading={busy} onClick={saveClass}>
                Lưu lớp
              </Button>
            </div>
            <p className="text-caption text-fg-muted">
              Chuyển cơ sở giữ nguyên số giờ. Lưu lớp xong mới Duyệt được; sau khi duyệt, phiếu
              chuyển tiếp theo cấu hình.
            </p>
          </DetailSection>
        </div>
        <p className="mt-4 text-caption text-fg-muted">
          <Link className="text-link underline" to="/crm/phieu-chuyen-co-so-den">
            ← Về danh sách phiếu chuyển cơ sở đến
          </Link>
        </p>
      </RecordDetail>
      <FormDialog
        open={asking !== null}
        onOpenChange={(o) => !o && setAsking(null)}
        title={asking === 'reject' ? 'Từ chối phiếu' : 'Duyệt phiếu'}
        subtitle={task.code}
        confirmLabel={asking === 'reject' ? 'Từ chối' : 'Duyệt'}
        canSubmit={asking !== 'reject' || note.trim() !== ''}
        busy={busy}
        error={error}
        onSubmit={() =>
          void run(
            () =>
              runTaskAction(
                supabase,
                asking === 'reject' ? 'reject' : 'approve',
                task.id,
                note.trim(),
              ),
            'Đã cập nhật phiếu.',
          )
        }
      >
        <TextAreaField
          label={asking === 'reject' ? 'Lý do từ chối' : 'Ghi chú duyệt'}
          required={asking === 'reject'}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </FormDialog>
    </>
  );
}
