// Tab «Cần gọi» (khung CanGoi): học sinh vắng, đi muộn hoặc chưa ai điểm danh cần gọi phụ huynh; ghi lý do liên hệ ngay trên dòng.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { rowKey } from './attendanceLogic';
import type { CallRow } from './attendanceTypes';
import { useSaveOpsEntry } from './useAttendanceData';

type Option = { value: string; label: string };

export function CallTab({
  rows,
  statuses,
  reasons,
}: {
  rows: CallRow[];
  statuses: Option[];
  reasons: Option[];
}) {
  if (rows.length === 0)
    return <p className="text-body text-fg-muted">Không có em nào cần gọi trong khoảng này.</p>;
  return (
    <div className="overflow-x-auto rounded-control border border-border">
      <table aria-label="Cần gọi" className="w-full text-body">
        <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
          <tr>
            {['Học sinh', 'Ngày', 'Lớp', 'Giờ', 'Tình trạng'].map((h) => (
              <th key={h} className="px-3 py-2">
                {h}
              </th>
            ))}
            <th className="px-3 py-2">Lý do liên hệ</th>
            <th className="px-3 py-2">Ghi chú</th>
            <th className="px-3 py-2">Gọi</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <Row key={rowKey(r)} row={r} statuses={statuses} reasons={reasons} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Row({ row, statuses, reasons }: { row: CallRow; statuses: Option[]; reasons: Option[] }) {
  const toast = useToast();
  const save = useSaveOpsEntry();
  const [reason, setReason] = useState(row.contact_reason_code ?? '');
  const [note, setNote] = useState(row.ops_note ?? '');
  const [error, setError] = useState<string | null>(null);
  const changed = reason !== (row.contact_reason_code ?? '') || note !== (row.ops_note ?? '');

  async function submit() {
    setError(null);
    try {
      await save.mutateAsync({
        sessionId: row.session_id,
        entry: { student_id: row.student_id, contact_reason_code: reason, note: note.trim() },
      });
      toast({ tone: 'success', title: 'Đã ghi lý do liên hệ' });
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <tr className="border-t border-border align-top">
      <td className="px-3 py-2">{row.student_name}</td>
      <td className="px-3 py-2">{formatDate(row.session_date)}</td>
      <td className="px-3 py-2">{row.class_code}</td>
      <td className="px-3 py-2">{row.start_time}</td>
      <td className="px-3 py-2">
        {statuses.find((s) => s.value === row.status_code)?.label ?? 'Chưa điểm danh'}
      </td>
      <td className="min-w-44 px-3 py-2">
        <OptionalSelect
          label="Lý do liên hệ"
          value={reason}
          onChange={setReason}
          options={reasons}
          placeholder="Chưa chọn"
          disabled={row.locked}
        />
      </td>
      <td className="min-w-52 px-3 py-2">
        <div className="flex items-end gap-2">
          <TextField
            label="Ghi chú"
            value={note}
            disabled={row.locked}
            onChange={(e) => setNote(e.target.value)}
          />
          <Button
            loading={save.isPending}
            disabled={row.locked || !changed}
            onClick={() => void submit()}
          >
            Lưu
          </Button>
        </div>
        {error && <Alert tone="danger">{error}</Alert>}
      </td>
      <td className="tabular px-3 py-2">
        {row.parent_phone ? (
          <a href={`tel:${row.parent_phone}`} className="focus-ring text-link">
            {row.parent_phone}
          </a>
        ) : (
          <span className="text-fg-muted">—</span>
        )}
      </td>
    </tr>
  );
}
