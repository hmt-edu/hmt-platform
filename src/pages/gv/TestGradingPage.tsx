// GV-15 Chấm kiểm tra đầu vào (cổng giáo viên, bản tối giản; R-CRM-10, R-CRM-11, R-GV-08, R-GV-13). Một lần gọi đọc phiếu (teacher_test_sheet,
// không có điện thoại, phụ huynh). Lưu = lưu nháp (phiếu vẫn Chờ giáo viên chấm); Trả về sale = nộp kết quả, phiếu Hoàn thành (QĐ-Đ25).
// Phiếu Hoàn thành chỉ xem; sửa sau đó do người phụ trách làm bên CRM (R-CRM-21). Ô «Lớp đề xuất» của canvas chưa làm: bảng phiếu chưa có cột (CauHoiMo).
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { errorOf, FORBIDDEN_CODE } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { StickyActionBar } from '../../ui/StickyActionBar';
import { Button, ButtonLink } from '../../ui/Button';
import { UnsavedGuard } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Field, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { Tag } from '../../ui/Data';
import { cn } from '../../ui/cn';
import { useToast } from '../../ui/toastContext';
import {
  draftErrors,
  initialTestDraft,
  isTestDirty,
  isTestEditable,
  parseTestScore,
  submitErrors,
  type TestDraft,
  type TestErrors,
  type TestSheet,
} from './testGrading';
import { useSaveTest, useTestSheet } from './useTestGrading';

export function TestGradingPage() {
  const { testId } = useParams();
  const query = useTestSheet(testId);
  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const error = errorOf(query.error);
    const forbidden = error.code === FORBIDDEN_CODE;
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'error'}
        title={forbidden ? 'Bạn không xem được mục này' : 'Không mở được phiếu kiểm tra'}
        actions={
          forbidden ? (
            <ButtonLink to="/gv" variant="primary">
              Về trang Hôm nay
            </ButtonLink>
          ) : (
            <Button variant="primary" onClick={() => void query.refetch()}>
              Thử lại
            </Button>
          )
        }
      >
        {forbidden ? 'Giáo viên chỉ thấy phiếu kiểm tra được giao cho mình chấm.' : error.message}
      </StateView>
    );
  }
  return <TestForm key={query.data.test.id} sheet={query.data} />;
}

