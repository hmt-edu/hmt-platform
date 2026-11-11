// BUOI-05 Dời một buổi (hộp thoại K08): đổi ngày, giờ, phòng; kiểm trùng phòng, giáo viên (chỉ cảnh báo, vẫn lưu được, R-LOP-08).
// Chỉ đổi cho buổi này, giáo viên và thời khoá biểu của lớp không đổi. Luật (buổi chưa Done, giờ hợp lệ) do máy chủ quyết.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { moveArgsOf } from './sessionLogic';
import type { SessionRecord } from './sessionTypes';
import { useMoveCheck, useMoveOptions, useMoveSession } from './useSessionData';

export function MoveSessionDialog({
  session,
  open,
  onClose,
}: {
  session: SessionRecord['session'];
  open: boolean;
  onClose: () => void;
}) {
  return open ? <Body session={session} onClose={onClose} /> : null;
}

function Body({ session, onClose }: { session: SessionRecord['session']; onClose: () => void }) {
  const toast = useToast();
  const options = useMoveOptions(session.id, true);
  const move = useMoveSession(session.id);
  const [date, setDate] = useState(session.session_date);
  const [start, setStart] = useState(session.start_time);
  const [end, setEnd] = useState(session.end_time);
  const [room, setRoom] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const roomId = room ?? options.data?.current_room_id ?? null;
  const args = moveArgsOf(date, start, end, roomId);
  const check = useMoveCheck(session.id, args);
  const clashes = [...(check.data?.room_clash ?? []), ...(check.data?.teacher_clash ?? [])];

  async function submit() {
    if (!args) return;
    setError(null);
    try {
      await move.mutateAsync(args);
      toast({ tone: 'success', title: 'Đã dời buổi' });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Dời buổi"
      subtitle={`${session.class_code} · Buổi ${session.session_no ?? '—'}`}
      confirmLabel="Xác nhận"
      cancelLabel="Đóng"
      canSubmit={args !== null}
      busy={move.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <TextField
          label="Ngày mới"
          type="date"
          required
          value={date}
          onChange={(e) => setDate(e.target.value)}
        />
        <div className="grid grid-cols-2 gap-3">
          <TextField
            label="Giờ bắt đầu"
            type="time"
            required
            value={start}
            onChange={(e) => setStart(e.target.value)}
          />
          <TextField
            label="Giờ kết thúc"
            type="time"
            required
            value={end}
            onChange={(e) => setEnd(e.target.value)}
          />
        </div>
        <OptionalSelect
          label="Phòng"
          value={roomId ?? ''}
          onChange={(v) => setRoom(v === '' ? null : v)}
          options={(options.data?.rooms ?? []).map((r) => ({ value: r.id, label: r.code }))}
          placeholder="Giữ phòng hiện tại"
        />
        <div aria-live="polite" className="flex flex-col gap-2">
          {clashes.map((c) => (
            <Alert key={c} tone="warning">
              {c}. Chỉ cảnh báo, vẫn lưu được (R-LOP-08).
            </Alert>
          ))}
        </div>
        <p className="text-caption text-fg-muted">
          Chỉ đổi cho buổi này, giáo viên và thời khoá biểu của lớp không đổi. Muốn đổi cho cả lớp,
          sửa thời khoá biểu ở bản ghi lớp.
        </p>
      </div>
    </FormDialog>
  );
}
