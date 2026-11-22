// CS-06 Chi tiết phiếu nghiệp vụ (canvas CSN06): thông tin phiếu, thanh trạng thái, các nút theo trạng thái (Trình, Duyệt, Từ chối, Thực hiện, Huỷ),
// nội dung Cập nhật hồ sơ (trước/sau) và dòng thời gian. Luật chặn thật ở hàm DB (AS-10, R-CS-07); nút chỉ là gợi ý theo `can_approve` và quyền.
import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, useDb } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { MONEY_MODES, TRANSFER_BRANCH_KIND, TRANSFER_KINDS } from './businessTaskForm';
import { useDestBranches } from './useTaskCreate';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Chatter } from '../../ui/Chatter';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { TextAreaField } from '../../ui/Field';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { taskStatusTone } from './phieuConfig';
import { approvalRows } from './approvalRows';
import { taskTimeline } from './phieuTimeline';
import {
  LEVEL_ROLE_LABEL,
  TASK_FIELD_LABEL,
  TASK_STATUS_LABEL,
  TASK_TYPE_LABEL,
} from './phieuTypes';
import { runTaskAction, useRefreshTasks, useTaskRecord, type TaskAction } from './usePhieuData';

const STEPS: StageStep[] = ['NHAP', 'CHO_DUYET', 'DA_DUYET', 'DA_THUC_HIEN'].map((code) => ({
  code,
  label: TASK_STATUS_LABEL[code] ?? code,
}));

/** Giá trị cũ để hiện: chuỗi hoặc số, rỗng thì «—». */
const beforeText = (v: unknown) =>
  typeof v === 'string' || typeof v === 'number' ? String(v) : '—';

/** Câu dưới hộp Duyệt (canvas CSN06): bạn duyệt ở cấp nào; cấp cuối thì phiếu sang Đã duyệt và người tạo bấm Thực hiện, chưa cuối thì chuyển cấp kế. */
function approveHint(level: number, levels: string[]): string {
  const role = (l: string | undefined) => (l ? (LEVEL_ROLE_LABEL[l] ?? l) : '');
  const head = `Bạn duyệt ở cấp ${level}: ${role(levels[level - 1])}. `;
  return level >= levels.length
    ? `${head}Sau khi duyệt, phiếu sang Đã duyệt và người tạo bấm Thực hiện.`
    : `${head}Sau khi duyệt, phiếu chuyển lên cấp ${level + 1}: ${role(levels[level])}.`;
}

type Asking = { action: 'approve' | 'reject' | 'cancel' | 'execute' } | null;

