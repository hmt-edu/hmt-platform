// CSN-03 Chi tiết ticket (đề nghị, khiếu nại, giáo viên): thông tin chỉ đọc, thanh trạng thái 7 bước, ghi chú và dòng thời gian.
// Đổi trạng thái gọi app.change_ticket_status (luật AS-02 ở hàm DB; giao diện chỉ hỏi thêm ghi chú, kết quả, mức hài lòng).
// Giao ticket (chọn đội, người phụ trách) và tạo mới làm ở lát sau: danh sách người giao cần mở rộng hàm máy chủ.
import { useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Chatter } from '../../ui/Chatter';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { QueryErrorView } from '../../ui/QueryErrorView';
import { Button } from '../../ui/Button';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  EMPTY_TASK_DRAFT,
  buildTaskPayload,
  validateTaskDraft,
  type TaskDraft,
} from '../phieu/taskForm';
import { BusinessTaskDialog } from '../phieu/BusinessTaskDialog';
import { ScheduleTaskDialog } from '../phieu/ScheduleTaskDialog';
import { createTicketTask, useTaskFields } from '../phieu/useTaskCreate';
import { TASK_STATUS_LABEL, TASK_TYPE_LABEL } from '../phieu/taskLabels';
import { groupsOf, subgroupsOf } from './ticketCreate';
import { statusDialogSpec } from './statusDialog';
import { taskFeatureOffMessage } from '../phieu/taskFeature';
import { ticketTimeline } from './ticketTimeline';
import {
  addTicketNote,
  assignTicket,
  changeTicketStatus,
  escalateTicket,
  reclassifyTicket,
  useTicketCategories,
  useTicketAssignees,
  updateTicketComplaint,
  useTicketRecord,
} from './useTicketData';
import { FromLink } from '../../layout/FromLink';
import { useNavigateFrom } from '../../layout/crumbTrail';

const TYPE_NAME = { DN: 'Đề nghị', KN: 'Khiếu nại', GV: 'Ticket giáo viên' } as const;

