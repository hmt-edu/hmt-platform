// Danh sách em của lead, cơ hội (TS-02, TS-08, canvas 9933; R-CRM-23): thẻ em, «+ Thêm em», sửa, bỏ em.
// Em đã gắn hồ sơ học sinh chỉ đọc ở đây («Sửa ở hồ sơ học sinh»). Điều khiển mờ khi màn đang ở chế độ sửa (tránh lệch với bản nháp của màn).
// Luật do hàm DB kiểm; hộp chỉ hiện lỗi của chúng. Số em tối đa lấy từ tham số prospect_max_students.
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { Button } from '../../ui/Button';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { useToast } from '../../ui/toastContext';
import { dateToIso, isoToDate } from '../../pages/lead/leadRecord';
import {
  EMPTY_EM_DRAFT,
  addEmText,
  draftOfStudent,
  emLabel,
  emPayload,
  emptyListText,
  fullListText,
  validateEmDraft,
  type EmDraft,
  type ProspectStudent,
} from './prospectLogic';
import {
  addProspectStudent,
  removeProspectStudent,
  updateProspectStudent,
  useParentChildren,
  type Entity,
} from './useProspect';

type Props = {
  entity: Entity;
  /** Id lead hoặc cơ hội. */
  recordId: string;
  students: ProspectStudent[];
  /** Cơ hội: phụ huynh để chọn con có sẵn. */
  parent?: { id: string; code: string; name: string } | undefined;
  /** Từ L5 trở lên (cơ hội): bắt buộc năm sinh. */
  requireYear: boolean;
  canEdit: boolean;
  /** Màn đang ở chế độ sửa: khoá các nút để không lệch bản nháp. */
  pageEditing: boolean;
  onChanged: () => void;
};

export function ProspectStudents({
  entity,
  recordId,
  students,
  parent,
  requireYear,
  canEdit,
  pageEditing,
  onChanged,
}: Props) {
  const supabase = useDb();
  const toast = useToast();
  const max = useIntSetting('prospect_max_students');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [dialog, setDialog] = useState<
    | { kind: 'add' }
    | { kind: 'edit'; line: ProspectStudent }
    | { kind: 'remove'; line: ProspectStudent }
    | null
  >(null);
  const selected = students.find((s) => s.id === selectedId) ?? students[0] ?? null;
  const fullText = fullListText(students.length, max);
  const locked = !canEdit || pageEditing;

  return (
    <section aria-labelledby="prospect-students-title" className="flex min-w-0 flex-col">
      <h3
        id="prospect-students-title"
        className="mb-1 text-caption font-semibold tracking-wide text-fg-muted uppercase"
      >
        Danh sách em
      </h3>
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2">
          {students.map((s) => (
            <button
              key={s.id}
              type="button"
              aria-pressed={selected?.id === s.id}
              onClick={() => setSelectedId(s.id)}
              className={`rounded-control border px-3 py-1.5 text-body ${
                selected?.id === s.id
                  ? 'border-accent bg-accent-subtle font-semibold'
                  : 'border-border bg-surface'
              }`}
            >
              {emLabel(s)}
              {s.student_code && (
                <span className="ml-2 text-caption text-fg-muted">{s.student_code}</span>
              )}
            </button>
          ))}
          {canEdit && (
            <Button
              icon="plus"
              disabled={fullText !== null || pageEditing}
              onClick={() => setDialog({ kind: 'add' })}
              {...(pageEditing ? { title: 'Lưu hoặc Huỷ chỉnh sửa trước khi thêm em.' } : {})}
            >
              Thêm em
            </Button>
          )}
          {fullText && <span className="text-caption text-fg-muted">{fullText}</span>}
        </div>
        {selected === null ? (
          <p className="text-body text-fg-muted">{emptyListText(entity)}</p>
        ) : (
          <div className="flex flex-col gap-2">
            <dl className="grid grid-cols-1 gap-y-1">
              <Row label="Tên học sinh" value={selected.full_name} />
              <Row
                label="Ngày sinh"
                value={
                  selected.birth_date ? formatDate(`${selected.birth_date}T00:00:00+07:00`) : null
                }
              />
              <Row
                label="Năm sinh"
                value={selected.birth_year === null ? null : String(selected.birth_year)}
              />
              <Row label="Trường học" value={selected.school} />
              <Row label="Học lực tự đánh giá" value={selected.self_rating} />
              <Row label="Mục tiêu" value={selected.goal} />
            </dl>
            <div className="flex flex-wrap items-center gap-2">
              {selected.student_id ? (
                <Link
                  className="text-body font-medium text-link hover:underline"
                  to={`/crm/hoc-sinh/${selected.student_id}`}
                >
                  Sửa ở hồ sơ học sinh
                </Link>
              ) : (
                canEdit && (
                  <Button
                    disabled={locked}
                    onClick={() => setDialog({ kind: 'edit', line: selected })}
                  >
                    Sửa em
                  </Button>
                )
              )}
              {canEdit && (
                <Button
                  disabled={locked}
                  onClick={() => setDialog({ kind: 'remove', line: selected })}
                >
                  Bỏ em
                </Button>
              )}
            </div>
          </div>
        )}
      </div>
      {dialog?.kind === 'add' || dialog?.kind === 'edit' ? (
        <EmDialog
          key={dialog.kind === 'edit' ? dialog.line.id : 'add'}
          entity={entity}
          recordId={recordId}
          line={dialog.kind === 'edit' ? dialog.line : null}
          students={students}
          parent={parent}
          requireYear={requireYear}
          onClose={() => setDialog(null)}
          onSaved={(message) => {
            setDialog(null);
            toast({ title: message });
            onChanged();
          }}
          supabase={supabase}
        />
      ) : null}
      {dialog?.kind === 'remove' && (
        <RemoveDialog
          line={dialog.line}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            setSelectedId(null);
            toast({ title: 'Đã bỏ em khỏi danh sách.' });
            onChanged();
          }}
        />
      )}
    </section>
  );
}

