// CH-07 Rubric nhận xét (Cấu hình · K10, máy tính, chỉ Admin). Khung: design/hmt-canvas-1aab CH07_* (bảng mô tả mức 1 đến 5 theo môn và phiên bản).
// Luật: R-GV-01, R-V2-19, S03-10; mô tả sửa tự do nhưng chỉ áp cho buổi mở nhận xét sau (buổi giữ bản chụp); tiêu chí đã dùng chỉ Ngừng.
// Tab «Câu mẫu lời nhắn phụ huynh» làm theo LUẬT R-V2-39 (24 câu = loại buổi × mức 1–4 × 3 câu); canvas CH07_cau_mau vẽ theo tiêu chí × mức 1–5
// nên VÊNH LUẬT (Chat chốt 18/11: luật thắng, báo Design). Chưa làm: Ngừng/Dùng lại tiêu chí (khung không có nút).
// Chữ mô tả mức trong DB là chữ mẫu, chờ sheet Rubric chính thức; máy chủ quyết quyền (get_rubric chỉ Admin), trang hiện lỗi của DB.
import { useState } from 'react';
import { errorOf, FORBIDDEN_CODE, useDb } from '../../lib/db';
import { UnsavedGuard, FormDialog } from '../../ui/Dialogs';
import { Button } from '../../ui/Button';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Field, TextField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import {
  GROUPS,
  LEVELS,
  PHRASE_KINDS,
  PHRASE_LEVELS,
  changedCells,
  changedPhrases,
  criteriaOfGroup,
  draftKey,
  emptyCells,
  groupNote,
  phraseKey,
  valueOf,
  versionLabel,
  type Draft,
  type Rubric,
} from './rubricLogic';
import {
  createRubricVersion,
  savePhrases,
  saveLevelDescs,
  usePhrases,
  useRefreshRubric,
  useRubric,
  useRubricSubjects,
} from './useRubricData';

const DEFAULT_SUBJECT = 'TOAN';

export function RubricPage() {
  const subjects = useRubricSubjects();
  const [subject, setSubject] = useState(DEFAULT_SUBJECT);
  const [versionId, setVersionId] = useState<string | null>(null);
  const [tab, setTab] = useState<'mo-ta' | 'cau-mau'>('mo-ta');
  const set = subjects.data?.find((s) => s.code === subject)?.set ?? 'TOAN';
  const rubric = useRubric(set, versionId);

  const header = (
    <div className="flex flex-col gap-1">
      <h1 className="text-h2">Rubric nhận xét</h1>
      <p className="text-body text-fg-muted">
        Mô tả mức 1 đến 5 hiện cho giáo viên khi chấm nhận xét. Sửa chỉ áp cho buổi tạo sau lúc sửa;
        kết quả cũ giữ tiêu chí đã chấm.
      </p>
    </div>
  );

  if (rubric.isError) {
    const error = errorOf(rubric.error);
    const forbidden = error.code === FORBIDDEN_CODE;
    return (
      <div className="mx-auto flex max-w-6xl flex-col gap-4">
        {header}
        <StateView
          kind={forbidden ? 'forbidden' : 'error'}
          title={forbidden ? 'Bạn không có quyền xem màn này' : 'Không tải được rubric'}
          actions={
            forbidden ? undefined : <Button onClick={() => void rubric.refetch()}>Thử lại</Button>
          }
        >
          {forbidden
            ? 'Rubric nhận xét chỉ dành cho Admin. Liên hệ quản trị viên nếu bạn cần quyền.'
            : error.message}
        </StateView>
      </div>
    );
  }

  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-4">
      {header}
      <div role="group" aria-label="Nội dung rubric" className="flex gap-1">
        <Button
          variant={tab === 'mo-ta' ? 'primary' : 'secondary'}
          aria-pressed={tab === 'mo-ta'}
          onClick={() => setTab('mo-ta')}
        >
          Mô tả mức
        </Button>
        <Button
          variant={tab === 'cau-mau' ? 'primary' : 'secondary'}
          aria-pressed={tab === 'cau-mau'}
          onClick={() => setTab('cau-mau')}
        >
          Câu mẫu lời nhắn phụ huynh
        </Button>
      </div>
      {tab === 'cau-mau' ? (
        <PhrasesPanel />
      ) : (
        <>
          <div className="flex flex-wrap items-end gap-3">
            <Field label="Môn">
              {(field) => (
                <Select
                  id={field.id}
                  label="Môn"
                  value={subject}
                  onChange={(v) => {
                    setSubject(v);
                    setVersionId(null);
                  }}
                  options={(
                    subjects.data ?? [{ code: DEFAULT_SUBJECT, name: 'Toán', set: 'TOAN' }]
                  ).map((s) => ({ value: s.code, label: s.name }))}
                />
              )}
            </Field>
            {rubric.data && (
              <Field label="Phiên bản">
                {(field) => (
                  <Select
                    id={field.id}
                    label="Phiên bản"
                    value={rubric.data.version.id}
                    onChange={(v) => setVersionId(v)}
                    options={rubric.data.versions.map((v) => ({
                      value: v.id,
                      label: versionLabel(v),
                    }))}
                  />
                )}
              </Field>
            )}
          </div>
          {!rubric.data ? (
            <Spinner label="Đang tải rubric…" />
          ) : (
            <RubricTable
              key={`${rubric.data.version.id}`}
              rubric={rubric.data}
              set={set === 'TOAN' ? 'TOAN' : 'MON_PHU'}
              onVersionCreated={() => setVersionId(null)}
            />
          )}
        </>
      )}
    </div>
  );
}

