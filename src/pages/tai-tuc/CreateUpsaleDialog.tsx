// TT-03 «Tạo phiếu tái tục thủ công» (khuôn K4 ③ FormDialog; canvas 9933 TT03_tao): nhập mã ghi danh của em trong lớp, hộp hiện học sinh, lớp; phiếu tạo theo (học sinh, lớp).
// Máy chủ kiểm quyền Tạo, học sinh đang học ở lớp, mỗi (học sinh, lớp) một phiếu mở; hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { TextField } from '../../ui/Field';
import { createUpsaleFromEnrollment, useUpsalePreview } from './useUpsaleData';

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreated: (code: string) => void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function CreateUpsaleDialog(props: Props) {
  return props.open ? <CreateForm {...props} /> : null;
}

function CreateForm({ open, onOpenChange, onCreated }: Props) {
  const supabase = useDb();
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const preview = useUpsalePreview(code);
  const found = preview.data?.found === true && code.trim().length >= 3; // allow-number: khớp ngưỡng tra mã ở useUpsalePreview
  const open_ticket = preview.data?.open_ticket_code ?? null;

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const created = await createUpsaleFromEnrollment(supabase, code);
      onCreated(created.code);
      onOpenChange(false);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const help = preview.isError
    ? errorOf(preview.error).message
    : code.trim().length < 3 // allow-number: khớp ngưỡng tra mã ở useUpsalePreview
      ? 'Phiếu tạo theo (học sinh, lớp): nhập mã của bất kỳ ghi danh nào của em trong lớp đó.'
      : preview.isPending
        ? 'Đang tra mã…'
        : preview.data?.found
          ? `${preview.data.student_name ?? ''} · ${preview.data.class_code ?? ''} · ${preview.data.enrollment_count ?? 0} ghi danh${open_ticket ? ` · đã có phiếu ${open_ticket}` : ''}`
          : 'Không tìm thấy ghi danh đang học với mã này.';

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Tạo phiếu tái tục thủ công"
      confirmLabel="Tạo"
      cancelLabel="Đóng"
      canSubmit={found && open_ticket === null}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <TextField
        label="Mã ghi danh của học sinh"
        required
        value={code}
        onChange={(e) => setCode(e.target.value)}
        help={help}
        placeholder="Nhập mã ghi danh"
      />
    </FormDialog>
  );
}