export function TicketRecordPage() {
  const { id } = useParams();
  const supabase = useDb();
  const access = useAccess();
  const warnPercent = useIntSetting('as_sla_warn_percent');
  const toast = useToast();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();
  const record = useTicketRecord(id);
  const [target, setTarget] = useState<string | null>(null);
  const [customerCancel, setCustomerCancel] = useState(false);
  const [note, setNote] = useState('');
  const [resolution, setResolution] = useState('');
  const [satisfaction, setSatisfaction] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [complaintOpen, setComplaintOpen] = useState(false);
  const [escalateOpen, setEscalateOpen] = useState(false);
  const [escalateReason, setEscalateReason] = useState('');
  const [complaint, setComplaint] = useState({
    accused: '',
    date: '',
    wish: '',
    cause: '',
    compensation: '',
  });
  const categories = useTicketCategories();
  const [reclassOpen, setReclassOpen] = useState(false);
  const [reclass, setReclass] = useState({ type: '', group: '', category: '', priority: '' });
  const openFrom = useNavigateFrom();
  const [taskOpen, setTaskOpen] = useState(false);
  const [taskDraft, setTaskDraft] = useState<TaskDraft>(EMPTY_TASK_DRAFT);
  const [taskShow, setTaskShow] = useState(false);
  const [assignOpen, setAssignOpen] = useState(false);
  const [team, setTeam] = useState('');
  const [assignee, setAssignee] = useState('');

  const ticket = record.data?.ticket;
  const taskFields = useTaskFields(taskOpen && ticket?.business_type === 'CAP_NHAT_HO_SO');
  const assignees = useTicketAssignees(ticket?.branch_id ?? null, assignOpen || complaintOpen);
  useCrumbTail(ticket?.code ?? '');
  const statusName = (code: string | null) => catalogs.name('TICKET_STATUS', code) ?? code ?? '';
  const steps: StageStep[] = useMemo(
    () => catalogs.options('TICKET_STATUS').map((o) => ({ code: o.value, label: o.label })),
    [catalogs],
  );
  const entries = useMemo(
    () => ticketTimeline(record.data?.events ?? [], statusName),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [record.data, catalogs],
  );

  if (record.isPending) return <Spinner label="Đang tải ticket…" />;
  if (record.isError || !ticket)
    return (
      <QueryErrorView error={record.error} subject="ticket" onRetry={() => void record.refetch()} />
    );

  const canEdit = access.can('TICKET', 'SUA');
  const closed = ticket.status_code === 'DA_DONG' || ticket.status_code === 'DA_HUY';
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['ticket-record', id] });
  const needResolution = target === 'DA_XU_LY' && !ticket.resolution;
  const needSatisfaction = target === 'DA_DONG' && ticket.ticket_type === 'KN';
  const dialogSpec = statusDialogSpec({
    from: ticket.status_code,
    to: target ?? '',
    ticketType: ticket.ticket_type,
    businessType: ticket.business_type,
    customerCancel,
  });
  const needNote = dialogSpec.noteRequired;
  const satisfactionValue = Number(satisfaction);
  const canSubmit =
    (!needResolution || resolution.trim() !== '') &&
    (!needNote || note.trim() !== '') &&
    (!needSatisfaction || (satisfactionValue >= 1 && satisfactionValue <= 5));

  const close = () => {
    setTarget(null);
    setCustomerCancel(false);
    setNote('');
    setResolution('');
    setSatisfaction('');
    setError(null);
  };

  const submit = async () => {
    if (target === null) return;
    setBusy(true);
    setError(null);
    try {
      await changeTicketStatus(supabase, {
        id: ticket.id,
        to: target,
        // Khách huỷ: ghi rõ ở nhật ký để phân biệt với huỷ nội bộ (không thêm trạng thái mới).
        ...(note.trim() !== '' && {
          note: customerCancel ? `Khách huỷ: ${note.trim()}` : note.trim(),
        }),
        ...(resolution.trim() !== '' && { resolution: resolution.trim() }),
        ...(needSatisfaction && { satisfaction: satisfactionValue }),
      });
      close();
      toast({ tone: 'success', title: 'Đã đổi trạng thái ticket.' });
      await refresh();
    } catch (cause) {
      // CSN04_khach_huy_loi: lý do vừa nhập vẫn giữ nguyên (không đóng hộp thoại).
      setError(
        customerCancel ? `Chưa huỷ được ticket. ${errorOf(cause).message}` : errorOf(cause).message,
      );
    } finally {
      setBusy(false);
    }
  };

  const openComplaint = () => {
    setComplaint({
      accused: ticket.accused_user_id ?? '',
      date: ticket.complaint_date ?? '',
      wish: ticket.customer_wish ?? '',
      cause: ticket.root_cause ?? '',
      compensation: ticket.compensation_note ?? '',
    });
    setError(null);
    setComplaintOpen(true);
  };

  const submitComplaint = async () => {
    setBusy(true);
    setError(null);
    try {
      await updateTicketComplaint(supabase, ticket.id, {
        accused_user_id: complaint.accused === '' ? null : complaint.accused,
        complaint_date: complaint.date === '' ? null : complaint.date,
        customer_wish: complaint.wish,
        root_cause: complaint.cause,
        compensation_note: complaint.compensation,
      });
      setComplaintOpen(false);
      toast({ tone: 'success', title: 'Đã lưu phần riêng của khiếu nại.' });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const openReclass = () => {
    const all = categories.data ?? [];
    const current = all.find((c) => c.code === ticket.category_code);
    setReclass({
      type: ticket.ticket_type,
      group: current?.parent_code ?? '',
      category: ticket.category_code,
      priority: ticket.priority_code,
    });
    setError(null);
    setReclassOpen(true);
  };

  const submitReclass = async () => {
    setBusy(true);
    setError(null);
    try {
      const typeChanged = reclass.type !== ticket.ticket_type;
      await reclassifyTicket(supabase, {
        id: ticket.id,
        ...(typeChanged && { type: reclass.type }),
        ...((typeChanged || reclass.category !== ticket.category_code) && {
          category: reclass.category,
        }),
        // Đổi loại đặt lại mức độ theo nhóm con mới; chỉ đổi riêng khi người dùng chọn khác và không đổi loại.
        ...(!typeChanged &&
          reclass.priority !== ticket.priority_code && { priority: reclass.priority }),
      });
      setReclassOpen(false);
      toast({ tone: 'success', title: 'Đã cập nhật phân loại ticket.' });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const nextEscalation =
    ticket.escalation_level === 'QUAN_LY_CO_SO' ? 'Ban giám đốc' : 'Quản lý cơ sở';
  const canEscalate = ticket.ticket_type === 'KN' && ticket.escalation_level !== 'BAN_GIAM_DOC';
  const openEscalate = () => {
    setEscalateReason('');
    setError(null);
    setEscalateOpen(true);
  };
  const submitEscalate = async () => {
    setBusy(true);
    setError(null);
    try {
      await escalateTicket(supabase, { id: ticket.id, reason: escalateReason.trim() });
      setEscalateOpen(false);
      toast({ tone: 'success', title: `Đã nâng cấp lên ${nextEscalation}.` });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const openTask = () => {
    setTaskDraft(EMPTY_TASK_DRAFT);
    setTaskShow(false);
    setError(null);
    setTaskOpen(true);
  };

  const createBusinessTask = async (reason: string, payload: unknown) => {
    setBusy(true);
    setError(null);
    try {
      const created = await createTicketTask(supabase, {
        ticketId: ticket.id,
        type: ticket.business_type ?? '',
        reason,
        payload,
      });
      setTaskOpen(false);
      toast({ tone: 'success', title: 'Đã tạo phiếu ở bước Nháp.' });
      openFrom(`/crm/phieu-nghiep-vu/${created.id}`);
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const submitTask = async () => {
    setTaskShow(true);
    const found = validateTaskDraft(taskDraft, taskFields.data ?? [], ticket.student_name !== null);
    if (Object.keys(found).length > 0) return;
    setBusy(true);
    setError(null);
    try {
      const created = await createTicketTask(supabase, {
        ticketId: ticket.id,
        type: ticket.business_type ?? '',
        reason: taskDraft.reason.trim(),
        payload: buildTaskPayload(taskDraft, taskFields.data ?? []),
      });
      setTaskOpen(false);
      toast({ tone: 'success', title: 'Đã tạo phiếu ở bước Nháp.' });
      openFrom(`/crm/phieu-nghiep-vu/${created.id}`);
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const openAssign = () => {
    setTeam(ticket.team_code ?? '');
    setAssignee('');
    setError(null);
    setAssignOpen(true);
  };

  const submitAssign = async () => {
    setBusy(true);
    setError(null);
    try {
      await assignTicket(supabase, { id: ticket.id, team, assignee });
      setAssignOpen(false);
      toast({ tone: 'success', title: 'Đã giao ticket.' });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const onStage = (step: StageStep) => {
    if (step.code === ticket.status_code) return;
    // Mới → Đã giao đi qua hộp thoại Giao (chọn đội và người phụ trách).
    if (step.code === 'DA_GIAO' && ticket.status_code === 'MOI') {
      openAssign();
      return;
    }
    setTarget(step.code);
  };

  // Công tắc tính năng theo cơ sở của ticket (hàm DB cũng chặn): tắt thì khoá «Tạo phiếu» kèm câu rõ ràng, không để đi tới bước cuối mới lỗi.
  const taskFeatureOff = taskFeatureOffMessage(
    ticket.business_type ?? '',
    access.featureOnAt,
    ticket.branch_code,
  );

  return (
    <>
      <RecordDetail
        kind="Ticket"
        title={ticket.title}
        mode="view"
        readOnly={!canEdit || closed}
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        onRefresh={() => void refresh()}
        headerActions={
          canEdit && !closed ? (
            <>
              <Button icon="user" onClick={openAssign}>
                Giao ticket
              </Button>
              {ticket.ticket_type !== 'GV' && <Button onClick={openReclass}>Phân loại lại</Button>}
              {ticket.ticket_type === 'DN' && (
                <Button
                  onClick={() => {
                    setCustomerCancel(true);
                    setTarget('DA_HUY');
                  }}
                >
                  Khách huỷ
                </Button>
              )}
              {canEscalate && <Button onClick={openEscalate}>Nâng cấp</Button>}
              {[
                'CAP_NHAT_HO_SO',
                'BAO_LUU',
                'CHUYEN_LOP',
                'DUNG_HOC',
                'DOI_LICH',
                'CHUYEN_PHI',
                'HOAN_PHI',
              ].includes(ticket.business_type ?? '') &&
                !(record.data?.tasks ?? []).some((k) =>
                  ['NHAP', 'CHO_DUYET', 'DA_DUYET'].includes(k.status_code),
                ) && (
                  <Button disabled={taskFeatureOff !== null} onClick={openTask}>
                    Tạo phiếu
                  </Button>
                )}
            </>
          ) : canEdit && ticket.status_code === 'DA_DONG' ? (
            // Mở lại ticket đã đóng (R-CS-06, AS-03): quá số ngày cho phép thì DB báo lỗi, hộp thoại hiện lỗi đó.
            <Button onClick={() => setTarget('DANG_XU_LY')}>Mở lại</Button>
          ) : undefined
        }
        stage={{
          steps,
          current: ticket.status_code,
          forwardOnly: false,
          onSelect: onStage,
        }}
        stageShowCode={false}
        aside={
          <Chatter
            entries={entries}
            status="ready"
            canWrite={
              canEdit && ticket.status_code !== 'DA_HUY' && ticket.status_code !== 'DA_DONG'
            }
            onSend={async (body) => {
              await addTicketNote(supabase, ticket.id, body);
              await refresh();
            }}
            searchPeople={() => Promise.resolve([])}
          />
        }
      >
        {taskFeatureOff && ticket.business_type && !closed && (
          <div className="mb-4">
            <Alert tone="warning">{taskFeatureOff}</Alert>
          </div>
        )}
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Tiếp nhận">
            <DetailField label="Mã" mode="view" value={ticket.code} />
            <DetailField label="Loại" mode="view" value={TYPE_NAME[ticket.ticket_type]} />
            <DetailField label="Tiêu đề" mode="view" value={ticket.title} />
            <DetailField label="Người gửi" mode="view" value={ticket.sender_name ?? ''} />
            <DetailField
              label="Kênh"
              mode="view"
              value={catalogs.name('TICKET_CHANNEL', ticket.channel_code) ?? ticket.channel_code}
            />
            <DetailField
              label="Cơ sở"
              mode="view"
              value={access.branchName(ticket.branch_code) ?? ticket.branch_code}
            />
            <DetailField label="Nhóm" mode="view" value={ticket.group_name ?? ''} />
            <DetailField label="Nhóm con" mode="view" value={ticket.category_name ?? ''} />
            {ticket.nature_code && (
              <DetailField
                label="Tính chất"
                mode="view"
                value={ticket.nature_code === 'HO_TRO' ? 'Cần hỗ trợ' : 'Phản ánh'}
              />
            )}
            <DetailField label="Mô tả" mode="view" value={ticket.description} />
          </DetailSection>
          <DetailSection title="Liên kết">
            <DetailField label="Học sinh" mode="view" value={ticket.student_name ?? ''} />
            <DetailField label="Lớp" mode="view" value={ticket.class_code ?? ''} />
            <DetailField label="Ghi danh" mode="view" value={ticket.enrollment_code ?? ''} />
            <DetailField label="Ticket khác" mode="view" value={ticket.related_ticket_code ?? ''} />
          </DetailSection>
          <DetailSection title="Xử lý">
            <DetailField
              label="Đội"
              mode="view"
              value={catalogs.name('TICKET_TEAM', ticket.team_code) ?? ''}
            />
            <DetailField label="Người phụ trách" mode="view" value={ticket.assignee_name ?? ''} />
            <DetailField
              label="Mức độ"
              hint="Đổi mức độ thì hạn tính lại từ lúc tạo."
              mode="view"
              value={catalogs.name('TICKET_PRIORITY', ticket.priority_code) ?? ''}
            />
            <DetailField
              label="Hạn phản hồi"
              mode="view"
              value={
                ticket.first_response_at
                  ? `Đã phản hồi ${formatDateTime(ticket.first_response_at)}`
                  : formatDateTime(ticket.response_due_at)
              }
            />
            <DetailField
              label="Hạn xử lý"
              hint={
                warnPercent !== null
                  ? `Theo loại, mức độ, nhóm con. Còn dưới ${warnPercent}% thời gian thì Sắp quá hạn.`
                  : undefined
              }
              mode="view"
              value={
                <>
                  {formatDateTime(ticket.resolve_due_at)}{' '}
                  {ticket.sla_state === 'QUA_HAN' && <Tag>Quá hạn</Tag>}
                  {ticket.sla_state === 'SAP_QUA_HAN' && <Tag>Sắp quá hạn</Tag>}
                </>
              }
            />
            <DetailField label="Kết quả" mode="view" value={ticket.resolution ?? ''} />
            {ticket.cancel_reason && (
              <DetailField label="Lý do huỷ" mode="view" value={ticket.cancel_reason} />
            )}
          </DetailSection>
        </div>
        {ticket.ticket_type === 'KN' && (
          <div className="mt-6">
            <DetailSection title="Riêng khiếu nại">
              <DetailField
                label="Mức nâng cấp"
                mode="view"
                value={
                  ticket.escalation_level === 'BAN_GIAM_DOC'
                    ? 'Ban giám đốc'
                    : ticket.escalation_level === 'QUAN_LY_CO_SO'
                      ? 'Quản lý cơ sở'
                      : 'Chưa nâng cấp'
                }
              />
              <DetailField
                label="Người bị khiếu nại"
                mode="view"
                value={ticket.accused_name ?? ''}
              />
              <DetailField
                label="Ngày xảy ra"
                mode="view"
                value={ticket.complaint_date ? formatDate(ticket.complaint_date) : ''}
              />
              <DetailField
                label="Mong muốn của khách"
                mode="view"
                value={ticket.customer_wish ?? ''}
              />
              <DetailField label="Nguyên nhân gốc" mode="view" value={ticket.root_cause ?? ''} />
              <DetailField label="Bồi hoàn" mode="view" value={ticket.compensation_note ?? ''} />
              <DetailField
                label="Mức hài lòng 1–5"
                hint="bắt buộc khi đóng"
                mode="view"
                value={ticket.satisfaction ?? ''}
              />
            </DetailSection>
            {canEdit && !closed && (
              <Button className="mt-2" onClick={openComplaint}>
                Sửa phần riêng
              </Button>
            )}
          </div>
        )}
        {(record.data?.tasks.length ?? 0) > 0 && (
          <div className="mt-6">
            <DetailSection title={`Phiếu nghiệp vụ (${record.data?.tasks.length ?? 0})`}>
              <ul className="flex flex-col gap-1">
                {record.data?.tasks.map((k) => (
                  <li key={k.id}>
                    <FromLink className="text-link underline" to={`/crm/phieu-nghiep-vu/${k.id}`}>
                      {k.code}
                    </FromLink>{' '}
                    {TASK_TYPE_LABEL[k.task_type] ?? k.task_type} ·{' '}
                    {TASK_STATUS_LABEL[k.status_code] ?? k.status_code}
                  </li>
                ))}
              </ul>
            </DetailSection>
          </div>
        )}
        {(record.data?.children.length ?? 0) > 0 && (
          <div className="mt-6">
            <DetailSection title={`Ticket liên quan (${record.data?.children.length ?? 0})`}>
              <ul className="flex flex-col gap-1">
                {record.data?.children.map((c) => (
                  <li key={c.id}>
                    <FromLink className="text-link underline" to={`/crm/ticket/${c.id}`}>
                      {c.code}
                    </FromLink>{' '}
                    {c.category_name} · {statusName(c.status_code)} ·{' '}
                    {c.assignee_name ?? 'Chưa giao'}
                  </li>
                ))}
              </ul>
              <p className="text-caption text-fg-muted">
                Đóng khiếu nại không tự đóng ticket con, và ngược lại.
              </p>
            </DetailSection>
          </div>
        )}
      </RecordDetail>
      {(ticket.business_type === 'BAO_LUU' ||
        ticket.business_type === 'CHUYEN_LOP' ||
        ticket.business_type === 'DUNG_HOC' ||
        ticket.business_type === 'CHUYEN_PHI' ||
        ticket.business_type === 'HOAN_PHI') && (
        <BusinessTaskDialog
          type={ticket.business_type}
          ticketId={ticket.id}
          ticketCode={ticket.code}
          ticketBranchId={ticket.branch_id}
          hasStudent={ticket.student_name !== null}
          open={taskOpen}
          onOpenChange={setTaskOpen}
          busy={busy}
          error={error}
          onCreate={(reason, payload) => void createBusinessTask(reason, payload)}
        />
      )}
      <FormDialog
        open={taskOpen && ticket.business_type === 'CAP_NHAT_HO_SO'}
        onOpenChange={setTaskOpen}
        title="Tạo phiếu Cập nhật hồ sơ"
        subtitle={ticket.code}
        confirmLabel="Tạo phiếu"
        canSubmit={
          !taskShow ||
          Object.keys(
            validateTaskDraft(taskDraft, taskFields.data ?? [], ticket.student_name !== null),
          ).length === 0
        }
        busy={busy}
        error={error}
        onSubmit={() => void submitTask()}
      >
        <OptionalSelect
          label="Hồ sơ cần sửa"
          value={taskDraft.entity}
          onChange={(v) =>
            setTaskDraft((d) => ({ ...d, entity: v === 'PARENT' ? 'PARENT' : 'STUDENT' }))
          }
          options={[
            { value: 'STUDENT', label: 'Học sinh' },
            { value: 'PARENT', label: 'Phụ huynh' },
          ]}
          placeholder="Chọn hồ sơ"
        />
        {(taskFields.data ?? [])
          .filter((f) => f.entity === taskDraft.entity)
          .map((f) => (
            <label key={f.field_code} className="flex flex-col gap-1">
              <span className="text-caption font-semibold text-fg-label">
                {f.label} (giá trị mới)
              </span>
              <input
                aria-label={f.label}
                value={taskDraft.values[f.field_code] ?? ''}
                onChange={(e) =>
                  setTaskDraft((d) => ({
                    ...d,
                    values: { ...d.values, [f.field_code]: e.target.value },
                  }))
                }
                className={INPUT_CLASS}
              />
            </label>
          ))}
        {taskShow &&
          validateTaskDraft(taskDraft, taskFields.data ?? [], ticket.student_name !== null)
            .values && (
            <p className="text-caption text-on-danger-subtle">
              {
                validateTaskDraft(taskDraft, taskFields.data ?? [], ticket.student_name !== null)
                  .values
              }
            </p>
          )}
        <TextAreaField
          label="Lý do"
          required
          value={taskDraft.reason}
          error={
            taskShow
              ? validateTaskDraft(taskDraft, taskFields.data ?? [], ticket.student_name !== null)
                  .reason
              : null
          }
          onChange={(e) => setTaskDraft((d) => ({ ...d, reason: e.target.value }))}
        />
        <p className="text-caption text-fg-muted">
          Ô để trống là giữ nguyên. Phiếu tạo ở bước Nháp; trình duyệt ở màn Phiếu nghiệp vụ.
        </p>
      </FormDialog>
      {ticket.business_type === 'DOI_LICH' && (
        <ScheduleTaskDialog
          ticketId={ticket.id}
          ticketCode={ticket.code}
          hasStudent={ticket.student_name !== null}
          open={taskOpen}
          onOpenChange={setTaskOpen}
          busy={busy}
          error={error}
          onCreate={(reason, payload) => void createBusinessTask(reason, payload)}
        />
      )}
      <FormDialog
        open={escalateOpen}
        onOpenChange={setEscalateOpen}
        title="Nâng cấp khiếu nại"
        subtitle={ticket.code}
        confirmLabel={`Nâng cấp lên ${nextEscalation}`}
        canSubmit={escalateReason.trim() !== ''}
        busy={busy}
        error={error}
        onSubmit={() => void submitEscalate()}
      >
        <p className="text-caption text-fg-muted">
          {ticket.escalation_level === 'QUAN_LY_CO_SO'
            ? 'Khiếu nại đang ở Quản lý cơ sở. Nâng cấp sẽ chuyển lên Ban giám đốc.'
            : 'Khiếu nại sẽ được nâng cấp lên Quản lý cơ sở. Nâng thêm một mức nữa là Ban giám đốc.'}
        </p>
        <TextAreaField
          label="Lý do nâng cấp"
          required
          value={escalateReason}
          onChange={(e) => setEscalateReason(e.target.value)}
        />
      </FormDialog>
      <FormDialog
        open={reclassOpen}
        onOpenChange={setReclassOpen}
        title="Phân loại lại ticket"
        subtitle={ticket.code}
        confirmLabel="Lưu"
        canSubmit={reclass.category !== ''}
        busy={busy}
        error={error}
        onSubmit={() => void submitReclass()}
      >
        <OptionalSelect
          label="Loại"
          value={reclass.type}
          onChange={(v) => setReclass((r) => ({ ...r, type: v, group: '', category: '' }))}
          options={
            ['DN', 'KN'].includes(ticket.ticket_type) &&
            ['MOI', 'DA_GIAO'].includes(ticket.status_code)
              ? [
                  { value: 'DN', label: 'Đề nghị' },
                  { value: 'KN', label: 'Khiếu nại' },
                ]
              : [{ value: ticket.ticket_type, label: TYPE_NAME[ticket.ticket_type] }]
          }
          placeholder="Chọn loại"
        />
        <OptionalSelect
          label="Nhóm"
          value={reclass.group}
          onChange={(v) => setReclass((r) => ({ ...r, group: v, category: '' }))}
          options={groupsOf(categories.data ?? [], reclass.type).map((c) => ({
            value: c.code,
            label: c.name,
          }))}
          placeholder="Chọn nhóm"
        />
        <OptionalSelect
          label="Nhóm con"
          value={reclass.category}
          onChange={(v) => setReclass((r) => ({ ...r, category: v }))}
          options={subgroupsOf(categories.data ?? [], reclass.group).map((c) => ({
            value: c.code,
            label: c.name,
          }))}
          placeholder="Chọn nhóm con"
          disabled={reclass.group === ''}
        />
        <OptionalSelect
          label="Mức độ"
          value={reclass.priority}
          onChange={(v) => setReclass((r) => ({ ...r, priority: v }))}
          options={catalogs.options('TICKET_PRIORITY', ticket.priority_code)}
          placeholder="Chọn mức độ"
        />
        <p className="text-caption text-fg-muted">
          Đổi mức độ hoặc nhóm con thì hạn tính lại từ lúc tạo. Đổi loại đặt lại mức độ theo nhóm
          con mới.
        </p>
      </FormDialog>
      <FormDialog
        open={complaintOpen}
        onOpenChange={setComplaintOpen}
        title="Riêng khiếu nại"
        subtitle={ticket.code}
        confirmLabel="Lưu"
        canSubmit
        busy={busy}
        error={error}
        onSubmit={() => void submitComplaint()}
      >
        <OptionalSelect
          label="Người bị khiếu nại"
          value={complaint.accused}
          onChange={(v) => setComplaint((c) => ({ ...c, accused: v }))}
          options={(assignees.data ?? []).map((p) => ({ value: p.id, label: p.display_name }))}
          placeholder={assignees.isPending ? 'Đang tải…' : 'Chưa chọn'}
        />
        <label className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label">Ngày xảy ra</span>
          <input
            type="date"
            value={complaint.date}
            onChange={(e) => setComplaint((c) => ({ ...c, date: e.target.value }))}
            className={INPUT_CLASS}
          />
        </label>
        <TextAreaField
          label="Mong muốn của khách"
          value={complaint.wish}
          onChange={(e) => setComplaint((c) => ({ ...c, wish: e.target.value }))}
        />
        <TextAreaField
          label="Nguyên nhân gốc"
          value={complaint.cause}
          onChange={(e) => setComplaint((c) => ({ ...c, cause: e.target.value }))}
        />
        <TextAreaField
          label="Bồi hoàn"
          help="Ghi bằng chữ; không nhập số tiền, ticket không tự sinh phiếu chi."
          value={complaint.compensation}
          onChange={(e) => setComplaint((c) => ({ ...c, compensation: e.target.value }))}
        />
      </FormDialog>
      <FormDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        title="Giao ticket"
        subtitle={ticket.code}
        confirmLabel="Giao"
        canSubmit={team !== '' && assignee !== ''}
        busy={busy}
        error={error}
        onSubmit={() => void submitAssign()}
      >
        <OptionalSelect
          label="Đội"
          value={team}
          onChange={setTeam}
          options={catalogs.options('TICKET_TEAM', ticket.team_code)}
          placeholder="Chưa chọn"
        />
        <OptionalSelect
          label="Người phụ trách"
          value={assignee}
          onChange={setAssignee}
          options={(assignees.data ?? []).map((p) => ({ value: p.id, label: p.display_name }))}
          placeholder={assignees.isPending ? 'Đang tải…' : 'Chưa giao'}
        />
      </FormDialog>
      <FormDialog
        open={target !== null}
        onOpenChange={(open) => !open && close()}
        title={dialogSpec.title ?? `Chuyển sang «${statusName(target)}»`}
        subtitle={ticket.code}
        confirmLabel={dialogSpec.confirmLabel}
        canSubmit={canSubmit}
        busy={busy}
        error={error}
        onSubmit={() => void submit()}
      >
        {dialogSpec.intro && <p className="text-body text-fg-muted">{dialogSpec.intro}</p>}
        {needResolution && (
          <TextAreaField
            label="Kết quả"
            required
            value={resolution}
            onChange={(e) => setResolution(e.target.value)}
          />
        )}
        {needSatisfaction && (
          <label className="flex flex-col gap-1">
            <span className="text-caption font-semibold text-fg-label">
              Mức hài lòng của phụ huynh (1 đến 5) *
            </span>
            <input
              type="number"
              min={1}
              max={5}
              value={satisfaction}
              onChange={(e) => setSatisfaction(e.target.value)}
              className={INPUT_CLASS}
            />
          </label>
        )}
        <TextAreaField
          label={dialogSpec.noteLabel}
          required={needNote}
          help={dialogSpec.hint}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </FormDialog>
    </>
  );
}