function PhrasesPanel() {
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshRubric();
  const phrases = usePhrases();
  const [kind, setKind] = useState(PHRASE_KINDS[0]!.code);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  if (phrases.isError)
    return (
      <StateView
        kind="error"
        title="Không tải được câu mẫu"
        actions={<Button onClick={() => void phrases.refetch()}>Thử lại</Button>}
      >
        {errorOf(phrases.error).message}
      </StateView>
    );
  if (!phrases.data) return <Spinner label="Đang tải câu mẫu…" />;
  const rows = phrases.data;
  const changes = changedPhrases(rows, draft);
  const save = () => {
    setBusy(true);
    setError(null);
    void savePhrases(supabase, changes)
      .then(async () => {
        await refresh();
        setEditing(false);
        setDraft({});
        toast({ title: 'Đã lưu câu mẫu.' });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };
  return (
    <div className="flex flex-col gap-3">
      <UnsavedGuard when={editing && changes.length > 0} />
      <div className="flex flex-wrap items-end justify-between gap-3">
        <Field label="Loại buổi">
          {(field) => (
            <Select
              id={field.id}
              label="Loại buổi"
              value={kind}
              disabled={editing}
              onChange={setKind}
              options={PHRASE_KINDS.map((k) => ({ value: k.code, label: k.label }))}
            />
          )}
        </Field>
        <div className="flex items-center gap-2">
          {editing ? (
            <>
              <Button
                onClick={() => {
                  setEditing(false);
                  setDraft({});
                  setError(null);
                }}
                disabled={busy}
              >
                Huỷ
              </Button>
              <Button variant="primary" loading={busy} onClick={save}>
                Lưu
              </Button>
            </>
          ) : (
            <Button onClick={() => setEditing(true)}>Sửa</Button>
          )}
        </div>
      </div>
      <p className="text-caption text-fg-muted">
        Hệ thống tự soạn lời nhắn phụ huynh từ điểm: mỗi loại buổi có 3 câu cho mỗi mức 1 đến 4. Chỉ
        sửa chữ, không thêm bớt câu.
      </p>
      {error && <Alert tone="danger">{error}</Alert>}
      <div className="overflow-x-auto rounded-box border border-border bg-surface">
        <table className="w-full min-w-[720px] table-fixed border-collapse text-body">
          <caption className="sr-only">Câu mẫu lời nhắn phụ huynh</caption>
          <thead>
            <tr className="bg-surface-subtle text-left text-caption text-fg-label">
              <th scope="col" className="w-24 p-2">
                Mức
              </th>
              {[1, 2, 3].map((n) => (
                <th key={n} scope="col" className="p-2">
                  Câu {n}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {PHRASE_LEVELS.map((level) => (
              <tr key={level} className="border-t border-border align-top">
                <th scope="row" className="p-2 text-left font-semibold">
                  Mức {level}
                </th>
                {[1, 2, 3].map((seq) => {
                  const row = rows.find(
                    (r) => r.kind === kind && r.level === level && r.seq === seq,
                  );
                  if (!row) return <td key={seq} className="p-2" />;
                  const key = phraseKey(row);
                  return (
                    <td key={seq} className="p-2">
                      {editing ? (
                        <textarea
                          aria-label={`Mức ${level}, câu ${seq}`}
                          className="min-h-20 w-full rounded-control border border-border bg-surface p-1 text-caption"
                          value={draft[key] ?? row.phrase}
                          onChange={(e) => setDraft((d) => ({ ...d, [key]: e.target.value }))}
                        />
                      ) : (
                        <span className="text-caption">{row.phrase}</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function RubricTable({
  rubric,
  set,
  onVersionCreated,
}: {
  rubric: Rubric;
  set: 'TOAN' | 'MON_PHU';
  onVersionCreated: () => void;
}) {
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshRubric();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<Draft>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const active = rubric.version.status === 'DANG_DUNG';
  const changes = changedCells(rubric, draft);
  const dirty = editing && changes.length > 0;

  const save = () => {
    if (emptyCells(changes)) {
      setError('Mô tả mức không được để trống.');
      return;
    }
    setBusy(true);
    setError(null);
    void saveLevelDescs(supabase, rubric.version.id, changes)
      .then(async () => {
        await refresh();
        setEditing(false);
        setDraft({});
        toast({ title: 'Đã lưu mô tả mức. Chỉ áp cho buổi tạo sau.' });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  return (
    <div className="flex flex-col gap-3">
      <UnsavedGuard when={dirty} />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-caption text-fg-muted">
          {set === 'TOAN'
            ? 'Đại số và Hình học dùng bộ tiêu chí của Toán.'
            : 'Bộ tiêu chí của môn phụ.'}
        </p>
        <div className="flex items-center gap-2">
          {editing ? (
            <>
              <span className="text-caption text-fg-muted">Đang sửa</span>
              <Button
                onClick={() => {
                  setEditing(false);
                  setDraft({});
                  setError(null);
                }}
                disabled={busy}
              >
                Huỷ
              </Button>
              <Button variant="primary" loading={busy} onClick={save}>
                Lưu
              </Button>
            </>
          ) : (
            <>
              {active && <Button onClick={() => setEditing(true)}>Sửa</Button>}
              <Button onClick={() => setCreating(true)}>Tạo phiên bản</Button>
            </>
          )}
        </div>
      </div>
      {!active && (
        <Alert tone="info">Phiên bản này đã ngừng, chỉ xem. Sửa ở phiên bản đang dùng.</Alert>
      )}
      {error && <Alert tone="danger">{error}</Alert>}
      <div className="overflow-x-auto rounded-box border border-border bg-surface">
        <table className="w-full min-w-[960px] table-fixed border-collapse text-body">
          <caption className="sr-only">Mô tả mức theo tiêu chí</caption>
          <thead>
            <tr className="bg-surface-subtle text-left text-caption text-fg-label">
              <th scope="col" className="w-48 p-2">
                Tiêu chí
              </th>
              {LEVELS.map((l) => (
                <th key={l} scope="col" className="p-2">
                  Mức {l}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {GROUPS.map((g) => (
              <GroupRows
                key={g.code}
                label={g.label}
                note={groupNote(g.code, set)}
                criteria={criteriaOfGroup(rubric, g.code)}
                editing={editing && active}
                draft={draft}
                onChange={(id, level, value) =>
                  setDraft((d) => ({ ...d, [draftKey(id, level)]: value }))
                }
              />
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-caption text-fg-muted">
        Chữ trong bảng là chữ mẫu, chờ sheet Rubric chính thức. Tiêu chí đã dùng chỉ Ngừng, không
        xoá.
      </p>
      {creating && (
        <CreateVersionDialog
          set={set}
          onClose={() => setCreating(false)}
          onCreated={async () => {
            setCreating(false);
            await refresh();
            onVersionCreated();
            toast({ title: 'Đã tạo phiên bản mới.' });
          }}
        />
      )}
    </div>
  );
}

function GroupRows({
  label,
  note,
  criteria,
  editing,
  draft,
  onChange,
}: {
  label: string;
  note: string;
  criteria: Rubric['criteria'];
  editing: boolean;
  draft: Draft;
  onChange: (criterionId: string, level: string, value: string) => void;
}) {
  return (
    <>
      <tr className="bg-surface-subtle">
        <th scope="colgroup" colSpan={6} className="p-2 text-left text-caption font-semibold">
          {label} <span className="font-normal text-fg-muted">· {note}</span>
        </th>
      </tr>
      {criteria.map((c) => (
        <tr key={c.id} className="border-t border-border align-top">
          <th scope="row" className="p-2 text-left font-semibold">
            {c.name}
            {!c.is_active && <span className="block text-caption text-fg-muted">Đã ngừng</span>}
          </th>
          {LEVELS.map((l) => (
            <td key={l} className="p-2">
              {editing ? (
                <textarea
                  aria-label={`${c.name}, mức ${l}`}
                  className="min-h-20 w-full rounded-control border border-border bg-surface p-1 text-caption"
                  value={valueOf(c, l, draft)}
                  onChange={(e) => onChange(c.id, l, e.target.value)}
                />
              ) : (
                <span className="text-caption">{c.levels[l] ?? ''}</span>
              )}
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}

function CreateVersionDialog({
  set,
  onClose,
  onCreated,
}: {
  set: string;
  onClose: () => void;
  onCreated: () => Promise<void>;
}) {
  const supabase = useDb();
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title="Phiên bản mới"
      confirmLabel="Tạo phiên bản"
      canSubmit
      busy={busy}
      error={error}
      onSubmit={() => {
        setBusy(true);
        setError(null);
        void createRubricVersion(supabase, set, note)
          .then(onCreated)
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <p className="text-body">
          Phiên bản mới chỉ áp cho buổi tạo sau lúc lưu. Kết quả cũ giữ tiêu chí đã chấm.
        </p>
        <TextField
          label="Ghi chú (không bắt buộc)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
