// BUOI-14 Sửa điểm danh sau khi buổi Done (hộp thoại K08): chọn em, trạng thái giáo viên mới, lý do (danh mục "Lý do điều chỉnh giờ"), ghi chú (bắt buộc khi lý do "Khác").
// Chỉ Điểm danh · Duyệt (Trưởng cơ sở, Admin). Đổi giữa các trạng thái đi học không đổi giờ trừ (R-GIO-07); luật do máy chủ quyết (app.correct_attendance_after_done).
// Chưa có khung riêng trong canvas (khung BUOI14_sua chỉ là bản ghi buổi Done có mục "Sửa điểm danh" ở Hành động): dựng theo khuôn K08, ghi vào PR "chưa có khung".
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import type { RecordStudent } from './sessionTypes';
import { useCorrectAttendance } from './useSessionData';

type Student = RecordStudent;

export function CorrectAttendanceDialog({
  sessionId,
  students,
  open,
  onClose,
}: {
  sessionId: string;
  students: Student[];
  open: boolean;
  onClose: () => void;
}) {
  // Khoá theo lần mở để dựng lại trạng thái nhập, không dùng effect.
  return open ? <Body sessionId={sessionId} students={students} onClose={onClose} /> : null;
}

function Body({
  sessionId,
  students,
  onClose,
}: {
  sessionId: string;
  students: Student[];
  onClose: () => void;
}) {
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const correct = useCorrectAttendance(sessionId);
  const [studentId, setStudentId] = useState('');
  const [status, setStatus] = useState('');
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const current = students.find((s) => s.student_id === studentId);
  const needsNote = reason !== '' && catalogs.requiresNote('HOURS_ADJUST_REASON', reason);
  const unchanged = current !== undefined && current.teacher_status_code === status;
  const canSubmit =
    studentId !== '' &&
    status !== '' &&
    reason !== '' &&
    !unchanged &&
    (!needsNote || note.trim() !== '');

  async function submit() {
    setError(null);
    try {
      await correct.mutateAsync({
        studentId,
        status,
        reason,
        note: note.trim() === '' ? null : note.trim(),
      });
      toast({ tone: 'success', title: 'Đã sửa điểm danh' });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Sửa điểm danh"
      confirmLabel="Lưu sửa điểm danh"
      cancelLabel="Đóng"
      canSubmit={canSubmit}
      busy={correct.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Buổi đã hoàn thành. Đổi giữa các trạng thái đi học không đổi giờ đã trừ. Bắt buộc ghi lý
          do.
        </p>
        <OptionalSelect
          label="Học sinh"
          value={studentId}
          onChange={(v) => {
            setStudentId(v);
            setStatus('');
          }}
          options={students.map((s) => ({
            value: s.student_id,
            label: `${s.full_name} · ${s.teacher_status_name ?? 'chưa điểm danh'}`,
          }))}
          placeholder="Chọn học sinh"
        />
        <OptionalSelect
          label="Trạng thái đúng"
          value={status}
          onChange={setStatus}
          options={catalogs.options('ATTENDANCE_STATUS')}
          placeholder="Chọn trạng thái"
        />
        {unchanged && (
          <p className="text-caption text-fg-muted">Trạng thái mới trùng trạng thái hiện tại.</p>
        )}
        <OptionalSelect
          label="Lý do"
          value={reason}
          onChange={setReason}
          options={catalogs.options('HOURS_ADJUST_REASON')}
          placeholder="Chọn lý do"
        />
        <TextAreaField
          label="Ghi chú"
          required={needsNote}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
