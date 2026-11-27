// BUOI-02 Nhập thay điểm danh giáo viên (hộp thoại K08, R-GIO-11): chọn trạng thái từng em (sẵn giá trị đang có), lý do bắt buộc.
// Chỉ gửi em đã đổi. Quyền và nhật ký do máy chủ (app.enter_for_teacher). Chưa có khung canvas: dựng theo khuôn K08.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import type { RecordStudent } from './sessionTypes';
import { useProxyAttendance } from './useSessionData';

type Props = { sessionId: string; students: RecordStudent[]; onClose: () => void };

export function ProxyAttendanceDialog({ open, ...props }: Props & { open: boolean }) {
  return open ? <Body {...props} /> : null;
}

function Body({ sessionId, students, onClose }: Props) {
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const proxy = useProxyAttendance(sessionId);
  const [picked, setPicked] = useState<Record<string, string>>({});
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const entries = students.flatMap((s) => {
    const next = picked[s.student_id];
    return next && next !== s.teacher_status_code
      ? [{ student_id: s.student_id, status_code: next }]
      : [];
  });

  async function submit() {
    setError(null);
    try {
      await proxy.mutateAsync({ entries, reason: reason.trim() });
      toast({ tone: 'success', title: 'Đã nhập thay điểm danh' });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Nhập thay điểm danh"
      confirmLabel="Lưu nhập thay"
      cancelLabel="Đóng"
      canSubmit={entries.length > 0 && reason.trim() !== ''}
      busy={proxy.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Ghi vào cột điểm danh giáo viên. Hệ thống lưu người nhập thay và lý do.
        </p>
        {students.map((s) => (
          <OptionalSelect
            key={s.student_id}
            label={s.full_name}
            value={picked[s.student_id] ?? s.teacher_status_code ?? ''}
            onChange={(v) => setPicked((p) => ({ ...p, [s.student_id]: v }))}
            options={catalogs.options('ATTENDANCE_STATUS')}
            placeholder="Chưa điểm danh"
          />
        ))}
        <TextAreaField
          label="Lý do"
          required
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