export function TaskRecordPage() {
  const { id } = useParams();
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const refresh = useRefreshTasks();
  const record = useTaskRecord(id);
  const destBranches = useDestBranches(
    record.data?.task.payload.kind_code === TRANSFER_BRANCH_KIND,
  );
  const [asking, setAsking] = useState<Asking>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const task = record.data?.task;
  useCrumbTail(task?.code ?? '');
  const entries = useMemo(() => taskTimeline(record.data?.events ?? []), [record.data]);

  if (record.isPending) return <Spinner label="Đang tải phiếu…" />;
  if (record.isError || !task || !record.data)
    return (
      <QueryErrorView error={record.error} subject="phiếu" onRetry={() => void record.refetch()} />
    );
  const ticket = record.data.ticket;
  const canEdit = access.can('TICKET', 'SUA');
  const open = ['NHAP', 'CHO_DUYET', 'DA_DUYET'].includes(task.status_code);
  const needsNote = asking?.action === 'reject' || asking?.action === 'cancel';

  const close = () => {
    setAsking(null);
    setNote('');
    setError(null);
  };
  const run = async (action: TaskAction, text?: string) => {
    setBusy(true);
    setError(null);
    try {
      await runTaskAction(supabase, action, task.id, text);
      close();
      toast({ tone: 'success', title: 'Đã cập nhật phiếu.' });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const changes = task.payload.changes ?? {};
  const before = task.result?.before ?? null;

  return (
    <>
      <RecordDetail
        kind="Phiếu"
        title={`${TASK_TYPE_LABEL[task.task_type] ?? task.task_type} · ${ticket.code}`}
        mode="view"
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => void refresh()}
        headerActions={
          <>
            {task.status_code === 'NHAP' && canEdit && (
              <Button variant="primary" loading={busy} onClick={() => void run('submit')}>
                Trình duyệt
              </Button>
            )}
            {task.status_code === 'CHO_DUYET' && task.can_approve && (
              <>
                <Button variant="primary" onClick={() => setAsking({ action: 'approve' })}>
                  Duyệt
                </Button>
                <Button onClick={() => setAsking({ action: 'reject' })}>Từ chối</Button>
              </>
            )}
            {task.status_code === 'DA_DUYET' && canEdit && (
              <Button variant="primary" onClick={() => setAsking({ action: 'execute' })}>
                Thực hiện
              </Button>
            )}
            {open && canEdit && (
              <Button onClick={() => setAsking({ action: 'cancel' })}>Huỷ phiếu</Button>
            )}
          </>
        }
        stage={
          ['TU_CHOI', 'DA_HUY'].includes(task.status_code)
            ? undefined
            : {
                steps: STEPS,
                current: task.status_code,
                forwardOnly: true,
                onSelect: () => undefined,
              }
        }
        stageShowCode={false}
        stageNote="Đổi trạng thái bằng các nút ở trên."
        aside={
          <Chatter
            entries={entries}
            status="ready"
            canWrite={false}
            onSend={() => Promise.resolve()}
            searchPeople={() => Promise.resolve([])}
          />
        }
      >
        {/* CSN06a «Lỗi lưu»: lỗi khi Trình duyệt (không có hộp thoại) hiện ngay trên phiếu, giữ nguyên nội dung, có nút Thử lại. */}
        {error && asking === null && (
          <div className="mb-4">
            <Alert tone="danger">
              <span className="flex flex-wrap items-center gap-3">
                <span>
                  <b>Chưa lưu được phiếu.</b> {error} Nội dung vẫn còn trên màn hình.
                </span>
                <Button loading={busy} onClick={() => void run('submit')}>
                  Thử lại
                </Button>
              </span>
            </Alert>
          </div>
        )}
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phiếu">
            <DetailField label="Mã phiếu" mode="view" value={task.code} />
            <DetailField
              label="Loại phiếu"
              mode="view"
              value={TASK_TYPE_LABEL[task.task_type] ?? task.task_type}
            />
            <DetailField
              label="Trạng thái"
              mode="view"
              value={
                <Tag tone={taskStatusTone(task.status_code)} dot>
                  {TASK_STATUS_LABEL[task.status_code] ?? task.status_code}
                </Tag>
              }
            />
            <DetailField
              label="Ticket gốc"
              mode="view"
              value={
                <Link className="text-link underline" to={`/crm/ticket/${ticket.id}`}>
                  {ticket.code} · {ticket.title}
                </Link>
              }
            />
            <DetailField label="Học sinh" mode="view" value={ticket.student_name ?? ''} />
            <DetailField
              label="Cơ sở"
              mode="view"
              value={access.branchName(task.branch_code) ?? task.branch_code}
            />
            <DetailField label="Người tạo" mode="view" value={task.created_by_name ?? ''} />
            <DetailField label="Lý do" mode="view" value={task.reason} />
            {task.reject_reason && (
              <DetailField label="Lý do từ chối" mode="view" value={task.reject_reason} />
            )}
            {task.cancel_reason && (
              <DetailField label="Lý do huỷ" mode="view" value={task.cancel_reason} />
            )}
          </DetailSection>
          <DetailSection title="Duyệt">
            <table aria-label="Các cấp duyệt" className="mb-4 w-full text-body">
              <thead>
                <tr className="text-left text-caption text-fg-muted">
                  <th className="py-1 pr-3 font-medium">Cấp</th>
                  <th className="py-1 pr-3 font-medium">Vai trò</th>
                  <th className="py-1 pr-3 font-medium">Người duyệt</th>
                  <th className="py-1 pr-3 font-medium">Kết quả</th>
                  <th className="py-1 font-medium">Lúc</th>
                </tr>
              </thead>
              <tbody>
                {approvalRows(
                  task.levels,
                  task.status_code,
                  record.data?.events ?? [],
                  (l) => LEVEL_ROLE_LABEL[l] ?? l,
                  task.next_approver ?? null,
                ).map((r) => (
                  <tr key={r.level} className="border-t border-border">
                    <td className="py-1 pr-3">Cấp {r.level}</td>
                    <td className="py-1 pr-3">{r.role}</td>
                    <td className="py-1 pr-3">{r.approver ?? '—'}</td>
                    <td className="py-1 pr-3">{r.result}</td>
                    <td className="py-1">{r.at ? formatDateTime(r.at) : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <DetailField
              label="Trình lúc"
              mode="view"
              value={task.submitted_at ? formatDateTime(task.submitted_at) : ''}
            />
            <DetailField
              label="Duyệt xong lúc"
              mode="view"
              value={task.approved_at ? formatDateTime(task.approved_at) : ''}
            />
            <DetailField
              label="Thực hiện lúc"
              mode="view"
              value={task.executed_at ? formatDateTime(task.executed_at) : ''}
            />
          </DetailSection>
        </div>
        {(task.task_type === 'BAO_LUU' || task.task_type === 'CHUYEN_LOP') && (
          <div className="mt-6">
            <DetailSection
              title={`Nội dung ${task.task_type === 'BAO_LUU' ? 'bảo lưu' : 'chuyển lớp'}`}
            >
              {task.task_type === 'BAO_LUU' ? (
                <DetailField
                  label="Số tháng bảo lưu"
                  mode="view"
                  value={task.payload.months !== undefined ? String(task.payload.months) : ''}
                />
              ) : (
                <>
                  <DetailField
                    label="Loại chuyển"
                    mode="view"
                    value={
                      TRANSFER_KINDS.find((k) => k.value === task.payload.kind_code)?.label ?? ''
                    }
                  />
                  {task.payload.kind_code === TRANSFER_BRANCH_KIND ? (
                    <DetailField
                      label="Cơ sở mới"
                      mode="view"
                      value={
                        destBranches.data?.find((b) => b.id === task.payload.dest_branch_id)
                          ?.name ?? ''
                      }
                    />
                  ) : (
                    <DetailField
                      label="Hiệu lực từ ngày"
                      mode="view"
                      value={task.payload.start_date ? formatDate(task.payload.start_date) : ''}
                    />
                  )}
                </>
              )}
            </DetailSection>
          </div>
        )}
        {task.task_type === 'DUNG_HOC' && (
          <div className="mt-6">
            <DetailSection title="Nội dung dừng học">
              <DetailField
                label="Ngày dừng"
                mode="view"
                value={task.payload.stop_date ? formatDate(task.payload.stop_date) : ''}
              />
              <DetailField
                label="Xử lý tiền còn lại"
                mode="view"
                value={
                  MONEY_MODES.find((m) => m.value === (task.payload.money_mode ?? 'GIU_SO_DU'))
                    ?.label ?? ''
                }
              />
            </DetailSection>
          </div>
        )}
        {task.task_type === 'CAP_NHAT_HO_SO' && (
          <div className="mt-6">
            <DetailSection
              title={`Nội dung cập nhật (${task.payload.entity === 'PARENT' ? 'phụ huynh' : 'học sinh'})`}
            >
              {Object.entries(changes).map(([field, value]) => (
                <DetailField
                  key={field}
                  label={TASK_FIELD_LABEL[field] ?? field}
                  mode="view"
                  value={
                    before && field in before ? (
                      <>
                        <span className="text-fg-muted line-through">
                          {beforeText(before[field])}
                        </span>{' '}
                        → {value}
                      </>
                    ) : (
                      value
                    )
                  }
                />
              ))}
            </DetailSection>
          </div>
        )}
      </RecordDetail>
      <FormDialog
        open={asking !== null && asking.action !== 'execute'}
        onOpenChange={(o) => !o && close()}
        title={
          asking?.action === 'approve'
            ? 'Duyệt phiếu'
            : asking?.action === 'reject'
              ? 'Từ chối phiếu'
              : 'Huỷ phiếu'
        }
        subtitle={task.code}
        confirmLabel={
          asking?.action === 'approve'
            ? 'Duyệt'
            : asking?.action === 'reject'
              ? 'Từ chối'
              : 'Huỷ phiếu'
        }
        canSubmit={!needsNote || note.trim() !== ''}
        busy={busy}
        error={error}
        onSubmit={() => asking && asking.action !== 'execute' && void run(asking.action, note)}
      >
        <TextAreaField
          label={needsNote ? 'Lý do' : 'Ghi chú duyệt'}
          required={needsNote}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
        {asking?.action === 'reject' && (
          <p className="text-caption text-fg-muted">
            Bắt buộc. Phiếu về trạng thái Từ chối, người tạo sửa và gửi lại.
          </p>
        )}
        {asking?.action === 'cancel' && (
          <p className="text-caption text-fg-muted">Phiếu không xoá được, chỉ chuyển sang Huỷ.</p>
        )}
        {asking?.action === 'approve' && (
          <p className="text-caption text-fg-muted">{approveHint(task.level, task.levels)}</p>
        )}
      </FormDialog>
      <ConfirmDialog
        open={asking?.action === 'execute'}
        onOpenChange={(o) => !o && close()}
        title="Thực hiện phiếu?"
        description="Hồ sơ sẽ được cập nhật theo nội dung phiếu, ticket chuyển sang Đã xử lý. Không hoàn tác bằng nút."
        confirmLabel="Thực hiện"
        busy={busy}
        onConfirm={() => void run('execute')}
      />
    </>
  );
}
