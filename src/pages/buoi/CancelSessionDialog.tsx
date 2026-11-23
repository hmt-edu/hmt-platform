// BUOI-04 Huỷ buổi (hộp thoại K08): "Trung tâm huỷ (cả lớp nghỉ)" hoặc "Học sinh huỷ (lớp riêng)". Trung tâm huỷ: không tính phí, tự thêm một buổi vào cuối lịch
// (R-BUOI-06; xem trước ngày buổi thêm). Học sinh huỷ: chỉ lớp riêng, người huỷ chọn có/không tính phí, bắt buộc lý do (R-BUOI-07). Luật do máy chủ quyết.
// Lệch khung: chưa hiện dòng "Nhãn bài dời theo" của phần xem trước, vì buổi chưa có nhãn bài riêng (chỉ có bài bắt đầu của lớp).
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { cancelReasonOptions } from './sessionLogic';
import { useCancelPreview, useCancelSession } from './useSessionData';

type Who = 'TT' | 'HS';

export function CancelSessionDialog({
  sessionId,
  isPrivateClass,
  open,
  onClose,
}: {
  sessionId: string;
  /** Lớp riêng: mới có lựa chọn "Học sinh huỷ". */
  isPrivateClass: boolean;
  open: boolean;
  onClose: () => void;
}) {
  // Khoá theo lần mở để dựng lại trạng thái nhập, không dùng effect.
  return open ? (
    <Body sessionId={sessionId} isPrivateClass={isPrivateClass} onClose={onClose} />
  ) : null;
}

function Body({
  sessionId,
  isPrivateClass,
  onClose,
}: {
  sessionId: string;
  isPrivateClass: boolean;
  onClose: () => void;
}) {
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const cancel = useCancelSession(sessionId);
  const [who, setWho] = useState<Who>('TT');
  const [kind, setKind] = useState<'HUY_CO_PHI' | 'HUY_KHONG_PHI' | ''>('');
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const preview = useCancelPreview(sessionId, who === 'TT');
  const reasons = cancelReasonOptions(catalogs.options('SESSION_CANCEL_REASON'), who);
  const needsNote = reason !== '' && catalogs.requiresNote('SESSION_CANCEL_REASON', reason);
  const canSubmit =
    reason !== '' && (who === 'TT' || kind !== '') && (!needsNote || note.trim() !== '');

  async function submit() {
    setError(null);
    try {
      const res = await cancel.mutateAsync({
        kind: who === 'TT' ? null : kind,
        reason,
        note: note.trim() === '' ? null : note.trim(),
      });
      toast({ tone: 'success', title: 'Đã huỷ buổi' });
      void res;
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  const pick = (next: Who) => {
    setWho(next);
    setReason('');
  };
  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Huỷ buổi"
      confirmLabel="Xác nhận huỷ buổi"
      cancelLabel="Đóng"
      canSubmit={canSubmit}
      busy={cancel.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <div role="radiogroup" aria-label="Ai huỷ" className="flex flex-wrap gap-2">
          <Choice
            checked={who === 'TT'}
            onChange={() => pick('TT')}
            label="Trung tâm huỷ (cả lớp nghỉ)"
          />
          {isPrivateClass && (
            <Choice
              checked={who === 'HS'}
              onChange={() => pick('HS')}
              label="Học sinh huỷ (lớp riêng)"
            />
          )}
        </div>
        {who === 'TT' ? (
          <p className="text-body">
            Trung tâm huỷ: <b>không tính phí</b>. Hệ thống tự thêm một buổi vào cuối lịch.
          </p>
        ) : (
          <div role="radiogroup" aria-label="Tính phí" className="flex flex-wrap gap-2">
            <Choice
              checked={kind === 'HUY_CO_PHI'}
              onChange={() => setKind('HUY_CO_PHI')}
              label="Huỷ có tính phí (không bù)"
            />
            <Choice
              checked={kind === 'HUY_KHONG_PHI'}
              onChange={() => setKind('HUY_KHONG_PHI')}
              label="Huỷ không tính phí (xếp buổi bù)"
            />
          </div>
        )}
        <OptionalSelect
          label="Lý do huỷ"
          value={reason}
          onChange={setReason}
          options={reasons}
          placeholder="Chọn lý do"
        />
        {(who === 'HS' || needsNote) && (
          <TextAreaField
            label="Ghi chú"
            required={needsNote}
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        )}
        {who === 'TT' && preview.data?.added_date && (
          <div className="rounded-control border border-border p-3 text-body">
            <p className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Xem trước
            </p>
            <p>
              Buổi thêm vào cuối lịch: Buổi {preview.data.added_session_no ?? '—'} ·{' '}
              {formatDate(preview.data.added_date)}
            </p>
          </div>
        )}
        {who === 'HS' && (
          <p className="text-caption text-fg-muted">
            Người huỷ tự chọn có hay không tính phí. Không áp mốc giờ cố định. Huỷ không tính phí
            thì xếp buổi bù ở bước sau.
          </p>
        )}
      </div>
    </FormDialog>
  );
}

function Choice({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={checked}
      onClick={onChange}
      className={`focus-ring min-h-11 rounded-control border px-3 text-body ${
        checked
          ? 'border-border-strong bg-selected font-semibold text-on-selected'
          : 'border-border bg-surface hover:bg-hover'
      }`}
    >
      {label}
    </button>
  );
}