/** Một dòng nhãn và giá trị; giá trị trống thì ẩn cả dòng (K06: không hiện «—» tràn lan). Giá trị dài xuống dòng trong ô của mình, không đè lên nhãn. */
function Row({ label, value }: { label: string; value: string | null }) {
  if (value === null || value === '') return null;
  return (
    <div className="flex gap-2">
      <dt className="w-40 shrink-0 text-body text-fg-muted">{label}</dt>
      <dd className="min-w-0 text-body break-words">{value}</dd>
    </div>
  );
}

function EmDialog({
  entity,
  recordId,
  line,
  students,
  parent,
  requireYear,
  onClose,
  onSaved,
  supabase,
}: {
  entity: Entity;
  recordId: string;
  line: ProspectStudent | null;
  students: ProspectStudent[];
  parent: Props['parent'];
  requireYear: boolean;
  onClose: () => void;
  onSaved: (message: string) => void;
  supabase: ReturnType<typeof useDb>;
}) {
  const [mode, setMode] = useState<'new' | 'existing'>('new');
  const [draft, setDraft] = useState<EmDraft>(line ? draftOfStudent(line) : EMPTY_EM_DRAFT);
  const [childId, setChildId] = useState('');
  const [tried, setTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const canPickExisting = entity === 'OPPORTUNITY' && line === null && parent !== undefined;
  const children = useParentChildren(parent?.id ?? null, canPickExisting && mode === 'existing');
  const taken = new Set(students.map((s) => s.student_id).filter(Boolean));
  const available = (children.data ?? []).filter((c) => !taken.has(c.id));
  const errors = validateEmDraft(draft, requireYear, new Date().getFullYear());
  const set = (patch: Partial<EmDraft>) => setDraft((d) => ({ ...d, ...patch }));
  const picking = mode === 'existing';
  const canSubmit = picking ? childId !== '' : true;

  const submit = async () => {
    if (!picking) {
      setTried(true);
      if (errors.fullName || errors.birthYear) return;
    }
    setBusy(true);
    setError(null);
    try {
      if (line) await updateProspectStudent(supabase, line.id, emPayload(draft));
      else
        await addProspectStudent(
          supabase,
          entity,
          recordId,
          picking ? { student_id: childId } : emPayload(draft),
        );
      onSaved(line ? 'Đã lưu em.' : 'Đã thêm em.');
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={line ? 'Sửa em' : 'Thêm em'}
      confirmLabel={line ? 'Lưu' : 'Thêm em'}
      canSubmit={canSubmit}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        {!line && <p className="text-caption text-fg-muted">{addEmText.note(entity)}</p>}
        {canPickExisting && (
          <fieldset className="flex gap-4">
            <legend className="sr-only">Cách thêm em</legend>
            <label className="flex items-center gap-2 text-body">
              <input
                type="radio"
                name="em-mode"
                checked={mode === 'new'}
                onChange={() => setMode('new')}
              />
              Em mới
            </label>
            <label className="flex items-center gap-2 text-body">
              <input
                type="radio"
                name="em-mode"
                checked={mode === 'existing'}
                onChange={() => setMode('existing')}
              />
              Chọn con có sẵn
            </label>
          </fieldset>
        )}
        {picking && parent ? (
          <fieldset className="flex flex-col gap-2">
            <legend className="text-caption text-fg-muted">
              {addEmText.existingNote(parent.name, parent.code)}
            </legend>
            {children.isPending && <p className="text-body text-fg-muted">Đang tải…</p>}
            {children.isError && (
              <p className="text-body text-danger">{errorOf(children.error).message}</p>
            )}
            {children.isSuccess && available.length === 0 && (
              <p className="text-body text-fg-muted">Không còn con nào của phụ huynh để chọn.</p>
            )}
            {available.map((c) => (
              <label key={c.id} className="flex items-center gap-2 text-body">
                <input
                  type="radio"
                  name="em-child"
                  checked={childId === c.id}
                  onChange={() => setChildId(c.id)}
                />
                {c.full_name}
                <span className="text-caption text-fg-muted">{c.code}</span>
              </label>
            ))}
          </fieldset>
        ) : (
          <>
            <TextField
              label="Họ tên em"
              required
              value={draft.fullName}
              error={tried ? errors.fullName : undefined}
              onChange={(e) => set({ fullName: e.target.value })}
            />
            <div className="grid grid-cols-2 gap-3">
              <DateInput
                label="Ngày sinh"
                value={isoToDate(draft.birthDate)}
                onChange={(d) => set({ birthDate: dateToIso(d) })}
              />
              <TextField
                label="Năm sinh"
                inputMode="numeric"
                value={draft.birthYear}
                help={requireYear ? 'Bắt buộc từ L5.' : undefined}
                error={tried ? errors.birthYear : undefined}
                onChange={(e) => set({ birthYear: e.target.value })}
              />
            </div>
            <TextField
              label="Trường học"
              value={draft.school}
              onChange={(e) => set({ school: e.target.value })}
            />
            <Field label="Học lực tự đánh giá">
              {(f) => (
                <input
                  {...f}
                  value={draft.selfRating}
                  placeholder="VD Khá, yếu phần Hình"
                  onChange={(e) => set({ selfRating: e.target.value })}
                  className="w-full rounded-control border border-border px-3 py-2"
                />
              )}
            </Field>
            <TextField
              label="Mục tiêu"
              value={draft.goal}
              onChange={(e) => set({ goal: e.target.value })}
            />
          </>
        )}
      </div>
    </FormDialog>
  );
}

function RemoveDialog({
  line,
  onClose,
  onDone,
}: {
  line: ProspectStudent;
  onClose: () => void;
  onDone: () => void;
}) {
  const supabase = useDb();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <ConfirmDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={`Bỏ em ${emLabel(line)}?`}
      description="Em bị bỏ khỏi danh sách em. Hồ sơ học sinh (nếu có) không bị xoá. Em đã có phiếu kiểm tra, báo giá hoặc đơn thì không bỏ được."
      confirmLabel="Bỏ em"
      tone="danger"
      busy={busy}
      error={error}
      onConfirm={() => {
        setBusy(true);
        setError(null);
        removeProspectStudent(supabase, line.id)
          .then(onDone)
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    />
  );
}
