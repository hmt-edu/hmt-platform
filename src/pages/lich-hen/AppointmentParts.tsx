// Các phần dùng chung của màn Lịch hẹn: nút thao tác theo trạng thái và quyền (dòng, thẻ Kanban, khung chi tiết Lịch),
// liên kết hồ sơ gắn.
import { Link } from 'react-router';
import { Button } from '../../ui/Button';
import { Code } from '../../ui/Data';
import { RECORD_KIND_LABEL, recordKind, type AppointmentRow } from './appointmentTypes';

export type RowActions = {
  canEdit: boolean;
  canCancel: boolean;
  /** Lịch đang xử lý (khoá nút để không bấm hai lần). */
  busyId: string | null;
  onComplete: (row: AppointmentRow) => void;
  onReschedule: (row: AppointmentRow) => void;
  onCancel: (row: AppointmentRow) => void;
  onReopen: (row: AppointmentRow) => void;
};

/** Các nút thao tác của một lịch hẹn theo trạng thái và quyền (dùng chung cho dòng, thẻ Kanban, khung chi tiết Lịch). */
export function AppointmentButtons({
  row,
  actions,
  size = 'sm',
}: {
  row: AppointmentRow;
  actions: RowActions;
  size?: 'sm' | 'md';
}) {
  const busy = actions.busyId === row.id;
  if (row.status === 'CHUA_LAM') {
    return (
      <div className="flex flex-wrap gap-1.5">
        {actions.canEdit && (
          <>
            <Button
              size={size}
              icon="checkMark"
              loading={busy}
              onClick={() => actions.onComplete(row)}
            >
              Hoàn thành
            </Button>
            <Button
              size={size}
              icon="calendar"
              disabled={busy}
              onClick={() => actions.onReschedule(row)}
            >
              Dời
            </Button>
          </>
        )}
        {actions.canCancel && (
          <Button
            size={size}
            variant="danger"
            icon="close"
            disabled={busy}
            onClick={() => actions.onCancel(row)}
          >
            Huỷ
          </Button>
        )}
      </div>
    );
  }
  return actions.canEdit ? (
    <Button size={size} loading={busy} onClick={() => actions.onReopen(row)}>
      Mở lại
    </Button>
  ) : null;
}

/** "Lead LD000232" có liên kết sang bản ghi (lead); cơ hội, phiếu chưa có màn nên chỉ hiện mã. */
export function RecordLink({ row }: { row: AppointmentRow }) {
  const kind = recordKind(row);
  if (!row.record_code) return <span className="text-fg-muted">—</span>;
  return (
    <span className="inline-flex flex-wrap items-baseline gap-1.5">
      <span className="text-caption text-fg-muted">{RECORD_KIND_LABEL[kind]}</span>
      {kind === 'LEAD' && row.lead_id ? (
        <Link to={`/crm/lead/${row.lead_id}`} className="font-medium text-link hover:underline">
          {row.record_code}
        </Link>
      ) : kind === 'OPPORTUNITY' && row.opportunity_id ? (
        <Link
          to={`/crm/co-hoi/${row.opportunity_id}`}
          className="font-medium text-link hover:underline"
        >
          {row.record_code}
        </Link>
      ) : (
        <Code>{row.record_code}</Code>
      )}
    </span>
  );
}
