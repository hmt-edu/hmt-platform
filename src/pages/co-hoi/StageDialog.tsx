// TS-09 Hộp chuyển giai đoạn cơ hội (bản vẽ TS09, TS09a đến TS09d): một hộp, năm dạng theo luật:
//  bình thường (nhóm con tuỳ chọn, ghi chú) · chặn vì còn phiếu dang dở (R-CRM-12) · bỏ qua test, bắt lý do (R-CRM-14) ·
//  L8 chọn nhóm con và xác nhận không hoàn tác (R-CRM-16) · chặn vì thiếu tên, năm sinh học sinh (R-CRM-03).
// Hàm cơ sở dữ liệu kiểm lại mọi luật; hộp chỉ chọn đúng dạng (planStageChange) và gom đủ thông tin trước khi gọi.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { Checkbox, Field, TextAreaField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { codeAndName } from '../lead/leadFormat';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { substageChoicesForMove, type StagePlan } from './oppStage';
import type { OppTest } from './oppTypes';

type Option = { value: string; label: string };

export type StageSubmit = {
  substage: string | null;
  skipReason: string | null;
  /** Ghi chú: bỏ qua test thì là ghi chú của lý do bỏ qua (R-CRM-14); còn lại là ghi chú gắn vào cơ hội. */
  note: string;
  confirmL8: boolean;
};

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** "CO000124 · Anh Phạm Văn Tú · đang ở L5 Đồng ý tham gia test". */
  subtitle: string;
  target: string;
  plan: StagePlan;
  catalogs: LeadCatalogs;
  /** Phiếu Hoàn thành gần nhất (dạng bình thường L7, L8: dòng xanh "Phiếu … đã Hoàn thành"). */
  lastCompleted: OppTest | null;
  /** Đóng hộp, mở chế độ Sửa tại ô còn thiếu (dạng thiếu thông tin học sinh). */
  onFillMissing: () => void;
  /** Mở trang phiếu kiểm tra đang dở (dạng chặn vì còn phiếu dang dở, R-CRM-12). */
  onOpenTest: (testId: string) => void;
  onSubmit: (data: StageSubmit) => Promise<void>;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function StageDialog(props: Props) {
  return props.open ? <StageForm {...props} /> : null;
}

const FOOTNOTE =
  'Giai đoạn đã qua bị khoá, cơ hội chỉ đi tới, không có Hoàn tác. L6 do hệ thống tự đổi. L8 chọn tay sau khi đã thu tiền.';

