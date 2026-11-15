// CSN-03 Chi tiết ticket (đề nghị, khiếu nại, giáo viên): thông tin chỉ đọc, thanh trạng thái 7 bước, ghi chú và dòng thời gian.
// Đổi trạng thái gọi app.change_ticket_status (luật AS-02 ở hàm DB; giao diện chỉ hỏi thêm ghi chú, kết quả, mức hài lòng).
// Giao ticket (chọn đội, người phụ trách) và tạo mới làm ở lát sau: danh sách người giao cần mở rộng hàm máy chủ.
import { useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { errorOf, FORBIDDEN_CODE, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Chatter } from '../../ui/Chatter';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Spinner, StateView } from '../../ui/Feedback';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { ticketTimeline } from './ticketTimeline';
import { addTicketNote, changeTicketStatus, useTicketRecord } from './useTicketData';

const TYPE_NAME = { DN: 'Đề nghị', KN: 'Khiếu nại', GV: 'Ticket giáo viên' } as const;

export function TicketRecordPage() {
  const { id } = useParams();
  const supabase = useDb();
  const access = useAccess();
  const toast = useToast();
  const queryClient = useQueryClient();
  const catalogs = useLeadCatalogs();
  const record = useTicketRecord(id);
  const [target, setTarget] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [resolution, setResolution] = useState('');
  const [satisfaction, setSatisfaction] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const ticket = record.data?.ticket;
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
  if (record.isError || !ticket) {
    const forbidden = record.error ? errorOf(record.error).code === FORBIDDEN_CODE : false;
    const missing = record.error ? errorOf(record.error).code === 'HMT_KHONG_TIM_THAY' : false;
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem ticket này'
            : missing
              ? 'Không tìm thấy ticket'
              : 'Chưa tải được ticket'
        }
      />
    );
  }

  const canEdit = access.can('TICKET', 'SUA');
  const closed = ticket.status_code === 'DA_DONG' || ticket.status_code === 'DA_HUY';
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['ticket-record', id] });
  const needResolution = target === 'DA_XU_LY' && !ticket.resolution;
  const needSatisfaction = target === 'DA_DONG' && ticket.ticket_type === 'KN';
  const needNote = target === 'DA_HUY';
  const satisfactionValue = Number(satisfaction);
  const canSubmit =
    (!needResolution || resolution.trim() !== '') &&
    (!needNote || note.trim() !== '') &&
    (!needSatisfaction || (satisfactionValue >= 1 && satisfactionValue <= 5));

  const close = () => {
    setTarget(null);
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
        ...(note.trim() !== '' && { note: note.trim() }),
        ...(resolution.trim() !== '' && { resolution: resolution.trim() }),
        ...(needSatisfaction && { satisfaction: satisfactionValue }),
      });
      close();
      toast({ tone: 'success', title: 'Đã đổi trạng thái ticket.' });
      await refresh();
    } catch (cause) {
      setError(errorOf(cause).message);
    } finally {
      setBusy(false);
    }
  };

  const onStage = (step: StageStep) => {
    if (step.code === ticket.status_code) return;
    setTarget(step.code);
  };

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
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin ticket">
            <DetailField label="Mã" mode="view" value={ticket.code} />
            <DetailField label="Loại" mode="view" value={TYPE_NAME[ticket.ticket_type]} />
            <DetailField label="Tiêu đề" mode="view" value={ticket.title} />
            <DetailField label="Người gửi" mode="view" value={ticket.sender_name ?? ''} />
            <DetailField label="Học sinh" mode="view" value={ticket.student_name ?? ''} />
            <DetailField label="Nhóm" mode="view" value={ticket.category_name ?? ''} />
            <DetailField label="Mô tả" mode="view" value={ticket.description} />
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
      </RecordDetail>
      <FormDialog
        open={target !== null}
        onOpenChange={(open) => !open && close()}
        title={`Chuyển sang «${statusName(target)}»`}
        subtitle={ticket.code}
        confirmLabel="Chuyển"
        canSubmit={canSubmit}
        busy={busy}
        error={error}
        onSubmit={() => void submit()}
      >
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
          label={needNote ? 'Lý do huỷ' : 'Ghi chú'}
          required={needNote}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </FormDialog>
    </>
  );
}
