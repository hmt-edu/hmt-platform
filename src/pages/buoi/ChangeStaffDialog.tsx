// BUOI-13 Đổi giáo viên, trợ giảng cho một buổi (dạy thay, hộp thoại K08): chỉ buổi Nháp, Đã chốt. Giờ dạy tính cho người dạy thật (R-LOP-11); buổi thành "chỉnh lẻ tay"
// nên không bị sinh lại lịch ghi đè (R-LOP-10). Trùng giờ chỉ cảnh báo (R-LOP-08). Chưa có khung riêng trong canvas (khung BUOI13_doi_gv chỉ là bản ghi): dựng theo K08, ghi vào PR.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useClassFormOptions } from '../lop/useClassData';
import { useChangeSessionStaff } from './useSessionData';

export function ChangeStaffDialog({
  sessionId,
  branchId,
  teacherId,
  assistantId,
  open,
  onClose,
}: {
  sessionId: string;
  branchId: string;
  teacherId: string | null;
  assistantId: string | null;
  open: boolean;
  onClose: () => void;
}) {
  // Khoá theo lần mở để dựng lại trạng thái nhập, không dùng effect.
  return open ? (
    <Body
      sessionId={sessionId}
      branchId={branchId}
      teacherId={teacherId}
      assistantId={assistantId}
      onClose={onClose}
    />
  ) : null;
}

function Body({
  sessionId,
  branchId,
  teacherId,
  assistantId,
  onClose,
}: {
  sessionId: string;
  branchId: string;
  teacherId: string | null;
  assistantId: string | null;
  onClose: () => void;
}) {
  const toast = useToast();
  const options = useClassFormOptions(branchId);
  const change = useChangeSessionStaff(sessionId);
  const [teacher, setTeacher] = useState(teacherId ?? '');
  const [assistant, setAssistant] = useState(assistantId ?? '');
  const [error, setError] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<string[]>([]);
  const unchanged = teacher === (teacherId ?? '') && assistant === (assistantId ?? '');
  const toOption = (u: { id: string; name: string; staff_code: string | null }) => ({
    value: u.id,
    label: u.staff_code ? `${u.name} (${u.staff_code})` : u.name,
  });

  async function submit() {
    setError(null);
    try {
      const res = await change.mutateAsync({
        teacherId: teacher === '' ? null : teacher,
        assistantId: assistant === '' ? null : assistant,
      });
      toast({ tone: 'success', title: 'Đã đổi người dạy' });
      if (res.warnings.length > 0) {
        setWarnings(res.warnings);
        return;
      }
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Đổi giáo viên"
      confirmLabel="Lưu người dạy"
      cancelLabel="Đóng"
      canSubmit={!unchanged && warnings.length === 0}
      busy={change.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Chỉ đổi cho buổi này (dạy thay). Giờ dạy tính cho người dạy thật.
        </p>
        <OptionalSelect
          label="Giáo viên"
          value={teacher}
          onChange={setTeacher}
          options={(options.data?.teachers ?? []).map(toOption)}
          placeholder="Chưa có giáo viên"
        />
        <OptionalSelect
          label="Trợ giảng"
          value={assistant}
          onChange={setAssistant}
          options={(options.data?.assistants ?? []).map(toOption)}
          placeholder="Không có trợ giảng"
        />
        {warnings.length > 0 && (
          <Alert tone="warning">
            <b>Đã lưu, kèm cảnh báo:</b> {warnings.join(' ')} Bấm Đóng để xong.
          </Alert>
        )}
      </div>
    </FormDialog>
  );
}