function StageForm({
  onOpenChange,
  subtitle,
  target,
  plan,
  catalogs,
  lastCompleted,
  onFillMissing,
  onOpenTest,
  onSubmit,
}: Props) {
  const [substage, setSubstage] = useState('');
  const [skipReason, setSkipReason] = useState('');
  const [note, setNote] = useState('');
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const blocked = plan.kind === 'blocked-student' || plan.kind === 'blocked-tests';
  const needsSkip = plan.kind === 'skip-test';
  const needsL8 = plan.kind === 'l8' || (plan.kind === 'skip-test' && plan.l8);

  const codes = catalogs.childrenOf('OPP_SUBSTAGE', 'OPP_STAGE', target).map((o) => o.value);
  const substageOptions: Option[] = substageChoicesForMove(target, codes).map((code) => ({
    value: code,
    label: codeAndName(code, catalogs.name('OPP_SUBSTAGE', code)),
  }));
  const skipOptions = catalogs.options('TEST_SKIP_REASON');
  const noteRequired = needsSkip && catalogs.requiresNote('TEST_SKIP_REASON', skipReason);
  const stageName = codeAndName(target, catalogs.name('OPP_STAGE', target));

  const canSubmit =
    !blocked &&
    (!needsSkip || skipReason !== '') &&
    (!noteRequired || note.trim() !== '') &&
    (!needsL8 || (substage !== '' && confirm));

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await onSubmit({
        substage: substage === '' ? null : substage,
        skipReason: needsSkip ? skipReason : null,
        note,
        confirmL8: needsL8 ? confirm : false,
      });
      onOpenChange(false);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title={`Chuyển sang ${stageName}`}
      subtitle={subtitle}
      confirmLabel={needsL8 ? 'Chuyển L8' : 'Chuyển giai đoạn'}
      canSubmit={canSubmit}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        {plan.kind === 'blocked-student' && (
          <Alert tone="danger" title={`Chưa chuyển sang ${target} được. Từ L5 bắt buộc có:`}>
            <ul className="mt-1 list-disc pl-5">
              {plan.missing.map((m) => (
                <li key={m}>{m} (đang trống)</li>
              ))}
            </ul>
            <Button
              className="mt-2"
              size="sm"
              icon="arrowRight"
              onClick={() => {
                onOpenChange(false);
                onFillMissing();
              }}
            >
              Đi tới ô cần điền
            </Button>
          </Alert>
        )}
        {plan.kind === 'blocked-tests' && (
          <Alert
            tone="danger"
            title={`Chưa chuyển sang ${target} được. Cơ hội còn phiếu Test đang dở:`}
          >
            <ul className="mt-1 list-disc pl-5">
              {plan.tests.length > 0
                ? plan.tests.map((t) => (
                    <li key={t.id}>
                      {t.code} · {t.status ?? t.status_code}
                      {t.subject ? ` · ${t.subject}` : ''} · {formatDateTime(t.scheduled_at)} ·{' '}
                      {t.test_branch_code}
                    </li>
                  ))
                : plan.codes.map((c) => <li key={c}>{c}</li>)}
            </ul>
            <p className="mt-1">Hoàn thành phiếu, hoặc Huỷ phiếu, rồi chuyển lại.</p>
            {plan.tests[0] && (
              <Button
                className="mt-2"
                size="sm"
                icon="arrowRight"
                onClick={() => {
                  onOpenChange(false);
                  onOpenTest(plan.tests[0]?.id ?? '');
                }}
              >
                Mở phiếu {plan.tests[0].code}
              </Button>
            )}
          </Alert>
        )}
        {plan.kind === 'skip-test' && (
          <Alert tone="warning">
            Cơ hội chưa có phiếu Test (hoặc mọi phiếu đều Huỷ). Chọn lý do bỏ qua test để chuyển
            tiếp.
          </Alert>
        )}
        {plan.kind === 'normal' && lastCompleted && (target === 'L7' || target === 'L8') && (
          <Alert tone="success">
            Phiếu {lastCompleted.code} đã Hoàn thành
            {lastCompleted.score !== null
              ? ` (điểm ${String(lastCompleted.score).replace('.', ',')}/10)`
              : ''}
            . Cơ hội không còn phiếu dang dở nên chuyển được sang {target}.
          </Alert>
        )}

        {needsSkip && (
          <Field
            label="Lý do bỏ qua test"
            required
            help={`Áp dụng khi chuyển sang L7 hoặc L8. Lý do được ghi vào lịch sử cơ hội.`}
          >
            {(field) => (
              <Select
                id={field.id}
                label="Lý do bỏ qua test"
                value={skipReason}
                onChange={setSkipReason}
                options={skipOptions}
                placeholder="Chọn lý do…"
                className="w-full"
              />
            )}
          </Field>
        )}

        {plan.kind === 'blocked-tests' && (
          <p className="text-caption text-fg-muted">
            Chặn khi chuyển sang L7 hoặc L8 mà cơ hội còn phiếu ở trạng thái Nháp, Đang test hoặc
            Chờ giáo viên chấm. Mỗi phiếu dang dở được nêu mã.
          </p>
        )}

        {plan.kind !== 'blocked-tests' && (substageOptions.length > 0 || needsL8) && (
          <Field
            label="Sub-stage"
            required={needsL8}
            help={
              needsL8
                ? 'Bắt buộc khi chuyển sang L8.'
                : `Chọn khi chuyển sang ${target}. Có thể để trống.`
            }
          >
            {(field) => (
              <Select
                id={field.id}
                label="Sub-stage"
                value={substage}
                onChange={setSubstage}
                options={substageOptions}
                placeholder={needsL8 ? 'Chọn L8A, L8B hoặc L8C…' : `Chọn sub-stage ${target}…`}
                disabled={blocked}
                className="w-full"
              />
            )}
          </Field>
        )}

        {needsL8 && (
          <>
            <Alert tone="warning">
              <b>Chuyển L8 không hoàn tác được.</b> Sau khi chuyển, cơ hội không quay lại L7 và
              không có thanh Hoàn tác.
            </Alert>
            <Checkbox
              label="Tôi xác nhận: Chuyển L8 không hoàn tác được"
              checked={confirm}
              onChange={(e) => setConfirm(e.target.checked)}
            />
          </>
        )}

        {plan.kind !== 'blocked-tests' && (
          <TextAreaField
            label="Ghi chú"
            required={noteRequired}
            value={note}
            disabled={blocked}
            onChange={(e) => setNote(e.target.value)}
            placeholder={
              needsSkip
                ? 'Ví dụ: đã test ở trung tâm khác, điểm 8/10'
                : 'Ví dụ: PH đồng ý cho con test tối thứ 5'
            }
            help={noteRequired ? 'Bắt buộc khi chọn "Khác".' : undefined}
          />
        )}
        <p className="text-caption text-fg-muted">{FOOTNOTE}</p>
      </div>
    </FormDialog>
  );
}