function TestForm({ sheet }: { sheet: TestSheet }) {
  const toast = useToast();
  const t = sheet.test;
  const save = useSaveTest(t.id);
  const [draft, setDraft] = useState<TestDraft>(() => initialTestDraft(t));
  const [errors, setErrors] = useState<TestErrors>({});
  const [saveError, setSaveError] = useState<string | null>(null);
  const editable = isTestEditable(t);
  const dirty = editable && isTestDirty(t, draft);
  const patch = (next: Partial<TestDraft>) => setDraft((d) => ({ ...d, ...next }));

  function run(submit: boolean) {
    const found = submit ? submitErrors(draft) : draftErrors(draft);
    setErrors(found);
    if (Object.keys(found).length > 0) return;
    setSaveError(null);
    save.mutate(
      {
        submit,
        score: parseTestScore(draft.score).value,
        note: draft.note.trim(),
        level: draft.level || null,
        framework: draft.framework || null,
      },
      {
        onSuccess: () =>
          toast({
            tone: 'success',
            title: submit ? 'Đã trả kết quả về sale' : 'Đã lưu nháp kết quả',
          }),
        onError: (error) => setSaveError(errorOf(error).message),
      },
    );
  }

  return (
    <div className="mx-auto flex w-full max-w-xl flex-col gap-4 p-4">
      <UnsavedGuard when={dirty} />
      <nav aria-label="Đường dẫn" className="text-caption text-fg-muted">
        <Link to="/gv/viec-can-lam" className="inline-flex min-h-11 items-center underline">
          Cần làm
        </Link>
        {' › Chấm kiểm tra đầu vào'}
      </nav>
      <header className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="text-caption text-fg-muted">{t.code}</p>
          <h1 className="text-h3">{t.student_name ?? 'Học sinh'}</h1>
        </div>
        <Tag tone={editable ? 'warning' : 'success'}>{t.status_name ?? t.status_code}</Tag>
      </header>
      {!editable && (
        <Alert tone="success">
          Đã nộp kết quả cho sale. Phiếu đã Hoàn thành, chỉ xem. Sửa sau khi Hoàn thành do người phụ
          trách làm bên CRM.
        </Alert>
      )}
      {saveError && <Alert tone="danger">{saveError}</Alert>}
      <dl className="grid grid-cols-2 gap-x-3 gap-y-2 rounded-control border border-border p-3 text-body">
        <Info label="Môn, khối" value={[t.subject_name, t.grade_name].filter(Boolean).join(' ')} />
        <Info label="Hình thức" value={t.mode_name} />
        <Info label="Cấp độ đề" value={t.level_name} />
        <Info
          label="Làm bài"
          value={[formatDateTime(t.scheduled_at), t.room_name].filter(Boolean).join(' · ')}
        />
      </dl>
      <Field label="Điểm (0 đến 10)" required error={errors.score}>
        {(field) => (
          <input
            {...field}
            className={INPUT_CLASS}
            inputMode="decimal"
            value={draft.score}
            disabled={!editable}
            onChange={(e) => patch({ score: e.target.value })}
          />
        )}
      </Field>
      <Chips
        label="Trình độ đề xuất"
        options={sheet.levels}
        value={draft.level}
        disabled={!editable}
        error={errors.level}
        onPick={(level) => patch({ level })}
      />
      <Chips
        label="Phân loại đề xuất"
        options={sheet.frameworks}
        value={draft.framework}
        disabled={!editable}
        error={errors.framework}
        onPick={(framework) => patch({ framework })}
      />
      <TextAreaField
        label="Nhận xét"
        value={draft.note}
        disabled={!editable}
        error={errors.note}
        onChange={(e) => patch({ note: e.target.value })}
      />
      {editable && (
        <>
          <p className="text-caption text-fg-muted">
            Lưu chỉ lưu nháp. Trả về sale là nộp kết quả, cần đủ điểm, trình độ, phân loại, nhận
            xét.
          </p>
          <StickyActionBar>
            {dirty && <span className="text-caption text-fg-muted">Chưa lưu</span>}
            <Button loading={save.isPending} onClick={() => run(false)}>
              Lưu
            </Button>
            <Button variant="primary" loading={save.isPending} onClick={() => run(true)}>
              Trả về sale
            </Button>
          </StickyActionBar>
        </>
      )}
    </div>
  );
}

function Info({ label, value }: { label: string; value: string | null }) {
  return (
    <div className="min-w-0">
      <dt className="text-caption text-fg-muted">{label}</dt>
      <dd className="font-medium">{value || '—'}</dd>
    </div>
  );
}

function Chips({
  label,
  options,
  value,
  disabled,
  error,
  onPick,
}: {
  label: string;
  options: { code: string; name: string }[];
  value: string;
  disabled: boolean;
  error: string | undefined;
  onPick: (code: string) => void;
}) {
  return (
    <fieldset className="flex flex-col gap-1">
      <legend className="text-caption font-semibold text-fg-label after:text-on-danger-subtle after:content-['_*']">
        {label}
      </legend>
      <div role="group" aria-label={label} className="flex flex-wrap gap-2">
        {options.map((o) => (
          <button
            key={o.code}
            type="button"
            aria-pressed={o.code === value}
            disabled={disabled}
            onClick={() => onPick(o.code)}
            className={cn(
              'min-h-11 min-w-11 rounded-control border px-3 text-body',
              o.code === value
                ? 'border-brand-600 bg-brand-100 text-brand-800'
                : 'border-border bg-surface',
            )}
          >
            {o.name}
          </button>
        ))}
      </div>
      {error && (
        <p role="alert" className="text-caption text-on-danger-subtle">
          {error}
        </p>
      )}
    </fieldset>
  );
}
