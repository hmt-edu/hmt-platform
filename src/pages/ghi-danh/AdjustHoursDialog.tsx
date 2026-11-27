// GD-05 Điều chỉnh giờ (hộp thoại K08): thêm một dòng điều chỉnh vào sổ giờ, giờ khác 0 (dương thêm, âm bớt), bắt buộc lý do (danh mục "Lý do điều chỉnh giờ"),
// ghi chú bắt buộc khi lý do "Khác". Sổ giờ chỉ thêm dòng, không sửa dòng cũ (R-GD-04); không để quỹ âm khi bớt (R-GD-18). Luật do máy chủ quyết
// (app.adjust_enrollment_hours); Ghi danh · Duyệt (Trưởng cơ sở, Admin) hoặc Kế toán · Duyệt (Kế toán). Canvas 9933 (GD05_dieu_chinh) vẽ thêm nút Cộng giờ/Trừ giờ, nút «Xác nhận»; code giữ ô số có dấu và nút «Thêm dòng điều chỉnh» (bài e2e hiện hành), vênh ghi trong docs/nghiep-vu/doi-chieu-ui-dao-tao.md.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { parseHours } from './enrollLogic';
import { useAdjustHours } from './useEnrollmentData';

export function AdjustHoursDialog({
  enrollmentId,
  remaining,
  open,
  onClose,
}: {
  enrollmentId: string;
  remaining: number;
  open: boolean;
  onClose: () => void;
}) {
  // Khoá theo lần mở để dựng lại trạng thái nhập, không dùng effect.
  return open ? <Body enrollmentId={enrollmentId} remaining={remaining} onClose={onClose} /> : null;
}

function Body({
  enrollmentId,
  remaining,
  onClose,
}: {
  enrollmentId: string;
  remaining: number;
  onClose: () => void;
}) {
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const adjust = useAdjustHours(enrollmentId);
  const [hoursText, setHoursText] = useState('');
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const hours = parseHours(hoursText);
  const needsNote = reason !== '' && catalogs.requiresNote('HOURS_ADJUST_REASON', reason);
  const canSubmit = hours !== null && reason !== '' && (!needsNote || note.trim() !== '');

  async function submit() {
    if (hours === null) return;
    setError(null);
    try {
      const balance = await adjust.mutateAsync({
        hours,
        reason,
        note: note.trim() === '' ? null : note.trim(),
      });
      toast({ tone: 'success', title: `Đã điều chỉnh giờ. Còn lại ${formatNumber(balance)} giờ` });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Điều chỉnh giờ"
      confirmLabel="Thêm dòng điều chỉnh"
      cancelLabel="Đóng"
      canSubmit={canSubmit}
      busy={adjust.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Quỹ giờ hiện còn <b>{formatNumber(remaining)} giờ</b>. Sổ giờ chỉ thêm dòng, không sửa
          dòng cũ: nhập số dương để thêm giờ, số âm để bớt giờ.
        </p>
        <TextField
          label="Số giờ (+ thêm, − bớt)"
          required
          inputMode="decimal"
          value={hoursText}
          onChange={(e) => setHoursText(e.target.value)}
        />
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
        <p className="text-caption text-fg-muted">
          Hệ thống ghi thêm <b>một dòng mới</b> vào sổ giờ (dòng ngược dấu), không sửa dòng cũ.
          {hours !== null && (
            <>
              {' '}
              Quỹ sau điều chỉnh: {formatNumber(remaining)} → {formatNumber(remaining + hours)} giờ.
            </>
          )}{' '}
          Muốn chuyển giờ sang ghi danh khác, tạo ticket Đề nghị nhóm “Chuyển phí”.
        </p>
      </div>
    </FormDialog>
  );
}
