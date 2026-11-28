// Hai ô ghi trên dòng của màn «Điểm danh»: «Vận hành» (bấm là tự lưu, không xoá về trống, R-DD-05) và «Liên hệ phụ huynh» (R-DD-03).
// Buổi đã Done thì khoá. Quyền và khoá do máy chủ quyết; ô chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { shortStatus } from './attendanceLogic';
import type { BoardRow } from './attendanceTypes';
import { useSaveOpsEntry } from './useAttendanceData';

export type Option = { value: string; label: string };

export function OpsCell({
  row,
  statuses,
  canEdit,
}: {
  row: BoardRow;
  statuses: Option[];
  canEdit: boolean;
}) {
  const toast = useToast();
  const save = useSaveOpsEntry();
  return (
    <div className="flex flex-col gap-1">
      <div
        role="group"
        aria-label={`Điểm danh ${row.student_name}`}
        className="flex flex-nowrap gap-1"
      >
        {statuses.map((s) => (
          <Button
            key={s.value}
            variant={row.ops_status_code === s.value ? 'primary' : 'secondary'}
            aria-pressed={row.ops_status_code === s.value}
            aria-label={s.label}
            title={s.label}
            disabled={!canEdit || row.locked || save.isPending}
            onClick={() => {
              if (row.ops_status_code === s.value) return;
              save.mutate(
                {
                  sessionId: row.session_id,
                  entry: { student_id: row.student_id, status_code: s.value },
                },
                { onError: (e) => toast({ tone: 'danger', title: errorOf(e).message }) },
              );
            }}
          >
            {shortStatus(s.value, s.label)}
          </Button>
        ))}
      </div>
      {row.locked && (
        <span>
          <Tag tone="info">Đã Done · khoá</Tag>
        </span>
      )}
    </div>
  );
}

export function ContactCell({
  row,
  reasons,
  canEdit,
}: {
  row: BoardRow;
  reasons: Option[];
  canEdit: boolean;
}) {
  const toast = useToast();
  const save = useSaveOpsEntry();
  const [reason, setReason] = useState(row.contact_reason_code ?? '');
  const [note, setNote] = useState(row.ops_note ?? '');
  const changed = reason !== (row.contact_reason_code ?? '') || note !== (row.ops_note ?? '');

  if (!canEdit || row.locked)
    return (
      <span>{[row.contact_reason_name, row.ops_note].filter(Boolean).join(' · ') || '—'}</span>
    );

  return (
    <div className="flex min-w-52 flex-col gap-1">
      <OptionalSelect
        label={`Lý do liên hệ ${row.student_name}`}
        value={reason}
        onChange={setReason}
        options={reasons}
        placeholder="Chưa chọn"
      />
      <TextField
        label="Ghi chú"
        aria-label={`Ghi chú ${row.student_name}`}
        value={note}
        onChange={(e) => setNote(e.target.value)}
      />
      {changed && (
        <Button
          loading={save.isPending}
          onClick={() =>
            save.mutate(
              {
                sessionId: row.session_id,
                entry: {
                  student_id: row.student_id,
                  contact_reason_code: reason,
                  note: note.trim(),
                },
              },
              {
                onSuccess: () => toast({ tone: 'success', title: 'Đã ghi liên hệ phụ huynh' }),
                onError: (e) => toast({ tone: 'danger', title: errorOf(e).message }),
              },
            )
          }
        >
          Lưu
        </Button>
      )}
    </div>
  );
}
